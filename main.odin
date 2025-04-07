#+feature dynamic-literals
package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:slice"
import rl "vendor:raylib"

Point :: distinct [2]int

Pattern :: distinct [dynamic]Point

SizedPattern :: struct {
  pat: Pattern,
  w:   int,
  h:   int,
}

shift :: proc(p: Pattern) -> Pattern {
  minX := max(int)
  minY := max(int)
  for &pt in p {
    minX = min(pt.x, minX)
    minY = min(pt.y, minY)
  }
  res: Pattern
  copy(res[:], p[:])
  for &pt in res {
    pt -= {minX, minY}
  }
  return res
}

rotations :: proc(p: Pattern) -> [4]Pattern {
  res: [4]Pattern
  res[0] = p
  for i := 1; i < 4; i += 1 {
    rotated := make(Pattern, len(p))
    for j := 0; j < len(p); j += 1 {
      rotated[j].x = res[i - 1][j].y
      rotated[j].y = -res[i - 1][j].x
    }
    res[i] = shift(rotated)
  }
  return res
}

mirrored :: proc(p: Pattern) -> Pattern {
  m: Pattern
  for i := 0; i < len(p); i += 1 {
    m[i].y = -p[i].y
  }
  return shift(m)
}

sized :: proc(p: Pattern) -> SizedPattern {
  res: SizedPattern
  res.pat = p
  maxX := min(int)
  maxY := min(int)
  for &pt in p {
    maxX = max(pt.x, maxX)
    maxY = max(pt.y, maxY)
  }
  res.w = int(maxX + 1)
  res.h = int(maxY + 1)
  return res
}

generate :: proc(p: Pattern, symmetric: bool = false) -> [dynamic]SizedPattern {
  s := rotations(p)
  res1: [dynamic]Pattern
  if !symmetric {
    m := mirrored(p)
    r := rotations(m)
    reserve(&res1, len(s) + len(r))
    copy(res1[:], r[:])
  } else {
    reserve(&res1, len(s))
  }
  copy(res1[:], s[:])
  res2: [dynamic]SizedPattern
  reserve(&res2, len(res1))
  for pt in res1 {
    append(&res2, sized(pt))
  }
  delete(res1)
  return res2
}

three_p_1: Pattern = {{0, 0}, {1, 1}, {0, 2}}
three_p_2: Pattern = {{1, 0}, {0, 1}, {0, 2}}
three_p_3: Pattern = {{0, 0}, {0, 1}, {0, 3}}
four_p: Pattern = {{0, 0}, {1, 1}, {0, 2}, {0, 3}}
five_p_1: Pattern = {{0, 0}, {0, 1}, {1, 2}, {0, 3}, {0, 4}}
five_p_2: Pattern = {{0, 0}, {1, 1}, {1, 2}, {2, 0}, {3, 0}}
//
threes1 := generate(three_p_1)
threes2 := generate(three_p_2)
threes3 := generate(three_p_3)
fours := generate(four_p)
fives1 := generate(five_p_1)
fives2 := generate(five_p_2)
threes_f :: proc() -> [dynamic]SizedPattern {
  res := make([dynamic]SizedPattern, len(threes1) + len(threes2) + len(threes3))
  copy(res[:], threes1[:])
  copy(res[len(threes1):], threes2[:])
  copy(res[len(threes1) + len(threes3):], threes3[:])
  return res
}
threes := threes_f()
patterns_f :: proc() -> [dynamic]SizedPattern {
  res := make([dynamic]SizedPattern, len(fours) + len(fives1) + len(fives2))
  copy(res[:], fours[:])
  copy(res[len(fours):], fives1[:])
  copy(res[len(fours) + len(fives1):], fives2[:])
  return res
}
patterns := patterns_f()
Pair :: struct {
  first:  int,
  second: int,
}
Triple :: struct {
  first:  int,
  second: int,
  third:  int,
}
Board :: struct {
  board:            [dynamic]int,
  w:                int,
  h:                int,
  matched_patterns: map[Pair]struct {},
  matched_threes:   map[Pair]struct {},
  magic_tiles:      map[Pair]struct {},
  magic_tiles2:     map[Pair]struct {},
  rm_i:             [dynamic]Triple,
  rm_j:             [dynamic]Triple,
  rm_b:             [dynamic]Pair,
  score:            int,
  normals:          int,
  longers:          int,
  longests:         int,
  crosses:          int,
}
coin :: proc() -> int {
  return rand.int_max(42) + 1
}
coin2 :: proc() -> int {
  return rand.int_max(69) + 1
}
uniform_dist :: proc() -> int {
  return rand.int_max(6) + 1
}
uniform_dist_2 :: proc(b: Board) -> int {
  return rand.int_max(b.w)
}
uniform_dist_3 :: proc(b: Board) -> int {
  return rand.int_max(b.h)
}
make_board :: proc(w, h: int) -> Board {
  b: Board
  b.w = w
  b.h = h
  b.board = make([dynamic]int, w * h)
  b.matched_patterns = make(map[Pair]struct {})
  b.matched_threes = make(map[Pair]struct {})
  b.magic_tiles = make(map[Pair]struct {})
  b.magic_tiles2 = make(map[Pair]struct {})
  return b
}
delete_board :: proc(b: ^Board) {
  delete(b.board)
  delete(b.matched_patterns)
  delete(b.matched_threes)
  delete(b.magic_tiles)
  delete(b.magic_tiles2)
}
copy_set :: proc(m: map[Pair]struct {}) -> map[Pair]struct {} {
  m1 := make(map[Pair]struct {}, len(m))
  for k, _ in m {
    m1[k] = {}
  }
  return m1
}
copy_board :: proc(b: Board) -> Board {
  b1 := make_board(b.w, b.h)
  copy(b1.board[:], b.board[:])
  b1.score = b.score
  b1.matched_patterns = copy_set(b.matched_patterns)
  b1.magic_tiles = copy_set(b.magic_tiles)
  b1.magic_tiles2 = copy_set(b.magic_tiles2)
  return b1
}
at :: proc(brd: Board, a, b: int) -> int {
  return brd.board[a * brd.h + b]
}
set_at :: proc(brd: ^Board, a, b, v: int) {
  brd.board[a * brd.h + b] = v
}
match_pattern :: proc(b: Board, x, y: int, p: SizedPattern) -> bool {
  color := at(b, x + p.pat[0].x, y + p.pat[0].y)
  for i := 1; i < len(p.pat); i += 1 {
    if color == at(b, x + p.pat[i].x, y + p.pat[i].y) {
      return false
    }
  }
  return true
}
match_patterns :: proc(b: ^Board) {
  clear(&b.matched_patterns)
  for sp in patterns {
    for i := 0; i <= b.w - sp.w; i += 1 {
      for j := 0; j <= b.h - sp.h; j += 1 {
        if match_pattern(b^, i, j, sp) {
          for p in sp.pat {
            b.matched_patterns[{i + p.x, j + p.y}] = {}
          }
        }
      }
    }
  }
}
is_matched :: proc(b: Board, x, y: int) -> bool {
  return {x, y} in b.matched_patterns
}
is_magic :: proc(b: Board, x, y: int) -> bool {
  return {x, y} in b.magic_tiles
}
is_magic2 :: proc(b: Board, x, y: int) -> bool {
  return {x, y} in b.magic_tiles2
}
swap :: proc(b: ^Board, x1, y1, x2, y2: int) {
  tmp := at(b^, x1, y1)
  set_at(b, x1, y1, at(b^, x2, y2))
  set_at(b, x2, y2, tmp)

  if is_magic(b^, x1, y1) {
    delete_key(&b.magic_tiles, Pair{x1, y1})
    b.magic_tiles[{x2, y2}] = {}
  }
  if is_magic(b^, x2, y2) {
    delete_key(&b.magic_tiles, Pair{x2, y2})
    b.magic_tiles[{x1, y1}] = {}
  }
  if is_magic2(b^, x1, y1) {
    delete_key(&b.magic_tiles2, Pair{x1, y1})
    b.magic_tiles2[{x2, y2}] = {}
  }
  if is_magic2(b^, x2, y2) {
    delete_key(&b.magic_tiles2, Pair{x2, y2})
    b.magic_tiles2[{x1, y1}] = {}
  }
}
fill :: proc(b: ^Board) {
  for &x in b.board {
    x = uniform_dist()
  }
}
reasonable_coord :: proc(b: Board, i, j: int) -> bool {
  return i >= 0 && i < b.w && j >= 0 && j < b.h
}
remove_trios :: proc(b: ^Board) {
  remove_i := make([dynamic]Triple)
  remove_j := make([dynamic]Triple)
  for i := 0; i < b.w; i += 1 {
    for j := 0; j < b.h; j += 1 {
      offset_i := 1
      offset_j := 1
      for (j + offset_j < b.h && at(b^, i, j) == at(b^, i, j + offset_j)) {
        offset_j += 1
      }
      if offset_j > 2 {
        append(&remove_i, Triple{i, j, offset_j})
      }
      for (i + offset_i < b.w && at(b^, i, j) == at(b^, i + offset_i, j)) {
        offset_i += 1
      }
      if offset_i > 2 {
        append(&remove_j, Triple{i, j, offset_i})
      }
    }
  }
  for t in remove_i {
    i := t.first
    j := t.second
    offset := t.third
    if offset == 4 {
      j = 0
      offset = b.h
      b.longers += 1
      b.normals += max(0, b.normals - 1)
    }
    for jj := j; jj < j + offset; jj += 1 {
      set_at(b, i, jj, 0)
      if is_magic(b^, i, jj) {
        b.score -= 3
        delete_key(&b.magic_tiles, Pair{i, jj})
      }
      if is_magic2(b^, i, jj) {
        b.score += 3
        delete_key(&b.magic_tiles2, Pair{i, jj})
      }
      b.score += 1
    }
    if offset == 5 {
      for i := 0; i < b.w; i += 1 {
        set_at(b, uniform_dist_2(b^), uniform_dist_3(b^), 0)
        b.score += 1
      }
      b.longests += 1
      b.normals = max(0, b.normals - 1)
    }
    b.normals += 1
  }
  for t in remove_j {
    i := t.first
    j := t.second
    offset := t.third
    if offset == 4 {
      i = 0
      offset = b.w
      b.longers += 1
      b.normals = max(0, b.normals - 1)
    }
    for ii := i; ii < i + offset; ii += 1 {
      set_at(b, ii, j, 0)
      if is_magic(b^, ii, j) {
        b.score -= 3
        delete_key(&b.magic_tiles, Pair{ii, j})
      }
      if is_magic2(b^, ii, j) {
        b.score += 3
        delete_key(&b.magic_tiles2, Pair{ii, j})
      }
      b.score += 1
    }
    if offset == 5 {
      for i := 0; i < b.w; i += 1 {
        set_at(b, uniform_dist_2(b^), uniform_dist_3(b^), 0)
        b.score += 1
      }
      b.longests += 1
      b.normals = max(0, b.normals - 1)
    }
    b.normals += 1
  }
  for i := 0; i < len(remove_i); i += 1 {
    for j := 0; j < len(remove_j); j += 1 {
      t1 := remove_i[i]
      t2 := remove_j[j]
      i1 := t1.first
      j1 := t1.second
      o1 := t1.third
      i2 := t2.first
      j2 := t2.second
      o2 := t2.third
      if i1 >= i2 && i1 < (i2 + o2) && j2 >= j1 && j2 < (j1 + o1) {
        for m := -1; m < 2; m += 1 {
          for n := -1; n < 2; n += 1 {
            if reasonable_coord(b^, i1 + m, j1 + n) {
              set_at(b, i1 + m, j1 + n, 0)
              b.score += 1
            }
          }
        }
        b.crosses += 1
        b.normals = max(0, b.normals - 2)
      }
    }
  }
}
fill_up :: proc(b: ^Board) {
  curr_i := -1
  for i := 0; i < b.w; i += 1 {
    for j := 0; j < b.h; j += 1 {
      if at(b^, i, j) == 0 {
        curr_i = i
        for curr_i < b.w - 1 && at(b^, curr_i + 1, j) == 0 {
          curr_i += 1
        }
        for k := curr_i; k >= 0; k -= 1 {
          if at(b^, k, j) != 0 {
            set_at(b, curr_i, j, at(b^, k, j))
            if is_magic(b^, k, j) {
              delete_key(&b.magic_tiles, Pair{k, j})
              b.magic_tiles[{curr_i, j}] = {}
            }
            if is_magic2(b^, k, j) {
              delete_key(&b.magic_tiles2, Pair{k, j})
              b.magic_tiles2[{curr_i, j}] = {}
            }
            curr_i -= 1
          }
        }
        for k := curr_i; k >= 0; k -= 1 {
          set_at(b, k, j, uniform_dist())
          if coin() == 1 {
            b.magic_tiles[{k, j}] = {}
          }
          if coin2() == 1 {
            b.magic_tiles2[{k, j}] = {}
          }
        }
      }
    }
  }
}
compare_boards :: proc(b1: Board, b2: Board) -> bool {
  if b1.w != b2.w || b1.h != b2.h {
    return false
  }
  for i := 0; i < b1.w * b1.h; i += 1 {
    if b1.board[i] != b2.board[i] {
      return false
    }
  }
  return true
}
match_threes :: proc(b: ^Board) {
  clear(&b.matched_threes)
  for sp in threes {
    for i := 0; i <= b.w - sp.w; i += 1 {
      for j := 0; j <= b.h - sp.h; j += 1 {
        if match_pattern(b^, i, j, sp) {
          for p in sp.pat {
            b.matched_threes[{i + p.x, j + p.y}] = {}
          }
        }
      }
    }
  }
}
is_three :: proc(b: Board, i, j: int) -> bool {
  return {i, j} in b.matched_threes
}
stabilize :: proc(b: ^Board) {
  for {
    old_board := copy_board(b^)
    defer delete_board(&old_board)
    remove_trios(b)
    fill_up(b)
    if compare_boards(old_board, b^) {
      break
    }
  }
  match_patterns(b)
  match_threes(b)
}
step :: proc(b: ^Board) {
  remove_trios(b)
  fill_up(b)
  match_patterns(b)
  match_threes(b)
}
zero :: proc(b: ^Board) {
  b.score = 0
  b.normals = 0
  b.longers = 0
  b.longests = 0
  b.crosses = 0
}
// New interface starts here

remove_one_thing :: proc(b: ^Board) -> [dynamic]Triple {
  res := make([dynamic]Triple)
  if len(b.rm_i) != 0 {
    t := b.rm_i[len(b.rm_i) - 1]
    i := t.first
    j := t.second
    offset := t.third
    if offset == 4 {
      j = 0
      offset = b.h
      b.longers += 1
      b.normals = max(0, b.normals - 1)
    }
    for jj := j; jj < j + offset; jj += 1 {
      append(&res, Triple{i, jj, at(b^, i, jj)})
      set_at(b, i, jj, 0)
      if is_magic(b^, i, jj) {
        b.score -= 3
        delete_key(&b.magic_tiles, Pair{i, jj})
      }
      if is_magic2(b^, i, jj) {
        b.score += 3
        delete_key(&b.magic_tiles2, Pair{i, jj})
      }
      b.score += 1
    }
    if offset == 5 {
      r := make(map[Pair]struct {})
      for i := 0; i < b.w; i += 1 {
        x, y: int
        for {
          x = uniform_dist_2(b^)
          y = uniform_dist_3(b^)
          if ({x, y} in r) {
            break
          }
        }
        r[{x, y}] = {}
        append(&res, Triple{x, y, at(b^, x, y)})
        set_at(b, x, y, 0)
        b.score += 1
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
    i := t.first
    j := t.second
    offset := t.third
    if offset == 4 {
      i = 0
      offset = b.w
      b.longers += 1
      b.normals = max(0, b.normals - 1)
    }
    for ii := i; ii < i + offset; ii += 1 {
      append(&res, Triple{ii, j, at(b^, ii, j)})
      set_at(b, ii, j, 0)
      if is_magic(b^, ii, j) {
        b.score -= 3
        delete_key(&b.magic_tiles, Pair{ii, j})
      }
      if is_magic2(b^, ii, j) {
        b.score += 3
        delete_key(&b.magic_tiles2, Pair{ii, j})
      }
      b.score += 1
    }
    if offset == 5 {
      r := make(map[Pair]struct {})
      for i := 0; i < b.w; i += 1 {
        x, y: int
        for {
          x = uniform_dist_2(b^)
          y = uniform_dist_3(b^)
          if ({x, y} in r) {
            break
          }
        }
        r[{x, y}] = {}
        append(&res, Triple{x, y, at(b^, x, y)})
        set_at(b, x, y, 0)
        b.score += 1
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
    i := t.first
    j := t.second
    for m := -2; m < 3; m += 1 {
      for n := -2; n < 3; n += 1 {
        if reasonable_coord(b^, i + m, j + n) {
          append(&res, Triple{i + m, j + n, at(b^, i + m, j + n)})
          set_at(b, i + m, j + n, 0)
          b.score += 1
        }
      }
    }
    b.crosses += 1
    b.normals = max(0, b.normals - 2)
    pop(&b.rm_b)
    return res
  }
  return res
}
prepare_removals :: proc(b: ^Board) {
  clear(&b.rm_i)
  clear(&b.rm_j)
  clear(&b.rm_b)
  clear(&b.matched_patterns)
  clear(&b.matched_threes)
  for i := 0; i < b.w; i += 1 {
    for j := 0; j < b.h; j += 1 {
      offset_j := 1
      offset_i := 1
      for j + offset_j < b.h && at(b^, i, j) == at(b^, i, j + offset_j) {
        offset_j += 1
      }
      if offset_j > 2 {
        append(&b.rm_i, Triple{i, j, offset_j})
      }
      for i + offset_i < b.w && at(b^, i, j) == at(b^, i + offset_i, j) {
        offset_i += 1
      }
      if offset_i > 2 {
        append(&b.rm_j, Triple{i, j, offset_i})
      }
    }
  }
  for i := 0; i < len(b.rm_i); i += 1 {
    for j := 0; j < len(b.rm_j); j += 1 {
      t1 := b.rm_i[i]
      t2 := b.rm_j[j]
      i1 := t1.first
      j1 := t1.second
      o1 := t1.third
      i2 := t2.first
      j2 := t2.second
      o2 := t2.third
      if i1 >= i2 && i1 < (i2 + o2) && j2 >= j1 && j2 < (j1 + o1) {
        append(&b.rm_b, Pair{i1, j2})
      }
    }
  }
  slice.sort_by(b.rm_i[:], proc(a, b: Triple) -> bool {
    return a.first > b.first
  })
  slice.sort_by(b.rm_j[:], proc(a, b: Triple) -> bool {
    return a.first > b.first
  })
  slice.sort_by(b.rm_b[:], proc(a, b: Pair) -> bool {
    return a.first > b.first
  })
}
has_removals :: proc(b: Board) -> bool {
  return bool(len(b.rm_i) + len(b.rm_j) + len(b.rm_b))
}
//std::ostream &operator<<(std::ostream &of, const Board &b) {
//  of << b.score << "\n"
//     << b.normals << "\n"
//     << b.longers << "\n"
//     << b.longests << "\n"
//     << b.crosses << "\n"
//     << b.w << " " << b.h << "\n"
//  for (int i = 0; i < b.w; ++i) {
//    for (int j = 0; j < b.h; ++j) {
//      of << b.at(i, j) << " "
//    }
//    of << std::endl
//  }
//  of << b.magic_tiles.size() << "\n"
//  for (auto it = b.magic_tiles.begin(); it != b.magic_tiles.end(); ++it) {
//    of << it->first << " " << it->second << " "
//  }
//  of << "\n"
//  of << b.magic_tiles2.size() << "\n"
//  for (auto it = b.magic_tiles2.begin(); it != b.magic_tiles2.end(); ++it) {
//    of << it->first << " " << it->second << " "
//  }
//  of << "\n"
//  return of
//}
//
//std::istream &operator>>(std::istream &in, Board &b) {
//  in >> b.score >> b.normals >> b.longers >> b.longests >> b.crosses >> b.w >>
//      b.h
//  b.board.resize(b.w * b.h)
//  for (int i = 0; i < b.w; ++i) {
//    for (int j = 0; j < b.h; ++j) {
//      in >> b.at(i, j)
//    }
//  }
//  int s
//  in >> s
//  b.magic_tiles.clear()
//  int i, j
//  for (int k = 0; k < s; ++k) {
//    in >> i >> j
//    b.magic_tiles.insert({i, j})
//  }
//  in >> s
//  for (int k = 0; k < s; ++k) {
//    in >> i >> j
//    b.magic_tiles2.insert({i, j})
//  }
//  return in
//}
//
LeaderboardRecord :: struct {
  name:  string,
  score: int,
}
Leaderboard :: distinct [dynamic]LeaderboardRecord
//using Leaderboard = std::vector<std::pair<std::string, int>>
//
//Leaderboard ReadLeaderboard() {
//  Leaderboard res
//  std::ifstream input("leaderboard.txt")
//  std::string line
//  while (std::getline(input, line)) {
//    auto idx = line.find(';')
//    if (idx != std::string::npos) {
//      std::string name = line.substr(0, idx)
//      int score = std::stoi(line.substr(idx + 1))
//      res.emplace_back(name, score)
//    }
//  }
//  std::sort(std::begin(res), std::end(res),
//            [](auto &a, auto &b) { return a.second > b.second; })
//  return res
//}
//
//void WriteLeaderboard(Leaderboard leaderboard) {
//  std::string text
//  std::sort(std::begin(leaderboard), std::end(leaderboard),
//            [](auto &a, auto &b) { return a.second > b.second; })
//  for (auto it : leaderboard) {
//    text += fmt::format("{};{}\n", it.first, it.second)
//  }
//  std::ofstream output("leaderboard.txt")
//  output << text
//}
//
//void DrawLeaderboard(Leaderboard leaderboard, size_t offset, int place) {
//  auto w = GetRenderWidth()
//  auto h = GetRenderHeight()
//  auto start_y = h / 4 + 10
//  DrawRectangle(w / 4, h / 4, w / 2, h / 2, WHITE)
//  DrawText("Leaderboard:", w / 4 + 10, start_y, 20, BLACK)
//  std::sort(std::begin(leaderboard), std::end(leaderboard),
//            [](auto &a, auto &b) { return a.second > b.second; })
//  offset = std::min(offset, leaderboard.size() - 1)
//  auto finish = std::min(offset + 9, leaderboard.size())
//  for (auto it = leaderboard.begin() + offset
//       it != leaderboard.begin() + finish; ++it) {
//    std::string text = fmt::format(
//        "{}. {}: {}\n", (it - leaderboard.begin()) + 1, it->first, it->second)
//    start_y += 30
//    Color c = BLACK
//    switch (it - leaderboard.begin()) {
//    case 0:
//      c = GOLD
//      break
//    case 1:
//      c = GRAY
//      break
//    case 2:
//      c = ORANGE
//      break
//    default:
//      break
//    }
//    if (place == it - leaderboard.begin()) {
//      auto width = MeasureText(text.c_str(), 20)
//      DrawRectangle(w / 4 + 5, start_y, width + 10, 25, LIGHTGRAY)
//    }
//    DrawText(text.c_str(), w / 4 + 10, start_y, 20, c)
//  }
//  if (finish != leaderboard.size()) {
//    DrawText("...", w / 4 + 10, start_y + 30, 20, BLACK)
//  }
//}
//
Button :: struct {
  x1: f32,
  y1: f32,
  x2: f32,
  y2: f32,
}
//
in_button :: proc(pos: rl.Vector2, button: Button) -> bool {
  return pos.x > button.x1 && pos.x < button.x2 && pos.y > button.y1 && pos.y < button.y2
}
//
//bool operator==(const Color &a, const Color &b) {
//  return a.r == b.r && a.g == b.g && a.b == a.b && a.a == b.a
//}
//class ButtonMaker {
//  bool _play_sound
//  Sound _sound
//  float _volume
//  std::vector<Button> buttons
//  static bool enter
//
//public:
//  ButtonMaker(bool play_sound, Sound sound, float volume)
//      : _play_sound{play_sound}, _sound{sound}, _volume{volume} {}
//  Button draw_button(Vector2 place, std::string text, bool enabled) {
//    bool button_down = IsMouseButtonDown(MOUSE_BUTTON_LEFT)
//    auto pos = GetMousePosition()
//    if (in_button(pos, Button{int(place.x), int(place.y), int(place.x + 200),
//                              int(place.y + 30)})) {
//      Color c = enabled ? YELLOW : (button_down ? DARKGRAY : LIGHTGRAY)
//      if (text == "SOUND") {
//        int level = int(_volume * 200)
//        DrawRectangle(place.x, place.y, level, 30, YELLOW)
//        DrawRectangle(place.x + level, place.y, 200 - level, 30, LIGHTGRAY)
//        if (button_down) {
//          int x = GetMouseX()
//          _volume = (x - place.x) / 200.0
//        }
//      } else {
//        DrawRectangle(place.x, place.y, 200, 30, c)
//      }
//    } else {
//      Color c = enabled ? GOLD : GRAY
//      if (text == "SOUND") {
//        int level = int(_volume * 200)
//        DrawRectangle(place.x, place.y, level, 30, GOLD)
//        DrawRectangle(place.x + level, place.y, 200 - level, 30, GRAY)
//      } else {
//        DrawRectangle(place.x, place.y, 200, 30, c)
//      }
//    }
//    const char *label =
//        text == "SOUND" ? fmt::format("SOUND ({}%)", int(_volume * 100)).c_str()
//                        : text.c_str()
//    auto width = MeasureText(label, 20)
//    DrawText(label, place.x + 100 - width / 2, place.y + 5, 20, BLACK)
//    auto button = Button{int(place.x), int(place.y), int(place.x + 200),
//                         int(place.y + 30)}
//    buttons.push_back(button)
//    return button
//  }
//  void play_sound() {
//    if (!_play_sound) {
//      return
//    }
//    bool in = false
//    for (auto it = buttons.begin(); it != buttons.end(); ++it) {
//      auto pos = GetMousePosition()
//      if (in_button(pos, *it)) {
//        in = true
//        if (enter) {
//          enter = false
//          if (IsSoundReady(_sound)) {
//            PlaySound(_sound)
//          }
//        }
//      }
//    }
//    if (!in) {
//      enter = true
//    }
//  }
//  float volume() const { return _volume; }
//}
//
//bool ButtonMaker::enter = true
//
//class Game {
//  std::string _name
//  Board _board
//  Board _old_board
//  bool _work_board = false
//  bool _first_work = true
//  std::vector<std::tuple<int, int, int>> _removed_cells
//
//public:
//  Game(size_t size) : _board{size, size}, _old_board{_board} {}
//  int counter = 0
//  void new_game() {
//    counter = 0
//    _work_board = false
//    _board.fill()
//    _board.stabilize()
//    _board.zero()
//  }
//  void save() {
//    std::ofstream save("save.txt")
//    save << _name << " " << counter << "\n"
//    save << _board
//  }
//  bool load() {
//    std::ifstream load("save.txt")
//    if (load) {
//      _work_board = false
//      load >> _name >> counter >> _board
//      _board.match_patterns()
//      _board.match_threes()
//      return true
//    }
//    return false
//  }
//  void save_state() { _old_board = _board; }
//  bool check_state() const { return _old_board == _board; }
//  void restore_state() { _board = _old_board; }
//  void match() {
//    _board.match_patterns()
//    _board.match_threes()
//  }
//  Board &board() { return _board; }
//  std::string &name() { return _name; }
//  void attempt_move(int row1, int col1, int row2, int col2) {
//    _first_work = true
//    _work_board = true
//    save_state()
//    _board.swap(row1, col1, row2, col2)
//    _board.prepare_removals()
//  }
//  std::vector<std::tuple<int, int, int>> step() {
//    std::vector<std::tuple<int, int, int>> res
//    if (!_board.has_removals()) {
//      _board.prepare_removals()
//    }
//    if (!_board.has_removals()) {
//      if (_first_work) {
//        restore_state()
//      } else {
//        counter += 1
//      }
//      _work_board = false
//      _board.match_patterns()
//      _board.match_threes()
//    }
//    res = _board.remove_one_thing()
//    _board.fill_up()
//    _first_work = false
//    return res
//  }
//  bool is_finished() { return counter == 50; }
//  bool is_processing() { return _work_board; }
//  std::string game_stats() {
//    return fmt::format("Moves: {}\nScore: {}\nTrios: {}\nQuartets: "
//                       "{}\nQuintets: {}\nCrosses: {}",
//                       counter, _board.score, _board.normals, _board.longers,
//                       _board.longests, _board.crosses)
//  }
//}
//
//struct Particle {
//  float dx = 0
//  float dy = 0
//  float da = 0
//  float x = 0
//  float y = 0
//  float a = 0
//  Color color
//  int lifetime = 0
//  int sides = 0
//}
//
//struct Explosion {
//  int x = 0
//  int y = 0
//  int lifetime = 0
//}
//
//void button_flag(Vector2 pos, Button button, bool &flag) {
//  if (in_button(pos, button)) {
//    flag = !flag
//  }
//}
//
//int main() {
//  auto w = 1280
//  auto h = 800
//  auto board_size = 16
//  Game game(board_size)
//  bool first_click = true
//  int saved_row = 0
//  int saved_col = 0
//  bool draw_leaderboard = false
//  bool input_name = false
//  int frame_counter = 0
//  bool hints = false
//  bool particles = false
//  bool play_sound = false
//  bool nonacid_colors = false
//  bool ignore_r = false
//  size_t l_offset = 0
//  float volume = 0.0f
//  int leaderboard_place = -1
//  Leaderboard leaderboard = ReadLeaderboard()
//  std::vector<Particle> flying
//  std::vector<Explosion> staying
//  std::default_random_engine eng{static_cast<unsigned>(
//      std::chrono::system_clock::now().time_since_epoch().count())}
//  std::uniform_int_distribution<int> dd{-10, 10}
//  InitAudioDevice()
//  Sound psound = LoadSound("p.ogg")
//  Sound ksound = LoadSound("k.ogg")
//  if (!game.load()) {
//    game.new_game()
//    input_name = true
//  }
//  SetConfigFlags(FLAG_WINDOW_RESIZABLE)
//  InitWindow(w, h, "Tiar2")
//  auto icon = LoadImage("icon.png")
//  SetWindowIcon(icon)
//  SetTargetFPS(60)
//  SetTextLineSpacing(23)
//  while (!WindowShouldClose()) {
//    SetMasterVolume(volume)
//    if (frame_counter == 60) {
//      frame_counter = 0
//    } else {
//      frame_counter += 1
//    }
//    w = GetRenderWidth()
//    h = GetRenderHeight()
//    auto s = 0
//    if (w > h) {
//      s = h
//    } else {
//      s = w
//    }
//    auto margin = 10
//    auto board_x = w / 2 - s / 2 + margin
//    auto board_y = h / 2 - s / 2 + margin
//    auto ss = (s - 2 * margin) / board_size
//    auto so = 2
//    auto mo = 0.5
//    if (game.is_processing() && frame_counter % 6 == 0) {
//      auto f = game.step()
//      if (play_sound && !f.empty() && IsSoundReady(psound)) {
//        PlaySound(psound)
//      }
//      if (particles) {
//        if (play_sound && !f.empty()) {
//          board_x += dd(eng)
//          board_y += dd(eng)
//        }
//        flying.reserve(flying.size() + f.size())
//        staying.reserve(staying.size() + f.size())
//        for (auto it = f.begin(); it != f.end(); ++it) {
//          Color c
//          int s
//          switch (std::get<2>(*it)) {
//          case 1: {
//            c = nonacid_colors ? PINK : RED
//            s = 4
//            break
//          }
//          case 2: {
//            c = nonacid_colors ? LIME : GREEN
//            s = 0
//            break
//          }
//          case 3: {
//            c = nonacid_colors ? SKYBLUE : BLUE
//            s = 6
//            break
//          }
//          case 4: {
//            c = nonacid_colors ? GOLD : ORANGE
//            s = 3
//            break
//          }
//          case 5: {
//            c = nonacid_colors ? PURPLE : MAGENTA
//            s = 5
//            break
//          }
//          case 6: {
//            c = nonacid_colors ? BEIGE : YELLOW
//            s = 4
//            break
//          }
//          }
//          flying.emplace_back(dd(eng), dd(eng), dd(eng),
//                              std::get<1>(*it) * ss + board_x + ss / 2,
//                              std::get<0>(*it) * ss + board_y + ss / 2, 0, c, 0,
//                              s)
//          staying.emplace_back(std::get<1>(*it), std::get<0>(*it), 0)
//        }
//      }
//    }
//    BeginDrawing()
//    ClearBackground(RAYWHITE)
//    DrawRectangle(board_x, board_y, ss * board_size, ss * board_size, BLACK)
//    for (int i = 0; i < board_size; ++i) {
//      for (int j = 0; j < board_size; ++j) {
//        auto pos_x = board_x + i * ss + so
//        auto pos_y = board_y + j * ss + so
//        auto radius = (ss - 2 * so) / 2
//        if (game.board().is_matched(j, i) && hints) {
//          DrawRectangle(pos_x, pos_y, ss - 2 * so, ss - 2 * so, DARKGRAY)
//        } else if (game.board().is_three(j, i) && hints) {
//          DrawRectangle(pos_x, pos_y, ss - 2 * so, ss - 2 * so, LIGHTGRAY)
//        } else {
//          DrawRectangle(pos_x, pos_y, ss - 2 * so, ss - 2 * so, GRAY)
//        }
//        switch (game.board().at(j, i)) {
//        case 1:
//          DrawPoly(Vector2{float(pos_x + radius), float(pos_y + radius)}, 4,
//                   radius - mo, 45, nonacid_colors ? PINK : RED)
//          break
//        case 2:
//          DrawCircle(pos_x + radius, pos_y + radius, radius - mo,
//                     nonacid_colors ? LIME : GREEN)
//          break
//        case 3:
//          DrawPoly(Vector2{float(pos_x + radius), float(pos_y + radius)}, 6,
//                   radius - mo, 0, nonacid_colors ? SKYBLUE : BLUE)
//          break
//        case 4:
//          DrawPoly(
//              Vector2{float(pos_x + radius), float(pos_y + radius + ss / 12)},
//              3, radius - mo, -90, nonacid_colors ? GOLD : ORANGE)
//          break
//        case 5:
//          DrawPoly(
//              Vector2{float(pos_x + radius), float(pos_y + radius + ss / 16)},
//              5, radius - mo, -90, nonacid_colors ? PURPLE : MAGENTA)
//          break
//        case 6:
//          DrawPoly(Vector2{float(pos_x + radius), float(pos_y + radius)}, 4,
//                   radius - mo, 0, nonacid_colors ? BEIGE : YELLOW)
//          break
//        default:
//          break
//        }
//        if (game.board().is_magic(j, i)) {
//          DrawCircleGradient(pos_x + radius, pos_y + radius, ss / 6, WHITE,
//                             BLACK)
//        }
//        if (game.board().is_magic2(j, i)) {
//          DrawCircleGradient(pos_x + radius, pos_y + radius, ss / 6, WHITE,
//                             DARKPURPLE)
//        }
//      }
//    }
//    if (!first_click) {
//      auto pos = GetMousePosition()
//      pos = Vector2Subtract(pos, Vector2{float(board_x), float(board_y)})
//      if (!(pos.x < 0 || pos.y < 0 || pos.x > ss * board_size || pos.y > ss * board_size)) {
//        int row = trunc(pos.y / ss)
//        int col = trunc(pos.x / ss)
//        auto dx = col - saved_col
//        auto dy = row - saved_row
//        auto radius = (ss - 2 * so) / 2
//        auto pos_x = board_x + saved_col * ss + so
//        auto pos_y = board_y + saved_row * ss + so
//        if (dx == 1 && dy == 0 || dx == 0 && dy == 1) {
//          if (dx == 1) {
//            DrawRectangleGradientH(pos_x + radius - 10, pos_y + radius - 10, dx == 1 ? ss : 20, dy == 1 ? ss : 20, BLANK, MAROON)
//          } else {
//            DrawRectangleGradientV(pos_x + radius - 10, pos_y + radius - 10, dx == 1 ? ss : 20, dy == 1 ? ss : 20, BLANK, MAROON)
//          }
//          DrawPoly(Vector2{float(pos_x + radius + (dx == 1 ? ss : 0)), float(pos_y + radius + (dy == 1 ? ss : 0))}, 3, radius - mo, dx == 1 ? 0 : 90, MAROON)
//        }
//        if (dx == -1 && dy == 0 || dx == 0 && dy == -1) {
//          if (dx == -1) {
//            DrawRectangleGradientH(pos_x + radius - (dx == -1 ? ss - 10 : 0), pos_y + radius - (dy == -1 ? ss : 10), dx == -1 ? ss : 20, dy == -1 ? ss + 10 : 20, MAROON, BLANK)
//          } else {
//            DrawRectangleGradientV(pos_x + radius - (dx == -1 ? ss : 10), pos_y + radius - (dy == -1 ? ss - 10 : 0), dx == -1 ? ss + 10 : 20, dy == -1 ? ss : 20, MAROON, BLANK)
//          }
//          DrawPoly(Vector2{float(pos_x + radius - (dx == -1 ? ss : 0)), float(pos_y + radius - (dy == -1 ? ss : 0))}, 3, radius - mo, dx == -1 ? 180 : 270, MAROON)
//        }
//      }
//    }
//    if (input_name) {
//      char c = GetCharPressed()
//      if ((std::isalnum(c) || c == '_') && game.name().length() < 22 &&
//          !ignore_r) {
//        game.name() += c
//      }
//      ignore_r = false
//      DrawRectangle(w / 4, h / 2 - h / 16, w / 2, h / 8, WHITE)
//      DrawText("Enter your name:", w / 4, h / 2 - h / 16, 50, BLACK)
//      DrawText(game.name().c_str(), w / 4, h / 2 - h / 16 + 50, 50, BLACK)
//    }
//    if (draw_leaderboard && !input_name) {
//      auto wheel_move = GetMouseWheelMove()
//      auto kd = IsKeyPressed(KEY_DOWN)
//      auto ku = IsKeyPressed(KEY_UP)
//      if (wheel_move == 0) {
//        if (kd) {
//          wheel_move = -1
//        }
//        if (ku) {
//          wheel_move = 1
//        }
//      }
//      if (wheel_move != 0) {
//        if (l_offset != 0 || wheel_move <= 0) {
//          l_offset = l_offset - size_t(std::signbit(wheel_move) ? -1 : 1)
//        }
//        l_offset = std::min(l_offset, leaderboard.size() - 1)
//      }
//      DrawLeaderboard(leaderboard, l_offset, leaderboard_place)
//    }
//    DrawText(game.game_stats().c_str(), 3, 0, 30, BLACK)
//    DrawText((fmt::format("Player:\n") + game.name()).c_str(), 3, h - 55, 20,
//             BLACK)
//    ButtonMaker bm(play_sound, ksound, volume)
//    auto start_y = 0
//    auto sound_button = bm.draw_button(
//        {float(w - 210), float(h - (start_y += 40))}, "SOUND", true)
//    auto particles_button = bm.draw_button(
//        {float(w - 210), float(h - (start_y += 40))}, "PARTICLES", particles)
//    auto hints_button = bm.draw_button(
//        {float(w - 210), float(h - (start_y += 40))}, "HINTS", hints)
//    auto acid_button =
//        bm.draw_button({float(w - 210), float(h - (start_y += 40))}, "NO ACID",
//                       nonacid_colors)
//    auto lbutton = bm.draw_button({float(w - 210), float(h - (start_y += 40))},
//                                  "LEADERBOARD", draw_leaderboard)
//    auto rbutton = bm.draw_button({float(w - 210), float(h - (start_y += 40))},
//                                  "RESTART", false)
//    auto load_button = bm.draw_button(
//        {float(w - 210), float(h - (start_y += 40))}, "LOAD", false)
//    auto save_button = bm.draw_button(
//        {float(w - 210), float(h - (start_y += 40))}, "SAVE", false)
//    bm.play_sound()
//    volume = bm.volume()
//    if (volume < 0.05f) {
//      volume = 0.0f
//    }
//    play_sound = volume != 0.0f
//    if (particles) {
//      std::vector<Explosion> new_staying
//      new_staying.reserve(staying.size())
//      for (auto it = staying.begin(); it != staying.end(); ++it) {
//        Explosion p = *it
//        DrawRectangle(board_x + p.x * ss + so, board_y + p.y * ss + so,
//                      ss - 2 * so, ss - 2 * so, WHITE)
//        if (p.lifetime > 6) {
//          continue
//        }
//        p.lifetime += 1
//        new_staying.push_back(p)
//      }
//      new_staying.shrink_to_fit()
//      staying = new_staying
//
//      std::vector<Particle> new_flying
//      new_flying.reserve(flying.size())
//      for (auto it = flying.begin(); it != flying.end(); ++it) {
//        Particle p = *it
//        auto c = p.color
//        c.a = 255 - p.lifetime
//        if (p.sides == 0) {
//          DrawCircle(p.x, p.y, ss / 2, c)
//        } else {
//          DrawPoly(Vector2{float(p.x), float(p.y)}, p.sides, ss / 2, p.a, c)
//        }
//        p.y += p.dy
//        if (p.y > h || p.x < 0 || p.x > w || p.lifetime > 254) {
//          continue
//        }
//        p.x += p.dx
//        p.a += p.da
//        p.dy += 1
//        p.lifetime += 1
//        new_flying.push_back(p)
//      }
//      new_flying.shrink_to_fit()
//      flying = new_flying
//    }
//    EndDrawing()
//    if (!input_name && !game.is_processing()) {
//      if (IsMouseButtonPressed(MOUSE_BUTTON_LEFT)) {
//        auto pos = GetMousePosition()
//        button_flag(pos, particles_button, particles)
//        button_flag(pos, hints_button, hints)
//        button_flag(pos, acid_button, nonacid_colors)
//        button_flag(pos, lbutton, draw_leaderboard)
//        if (in_button(pos, rbutton)) {
//          game.new_game()
//          input_name = true
//        }
//        if (in_button(pos, load_button)) {
//          game.load()
//        }
//        if (in_button(pos, save_button)) {
//          game.save()
//        }
//        if (draw_leaderboard) {
//          goto outside
//        }
//        pos = Vector2Subtract(pos, Vector2{float(board_x), float(board_y)})
//        if (pos.x < 0 || pos.y < 0 || pos.x > ss * board_size ||
//            pos.y > ss * board_size) {
//          goto outside
//        }
//        auto row = trunc(pos.y / ss)
//        auto col = trunc(pos.x / ss)
//        if (first_click) {
//          saved_row = row
//          saved_col = col
//          first_click = false
//        } else {
//          first_click = true
//          if (((abs(row - saved_row) == 1) ^ (abs(col - saved_col) == 1))) {
//            game.attempt_move(row, col, saved_row, saved_col)
//          }
//        }
//      } else if (IsMouseButtonReleased(MOUSE_BUTTON_LEFT)) {
//        auto pos = GetMousePosition()
//        pos = Vector2Subtract(pos, Vector2{float(board_x), float(board_y)})
//        if (pos.x < 0 || pos.y < 0 || pos.x > ss * board_size ||
//            pos.y > ss * board_size) {
//          goto outside
//        }
//        auto row = trunc(pos.y / ss)
//        auto col = trunc(pos.x / ss)
//        if (row != saved_row || col != saved_col) {
//          if (!first_click) {
//            first_click = true
//            if (((abs(row - saved_row) == 1) ^ (abs(col - saved_col) == 1))) {
//              game.attempt_move(row, col, saved_row, saved_col)
//            }
//          }
//        }
//      }
//    }
//  outside:
//    if (IsKeyPressed(KEY_ENTER) && input_name) {
//      input_name = false
//      if (game.name().empty()) {
//        game.name() = "dupa"
//      }
//    } else if (IsKeyPressed(KEY_BACKSPACE) && input_name) {
//      if (!game.name().empty()) {
//        game.name().pop_back()
//      }
//    } else if (!input_name) {
//      while (int key = GetKeyPressed()) {
//        switch (KeyboardKey(key)) {
//        case KEY_R: {
//          game.new_game()
//          ignore_r = true
//          input_name = true
//          break
//        }
//        case KEY_L: {
//          draw_leaderboard = !draw_leaderboard
//          if (draw_leaderboard == false) {
//            leaderboard_place = -1
//          }
//          break
//        }
//        case KEY_P: {
//          particles = !particles
//          break
//        }
//        case KEY_M: {
//          play_sound = !play_sound
//          break
//        }
//        case KEY_H: {
//          hints = !hints
//          break
//        }
//        case KEY_A: {
//          nonacid_colors = !nonacid_colors
//          break
//        }
//        case KEY_S: {
//          game.save()
//          break
//        }
//        case KEY_O: {
//          game.load()
//          break
//        }
//        default:
//          break
//        }
//      }
//    }
//    if (game.is_finished()) {
//      for (auto i = 0; i <= leaderboard.size(); ++i) {
//        if (i == leaderboard.size() || leaderboard[i].second < game.board().score) {
//          leaderboard.insert(leaderboard.begin() + i,
//                             {game.name(), game.board().score})
//          leaderboard_place = i
//          l_offset = std::max(0, i - 4)
//          break
//        }
//      }
//      WriteLeaderboard(leaderboard)
//      game.new_game()
//      draw_leaderboard = true
//    }
//  }
//  game.save()
//  WriteLeaderboard(leaderboard)
//  CloseWindow()
//  CloseAudioDevice()
//  return 0
//}
