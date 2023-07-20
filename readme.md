# Draughts

## What is this?
This is the game Draughts (known as Checkers in the USA), where two players
try to capture the opponents pieces or prevent them from having a legal move
within a eight by eight board. This game is written in [Nim](https://nim-lang.org).

## How do I compile it?
Make sure Nim (1.6.x or higher) is downloaded and installed as per the Nim
website's instructions, including a C compiler like MinGW (GCC).  You can check
both at the command line using:

    nim -v
    gcc -v

This should display the versions of each if they're installed and available on
the path.

You can compile this game using Nimble, the package manager that comes with Nim.
In the root directory (where the draughts.nimble file is):

    nimble build -d:release

... which will install the dependencies and compile the source.  If you've
already installed the dependencies, you can run the Nim compiler directly:

    cd src
    nim c -r draughts

For a smaller executable, you can add the 'strip' flag, although that takes a
little longer (and also consider uncommenting the passL/passC stuff in the
draughts.nim.cfg file, or pass the -d:lto flag to the command line):

    cd src
    nim c -d:strip -r draughts

## How do I play it?
Here's an article on the rules of Draughts:
https://www.mastersofgames.com/rules/draughts-rules.htm

You select a piece by clicking it with the mouse, then click a destination.
Note that if captures are available, they must be made (if there are multiple
captures then you can choose which one to make).

The game ends when all the opponent pieces are captures or if a player can't
make a legal move.

If you want to see debug output (i.e. echo statements), remove the '--app:gui'
line in draughts.nim.cfg.  This has the side effect of opening a terminal window
when the app runs when you run it outside an IDE though.

## Any other notes?
This game uses Treeform's great libraries.  I definitely recommend checking his
GitHub repositories because he has libraries for everything:

https://github.com/treeform

Also an honorary mention to Guzba, his comrade in arms:
https://github.com/guzba

As to why I wrote this game, I simply wanted to get back into programming for
fun outside of work.  I've reached the "I know how to x" stage and don't
actually _do X_, which is a counterproductive mindset.  As a result, I'm trying
to put out knock out as many simple games as I can to get into the habit. These
will include simple things like this as well as more interesting stuff like
Minesweeper and Solitaire.

## Fixes / Rainy day work

* Bug - if you click a square and mouse over opposite colour piece, it highlights
* Improvement - use bit boards rather than looping all the time
* Improvement - AI opponent (need to make sure it's not perfect!)
* Improvement - drag/drop support for moving pieces