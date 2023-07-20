import boxy, opengl, staticglfw
import draughtsgame
import std/options

const
  windowWidth = 800
  windowHeight = 400
  squareSize = min(windowWidth div 8, windowHeight div 8)
  boardPx = 8 * squareSize
  blackSquare = rgba(128, 128, 128, 255)
  whiteSquare = rgba(240, 240, 235, 255)

var
  game = initGame()
  squareUnderCursor: Option[tuple[x, y: int]]
  validMoves: seq[PieceMove]
  clickedPiece: Option[Piece]

proc handleKeyPress(window: Window, key, scancode, action, modifiers: cint) {.cdecl.} =
  if action == PRESS:
    if game.state != inProgress and key in {KEY_SPACE}:
      echo "Starting new game"
      game = initGame()
    elif key in {KEY_A .. KEY_Z, KEY_ESCAPE}:
      echo "Pressed a key: ", key
      case key
        of KEY_ESCAPE: window.setWindowShouldClose(1.cint)
        else: discard

func squareIndex(x, y: SomeNumber): tuple[x, y: int] =
  ((x / squareSize).int, ((boardPx - y) / squareSize).int)

proc cursorPosChanged(window: Window, x, y: cdouble) {.cdecl.} =
  var (squareX, squareY) = squareIndex(x, y)
  squareUnderCursor = some (squareX, squareY)
  if not clickedPiece.isSome:
    let piece = game.getPieceAt(squareX, squareY, {game.playerToMove})
    if piece.isSome:
      validMoves = game.getValidMoves(piece.get)
    else:
      squareUnderCursor.reset
      validMoves.reset

proc mouseButtonClicked(window: Window, button, action, modifiers: cint) {.cdecl.} =
  if button == MOUSE_BUTTON_1:
    if clickedPiece.isSome:
      # Either deselect or try to move
      if squareUnderCursor.isSome:
        let sq = squareUnderCursor.get
        if sq != (clickedPiece.get.x, clickedPiece.get.y):
          if game.moveTo(clickedPiece.get, sq):
            clickedPiece.reset
          else:
            echo "Setting clicked piece: ", $sq
            let piece = game.getPieceAt(sq.x, sq.y, {game.playerToMove})
            clickedPiece = piece
    elif squareUnderCursor.isSome:
      echo "Changing clicked piece"
      let sq = squareUnderCursor.get
      clickedPiece = game.getPieceAt(sq.x, sq.y, {game.playerToMove})

    if clickedPiece.isSome:
      validMoves = game.getValidMoves(clickedPiece.get)
    else:
      validMoves.reset

proc generateLetters(bxy: Boxy) =
  var typeface = readTypeface(getDataDir() & "IBMPlexMono-Bold.ttf")
  var font = newFont(typeface)
  font.size = 28
  font.paint = "#000000"
  for ch in {'A'..'Z', 'a'..'z', '0'..'9', ',', '[', ']', '!', '-', '_', '/', '\\', ':'}:
    let arrangement = typeset(@[newSpan($ch, font)], bounds = vec2(32, 32))
    let textImage = newImage(32, 32)
    textImage.fillText(arrangement)
    bxy.addImage("text" & $ch, textImage)

proc drawNormalText(bxy: Boxy, text: string, origin: Vec2) =
  var pos = origin
  for ch in text:
    if ch != ' ':
      bxy.drawImage("text" & $ch, rect = rect(pos, vec2(32, 32)))
    pos.x += 16

proc generateBoard(bxy: Boxy) =
  let boardImage = newImage(boardPx, boardPx)

  let ctx = boardImage.newContext
  ctx.fillStyle = blackSquare
  ctx.fillRect(rect(vec2(0, 0), vec2(boardPx.float32, boardPx.float32)))
  ctx.fillStyle = whiteSquare

  var squareCount = 0
  var x, y: int
  while squareCount < 32:
    defer: inc squareCount
    ctx.fillRect(rect(vec2(x.float32, y.float32), vec2(squareSize.float32, squareSize.float32)))
    inc x, squareSize * 2
    if x >= boardPx:
      inc y, squareSize
      x = if x == boardPx + squareSize: 0 else: squareSize

  bxy.addImage("gameBoard", boardImage)

proc generatePieces(bxy: Boxy) =

  let pieceImage = newImage(squareSize, squareSize)
  let ctx = pieceImage.newContext()

  template drawKingIndicator() =
    ctx.strokeSegment(segment(vec2(22, 16), vec2(22, 36)))
    ctx.strokeSegment(segment(vec2(22, 26), vec2(30, 18)))
    ctx.strokeSegment(segment(vec2(22, 26), vec2(30, 36)))

  ctx.fillStyle = blackSquare
  ctx.fillRect(rect(vec2(0, 0), vec2(squareSize.float32, squareSize.float32)))

  ctx.strokeStyle = "#000000"
  ctx.fillStyle = rgba(255, 255, 255, 255)
  ctx.lineWidth = 3
  ctx.fillCircle(Circle(pos: vec2(squareSize div 2, squareSize div 2),
                          radius: (squareSize div 2) - 5))
  bxy.addImage("piece1", pieceImage)

  drawKingIndicator()
  bxy.addImage("piece1king", pieceImage)

  ctx.strokeStyle = "#FFFFFF"
  ctx.fillStyle = rgba(0, 0, 0, 255)
  ctx.lineWidth = 3
  ctx.fillCircle(Circle(pos: vec2(squareSize div 2, squareSize div 2),
                          radius: (squareSize div 2) - 5))
  bxy.addImage("piece2", pieceImage)

  drawKingIndicator()
  bxy.addImage("piece2king", pieceImage)

proc generateMoveIndicators(bxy: Boxy) =
  let
    pieceImage = newImage(squareSize, squareSize)
    ctx = pieceImage.newContext()

  template generateIndicator(name: string, backgroundColour: Paint) =
    ctx.fillStyle = backgroundColour
    ctx.fillRect(rect(vec2(0, 0), vec2(squareSize.float32, squareSize.float32)))
    ctx.strokeStyle = "#008000"
    ctx.fillStyle = rgba(0, 80, 0, 255)
    ctx.lineWidth = 3
    ctx.fillCircle(Circle(pos: vec2(squareSize div 2, squareSize div 2), radius: 5))
    bxy.addImage(name, pieceImage)

  generateIndicator("whiteSquareMoveIndicator", whiteSquare)
  generateIndicator("blackSquareMoveIndicator", blackSquare)

proc doGame() =
  let windowSize = ivec2(windowWidth, windowHeight)

  if init() == 0:
    quit("Failed to Initialize GLFW.")

  windowHint(RESIZABLE, false.cint)
  windowHint(CONTEXT_VERSION_MAJOR, 4)
  windowHint(CONTEXT_VERSION_MINOR, 1)

  let window = createWindow(windowSize.x, windowSize.y, "Draughts", nil, nil)
  makeContextCurrent(window)

  loadExtensions()

  discard window.setKeyCallback(handleKeyPress)
  discard window.setCursorPosCallback(cursorPosChanged)
  discard window.setMouseButtonCallback(mouseButtonClicked)

  var bxy = newBoxy()

  bxy.addImage("bg", readImage(getDataDir() & "bg.png"))
  bxy.generateLetters()
  bxy.generateBoard()
  bxy.generatePieces()
  bxy.generateMoveIndicators()

  proc display() =
    bxy.beginFrame(windowSize)
    bxy.drawImage("bg", rect = rect(vec2(0, 0), windowSize.vec2))
    bxy.drawImage("gameBoard", rect = rect(vec2(0, 0), vec2(boardPx.float32, boardPx.float32)))

    proc drawPieces(pieces: seq[Piece], image: string) =
      for piece in pieces:
        var tint = color(1, 1, 1, 1)
        if clickedPiece.isSome and piece == clickedPiece.get:
          tint = color(0.5, 1, 0, 1)
        elif squareUnderCursor.isSome:
          let sq = squareUnderCursor.get
          if sq.x == piece.x and sq.y == piece.y:
            tint = color(1, 1, 0, 1)
        let img = if piece.king: image & "king" else: image
        bxy.drawImage(img, rect = rect(vec2((piece.x * squareSize).float32, ((7 - piece.y) * squareSize).float32),
                                       vec2(squareSize.float32, squareSize.float32)),
                           tint = tint)

    drawPieces(game.gamePieces[white], "piece1")
    drawPieces(game.gamePieces[black], "piece2")

    block drawMoveIndicators:
      for mv in validMoves:
        bxy.drawImage("whiteSquareMoveIndicator",
                      rect = rect(vec2((mv.there.x * squareSize).float32, ((7 - mv.there.y) * squareSize).float32),
                                  vec2(squareSize.float32, squareSize.float32)),  tint = color(0, 1, 0, 1))

    const helpTextLeft = boardPx + squareSize
    var y = 24'f32

    case game.state
      of inProgress:
        bxy.drawNormalText("Draughts", vec2(helpTextLeft, y)); y += 48
        let str = if game.playerToMove == white: "White to move" else: "Black to move"
        bxy.drawNormalText(str, vec2(helpTextLeft, y)); y += 36;
        if game.captureRequired:
          bxy.drawNormalText("You must capture!", vec2(helpTextLeft, y))

      of whiteWin:
        bxy.drawNormalText("White wins!", vec2(helpTextLeft, y)); y += 128
        bxy.drawNormalText("Press Space", vec2(helpTextLeft, y));

      of blackWin:
        bxy.drawNormalText("Black wins!", vec2(helpTextLeft, y)); y += 128
        bxy.drawNormalText("Press Space", vec2(helpTextLeft, y))

    bxy.endFrame()
    window.swapBuffers()

  while windowShouldClose(window) != 1:
    display()
    waitEvents()

when isMainModule:
  doGame()
