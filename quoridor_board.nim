# The "Quoridor_Board" class holds all the information
# pertaining to a quoridor board, like the ai
#
# Author: Peter Plantinga
# Start Date: Mar 30, 2014

import tables

# The Quoridor Board type includes all information about a game
type
  Quoridor_Board* = object
    turn: int
    xs, ys, walls, path_lengths, openings: array[0 .. 1, int]
    board: array[0 .. 17, array[0 .. 17, int]]
    moves: seq[array[0 .. 2, int]]
    walls_in_path: array[0 .. 1, array[0 .. 127, bool]]

# Init function returns a reference to a quoridor board.
proc init_Quoridor_Board*(): ref Quoridor_Board =
  var qb = new(Quoridor_Board)
  qb.xs = [8, 8]
  qb.ys = [16, 0]
  qb.board[8][16] = 1
  qb.board[8][0] = 2
  qb.walls = [10, 10]
  qb.moves = @[]
  qb.path_lengths = [8, 8]
  return qb

# Asserts a move is within the limits of the board.
proc is_on_board(d: int): bool {.inline, nosideeffect.} =
  return d >= 0 and d < 17

# Change x, y, o into a number for walls in path checkage
proc linearize(x, y, o: int): int {.inline, nosideeffect.} =
  return x - 1 + 8 * (y - 1) + o

# Accessors for displaying the board to the world
proc wall_count*(qb: ref Quoridor_Board; player: int): int =
  assert player == 1 or player == 2
  return qb.walls[player - 1]
proc board_value*(qb: ref Quoridor_Board; x, y: int): int =
  assert is_on_board(x) and is_on_board(y)
  return qb.board[x][y]

# Translates moves from strings like 'a3h' to a more useful format
# 
# Returns: array of the form [x, y, o]
#   where o is the orientation: 0 for a piece movement,
#   1 for vertical wall placement, 2 for horizontal wall
proc move_string_to_array(move_string: string): array[0 .. 2, int] =

  assert move_string[0] >= 'a' and move_string[0] <= 'i'
  assert move_string[1] >= '1' and move_string[1] <= '9'
  assert len(move_string) < 3 or move_string[2] == 'h' or move_string[2] == 'v'

  var orientation = 0
  var is_wall = 0
  if len(move_string) > 2:
    is_wall = 1
    if move_string[2] == 'v':
      orientation = 1
    elif move_string[2] == 'h':
      orientation = 2

  return [ (int(move_string[0]) - 97) * 2 + is_wall,
    (int(move_string[1]) - 49) * 2 + is_wall,
    orientation ]

# Test move_string_to_array
assert move_string_to_array("e8")[0] == 8
assert move_string_to_array("e8")[1] == 14
assert move_string_to_array("e8")[2] == 0
assert move_string_to_array("b6h")[0] == 3
assert move_string_to_array("b6h")[1] == 11
assert move_string_to_array("b6h")[2] == 2
# Check if this piece movement is legal
#
# Params:
#   x, y = potential new location
#   old_x, old_y = current location
#
# Returns:
#   Whether or not the move is legal
proc is_legal_move(qb: ref Quoridor_Board; x, y, old_x, old_y: int): bool =

  # Check for out-of-bounds
  if not is_on_board(x) or not is_on_board(y):
    return false

  # Check if another player is where we're going
  if qb.board[x][y] != 0:
    return false

  # Jump dist
  let x_dist = abs(x - old_x)
  let y_dist = abs(y - old_y)
  let avg_x = int((x + old_x) / 2)
  let avg_y = int((y + old_y) / 2)
  let in_between = qb.board[avg_x][avg_y]
  let one_past_x = x + avg_x - old_x
  let one_past_y = y + avg_y - old_y

  # normal move: one space away and no wall between
  if ((x_dist == 2 and y_dist == 0 or
        y_dist == 2 and x_dist == 0) and
      in_between != 3):
    return true

  elif (# jump in a straight line
      (x_dist == 4 and y_dist == 0 and
        qb.board[avg_x + 1][old_y] != 3 and
        qb.board[avg_x - 1][old_y] != 3 or

        y_dist == 4 and x_dist == 0 and
        qb.board[old_x][avg_y + 1] != 3 and
        qb.board[old_x][avg_y - 1] != 3) and
      in_between != 0):
    return true

  elif (# jump diagonally if blocked by enemy player and a wall
    x_dist == 2 and y_dist == 2 and (
      qb.board[x][old_y] != 0 and

      (not is_on_board(one_past_x) or
        qb.board[one_past_x][old_y] == 3) and

      qb.board[avg_x][old_y] != 3 and

      qb.board[x][avg_y] != 3 or

      qb.board[old_x][y] != 0 and

      (not is_on_board(one_past_y) or
        qb.board[old_x][one_past_y] == 3) and

      qb.board[old_x][avg_y] != 3 and

      qb.board[avg_x][y] != 3)):
    return true
  else:
    return false

# Measure straight-line distance to the goal for A* purposes
proc heuristic(player, y: int): int {.inline, nosideeffect.} =
  assert player == 1 or player == 0
  if (player == 1):
    return 16 - y
  else:
    return y

# Finds the length of the shortest path for a player
# Also keeps track of walls that would block the path
#
# Returns: length of the shortest path, ignoring the other player
#   0 for no path
proc path_length(qb: ref Quoridor_Board; player: int): int =

  let other_player = (player + 1) mod 2
  let other_x = qb.xs[other_player]
  let other_y = qb.ys[other_player]
  
  qb.board[other_x][other_y] = 0
  
  # get current location
  var x = qb.xs[player]
  var y = qb.ys[player]

  # distance from current location
  var g = 0

  # heuristic distance (distance from goal)
  var h = heuristic(player, y)

  # To keep track of where we go
  var paths: array[0 .. 17, array[0 .. 17, int]]

  # Starting location
  paths[x][y] = 1

  # This is a sort of priority queue, specific to this application
  # We'll only be adding elements of the same or slightly lower priority
  var nodes = initTable[int, seq[array[0 .. 2, int]]]()

  # add first node, current location
  nodes[h] = @[[qb.xs[player], qb.ys[player], 0]]
  var key = h

  # while there are nodes left to evaluate
  while nodes.len != 0:
    # current stores the node we're using on each iteration
    let current = mget(nodes, key).pop
    x = current[0]
    y = current[1]
    g = current[2]
    h = heuristic(player, y)

    # if we've reached the end
    if h == 0:
      break

    # Try all moves
    for i in [[x - 2, y], [x, y - 2], [x + 2, y], [x, y + 2]]:
      if (qb.is_legal_move(x = i[0], y = i[1], old_x = x, old_y = y) and
          paths[i[0]][i[1]] == 0):
        h = heuristic(player, i[1])
        paths[i[0]][i[1]] = 100 * x + y + 2
        if not hasKey(nodes, g + h + 2):
          nodes.add(g + h + 2, @[[i[0], i[1], g + 2]])
        else:
          mget(nodes, g + h + 2).add([i[0], i[1], g + 2])

    # if this is the last of this weight
    # check for empty queue and change the key
    if nodes[key].len == 1:

      del(nodes, key)

      if nodes.len == 0:
        for row in paths:
          echo repr(row)
        qb.board[other_x][other_y] = other_player + 1
        return 0

      while not hasKey(nodes, key):
        key += 2

  if nodes.len == 0:
    qb.board[other_x][other_y] = other_player + 1
    return 0

  # re-initialize
  for i, wall in qb.walls_in_path[player]:
    qb.walls_in_path[player][i] = false
  var old_x, old_y: int

  while paths[x][y] != 1:
    old_x = x
    old_y = y
    x = int(paths[x][y] / 100)
    y = paths[old_x][y] mod 100 - 2
    #add_walls(player, x, y, old_x, old_y)

  qb.board[other_x][other_y] = other_player + 1
  return int(g / 2)

# Undo last n moves
#
# Params:
#   n = the number of moves to undo
proc undo*(qb: ref Quoridor_Board; n: int) =
  for i in 1 .. n:
    let move = qb.moves.pop
    let x = move[0]
    let y = move[1]
    let o = move[2]

    # update turn
    qb.turn -= 1
    let turn = qb.turn mod 2

    if o != 0:
      # undo wall
      let x_add = o - 1
      let y_add = o mod 2

      qb.board[x][y] = 0
      qb.board[x + x_add][y + y_add] = 0
      qb.board[x - x_add][y - y_add] = 0

    else:
      # undo move
      qb.board[x][y] = turn + 1
      qb.board[qb.xs[turn]][qb.ys[turn]] = 0
      qb.xs[turn] = x
      qb.ys[turn] = y

  qb.path_lengths = [qb.path_length(0), qb.path_length(1)]

# Checks for move legality, and if legal, moves the player
#
# Params:
#   x, y = the desired location
#
# Returns: whether or not the move occured
proc move_piece(qb: ref Quoridor_Board; x, y: int): bool =

  let player = qb.turn mod 2
  let old_x = qb.xs[player]
  let old_y = qb.ys[player]

  if qb.is_legal_move(x, y, old_x, old_y):

    # make the move
    qb.xs[player] = x
    qb.ys[player] = y
    qb.board[old_x][old_y] = 0
    qb.board[x][y] = player + 1

    # update shortest path length
    qb.path_lengths[player] = qb.path_length(player)

    # update turn
    qb.turn += 1

    # add old location to undo list
    add(qb.moves, [old_x, old_y, 0])

    return true

  return false

# Asserts a wall placement is legal
#
# Params:
#   x = horizontal location of new wall
#   y = vertical location of new wall
#   o = orientation of new wall (vertical, 1, or horizontal, 2)
proc is_legal_wall(qb: ref Quoridor_Board; x, y, o: int): bool =

  # Make sure wall isn't in move land
  assert x mod 2 == 1 and y mod 2 == 1

  # Make sure orientation is valid
  assert o == 1 or o == 2

  # Check for out-of-bounds
  if not is_on_board(x) or not is_on_board(y):
    return false

  # Make sure the player has walls left
  if qb.walls[qb.turn mod 2] == 0:
    return false

  let y_add = o - 1
  let x_add = o mod 2

  if qb.board[x][y] != 0 or
      qb.board[x + x_add][y + y_add] != 0 or
      qb.board[x - x_add][y - y_add] != 0:
    return false

  return true

# Insert a wall at x, y, o
proc wall_val(qb: ref Quoridor_Board; x, y, o, val: int) =

  let x_add = o - 1
  let y_add = o mod 2

  qb.board[x][y] = val
  qb.board[x + x_add][y + y_add] = val
  qb.board[x - x_add][y - y_add] = val

# Checks for wall legality, and if legal, places the wall
#
# Params:
#   x = the horizontal location
#   y = the vertical location
#   o = the orientation (1 for vertical, 2 for horizontal)
proc place_wall(qb: ref Quoridor_Board; x, y, o: int): bool =

  if not qb.is_legal_wall(x, y, o):
    return false

  # Add the wall for checking both player's paths
  qb.wall_val(x, y, o, 3)

  var test_length_one, test_length_two : int
  # Check player 1's path if the wall blocks it
  if qb.walls_in_path[0][linearize(x, y, o)]:
    test_length_one = qb.path_length(0)

    if test_length_one == 0:

      # remove wall
      qb.wall_val(x, y, o, 0)
      return false

  if qb.walls_in_path[1][linearize(x, y, o)]:
    test_length_two = qb.path_length(1)

    if test_length_two == 0:
      
      qb.wall_val(x, y, o, 0)
      return false

  # Both players have a path, so update shortest paths
  if test_length_one != 0:
    qb.path_lengths[0] = test_length_one

  if test_length_two != 0:
    qb.path_lengths[1] = test_length_two

  # Reduce the walls remaining
  qb.walls[qb.turn mod 2] -= 1

  # update turn
  qb.turn += 1

  # add wall to the list of moves
  qb.moves.add([x, y, o])

  return true

# Alters board state with a move if legal.
#
# Params:
#   move_string = a properly formatted move like "e3" or "b7v"
#
# Returns: 0 unless someone won the game. If so, then the player who won.
proc move*(qb: ref Quoridor_Board, move_string: string): int =
  let move_array = move_string_to_array(move_string)

  if move_array[2] == 0:
    if not qb.move_piece(x = move_array[0], y = move_array[1]):
      raise newException(EInvalidValue, "Illegal move")
    elif qb.turn mod 2 == 1 and move_array[1] == 0 or
        qb.turn mod 2 == 0 and move_array[1] == 16:
      return (qb.turn + 1) mod 2 + 1

  else:
    if not qb.place_wall(move_array[0], move_array[1], move_array[2]):
      raise newException(EInvalidValue, "Illegal wall")

  return 0

