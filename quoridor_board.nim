# The "Quoridor_Board" class holds all the information
# pertaining to a quoridor board, like the ai
#
# Author: Peter Plantinga
# Start Date: Mar 30, 2014

import tables

type
  Quoridor_Board* = object
    my_turn: int
    my_x, my_y, my_walls, path_lengths, my_openings: array[0 .. 1, int]
    my_board: array[0 .. 17, array[0 .. 17, int]]
    moves: seq[array[0 .. 2, int]]
    walls_in_path: array[0 .. 1, array[0 .. 127, bool]]

proc path_length(b: ref Quoridor_Board; player: int): int

proc init_Quoridor_Board*(): ref Quoridor_Board =
  var b = new(Quoridor_Board)
  b.my_x = [8, 8]
  b.my_y = [16, 0]
  b.my_board[8][16] = 1
  b.my_board[8][0] = 2
  b.my_walls = [10, 10]
  b.moves = @[]
  b.path_lengths = [8, 8]
  #b.path_lengths = [b.path_length(0), b.path_length(1)]
  return b

# Asserts a move is within the limits of the board.
proc is_on_board(d: int): bool {.inline, nosideeffect.} =
  return d >= 0 and d < 17

# Accessors
proc wall_count*(b: ref Quoridor_Board; player: int): int =
  assert player == 1 or player == 2
  return b.my_walls[player - 1]
proc board_value*(b: ref Quoridor_Board; x, y: int): int =
  assert is_on_board(x) and is_on_board(y)
  return b.my_board[x][y]

# Translates moves from strings like 'a3h' to a more useful format
# 
# Returns: array of the form [x, y, o]
#   where o is the orientation: 0 for a piece movement,
#   1 for vertical wall placement, 2 for horizontal wall
proc move_string_to_array( move_string: string ): array[0 .. 2, int] =

  assert move_string[0] >= 'a' and move_string[0] <= 'i'
  assert move_string[1] >= '1' and move_string[1] <= '9'
  assert len( move_string ) < 3 or move_string[2] == 'h' or move_string[2] == 'v'

  var orientation = 0
  var is_wall = 0
  if len( move_string ) > 2:
    is_wall = 1
    if move_string[2] == 'v':
      orientation = 1
    elif move_string[2] == 'h':
      orientation = 2

  return [ (int(move_string[0]) - 97) * 2 + is_wall,
    (int(move_string[1]) - 49) * 2 + is_wall,
    orientation ]

# Test move_string_to_array
assert move_string_to_array( "e8" )[0] == 8
assert move_string_to_array( "e8" )[1] == 14
assert move_string_to_array( "e8" )[2] == 0
assert move_string_to_array( "b6h" )[0] == 3
assert move_string_to_array( "b6h" )[1] == 11
assert move_string_to_array( "b6h" )[2] == 2

# Undo last n moves
#
# Params:
#   n = the number of moves to undo
proc undo*(b: ref Quoridor_Board; n: int) =
  for i in 1 .. n:
    let move = b.moves.pop
    let x = move[0]
    let y = move[1]
    let o = move[2]

    # update turn
    b.my_turn -= 1
    let turn = b.my_turn mod 2

    if o != 0:
      # undo wall
      let x_add = o - 1
      let y_add = o mod 2

      b.my_board[x][y] = 0
      b.my_board[x + x_add][y + y_add] = 0
      b.my_board[x - x_add][y - y_add] = 0

    else:
      # undo move
      b.my_board[x][y] = turn + 1
      b.my_board[b.my_x[turn]][b.my_y[turn]] = 0
      b.my_x[turn] = x
      b.my_y[turn] = y

    b.path_lengths = [b.path_length(0), b.path_length(1)]

# Check if this piece movement is legal
#
# Params:
#   x, y = potential new location
#   old_x, old_y = current location
#
# Returns:
#   Whether or not the move is legal
proc is_legal_move(b: ref Quoridor_Board; x, y, old_x, old_y: int): bool =

  # Check for out-of-bounds
  if not is_on_board(x) or not is_on_board(y):
    return false

  # Check if another player is where we're going
  if b.my_board[x][y] != 0:
    return false

  # Jump dist
  let x_dist = abs(x - old_x)
  let y_dist = abs(y - old_y)
  let avg_x = int((x + old_x) / 2)
  let avg_y = int((y + old_y) / 2)
  let in_between = b.my_board[avg_x][avg_y]
  let one_past_x = x + avg_x - old_x
  let one_past_y = y + avg_y - old_y

  # normal move: one space away and no wall between
  if ((x_dist == 2 and y_dist == 0 or
        y_dist == 2 and x_dist == 0) and
      in_between != 3 ):
    return true

  elif ( # jump in a straight line
    ( x_dist == 4 and y_dist == 0 and
      b.my_board[avg_x + 1][old_y] != 3 and
      b.my_board[avg_x - 1][old_y] != 3 or

      y_dist == 4 and x_dist == 0 and
      b.my_board[old_x][avg_y + 1] != 3 and
      b.my_board[old_x][avg_y - 1] != 3 ) and
    in_between != 0
  ):
    return true

  elif ( # jump diagonally if blocked by enemy player and a wall
    x_dist == 2 and y_dist == 2 and (
      b.my_board[x][old_y] != 0 and

      (not is_on_board(one_past_x) or
        b.my_board[one_past_x][old_y] == 3) and

      b.my_board[avg_x][old_y] != 3 and

      b.my_board[x][avg_y] != 3 or

      b.my_board[old_x][y] != 0 and

      (not is_on_board(one_past_y) or
        b.my_board[old_x][one_past_y] == 3) and

      b.my_board[old_x][avg_y] != 3 and

      b.my_board[avg_x][y] != 3
    )
  ):
    return true
  else:
    return false

proc heuristic(player, y: int): int {.inline, nosideeffect.} =
  assert player == 1 or player == 0
  if (player == 1):
    return 16 - y
  else:
    return y

# Finds the length of the shortest path for a player
# Also keeps track of walls that would block the path

# Returns: length of the shortest path, ignoring the other player
#   0 for no path
proc path_length(b: ref Quoridor_Board; player: int): int =

  let other_player = (player + 1) mod 2
  let other_x = b.my_x[other_player]
  let other_y = b.my_y[other_player]
  
  b.my_board[other_x][other_y] = 0
  
  # get current location
  var x = b.my_x[player]
  var y = b.my_y[player]

  # distance from current location
  var g = 0

  # heuristic distance (distance from goal)
  var h = heuristic(player, y)

  # To keep track of where we go
  var paths: array[0 .. 9, array[0 .. 9, int]]

  # Starting location
  paths[int(x / 2)][int(y / 2)] = 1

  # This is a sort of priority queue, specific to this application
  # We'll only be adding elements of the same or slightly lower priority
  var nodes = initTable[int, seq[array[0 .. 2, int]]]()

  # add first node, current location
  nodes[h] = @[[x, y, g]]

  # current stores the node we're using on each iteration
  var current: array[0 .. 2, int]
  var key = h

  # while there are nodes left to evaluate
  while nodes.len != 0:
    current = nodes[key][nodes[key].len - 1]
    x = current[0]
    y = current[1]
    g = current[2]
    h = heuristic(player, y)

    # if we've reached the end
    if h == 0:
      break

    # Try all moves
    for i in [[x - 2, y], [x, y - 2], [x + 2, y], [x, y + 2]]:
      if (b.is_legal_move(i[0], i[1], x, y) and
          paths[int(i[0]/2)][int(i[1]/2)] == 0):
        h = heuristic(player, i[1])
        paths[int(i[0] / 2)][int(i[1] / 2)] = 100 * x + y + 2
        mget(nodes, int((g + h + 2)/2)).add([i[0], i[1], g + 2])

    # if this is the last of this weight
    # check for empty queue and change the key
    if nodes[key].len == 1:

      del(nodes, key)

      if nodes.len == 0:
        b.my_board[other_x][other_y] = other_player + 1
        return 0

      while not hasKey(nodes, key):
        key += 1

    else:
      discard mget(nodes, key).pop

  if nodes.len == 0:
    b.my_board[other_x][other_y] = other_player + 1
    return 0

  # re-initialize
  for i, wall in b.walls_in_path[player]:
    b.walls_in_path[player][i] = false
  var old_x, old_y: int

  while paths[int(x/2)][int(y/2)] != 1:
    old_x = x
    old_y = y
    x = int( paths[int(x/2)][int(y/2)] / 100 )
    y = paths[int(old_x/2)][int(y/2)] mod 100 - 2
    #add_walls(player, x, y, old_x, old_y)

  b.my_board[other_x][other_y] = other_player + 1
  return int(g / 2)

# Checks for move legality, and if legal, moves the player
#
# Params:
#   x, y = the desired location
#
# Returns: whether or not the move occured

proc move_piece(b: ref Quoridor_Board; x, y: int): bool =

  let player = b.my_turn mod 2
  let old_x = b.my_x[player]
  let old_y = b.my_y[player]

  if b.is_legal_move(x = x, y = y, old_x = old_x, old_y = old_y):

    # make the move
    b.my_x[player] = x
    b.my_y[player] = y
    b.my_board[old_x][old_y] = 0
    b.my_board[x][y] = player + 1

    # update shortest path length
    #b.path_lengths[player] = b.path_length(player = player)

    # update turn
    b.my_turn += 1

    # add old location to undo list
    add( b.moves, [old_x, old_y, 0] )

    return true

  return false

proc place_wall( b: ref Quoridor_Board; x, y, o: int ): bool =
  return false

proc move*( b: ref Quoridor_Board, move_string: string ): int =
  let move_array = move_string_to_array( move_string )

  if move_array[2] == 0:
    if not b.move_piece(x = move_array[0], y = move_array[1]):
      raise newException(EInvalidValue, "Illegal move")
    elif b.my_turn mod 2 == 1 and move_array[1] == 0 or
        b.my_turn mod 2 == 0 and move_array[1] == 16:
      return ( b.my_turn + 1 ) mod 2 + 1

  else:
    if not b.place_wall(move_array[0], move_array[1], move_array[2]):
      raise newException(EInvalidValue, "Illegal wall")

  return 0

