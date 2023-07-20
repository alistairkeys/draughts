import std/[options, os, sequtils]

type
  GameState* = enum
    inProgress, whiteWin, blackWin

  PieceColour* = enum
    white = 0, black = 1

  Piece* = object
    x*, y*: int
    king*: bool
    colour*: PieceColour

  PieceMove* = object
    here*, there*: tuple[x, y: int]

  DraughtsGame* = object
    state*: GameState
    captureRequired*: bool
    movedPieceThatCanCapture: Option[Piece]
    playerToMove*: PieceColour
    gamePieces*: array[PieceColour, seq[Piece]]

proc getDataDir*(): string =
  if dirExists("./data"): "data/" else: "src/data/"

func opposite*(colour: PieceColour): PieceColour =
  if colour == white: black else: white

template xy(piece: Piece): tuple[x, y:int] =
  (piece.x, piece.y)

func isCapture(start, dest: tuple[x, y: int]): bool =
  abs(dest.y - start.y) == 2

func anyCaptures(moves: openArray[PieceMove]): bool =
  moves.anyIt(isCapture(it.here, it.there))

func getPieceAt*(game: DraughtsGame, x, y: int, colours: set[PieceColour] = {white, black}): Option[Piece] =
  template findPiece(pieces: openArray[Piece]) =
    for piece in pieces:
      if piece.x == x and piece.y == y and piece.colour in colours:
        return some(piece)
  findPiece(game.gamePieces[black])
  findPiece(game.gamePieces[white])

func canMove*(game: DraughtsGame, piece: Piece, dest: tuple[x, y: int]): bool =

  if dest.x notin 0..7 or dest.y notin 0..7:
    return false

  if game.movedPieceThatCanCapture.isSome and game.movedPieceThatCanCapture.get.xy != piece.xy:
    debugEcho "Nope, a piece needs to continue its capture sequence!"
    return false

  let
    distanceX = (dest.x - piece.x).int8
    distanceY = (dest.y - piece.y).int8
    absDistX = abs(distanceX)

  if absDistX != abs(distanceY) or absDistX notin {1, 2}:
    return false

  # Sign here is the move direction on the y axis - positive for white, negative for black
  let sign = if piece.colour == white: 1'i8 else: -1'i8
  let captureDistance = if piece.king: {-2 * sign, 2 * sign} else: {2 * sign}

  if distanceY == sign or (piece.king and distanceY == -sign):
    if not game.captureRequired:
      return not game.getPieceAt(dest.x, dest.y).isSome
  elif distanceY in captureDistance:
    return not game.getPieceAt(dest.x, dest.y).isSome and
               game.getPieceAt(piece.x + distanceX div 2, piece.y + distanceY div 2, {opposite piece.colour}).isSome

proc removePiece(game: var DraughtsGame, removeFrom: tuple[x, y: int]) =
  for col in game.gamePieces.mitems:
    for idx, piece in col.mpairs:
      if piece.xy == removeFrom:
        col.del idx
        return

proc getValidMoves*(game: DraughtsGame, piece: Piece): seq[PieceMove] =
  for sq in [(-1, -1), (-2, -2), (1, 1), (2, 2), (-1, 1), (-2, 2), (1, -1), (2, -2)]:
    if game.canMove(piece, (piece.x + sq[0], piece.y + sq[1])):
      result.add PieceMove(here: (piece.x, piece.y),
                           there: (piece.x + sq[0], piece.y + sq[1]))

proc moveTo*(game: var DraughtsGame, piece: var Piece, where: tuple[x, y: int]): bool =

  if not game.canMove(piece, where):
    echo "Invalid move!"
    return false

  let capture = isCapture(piece.xy, where)
  echo if capture: "Capture!" else: "Not a capture"

  if capture:
    game.removePiece((piece.x + (where.x - piece.x) div 2,
                      piece.y + (where.y - piece.y) div 2))
    if game.gamePieces[black].len == 0:
      game.state = whiteWin
    elif game.gamePieces[white].len == 0:
      game.state = blackWin

  block changePieceXy:
    for p in game.gamePieces[piece.colour].mitems:
      if p.xy == piece.xy:
        echo "Changing piece XY from ", $piece.xy, " to ", $where
        (piece.x, piece.y) = (where.x, where.y)
        piece.king = piece.king or where.y in {0, 7}
        p = piece
        if game.movedPieceThatCanCapture.isSome:
          game.movedPieceThatCanCapture = some p
        break

  game.captureRequired = false

  var swapPlayer = true
  if capture:
    if anyCaptures(game.getValidMoves(piece)):
      swapPlayer = false
      game.captureRequired = true
      game.movedPieceThatCanCapture = some piece

  if swapPlayer:
    game.playerToMove = opposite game.playerToMove
    game.movedPieceThatCanCapture.reset

    var foundAnyMoves = false

    for p in game.gamePieces[game.playerToMove]:
      let vm = game.getValidMoves p
      if vm.len > 0:
        foundAnyMoves = true
      if anyCaptures vm:
        game.captureRequired = true
        break

    if not foundAnyMoves:
      game.state = if game.playerToMove == white: blackWin else: whiteWin

  return true

proc initGame*(): DraughtsGame =
  result = DraughtsGame(
    state: inProgress,
    captureRequired: false,
    movedPieceThatCanCapture: none(Piece),
    playerToMove: white,
    gamePieces: [newSeq[Piece](), newSeq[Piece]()]
  )

  block addPieces:
    var addWhite = true
    for idx in 0 ..< 24:
      if addWhite:
        result.gamePieces[white].add Piece(x: idx mod 8, y: idx div 8, king: false, colour: white)
      if not addWhite:
        result.gamePieces[black].add Piece(x: idx mod 8, y: 7 - idx div 8, king: false, colour: black)
      addWhite = not addWhite
      if idx in {7, 15}: addWhite = not addWhite
