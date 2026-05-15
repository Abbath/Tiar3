#+feature dynamic-literals
package main

import "core:bufio"
import "core:flags"
import "core:fmt"
import "core:hash"
import "core:io"
import "core:math/rand"
import "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"
import "core:time"
import "core:unicode"
import rl "vendor:raylib"

Point :: distinct [2]int
Pat :: struct($N: int) {
  pat: [N]Point,
}
SPat :: struct($N: int) {
  using pattern: Pat(N),
  w:             int,
  h:             int,
}
Threes :: [24]SPat(3)
Fours :: [16]SPat(4)
Fives :: [16]SPat(5)
shift_p :: proc(p: ^Pat($N)) {
  minX, minY := max(int), max(int)
  for pt in p.pat do minX, minY = min(pt.x, minX), min(pt.y, minY)
  for &pt in p.pat do pt -= {minX, minY}
}
rotations_p :: proc(p: Pat($N)) -> (res: [4]Pat(N)) {
  res[0] = p
  for i in 1 ..< 4 {
    rotated: Pat(N)
    for j in 0 ..< N {
      rotated.pat[j].xy = res[i - 1].pat[j].yx
      rotated.pat[j].y *= -1
    }
    shift_p(&rotated)
    res[i] = rotated
  }
  return
}
mirrored_p :: proc(p: Pat($N)) -> (m: Pat(N)) {
  m = p
  for i in 0 ..< N do m.pat[i].y = -p.pat[i].y
  shift_p(&m)
  return
}
sized_p :: proc(p: Pat($N)) -> (res: SPat(N)) {
  res.pat = p.pat
  maxX, maxY := min(int), min(int)
  for pt in p.pat do maxX, maxY = max(pt.x, maxX), max(pt.y, maxY)
  res.w, res.h = maxX + 1, maxY + 1
  return
}
copy_into :: proc(res: $T/[]$E, slices: []T) {for offset := 0; s in slices do offset += copy(res[offset:], s)}
generate_p :: proc(p: Pat($N)) -> (res2: [8]SPat(N)) {
  s, m := rotations_p(p), mirrored_p(p)
  r := rotations_p(m)
  res1: [8]Pat(N)
  copy_into(res1[:], [][]Pat(N){r[:], s[:]})
  for i in 0 ..< 8 do res2[i] = sized_p(res1[i])
  return
}
threes_p :: proc() -> (res: [24]SPat(3)) {
  threes1, threes2, threes3 := generate_p(Pat(3){{{0, 0}, {1, 1}, {0, 2}}}), generate_p(Pat(3){{{1, 0}, {0, 1}, {0, 2}}}), generate_p(Pat(3){{{0, 0}, {0, 1}, {0, 3}}})
  copy_into(res[:], [][]SPat(3){threes1[:], threes2[:], threes3[:]})
  return
}
fours_p :: proc() -> (res: [16]SPat(4)) {
  fours1, fours2 := generate_p(Pat(4){{{0, 0}, {1, 1}, {0, 2}, {0, 3}}}), generate_p(Pat(4){{{0, 0}, {0, 1}, {1, 1}, {2, 0}}})
  copy_into(res[:], [][]SPat(4){fours1[:], fours2[:]})
  return
}
fives_p :: proc() -> (res: [16]SPat(5)) {
  fives1, fives2 := generate_p(Pat(5){{{0, 0}, {0, 1}, {1, 2}, {0, 3}, {0, 4}}}), generate_p(Pat(5){{{0, 0}, {1, 1}, {1, 2}, {2, 0}, {3, 0}}})
  copy_into(res[:], [][]SPat(5){fives1[:], fives2[:]})
  return
}
Pair :: distinct [2]int
Triple :: distinct [3]int
IndexedTile :: struct {
  first:  int,
  second: int,
  third:  Tile,
}
PairSet :: distinct map[Pair]struct{}
PairMap :: distinct map[Pair]int
Board :: struct {
  board:            [dynamic]Tile,
  w:                int,
  h:                int,
  matched_patterns: PairSet,
  matched_threes:   PairSet,
  magic_tiles:      PairMap,
  rm_i:             [dynamic]Triple,
  rm_j:             [dynamic]Triple,
  rm_b:             [dynamic]Pair,
  rm_s:             [dynamic]Pair,
  score:            int,
  normals:          int,
  longers:          int,
  longests:         int,
  crosses:          int,
}
Tile :: enum {
  NONE,
  SQUARE,
  CIRCLE,
  HEXAGON,
  TRIANGLE,
  PENTAGON,
  RHOMBUS,
  BRICK,
}
coin :: proc() -> int {return rand.int_max(42) + 1}
coin2 :: proc() -> int {return rand.int_max(69) + 1}
random_tile :: proc() -> int {return rand.int_max(len(Tile) - 1) + 1}
random_w :: proc(b: Board) -> int {return rand.int_max(b.w)}
random_h :: proc(b: Board) -> int {return rand.int_max(b.h)}
make_board :: proc(w, h: int) -> (b: Board) {
  b.w = w
  b.h = h
  b.board = make([dynamic]Tile, w * h)
  b.matched_patterns = make(PairSet)
  b.matched_threes = make(PairSet)
  b.magic_tiles = make(PairMap)
  b.rm_i = make([dynamic]Triple)
  b.rm_j = make([dynamic]Triple)
  b.rm_b = make([dynamic]Pair)
  b.rm_s = make([dynamic]Pair)
  return
}
delete_board :: proc(b: ^Board) {
  delete(b.board)
  delete(b.matched_patterns)
  delete(b.matched_threes)
  delete(b.magic_tiles)
  delete(b.rm_i)
  delete(b.rm_j)
  delete(b.rm_b)
  delete(b.rm_s)
}
copy_map :: proc(m: $T) -> (m1: T) {
  m1 = make(T, len(m))
  for k, v in m do m1[k] = v
  return
}
copy_board :: proc(b: Board) -> (b1: Board) {
  b1 = make_board(b.w, b.h)
  copy(b1.board[:], b.board[:])
  b1.score = b.score
  b1.matched_patterns = copy_map(b.matched_patterns)
  b1.magic_tiles = copy_map(b.magic_tiles)
  b1.normals = b.normals
  b1.longers = b.longers
  b1.longests = b.longests
  b1.crosses = b.crosses
  return
}
at_out :: proc(brd: Board, a, b: int) -> Tile {return brd.board[a * brd.h + b]}
@(require_results)
at_in :: proc(brd: ^Board, a, b: int) -> ^Tile {return &brd.board[a * brd.h + b]}
at :: proc {
  at_in,
  at_out,
}
match_pattern :: proc(b: Board, x, y: int, p: SPat($N)) -> bool {
  color := at(b, x + p.pat[0].x, y + p.pat[0].y)
  if color == .BRICK do return false
  for i in 1 ..< len(p.pat) do if color != at(b, x + p.pat[i].x, y + p.pat[i].y) do return false
  return true
}
match_patterns :: proc(b: ^Board, patterns: [$M]SPat($N)) {for sp in patterns do for i in 0 ..= b.w - sp.w do for j in 0 ..= b.h - sp.h do if match_pattern(b^, i, j, sp) do for p in sp.pat do b.matched_patterns[{i + p.x, j + p.y}] = {}}
is_matched :: proc(b: Board, x, y: int) -> bool {return {x, y} in b.matched_patterns}
is_magic :: proc(b: Board, x, y: int) -> bool {return {x, y} in b.magic_tiles}
swap_tiles :: proc(b: ^Board, a1, b1, a2, b2: int) {slice.swap(b.board[:], a1 * b.h + b1, a2 * b.h + b2)}
handle_magic :: proc(ps: ^PairMap, p1, p2: Pair) {
  if (p1 in ps) {
    ps[p2] = ps[p1]
    delete_key(ps, p1)
  }
}
consume_magic :: proc(b: ^Board, p: Pair) {
  if (p in b.magic_tiles) {
    b.score += b.magic_tiles[p]
    delete_key(&b.magic_tiles, p)
  }
}
swap :: proc(b: ^Board, x1, y1, x2, y2: int) {
  swap_tiles(b, x1, y1, x2, y2)
  handle_magic(&b.magic_tiles, {x1, y1}, {x2, y2})
  handle_magic(&b.magic_tiles, {x2, y2}, {x1, y1})
}
fill :: proc(b: ^Board) {for &x in b.board do x = Tile(random_tile())}
reasonable_coord :: proc(b: Board, i, j: int) -> bool {return i >= 0 && i < b.w && j >= 0 && j < b.h}
remove_trios :: proc(b: ^Board) {
  remove_i, remove_j := make([dynamic]Triple), make([dynamic]Triple)
  defer {
    delete(remove_i)
    delete(remove_j)
  }
  for i in 0 ..< b.w do for j in 0 ..< b.h {
    if at(b^, i, j) == .BRICK do continue
    offset_i, offset_j := 1, 1
    for (j + offset_j < b.h && at(b^, i, j) == at(b^, i, j + offset_j)) do offset_j += 1
    if offset_j > 2 do append(&remove_i, Triple{i, j, offset_j})
    for (i + offset_i < b.w && at(b^, i, j) == at(b^, i + offset_i, j)) do offset_i += 1
    if offset_i > 2 do append(&remove_j, Triple{i, j, offset_i})
  }
  for t in remove_i {
    i, j, offset := t.x, t.y, t.z
    b.normals += 1
    if offset == 4 {
      j, offset = 0, b.h
      b.longers += 1
      b.normals += max(0, b.normals - 1)
    }
    for jj in j ..< j + offset {
      at(b, i, jj)^ = .NONE
      consume_magic(b, {i, jj})
      b.score += 1
    }
    if offset == 5 {
      for _ in 0 ..< b.w {
        at(b, random_w(b^), random_h(b^))^ = .NONE
        b.score += 1
      }
      b.longests += 1
      b.normals = max(0, b.normals - 1)
    }
  }
  for t in remove_j {
    i, j, offset := t.x, t.y, t.z
    b.normals += 1
    if offset == 4 {
      i, offset = 0, b.w
      b.longers += 1
      b.normals = max(0, b.normals - 1)
    }
    for ii in i ..< i + offset {
      at(b, ii, j)^ = .NONE
      consume_magic(b, {ii, j})
      b.score += 1
    }
    if offset == 5 {
      for _ in 0 ..< b.w {
        at(b, random_w(b^), random_h(b^))^ = .NONE
        b.score += 1
      }
      b.longests += 1
      b.normals = max(0, b.normals - 1)
    }
  }
  for i in 0 ..< len(remove_i) do for j in 0 ..< len(remove_j) {
    t1, t2 := remove_i[i], remove_j[j]
    i1, j1, o1 := t1.x, t1.y, t1.z
    i2, j2, o2 := t2.x, t2.y, t2.z
    if i1 >= i2 && i1 < (i2 + o2) && j2 >= j1 && j2 < (j1 + o1) {
      for m in -1 ..< 2 {
        for n in -1 ..< 2 {
          if reasonable_coord(b^, i1 + m, j1 + n) {
            at(b, i1 + m, j1 + n)^ = .NONE
            b.score += 1
          }
        }
      }
      b.crosses += 1
      b.normals = max(0, b.normals - 2)
    }
  }
}
fill_up :: proc(b: ^Board) {
  curr_i := -1
  for i in 0 ..< b.w do for j in 0 ..< b.h do if at(b^, i, j) == .NONE {
    curr_i = i
    for curr_i < b.w - 1 && at(b^, curr_i + 1, j) == .NONE do curr_i += 1
    for k := curr_i; k >= 0; k -= 1 {
      if at(b^, k, j) != .NONE {
        at(b, curr_i, j)^ = at(b^, k, j)
        handle_magic(&b.magic_tiles, {k, j}, {curr_i, j})
        curr_i -= 1
      }
    }
    for k := curr_i; k >= 0; k -= 1 {
      at(b, k, j)^ = Tile(random_tile())
      if coin() == 1 do b.magic_tiles[{k, j}] = -3
      if coin2() == 1 do b.magic_tiles[{k, j}] = 3
    }
  }
}
compare_boards :: proc(b1: Board, b2: Board) -> bool {
  if b1.w != b2.w || b1.h != b2.h do return false
  for i in 0 ..< b1.w * b1.h do if b1.board[i] != b2.board[i] do return false
  return true
}
match_threes :: proc(b: ^Board, threes: Threes) {
  clear(&b.matched_threes)
  for sp in threes do for i in 0 ..= b.w - sp.w do for j in 0 ..= b.h - sp.h do if match_pattern(b^, i, j, sp) do for p in sp.pat do b.matched_threes[{i + p.x, j + p.y}] = {}
}
is_three :: proc(b: Board, i, j: int) -> bool {return {i, j} in b.matched_threes}
stabilize :: proc(b: ^Board, threes: Threes, fours: Fours, fives: Fives) {
  for {
    old_board := copy_board(b^)
    defer delete_board(&old_board)
    remove_trios(b)
    fill_up(b)
    if compare_boards(old_board, b^) do break
  }
  clear(&b.matched_patterns)
  match_patterns(b, fours)
  match_patterns(b, fives)
  match_threes(b, threes)
}
step :: proc(b: ^Board, threes: Threes, fours: Fours, fives: Fives) {
  remove_trios(b)
  fill_up(b)
  clear(&b.matched_patterns)
  match_patterns(b, fours)
  match_patterns(b, fives)
  match_threes(b, threes)
}
zero :: proc(b: ^Board) {
  b.score = 0
  b.normals = 0
  b.longers = 0
  b.longests = 0
  b.crosses = 0
}
remove_tile :: proc(b: ^Board, i, j: int, res: ^[dynamic]IndexedTile) {
  append(res, IndexedTile{i, j, at(b^, i, j)})
  at(b, i, j)^ = .NONE
  consume_magic(b, {i, j})
  for k in -1 ..= 1 do for l in -1 ..= 1 do if k != l && reasonable_coord(b^, i + k, j + l) && at(b^, i + k, j + l) == .BRICK {
    append(res, IndexedTile{i + k, j + l, at(b^, i + k, j + l)})
    at(b, i + k, j + l)^ = .NONE
    consume_magic(b, {i + k, j + l})
  }
}
remove_one_thing :: proc(b: ^Board) -> [dynamic]IndexedTile {
  res := make([dynamic]IndexedTile)
  if len(b.rm_i) != 0 {
    t := b.rm_i[len(b.rm_i) - 1]
    i, j, offset := t.x, t.y, t.z
    if offset == 4 {
      j, offset = 0, b.h
      b.longers += 1
      b.normals = max(0, b.normals - 1)
    }
    for jj in j ..< j + offset do if at(b^, i, jj) != .NONE {
      remove_tile(b, i, jj, &res)
      b.score += 1
    }
    if offset == 5 {
      r := make(PairSet)
      defer delete(r)
      for _ in 0 ..< b.w {
        for do if x, y := random_w(b^), random_h(b^); ({x, y} not_in r) && at(b^, x, y) != .NONE {
          r[{x, y}] = {}
          remove_tile(b, x, y, &res)
          b.score += 1
          break
        }
      }
      b.longests += 1
      b.normals = max(0, b.normals - 1)
    }
    b.normals += 1
    pop(&b.rm_i)
    return res
  }
  if len(b.rm_j) != 0 {
    t := b.rm_j[len(b.rm_j) - 1]
    i, j, offset := t.x, t.y, t.z
    if offset == 4 {
      i, offset = 0, b.w
      b.longers += 1
      b.normals = max(0, b.normals - 1)
    }
    for ii in i ..< i + offset do if at(b^, ii, j) != .NONE {
      remove_tile(b, ii, j, &res)
      b.score += 1
    }
    if offset == 5 {
      r := make(PairSet)
      defer delete(r)
      for _ in 0 ..< b.w {
        for do if x, y := random_w(b^), random_h(b^); ({x, y} not_in r) && at(b^, x, y) != .NONE {
          r[{x, y}] = {}
          remove_tile(b, x, y, &res)
          b.score += 1
          break
        }
      }
      b.longests += 1
      b.normals = max(0, b.normals - 1)
    }
    b.normals += 1
    pop(&b.rm_j)
    return res
  }
  if len(b.rm_b) != 0 {
    t := b.rm_b[len(b.rm_b) - 1]
    i, j := t.x, t.y
    for m in -2 ..< 3 do for n in -2 ..< 3 do if reasonable_coord(b^, i + m, j + n) && at(b^, i + m, j + n) != .NONE {
      remove_tile(b, i + m, j + n, &res)
      b.score += 1
    }
    b.crosses += 1
    b.normals = max(0, b.normals - 2)
    pop(&b.rm_b)
    return res
  }
  if len(b.rm_s) != 0 {
    t := b.rm_s[len(b.rm_s) - 1]
    i, j := t.x, t.y
    for m in 0 ..= 1 do for n in 0 ..= 1 do if reasonable_coord(b^, i + m, j + n) && at(b^, i + m, j + n) != .NONE {
      remove_tile(b, i + m, j + n, &res)
      b.score += 1
    }
    pop(&b.rm_s)
    return res
  }
  return res
}
sorter_factory :: proc($T: typeid) -> proc(_: T, _: T) -> bool {return proc(a, b: T) -> bool {return a.x < b.y}}
prepare_removals :: proc(b: ^Board) {
  clear(&b.rm_i)
  clear(&b.rm_j)
  clear(&b.rm_b)
  clear(&b.rm_s)
  clear(&b.matched_patterns)
  clear(&b.matched_threes)
  for i in 0 ..< b.w do for j in 0 ..< b.h {
    if at(b^, i, j) == .BRICK do continue
    val, offset_j, offset_i := at(b^, i, j), 1, 1
    for j + offset_j < b.h && val == at(b^, i, j + offset_j) do offset_j += 1
    if offset_j > 2 do append(&b.rm_i, Triple{i, j, offset_j})
    for i + offset_i < b.w && val == at(b^, i + offset_i, j) do offset_i += 1
    if offset_i > 2 do append(&b.rm_j, Triple{i, j, offset_i})
    if i != b.w - 1 && j != b.h - 1 do if at(b^, i + 1, j) == val && at(b^, i, j + 1) == val && at(b^, i + 1, j + 1) == val do append(&b.rm_s, Pair{i, j})
  }
  for i in 0 ..< len(b.rm_i) do for j in 0 ..< len(b.rm_j) {
    t1, t2 := b.rm_i[i], b.rm_j[j]
    i1, j1, o1 := t1.x, t1.y, t1.z
    i2, j2, o2 := t2.x, t2.y, t2.z
    if i1 >= i2 && i1 < (i2 + o2) && j2 >= j1 && j2 < (j1 + o1) do append(&b.rm_b, Pair{i1, j2})
  }
  slice.sort_by(b.rm_i[:], sorter_factory(Triple))
  slice.sort_by(b.rm_j[:], sorter_factory(Triple))
  slice.sort_by(b.rm_b[:], sorter_factory(Pair))
  slice.sort_by(b.rm_s[:], sorter_factory(Pair))
}
has_removals :: proc(b: Board) -> bool {return bool(len(b.rm_i) + len(b.rm_j) + len(b.rm_b) + len(b.rm_s))}
LeaderboardRecord :: struct {
  name:  string,
  score: int,
}
Leaderboard :: distinct [dynamic]LeaderboardRecord
delete_leaderboard :: proc(l: ^Leaderboard) {for lr in l do delete(lr.name)}
ReadLeaderboard :: proc() -> (res: Leaderboard, ok: bool) {
  defer free_all(context.temp_allocator)
  res = make(Leaderboard)
  data, ok1 := os.read_entire_file("leaderboard.txt", context.temp_allocator)
  if ok1 == nil {
    lines := strings.split_lines(string(data), context.temp_allocator)
    for m: u64 = 0; line in lines {
      parts := strings.split(line, ";", context.temp_allocator) or_continue
      if len(parts) == 3 {
        lr := LeaderboardRecord{strings.clone(parts[0]), strconv.parse_int(parts[1]) or_return}
        h, ok2 := strconv.parse_u64(parts[2])
        if !ok2 || !check_hash(lr, h + m) {
          delete(res)
          return nil, false
        }
        m = h
        append(&res, lr)
      }
    }
  }
  slice.sort_by(res[:], proc(a, b: LeaderboardRecord) -> bool {return a.score > b.score})
  return res, true
}
WriteLeaderboard :: proc(leaderboard: ^Leaderboard) {
  builder := strings.builder_make()
  defer strings.builder_destroy(&builder)
  slice.sort_by(leaderboard[:], proc(a, b: LeaderboardRecord) -> bool {return a.score > b.score})
  for m: u64 = 0; lr in leaderboard {
    m = compute_hash(lr, m)
    fmt.sbprintf(&builder, "%s;%d;%d", lr.name, lr.score, m, newline = true)
  }
  err := os.write_entire_file("leaderboard.txt", transmute([]u8)strings.to_string(builder))
  if err != nil do fmt.eprintfln("Leaderboard could not be read because: %v", err)
}
DrawLeaderboard :: proc(leaderboard: ^Leaderboard, offset: int, place: int) {
  if len(leaderboard) == 0 do return
  w, h := rl.GetRenderWidth(), rl.GetRenderHeight()
  start_y := h / 4 + 10
  rl.DrawRectangle(w / 4, h / 4, w / 2, h / 2, rl.WHITE)
  rl.DrawText("Leaderboard:", w / 4 + 10, start_y, 20, rl.BLACK)
  slice.sort_by(leaderboard[:], proc(a, b: LeaderboardRecord) -> bool {return a.score > b.score})
  new_offset := min(offset, len(leaderboard) - 1)
  finish := min(new_offset + 9, len(leaderboard))
  for i in new_offset ..< finish {
    lr := leaderboard[i]
    text := fmt.ctprintf("%d. %s: %d", i, lr.name, lr.score, newline = true)
    start_y += 30
    c := rl.BLACK
    switch i {
    case 0: c = rl.GOLD
    case 1: c = rl.GRAY
    case 2: c = rl.ORANGE
    }
    if place == i {
      width := rl.MeasureText(text, 20)
      rl.DrawRectangle(w / 4 + 5, start_y, width + 10, 25, rl.LIGHTGRAY)
    }
    rl.DrawText(text, w / 4 + 10, start_y, 20, c)
  }
  if finish != len(leaderboard) do rl.DrawText("...", w / 4 + 10, start_y + 30, 20, rl.BLACK)
}
Button :: struct {
  x1: f32,
  y1: f32,
  x2: f32,
  y2: f32,
}
in_button :: proc(pos: rl.Vector2, button: Button) -> bool {return pos.x > button.x1 && pos.x < button.x2 && pos.y > button.y1 && pos.y < button.y2}
button_maker_enter := true
ButtonMaker :: struct {
  play_sound: bool,
  sound:      rl.Sound,
  volume:     f32,
  buttons:    [dynamic]Button,
}
delete_button_maker :: proc(bm: ^ButtonMaker) {delete(bm.buttons)}
draw_button :: proc(bm: ^ButtonMaker, place: [2]i32, text: string, enabled: bool) -> Button {
  button_down, pos := rl.IsMouseButtonDown(rl.MouseButton.LEFT), rl.GetMousePosition()
  button := Button{f32(place.x), f32(place.y), f32(place.x + 200), f32(place.y + 30)}
  if in_button(pos, button) {
    c := enabled ? rl.YELLOW : (button_down ? rl.DARKGRAY : rl.LIGHTGRAY)
    if text == "SOUND" {
      level := bm.volume * 200
      rl.DrawRectangleV(rl.Vector2(place), {level, 30}, rl.YELLOW)
      rl.DrawRectangleV(rl.Vector2(place + {i32(level), 0}), {200 - level, 30}, rl.LIGHTGRAY)
      if button_down {
        x := rl.GetMouseX()
        bm.volume = f32(x - place.x) / 200.0
      }
    } else do rl.DrawRectangleV(rl.Vector2(place), {200, 30}, c)
  } else {
    c := enabled ? rl.GOLD : rl.GRAY
    if text == "SOUND" {
      level := bm.volume * 200
      rl.DrawRectangleV(rl.Vector2(place), {level, 30}, rl.GOLD)
      rl.DrawRectangleV(rl.Vector2(place + {i32(level), 0}), {200 - level, 30}, rl.GRAY)
    } else do rl.DrawRectangleV(rl.Vector2(place), {200, 30}, c)
  }
  label := text == "SOUND" ? fmt.ctprintf("SOUND (%d)", int(bm.volume * 100)) : fmt.ctprintf("%s", text)
  width := rl.MeasureText(label, 20)
  rl.DrawText(label, place.x + 100 - width / 2, place.y + 5, 20, rl.BLACK)
  append(&bm.buttons, button)
  return button
}
play_sound :: proc(bm: ButtonMaker) {
  if !bm.play_sound do return
  inn := false
  for it in bm.buttons {
    pos := rl.GetMousePosition()
    if in_button(pos, it) {
      inn = true
      if button_maker_enter {
        button_maker_enter = false
        if (rl.IsSoundReady(bm.sound)) do rl.PlaySound(bm.sound)
      }
    }
  }
  if !inn do button_maker_enter = true
}
Game :: struct {
  name:          string,
  board:         Board,
  old_board:     Board,
  work_board:    bool,
  first_work:    bool,
  removed_cells: [dynamic]Triple,
  counter:       int,
  threes:        Threes,
  fours:         Fours,
  fives:         Fives,
}
make_game :: proc(size: int) -> Game {
  board := make_board(size, size)
  return Game{board = board, old_board = copy_board(board), removed_cells = make([dynamic]Triple), name = "", threes = Threes(threes_p()), fours = Fours(fours_p()), fives = Fives(fives_p())}
}
delete_game :: proc(g: ^Game) {
  delete(g.name)
  delete_board(&g.board)
  delete_board(&g.old_board)
}
new_game :: proc(g: ^Game) {
  g.counter = 0
  g.work_board = false
  fill(&g.board)
  stabilize(&g.board, g.threes, g.fours, g.fives)
  zero(&g.board)
}
save :: proc(g: Game, auto_clean: bool = false) {
  builder := strings.builder_make(context.temp_allocator)
  fmt.sbprintf(&builder, "%s %d\n", g.name, g.counter)
  save_board(&builder, g.board)
  _ = os.write_entire_file("save.txt", transmute([]u8)strings.to_string(builder))
  if auto_clean do free_all(context.temp_allocator)
}
save_board :: proc(b: ^strings.Builder, board: Board) {
  fmt.sbprintf(b, "%d\n%d\n%d\n%d\n%d\n%d %d\n", board.score, board.normals, board.longers, board.longests, board.crosses, board.w, board.h)
  for i in 0 ..< board.w {
    for j in 0 ..< board.h do fmt.sbprintf(b, "%d ", at(board, i, j))
    fmt.sbprintf(b, "\n")
  }
  fmt.sbprintf(b, "%d\n", len(board.magic_tiles))
  for key, val in board.magic_tiles do fmt.sbprintf(b, "%d %d %d ", key.x, key.y, val)
  fmt.sbprintf(b, "\n")
}
ShitPants :: union {
  bool,
  io.Error,
}
load_game :: proc(g: ^Game, h: ^os.File, auto_clear: bool = false) -> ShitPants {
  read_value :: proc(r: ^bufio.Reader, delim: rune = '\n') -> (val: int, ok: bool) {
    temp_s, err := bufio.reader_read_string(r, u8(delim), context.temp_allocator)
    if err != .None do return 0, false
    return strconv.parse_int(strings.trim_space(temp_s))
  }
  r: bufio.Reader
  bufio.reader_init(&r, os.to_stream(h))
  defer bufio.reader_destroy(&r)
  name_tmp := bufio.reader_read_string(&r, ' ', context.temp_allocator) or_return
  g.name = strings.clone(name_tmp)
  g.counter = read_value(&r) or_return
  g.board.score = read_value(&r) or_return
  g.board.normals = read_value(&r) or_return
  g.board.longers = read_value(&r) or_return
  g.board.longests = read_value(&r) or_return
  g.board.crosses = read_value(&r) or_return
  g.board.w = read_value(&r, ' ') or_return
  g.board.h = read_value(&r) or_return
  resize(&g.board.board, g.board.w * g.board.h)
  for i in 0 ..< g.board.w do for j in 0 ..< g.board.h {
    val := read_value(&r, j == g.board.h - 1 ? '\n' : ' ') or_return
    at(&g.board, i, j)^ = Tile(val)
  }
  mt := read_value(&r) or_return
  clear(&g.board.magic_tiles)
  for i in 0 ..< mt {
    x := read_value(&r, ' ') or_return
    y := read_value(&r, ' ') or_return
    z := read_value(&r, i == mt - 1 ? '\n' : ' ') or_return
    g.board.magic_tiles[{x, y}] = z
  }
  if auto_clear do free_all(context.temp_allocator)
  return true
}
load :: proc(g: ^Game, auto_clear: bool = false) -> bool {
  file, err := os.open("save.txt")
  if err == nil {
    g.work_board = false
    err := load_game(g, file, auto_clear)
    fmt.println(err.(bool))
    if err != true do return false
    match(g)
    return true
  }
  return false
}
save_state :: proc(g: ^Game) {
  delete_board(&g.old_board)
  g.old_board = copy_board(g.board)
}
check_state :: proc(g: Game) -> bool {return compare_boards(g.old_board, g.board)}
restore_state :: proc(g: ^Game) {
  delete_board(&g.board)
  g.board = copy_board(g.old_board)
}
match :: proc(g: ^Game) {
  match_patterns(&g.board, g.fours)
  match_patterns(&g.board, g.fives)
  match_threes(&g.board, g.threes)
}
attempt_move :: proc(g: ^Game, row1, col1, row2, col2: $T) {
  g.first_work = true
  g.work_board = true
  save_state(g)
  swap(&g.board, int(row1), int(col1), int(row2), int(col2))
  prepare_removals(&g.board)
}
step_game :: proc(g: ^Game) -> (res: [dynamic]IndexedTile) {
  if !has_removals(g.board) do prepare_removals(&g.board)
  if !has_removals(g.board) {
    if g.first_work do restore_state(g)
    else do g.counter += 1
    g.work_board = false
    match(g)
  }
  res = remove_one_thing(&g.board)
  fill_up(&g.board)
  g.first_work = false
  return
}
is_finished :: proc(g: Game, max_steps: int = 50) -> bool {return g.counter == max_steps}
is_processing :: proc(g: Game) -> bool {return g.work_board}
game_stats :: proc(g: Game) -> string {return fmt.tprintf("Moves: %d\nScore: %d\nTrios: %d\nQuartets: %d\nQuintets: %d\nCrosses: %d", g.counter, g.board.score, g.board.normals, g.board.longers, g.board.longests, g.board.crosses)}
Particle :: struct {
  dx:       f32,
  dy:       f32,
  da:       f32,
  x:        f32,
  y:        f32,
  a:        f32,
  color:    rl.Color,
  lifetime: int,
  sides:    int,
}
Explosion :: struct {
  x:        int,
  y:        int,
  lifetime: int,
}
button_flag :: proc(pos: rl.Vector2, button: Button, flag: ^bool) {if in_button(pos, button) do flag^ = !flag^}
compute_hash :: proc(lr: LeaderboardRecord, m: u64) -> (n: u64) {
  for {
    n = rand.uint64()
    str := fmt.aprintf("%s%d%d", lr.name, lr.score, m + n)
    defer delete(str)
    crc := hash.crc64_iso_3306(transmute([]byte)str)
    if crc & 0xff == 0 do return
  }
}
check_hash :: proc(lr: LeaderboardRecord, m: u64) -> bool {
  str := fmt.aprintf("%s%d%d", lr.name, lr.score, m)
  defer delete(str)
  return hash.crc64_iso_3306(transmute([]byte)str) & 0xff == 0
}
v2 :: proc(a: [2]i32) -> [2]f32 {return cast([2]f32)a}
add_thing :: proc(things: ^[dynamic]$T, thing: T) {
  found := false
  for &t in things {
    if t.lifetime == 0 {
      t = thing
      found = true
      break
    }
  }
  if !found do append(things, thing)
}
main :: proc() {
  when ODIN_DEBUG {
    context.allocator = debug_stuff_init()
    defer debug_stuff_defer()
  }
  Options :: struct {
    steps: int "args:name=steps",
    score: int "args:name=score",
  }
  opts: Options
  flags.parse_or_exit(&opts, os.args)
  opts.score = opts.score == 0 ? 1000 : opts.score
  opts.steps = opts.steps == 0 ? 50 : opts.steps
  rand.reset(auto_cast time.time_to_unix(time.now()))
  dd :: proc() -> int {return rand.int_max(21) - 10}
  w: i32 = 1280
  h: i32 = 800
  board_size := 16
  game := make_game(board_size)
  defer {
    save(game, true)
    delete_game(&game)
  }
  first_click := true
  saved_row: i32 = 0
  saved_col: i32 = 0
  draw_leaderboard := false
  input_name := false
  frame_counter := 0
  hints := false
  particles := false
  is_play_sound := false
  nonacid_colors := false
  ignore_r := false
  l_offset := 0
  volume: f32 = 0.0
  leaderboard_place := -1
  leaderboard, ok := ReadLeaderboard()
  if !ok {
    fmt.println("Leaderboard is compromised or doesn't exist")
    leaderboard = Leaderboard{}
  }
  defer {
    WriteLeaderboard(&leaderboard)
    delete_leaderboard(&leaderboard)
    delete(leaderboard)
  }
  flying := make([dynamic]Particle)
  defer delete(flying)
  kabooms := make([dynamic]Explosion)
  defer delete(kabooms)
  rl.InitAudioDevice()
  defer rl.CloseAudioDevice()
  psound := rl.LoadSound("p.ogg")
  ksound := rl.LoadSound("k.ogg")
  if !load(&game, true) {
    new_game(&game)
    input_name = true
  }
  builder := strings.builder_make()
  defer strings.builder_destroy(&builder)
  rl.SetConfigFlags({rl.ConfigFlag.WINDOW_RESIZABLE})
  rl.InitWindow(w, h, "Tiar3")
  defer rl.CloseWindow()
  icon := rl.LoadImage("icon.png")
  rl.SetWindowIcon(icon)
  rl.SetTargetFPS(60)
  for !rl.WindowShouldClose() {
    defer free_all(context.temp_allocator)
    rl.SetMasterVolume(volume)
    if frame_counter == 60 do frame_counter = 0
    else do frame_counter += 1
    w, h = rl.GetRenderWidth(), rl.GetRenderHeight()
    s: i32 = w > h ? h : w
    margin: i32 = 10
    board_x, board_y := w / 2 - s / 2 + margin, h / 2 - s / 2 + margin
    ss := (s - 2 * margin) / auto_cast board_size
    so: i32 = 2
    mo: f32 = 0.5
    if is_processing(game) && frame_counter % 6 == 0 {
      f := step_game(&game)
      defer delete(f)
      if is_play_sound && len(f) != 0 && rl.IsSoundReady(psound) do rl.PlaySound(psound)
      if particles {
        if is_play_sound && len(f) != 0 {
          board_x += auto_cast dd()
          board_y += auto_cast dd()
        }
        reserve(&flying, len(flying) + len(f))
        reserve(&kabooms, len(kabooms) + len(f))
        for it in f {
          c: rl.Color
          s: int
          switch it.third {
          case .NONE: continue
          case .SQUARE: s, c = 4, nonacid_colors ? rl.PINK : rl.RED
          case .CIRCLE: s, c = 0, nonacid_colors ? rl.LIME : rl.GREEN
          case .HEXAGON: s, c = 6, nonacid_colors ? rl.SKYBLUE : rl.BLUE
          case .TRIANGLE: s, c = 3, nonacid_colors ? rl.GOLD : rl.ORANGE
          case .PENTAGON: s, c = 5, nonacid_colors ? rl.PURPLE : rl.MAGENTA
          case .RHOMBUS: s, c = 4, nonacid_colors ? rl.BEIGE : rl.YELLOW
          case .BRICK: s, c = 4, rl.BROWN
          }
          add_thing(&flying, Particle{auto_cast dd(), auto_cast dd(), auto_cast dd(), f32(i32(it.second) * ss + board_x + ss / 2), f32(i32(it.first) * ss + board_y + ss / 2), 0, c, 255, s})
          add_thing(&kabooms, Explosion{it.second, it.first, 6})
        }
      }
    }
    rl.BeginDrawing()
    rl.ClearBackground(rl.RAYWHITE)
    rl.DrawRectangle(board_x, board_y, ss * auto_cast board_size, ss * auto_cast board_size, rl.BLACK)
    for i in 0 ..< board_size do for j in 0 ..< board_size {
      pos_x, pos_y := board_x + auto_cast i * ss + so, board_y + auto_cast j * ss + so
      radius := (ss - 2 * so) / 2
      back_color := rl.GRAY
      switch {
      case hints && is_matched(game.board, j, i): back_color = rl.DARKGRAY
      case hints && is_three(game.board, j, i): back_color = rl.LIGHTGRAY
      }
      rl.DrawRectangle(pos_x, pos_y, ss - 2 * so, ss - 2 * so, back_color)
      switch at(game.board, j, i) {
      case .NONE: rl.DrawPoly(v2({pos_x + radius, pos_y + radius}), 4, f32(radius) * 1.2, 45, rl.BLACK)
      case .SQUARE: rl.DrawPoly(v2({pos_x + radius, pos_y + radius}), 4, f32(radius) * 1.2 - mo, 45, nonacid_colors ? rl.PINK : rl.RED)
      case .CIRCLE: rl.DrawCircle(pos_x + radius, pos_y + radius, f32(radius) - mo, nonacid_colors ? rl.LIME : rl.GREEN)
      case .HEXAGON: rl.DrawPoly(v2({pos_x + radius, pos_y + radius}), 6, f32(radius) - mo, 0, nonacid_colors ? rl.SKYBLUE : rl.BLUE)
      case .TRIANGLE: rl.DrawPoly({f32(pos_x + radius), f32(pos_y) + f32(radius) * 1.3}, 3, f32(radius) * 1.2 - mo, -90, nonacid_colors ? rl.GOLD : rl.ORANGE)
      case .PENTAGON: rl.DrawPoly({f32(pos_x + radius), f32(pos_y) + f32(radius) * 1.1}, 5, f32(radius) - mo, -90, nonacid_colors ? rl.PURPLE : rl.MAGENTA)
      case .RHOMBUS: rl.DrawPoly(v2({pos_x + radius, pos_y + radius}), 4, f32(radius) - mo, 0, nonacid_colors ? rl.GOLD : rl.YELLOW)
      case .BRICK: rl.DrawPoly(v2({pos_x + radius, pos_y + radius}), 4, f32(radius) * 1.4, 45, nonacid_colors ? rl.BROWN : rl.BEIGE)
      }
      if is_magic(game.board, j, i) do rl.DrawCircleGradient(pos_x + radius, pos_y + radius, f32(ss) / 6, rl.WHITE, game.board.magic_tiles[{j, i}] < 0 ? rl.BLACK : rl.DARKPURPLE)
    }
    if !first_click {
      pos := rl.GetMousePosition() - {f32(board_x), f32(board_y)}
      if !(pos.x < 0 || pos.y < 0 || pos.x > f32(ss * auto_cast board_size) || pos.y > f32(ss * auto_cast board_size)) {
        row, col := i32(pos.y / auto_cast ss), i32(pos.x / auto_cast ss)
        dx, dy := col - saved_col, row - saved_row
        radius := (ss - 2 * so) / 2
        pos_x, pos_y := board_x + saved_col * ss + so, board_y + saved_row * ss + so
        if dx == 1 && dy == 0 || dx == 0 && dy == 1 {
          (dx == 1 ? rl.DrawRectangleGradientH : rl.DrawRectangleGradientV)(pos_x + radius - 10, pos_y + radius - 10, dx == 1 ? ss / 2 : 20, dy == 1 ? ss / 2 : 20, rl.BLANK, rl.MAROON)
          rl.DrawPoly({f32(pos_x + radius + (dx == 1 ? ss / 2 : 0)), f32(pos_y + radius + (dy == 1 ? ss / 2 : 0))}, 3, f32(radius) - mo, dx == 1 ? 0 : 90, rl.MAROON)
        }
        if dx == -1 && dy == 0 || dx == 0 && dy == -1 {
          if dx == -1 do rl.DrawRectangleGradientH(pos_x + radius - (dx == -1 ? ss / 2 - 10 : 0), pos_y + radius - (dy == -1 ? ss / 2 : 10), dx == -1 ? ss / 2 : 20, dy == -1 ? ss / 2 + 10 : 20, rl.MAROON, rl.BLANK)
          else do rl.DrawRectangleGradientV(pos_x + radius - (dx == -1 ? ss / 2 : 10), pos_y + radius - (dy == -1 ? ss / 2 - 10 : 0), dx == -1 ? ss / 2 + 10 : 20, dy == -1 ? ss / 2 : 20, rl.MAROON, rl.BLANK)
          rl.DrawPoly(v2({pos_x + radius - (dx == -1 ? ss / 2 : 0), pos_y + radius - (dy == -1 ? ss / 2 : 0)}), 3, f32(radius) - mo, dx == -1 ? 180 : 270, rl.MAROON)
        }
      }
    }
    if input_name {
      c := rl.GetCharPressed()
      if unicode.is_alpha(c) || unicode.is_number(c) || c == '_' && len(game.name) < 22 && !ignore_r do strings.write_rune(&builder, c)
      ignore_r = false
      rl.DrawRectangle(w / 4, h / 2 - h / 16, w / 2, h / 8, rl.WHITE)
      rl.DrawText("Enter your name:", w / 4, h / 2 - h / 16, 50, rl.BLACK)
      rl.DrawText(fmt.ctprintf("%s", strings.to_string(builder)), w / 4, h / 2 - h / 16 + 50, 50, rl.BLACK)
    }
    if draw_leaderboard && !input_name {
      wheel_move := rl.GetMouseWheelMove()
      kd, ku := rl.IsKeyPressed(rl.KeyboardKey.DOWN), rl.IsKeyPressed(rl.KeyboardKey.UP)
      if wheel_move == 0 {
        if kd do wheel_move = -1
        if ku do wheel_move = 1
      }
      if wheel_move != 0 {
        if l_offset != 0 || wheel_move <= 0 do l_offset -= wheel_move < 0 ? -1 : 1
        l_offset = min(l_offset, len(leaderboard) - 1)
      }
      DrawLeaderboard(&leaderboard, l_offset, leaderboard_place)
    }
    rl.DrawText(fmt.ctprintf("%s", game_stats(game)), 3, 0, 30, rl.BLACK)
    rl.DrawText(fmt.ctprintf("Player:\n%s", game.name), 3, h - 55, 20, rl.BLACK)
    bm := ButtonMaker {
      play_sound = is_play_sound,
      sound      = ksound,
      volume     = volume,
    }
    defer delete_button_maker(&bm)
    start_y: i32 = 0
    inc :: proc(var: ^i32, val: i32) -> i32 {
      var^ += val
      return var^
    }
    draw_button(&bm, {w - 210, h - inc(&start_y, 40)}, "SOUND", true)
    particles_button := draw_button(&bm, {w - 210, h - inc(&start_y, 40)}, "PARTICLES", particles)
    hints_button := draw_button(&bm, {w - 210, h - inc(&start_y, 40)}, "HINTS", hints)
    acid_button := draw_button(&bm, {w - 210, h - inc(&start_y, 40)}, "NO ACID", nonacid_colors)
    lbutton := draw_button(&bm, {w - 210, h - inc(&start_y, 40)}, "LEADERBOARD", draw_leaderboard)
    rbutton := draw_button(&bm, {w - 210, h - inc(&start_y, 40)}, "RESTART", false)
    load_button := draw_button(&bm, {w - 210, h - inc(&start_y, 40)}, "LOAD", false)
    save_button := draw_button(&bm, {w - 210, h - inc(&start_y, 40)}, "SAVE", false)
    play_sound(bm)
    volume = bm.volume
    if volume < 0.05 do volume = 0
    if volume >= 0.99 do volume = 1
    is_play_sound = volume != 0
    if particles {
      for &p in kabooms {
        if p.lifetime == 0 do continue
        rl.DrawRectangle(board_x + i32(p.x) * ss + so, board_y + i32(p.y) * ss + so, ss - 2 * so, ss - 2 * so, rl.WHITE)
        p.lifetime -= 1
      }
      for &p in flying {
        if p.y > auto_cast h || p.x < 0 || p.x > auto_cast w do p.lifetime = 0
        if p.lifetime == 0 do continue
        p.color.a = u8(p.lifetime)
        if p.sides == 0 do rl.DrawCircle(auto_cast p.x, auto_cast p.y, auto_cast ss / 2, p.color)
        else do rl.DrawPoly({auto_cast p.x, auto_cast p.y}, auto_cast p.sides, auto_cast ss / 2, p.a, p.color)
        p.y += p.dy
        p.x += p.dx
        p.a += p.da
        p.dy += 1
        p.lifetime -= 1
      }
    }
    rl.EndDrawing()
    outside: {
      if !input_name && !is_processing(game) do if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
        pos := rl.GetMousePosition()
        button_flag(pos, particles_button, &particles)
        button_flag(pos, hints_button, &hints)
        button_flag(pos, acid_button, &nonacid_colors)
        button_flag(pos, lbutton, &draw_leaderboard)
        if in_button(pos, rbutton) {
          new_game(&game)
          input_name = true
        }
        if in_button(pos, load_button) do load(&game)
        if in_button(pos, save_button) do save(game)
        if draw_leaderboard do break outside
        pos = pos - {auto_cast board_x, auto_cast board_y}
        if pos.x < 0 || pos.y < 0 || pos.x > f32(ss * auto_cast board_size) || pos.y > f32(ss * auto_cast board_size) do break outside
        row, col := i32(pos.y / auto_cast ss), i32(pos.x / auto_cast ss)
        if first_click {
          saved_row = row
          saved_col = col
          first_click = false
        } else {
          first_click = true
          if bool(int(abs(row - saved_row) == 1) ~ int(abs(col - saved_col) == 1)) do attempt_move(&game, row, col, saved_row, saved_col)
        }
      } else if rl.IsMouseButtonReleased(rl.MouseButton.LEFT) {
        pos := rl.GetMousePosition() - {f32(board_x), f32(board_y)}
        if pos.x < 0 || pos.y < 0 || pos.x > f32(ss * i32(board_size)) || pos.y > f32(ss * i32(board_size)) do break outside
        row, col := i32(pos.y / f32(ss)), i32(pos.x / f32(ss))
        if row != saved_row || col != saved_col {
          if !first_click {
            first_click = true
            if bool(int(abs(row - saved_row) == 1) ~ int(abs(col - saved_col) == 1)) do attempt_move(&game, row, col, saved_row, saved_col)
          }
        }
      }
    }
    if rl.IsKeyPressed(.ENTER) && input_name {
      input_name = false
      delete(game.name)
      if len(strings.to_string(builder)) == 0 do game.name = strings.clone("dupa")
      else do game.name = strings.clone(strings.to_string(builder))
    } else if rl.IsKeyPressed(.BACKSPACE) {
      strings.pop_rune(&builder)
    } else if !input_name {
      for {
        key := rl.GetKeyPressed()
        if key == .KEY_NULL do break
        #partial switch key {
        case .R:
          new_game(&game)
          ignore_r = true
          input_name = true
          strings.builder_reset(&builder)
        case .L:
          draw_leaderboard = !draw_leaderboard
          if !draw_leaderboard do leaderboard_place = -1
        case .P: particles = !particles
        case .M: is_play_sound = !is_play_sound
        case .H: hints = !hints
        case .A: nonacid_colors = !nonacid_colors
        case .S: save(game)
        case .O: load(&game)
        }
      }
    }
    if is_finished(game, opts.steps) {
      for lr, idx in leaderboard do if lr.score < game.board.score {
        inject_at(&leaderboard, idx, LeaderboardRecord{strings.clone(game.name), game.board.score})
        leaderboard_place = idx
        l_offset = max(0, idx - 4)
        break
      }
      if leaderboard_place == -1 {
        leaderboard_place = len(leaderboard)
        append(&leaderboard, LeaderboardRecord{strings.clone(game.name), game.board.score})
        l_offset = max(0, leaderboard_place - 4)
      }
      WriteLeaderboard(&leaderboard)
      new_game(&game)
      draw_leaderboard = true
    }
  }
}

