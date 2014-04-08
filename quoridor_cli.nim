# A command line interface for the quoridor ai in quoridor_board.nim
#
# Author: Peter Massey-Plantinga
# Date: 4-3-14

import parseopt
from strutils import strip
from parseutils import parseFloat
import quoridor_board

var times = [0.0, 0.0]
var moves = newSeq[string]()

# Parse the args.
# Usage:
#   --player1time and --player2time are specified in seconds
#     0 means human player
#   
#   any other argument is interpreted as a move
for kind, key, val in getopt():
  case kind
  of cmdArgument:
    # Every unnamed argument is a move
    moves.add(key)
  of cmdLongOption, cmdShortOption:
    # Only valid argument names are player1time and player2time
    case key
    of "player1time":
      discard val.parseFloat(times[0])
    of "player2time":
      discard val.parseFloat(times[1])
    else:
      raise newException(EInvalidKey, "Unknown option: " & key)
  of cmdEnd:
    assert false # Inconceivable

# Print the board nicely
proc print( b: ref Quoridor_Board ) =
  stdout.write("\n")

  # Draw the walls of player 2
  for j in 1 .. 2:
    for i in 1 .. b.wall_count(2):
      stdout.write(" |  ")
    stdout.write("\n")

  # Draw the board header
  stdout.write("\n   ")
  for c in 'a' .. 'i':
    stdout.write("   " & c)
  stdout.write("\n   ")
  for i in 0 .. 8:
    stdout.write("+---")
  stdout.writeln("+")

  # Draw the board with low y at the bottom
  for i in 0 .. 16:
    if i mod 2 == 0:
      var number = $(int(i / 2 + 1))

      # append a space to shorter numbers so formatting looks nice
      if number.len == 1:
        number &= " "
      stdout.write(number, " |")
    else:
      stdout.write("   +")

    for j in 0 .. 16:
      # If we're at a wall location
      if j mod 2 == 1:
        if b.board_value(j, i) == 3:
          stdout.write("#")
        else:
          stdout.write("|")

      elif i mod 2 == 0:
        # Even rows have pieces
        # Write a piece if one exists here
        if b.board_value(j, i) != 0:
          stdout.write(" ", b.board_value(j, i), " ")
        else:
          stdout.write("   ")

      else:
        # Odd rows have walls
        if b.board_value(j, i) == 3:
          stdout.write("###")
        else:
          stdout.write("---")

    if i mod 2 == 0:
      stdout.writeln("|")
    else:
      stdout.writeln("+")

  stdout.write("   ")
  for i in 1 .. 9:
    stdout.write("+---")
  stdout.writeln("+\n")

  # Draw player 1's walls
  for j in 1 .. 2:
    for i in 1 .. b.wall_count(1):
      stdout.write(" |  ")
    stdout.write("\n")
  stdout.write("\n")


# Start main program

var qb = init_Quoridor_Board()

if moves != nil:
  for m in moves:
    discard qb.move(m)

qb.print()

var move: string
var winner, turn: int

# Until the game is over, read moves from the command line
while true:

  if times[turn] == 0:
    # If player is human
    move = strip(stdin.readline)
    if move == nil:
      break

    elif move == "u":
      qb.undo(2)
      turn = (turn + 1) mod 2

    else:
      try:
        winner = qb.move(move)
        if winner != 0:
          qb.print()
          echo "Player " & $winner & " wins!"
          break
      except EInvalidValue:
        echo "Invalid move"

  else:
    # Player is a computer
    echo "turn is " & $turn
    move = qb.ai_move(times[turn])
    if move.len > 2 and move[2] == 'w':
      qb.print()
      echo "Player " & $(turn + 1) & " wins!"
      break

  qb.print()
  turn = (turn + 1) mod 2

