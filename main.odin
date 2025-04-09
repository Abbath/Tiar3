#+feature dynamic-literals
package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:mem"
import "core:slice"
import "core:strings"
import "core:unicode"
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
  res := make(Pattern, len(p))
  copy(res[:], p[:])
  for &pt in res {
    pt -= {minX, minY}
  }
  return res
}

rotations :: proc(p: Pattern) -> [4]Pattern {
  res: [4]Pattern
  res[0] = make(Pattern, len(p))
  copy(res[0][:], p[:])
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
  m := make(Pattern, len(p))
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
  b.rm_i = make([dynamic]Triple)
  b.rm_j = make([dynamic]Triple)
  b.rm_b = make([dynamic]Pair)
  return b
}
delete_board :: proc(b: ^Board) {
  delete(b.board)
  delete(b.matched_patterns)
  delete(b.matched_threes)
  delete(b.magic_tiles)
  delete(b.magic_tiles2)
  delete(b.rm_i)
  delete(b.rm_j)
  delete(b.rm_b)
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
  defer delete(remove_i)
  remove_j := make([dynamic]Triple)
  defer delete(remove_j)
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

in_button :: proc(pos: rl.Vector2, button: Button) -> bool {
  return pos.x > button.x1 && pos.x < button.x2 && pos.y > button.y1 && pos.y < button.y2
}

button_maker_enter := true

ButtonMaker :: struct {
  play_sound: bool,
  sound:      rl.Sound,
  volume:     f32,
  buttons:    [dynamic]Button,
}

delete_button_maker :: proc(bm: ^ButtonMaker) {
  delete(bm.buttons)
}

draw_button :: proc(bm: ^ButtonMaker, place: [2]i32, text: string, enabled: bool) -> Button {
  button_down := rl.IsMouseButtonDown(rl.MouseButton.LEFT)
  pos := rl.GetMousePosition()
  button := Button{f32(place.x), f32(place.y), f32(place.x + 200), f32(place.y + 30)}
  if in_button(pos, button) {
    c := enabled ? rl.YELLOW : (button_down ? rl.DARKGRAY : rl.LIGHTGRAY)
    if text == "SOUND" {
      level := bm.volume * 200
      rl.DrawRectangle(place.x, place.y, i32(level), 30, rl.YELLOW)
      rl.DrawRectangle(place.x + i32(level), place.y, i32(200 - level), 30, rl.LIGHTGRAY)
      if button_down {
        x := rl.GetMouseX()
        bm.volume = f32((x - place.x) / 200.0)
      }
    } else {
      rl.DrawRectangle(place.x, place.y, 200, 30, c)
    }
  } else {
    c := enabled ? rl.GOLD : rl.GRAY
    if text == "SOUND" {
      level := bm.volume * 200
      rl.DrawRectangle(place.x, place.y, i32(level), 30, rl.GOLD)
      rl.DrawRectangle(place.x + i32(level), place.y, i32(200 - level), 30, rl.GRAY)
    } else {
      rl.DrawRectangle(place.x, place.y, 200, 30, c)
    }
  }
  label := text == "SOUND" ? fmt.ctprintf("SOUND (%d)", int(bm.volume * 100)) : fmt.ctprintf("%s", text)
  width := rl.MeasureText(label, 20)
  rl.DrawText(label, place.x + 100 - width / 2, place.y + 5, 20, rl.BLACK)
  append(&bm.buttons, button)
  return button
}

play_sound :: proc(bm: ButtonMaker) {
  if !bm.play_sound {
    return
  }
  inn := false
  for it in bm.buttons {
    pos := rl.GetMousePosition()
    if in_button(pos, it) {
      inn = true
      if button_maker_enter {
        button_maker_enter = false
        if (rl.IsSoundReady(bm.sound)) {
          rl.PlaySound(bm.sound)
        }
      }
    }
  }
  if !inn {
    button_maker_enter = true
  }
}

Game :: struct {
  name:          string,
  board:         Board,
  old_board:     Board,
  work_board:    bool,
  first_work:    bool,
  removed_cells: [dynamic]Triple,
  counter:       int,
}

make_game :: proc(size: int) -> Game {
  board := make_board(size, size)
  return Game{board = board, old_board = copy_board(board), removed_cells = make([dynamic]Triple), name = ""}
}

delete_game :: proc(g: ^Game) {
  delete_board(&g.board)
  delete_board(&g.old_board)
}

new_game :: proc(g: ^Game) {
  g.counter = 0
  g.work_board = false
  fill(&g.board)
  stabilize(&g.board)
  zero(&g.board)
}


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

save_state :: proc(g: ^Game) {
  delete_board(&g.old_board)
  g.old_board = copy_board(g.board)
}

check_state :: proc(g: Game) -> bool {
  return compare_boards(g.old_board, g.board)
}

restore_state :: proc(g: ^Game) {
  delete_board(&g.board)
  g.board = copy_board(g.old_board)
}

match :: proc(g: ^Game) {
  match_patterns(&g.board)
  match_threes(&g.board)
}

attempt_move :: proc(g: ^Game, row1, col1, row2, col2: int) {
  g.first_work = true
  g.work_board = true
  save_state(g)
  swap(&g.board, row1, col1, row2, col2)
  prepare_removals(&g.board)
}

step_game :: proc(g: ^Game) -> [dynamic]Triple {
  res := make([dynamic]Triple)
  if !has_removals(g.board) {
    prepare_removals(&g.board)
  }
  if !has_removals(g.board) {
    if g.first_work {
      restore_state(g)
    } else {
      g.counter += 1
    }
    g.work_board = false
    match_patterns(&g.board)
    match_threes(&g.board)
  }
  res = remove_one_thing(&g.board)
  fill_up(&g.board)
  g.first_work = false
  return res
}

is_finished :: proc(g: Game) -> bool {
  return g.counter == 50
}

is_processing :: proc(g: Game) -> bool {
  return g.work_board
}

game_stats :: proc(g: Game) -> string {
  return fmt.tprintf(
    "Moves: %d\nScore: %d\nTrios: %d\nQuartets: %d\nQuintets: %d\nCrosses: %d",
    g.counter,
    g.board.score,
    g.board.normals,
    g.board.longers,
    g.board.longests,
    g.board.crosses,
  )
}

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

button_flag :: proc(pos: rl.Vector2, button: Button, flag: ^bool) {
  if in_button(pos, button) {
    flag^ = !flag^
  }
}

main :: proc() {
  when ODIN_DEBUG {
    track: mem.Tracking_Allocator
    mem.tracking_allocator_init(&track, context.allocator)
    context.allocator = mem.tracking_allocator(&track)

    defer {
      if len(track.allocation_map) > 0 {
        fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
        for _, entry in track.allocation_map {
          fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
        }
      }
      mem.tracking_allocator_destroy(&track)
    }
  }
  w: i32 = 1280
  h: i32 = 800
  board_size := 16
  game := make_game(board_size)
  defer delete_game(&game)
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
  leaderboard: Leaderboard
  flying := make([dynamic]Particle)
  staying := make([dynamic]Explosion)
  dd := proc() -> int {return rand.int_max(21) - 10}
  rl.InitAudioDevice()
  psound := rl.LoadSound("p.ogg")
  ksound := rl.LoadSound("k.ogg")
  // TODO: Add game loading here
  new_game(&game)
  input_name = true
  builder := strings.builder_make()
  rl.SetConfigFlags({rl.ConfigFlag.WINDOW_RESIZABLE})
  rl.InitWindow(w, h, "Tiar3")
  icon := rl.LoadImage("icon.png")
  rl.SetWindowIcon(icon)
  rl.SetTargetFPS(60)
  rl.SetTextLineSpacing(23)
  for !rl.WindowShouldClose() {
    rl.SetMasterVolume(volume)
    if frame_counter == 60 {
      frame_counter = 0
    } else {
      frame_counter += 1
    }
    w = rl.GetRenderWidth()
    h = rl.GetRenderHeight()
    s: i32 = 0
    if w > h {
      s = h
    } else {
      s = w
    }
    margin: i32 = 10
    board_x := w / 2 - s / 2 + margin
    board_y := h / 2 - s / 2 + margin
    ss := (s - 2 * margin) / i32(board_size)
    so: i32 = 2
    mo: f32 = 0.5
    if is_processing(game) && frame_counter % 6 == 0 {
      f := step_game(&game)
      defer delete(f)
      if is_play_sound && !(len(f) == 0) && rl.IsSoundReady(psound) {
        rl.PlaySound(psound)
      }
      if particles {
        if is_play_sound && !(len(f) == 0) {
          board_x += i32(dd())
          board_y += i32(dd())
        }
        reserve(&flying, len(flying) + len(f))
        reserve(&staying, len(staying) + len(f))
        for it in f {
          c: rl.Color
          s: int
          switch it.third {
          case 1:
            {
              c = nonacid_colors ? rl.PINK : rl.RED
              s = 4
            }
          case 2:
            {
              c = nonacid_colors ? rl.LIME : rl.GREEN
              s = 0
            }
          case 3:
            {
              c = nonacid_colors ? rl.SKYBLUE : rl.BLUE
              s = 6
            }
          case 4:
            {
              c = nonacid_colors ? rl.GOLD : rl.ORANGE
              s = 3
            }
          case 5:
            {
              c = nonacid_colors ? rl.PURPLE : rl.MAGENTA
              s = 5
            }
          case 6:
            {
              c = nonacid_colors ? rl.BEIGE : rl.YELLOW
              s = 4
            }
          }
          append(
            &flying,
            Particle{f32(dd()), f32(dd()), f32(dd()), f32(i32(it.second) * ss + board_x + ss / 2), f32(i32(it.first) * ss + board_y + ss / 2), 0, c, 0, s},
          )
          append(&staying, Explosion{it.second, it.first, 0})
        }
      }
    }
    rl.BeginDrawing()
    rl.ClearBackground(rl.RAYWHITE)
    rl.DrawRectangle(board_x, board_y, ss * i32(board_size), ss * i32(board_size), rl.BLACK)
    for i := 0; i < board_size; i += 1 {
      for j := 0; j < board_size; j += 1 {
        pos_x := board_x + i32(i) * ss + so
        pos_y := board_y + i32(j) * ss + so
        radius := (ss - 2 * so) / 2
        if is_matched(game.board, j, i) && hints {
          rl.DrawRectangle(pos_x, pos_y, ss - 2 * so, ss - 2 * so, rl.DARKGRAY)
        } else if is_three(game.board, j, i) && hints {
          rl.DrawRectangle(pos_x, pos_y, ss - 2 * so, ss - 2 * so, rl.LIGHTGRAY)
        } else {
          rl.DrawRectangle(pos_x, pos_y, ss - 2 * so, ss - 2 * so, rl.GRAY)
        }
        switch at(game.board, j, i) {
        case 1:
          {
            rl.DrawPoly({f32(pos_x + radius), f32(pos_y + radius)}, 4, f32(radius) - mo, 45, nonacid_colors ? rl.PINK : rl.RED)
          }
        case 2:
          {
            rl.DrawCircle(pos_x + radius, pos_y + radius, f32(radius) - mo, nonacid_colors ? rl.LIME : rl.GREEN)
          }
        case 3:
          {
            rl.DrawPoly({f32(pos_x + radius), f32(pos_y + radius)}, 6, f32(radius) - mo, 0, nonacid_colors ? rl.SKYBLUE : rl.BLUE)
          }
        case 4:
          {
            rl.DrawPoly({f32(pos_x + radius), f32(pos_y + radius)}, 3, f32(radius) - mo, -90, nonacid_colors ? rl.GOLD : rl.ORANGE)
          }
        case 5:
          {
            rl.DrawPoly({f32(pos_x + radius), f32(pos_y + radius)}, 5, f32(radius) - mo, -90, nonacid_colors ? rl.PURPLE : rl.MAGENTA)
          }
        case 6:
          {
            rl.DrawPoly({f32(pos_x + radius), f32(pos_y + radius)}, 4, f32(radius) - mo, 0, nonacid_colors ? rl.BEIGE : rl.YELLOW)
          }
        }
        if is_magic(game.board, j, i) {
          rl.DrawCircleGradient(pos_x + radius, pos_y + radius, f32(ss) / 6, rl.WHITE, rl.BLACK)
        }
        if is_magic2(game.board, j, i) {
          rl.DrawCircleGradient(pos_x + radius, pos_y + radius, f32(ss) / 6, rl.WHITE, rl.DARKPURPLE)
        }
      }
    }
    if !first_click {
      pos := rl.GetMousePosition()
      pos -= {f32(board_x), f32(board_y)}
      if !(pos.x < 0 || pos.y < 0 || pos.x > f32(ss * i32(board_size)) || pos.y > f32(ss * i32(board_size))) {
        row := i32(pos.y / f32(ss))
        col := i32(pos.x / f32(ss))
        dx := col - saved_col
        dy := row - saved_row
        radius := (ss - 2 * so) / 2
        pos_x := board_x + saved_col * ss + so
        pos_y := board_y + saved_row * ss + so
        if dx == 1 && dy == 0 || dx == 0 && dy == 1 {
          if dx == 1 {
            rl.DrawRectangleGradientH(pos_x + radius - 10, pos_y + radius - 10, dx == 1 ? ss : 20, dy == 1 ? ss : 20, rl.BLANK, rl.MAROON)
          } else {
            rl.DrawRectangleGradientV(pos_x + radius - 10, pos_y + radius - 10, dx == 1 ? ss : 20, dy == 1 ? ss : 20, rl.BLANK, rl.MAROON)
          }
          rl.DrawPoly({f32(pos_x + radius + (dx == 1 ? ss : 0)), f32(pos_y + radius + (dy == 1 ? ss : 0))}, 3, f32(radius) - mo, dx == 1 ? 0 : 90, rl.MAROON)
        }
        if dx == -1 && dy == 0 || dx == 0 && dy == -1 {
          if (dx == -1) {
            rl.DrawRectangleGradientH(
              pos_x + radius - (dx == -1 ? ss - 10 : 0),
              pos_y + radius - (dy == -1 ? ss : 10),
              dx == -1 ? ss : 20,
              dy == -1 ? ss + 10 : 20,
              rl.MAROON,
              rl.BLANK,
            )
          } else {
            rl.DrawRectangleGradientV(
              pos_x + radius - (dx == -1 ? ss : 10),
              pos_y + radius - (dy == -1 ? ss - 10 : 0),
              dx == -1 ? ss + 10 : 20,
              dy == -1 ? ss : 20,
              rl.MAROON,
              rl.BLANK,
            )
          }
          rl.DrawPoly(
            {f32(pos_x + radius - (dx == -1 ? ss : 0)), f32(pos_y + radius - (dy == -1 ? ss : 0))},
            3,
            f32(radius) - mo,
            dx == -1 ? 180 : 270,
            rl.MAROON,
          )
        }
      }
    }
    if input_name {
      c := rl.GetCharPressed()
      if unicode.is_alpha(c) || c == '_' && len(game.name) < 22 && !ignore_r {
        strings.write_rune(&builder, c)
      }
      ignore_r = false
      rl.DrawRectangle(w / 4, h / 2 - h / 16, w / 2, h / 8, rl.WHITE)
      rl.DrawText("Enter your name:", w / 4, h / 2 - h / 16, 50, rl.BLACK)
      rl.DrawText(fmt.ctprintf("%s", strings.to_string(builder)), w / 4, h / 2 - h / 16 + 50, 50, rl.BLACK)
    }
    if draw_leaderboard && !input_name {
      wheel_move := rl.GetMouseWheelMove()
      kd := rl.IsKeyPressed(rl.KeyboardKey.DOWN)
      ku := rl.IsKeyPressed(rl.KeyboardKey.UP)
      if wheel_move == 0 {
        if kd {
          wheel_move = -1
        }
        if ku {
          wheel_move = 1
        }
      }
      if wheel_move != 0 {
        if l_offset != 0 || wheel_move <= 0 {
          l_offset = l_offset - (wheel_move < 0 ? -1 : 1)
        }
        l_offset = min(l_offset, len(leaderboard) - 1)
      }
      //      DrawLeaderboard(leaderboard, l_offset, leaderboard_place)
    }
    rl.DrawText(fmt.ctprintf("%s", game_stats(game)), 3, 0, 30, rl.BLACK)
    rl.DrawText(fmt.ctprintf("Player:\n%s", game.name), 3, h - 55, 20, rl.BLACK)
    bm := ButtonMaker {
      play_sound = is_play_sound,
      sound      = ksound,
      volume     = volume,
    }
    defer delete_button_maker(&bm)
    start_y: i32 = 40
    sound_button := draw_button(&bm, {w - 210, h - start_y}, "SOUND", true)
    start_y += 40
    particles_button := draw_button(&bm, {w - 210, h - start_y}, "PARTICLES", particles)
    start_y += 40
    hints_button := draw_button(&bm, {w - 210, h - start_y}, "HINTS", hints)
    start_y += 40
    acid_button := draw_button(&bm, {w - 210, h - start_y}, "NO ACID", nonacid_colors)
    start_y += 40
    lbutton := draw_button(&bm, {w - 210, h - start_y}, "LEADERBOARD", draw_leaderboard)
    start_y += 40
    rbutton := draw_button(&bm, {w - 210, h - start_y}, "RESTART", false)
    start_y += 40
    load_button := draw_button(&bm, {w - 210, h - start_y}, "LOAD", false)
    start_y += 40
    save_button := draw_button(&bm, {w - 210, h - start_y}, "SAVE", false)
    play_sound(bm)
    volume = bm.volume
    if volume < 0.05 {
      volume = 0
    }
    is_play_sound = volume != 0
    if particles {
      new_staying := make([dynamic]Explosion)
      reserve(&new_staying, len(staying))
      for it in staying {
        p := it
        rl.DrawRectangle(board_x + i32(p.x) * ss + so, board_y + i32(p.y) * ss + so, ss - 2 * so, ss - 2 * so, rl.WHITE)
        if p.lifetime > 6 {
          continue
        }
        p.lifetime += 1
        append(&new_staying, p)
      }
      delete(staying)
      shrink(&new_staying)
      staying = new_staying

      new_flying := make([dynamic]Particle)
      reserve(&new_flying, len(flying))
      for it in flying {
        p := it
        c := p.color
        c.a = u8(255 - p.lifetime)
        if p.sides == 0 {
          rl.DrawCircle(i32(p.x), i32(p.y), f32(ss / 2), c)
        } else {
          rl.DrawPoly({f32(p.x), f32(p.y)}, i32(p.sides), f32(ss / 2), p.a, c)
        }
        p.y += p.dy
        if p.y > f32(h) || p.x < 0 || p.x > f32(w) || p.lifetime > 254 {
          continue
        }
        p.x += p.dx
        p.a += p.da
        p.dy += 1
        p.lifetime += 1
        append(&new_flying, p)
      }
      shrink(&new_flying)
      delete(flying)
      flying = new_flying
    }
    rl.EndDrawing()
    outside: {
      if !input_name && !is_processing(game) {
        if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
          pos := rl.GetMousePosition()
          button_flag(pos, particles_button, &particles)
          button_flag(pos, hints_button, &hints)
          button_flag(pos, acid_button, &nonacid_colors)
          button_flag(pos, lbutton, &draw_leaderboard)
          if in_button(pos, load_button) {
            // TODO: load game
          }
          if in_button(pos, save_button) {
            // TODO: save game
          }
          if draw_leaderboard {
            break outside
          }
          pos = pos - {f32(board_x), f32(board_y)}
          if pos.x < 0 || pos.y < 0 || pos.x > f32(ss * i32(board_size)) || pos.y > f32(ss * i32(board_size)) {
            break outside
          }
          row := i32(pos.y / f32(ss))
          col := i32(pos.x / f32(ss))
          if first_click {
            saved_row = row
            saved_col = col
            first_click = false
          } else {
            first_click = true
            if bool(int(abs(row - saved_row) == 1) ~ int(abs(col - saved_col) == 1)) {
              attempt_move(&game, int(row), int(col), int(saved_row), int(saved_col))
            }
          }
        } else if rl.IsMouseButtonReleased(rl.MouseButton.LEFT) {
          pos := rl.GetMousePosition()
          pos = pos - {f32(board_x), f32(board_y)}
          if pos.x < 0 || pos.y < 0 || pos.x > f32(ss * i32(board_size)) || pos.y > f32(ss * i32(board_size)) {
            break outside
          }
          row := i32(pos.y / f32(ss))
          col := i32(pos.x / f32(ss))
          if row != saved_row || col != saved_col {
            if !first_click {
              first_click = true
              if bool(int(abs(row - saved_row) == 1) ~ int(abs(col - saved_col) == 1)) {
                attempt_move(&game, int(row), int(col), int(saved_row), int(saved_col))
              }
            }
          }
        }
      }
    }
    if rl.IsKeyPressed(.ENTER) && input_name {
      input_name = false
      game.name = strings.to_string(builder)
      if len(game.name) == 0 {
        game.name = "dupa"
      }
    } else if rl.IsKeyPressed(.BACKSPACE) {
      strings.pop_rune(&builder)
    } else if !input_name {
      for {
        key := rl.GetKeyPressed()
        if key == .KEY_NULL {
          break
        }
        #partial switch key {
        case .R:
          {
            new_game(&game)
            ignore_r = true
            input_name = true
            strings.builder_reset(&builder)
          }
        case .L:
          {
            draw_leaderboard = !draw_leaderboard
            if !draw_leaderboard {
              leaderboard_place = -1
            }
          }
        case .P:
          {
            particles = !particles
          }
        case .M:
          {
            is_play_sound = !is_play_sound
          }
        case .H:
          {
            hints = !hints
          }
        case .A:
          {
            nonacid_colors = !nonacid_colors
          }
        case .S:
          {
            // TODO: save game
          }
        case .O:
          {
            // TODO: load game
          }
        }
      }
    }

    if is_finished(game) {
      for lr, idx in leaderboard {
        if lr.score < game.board.score {
          assign_at(&leaderboard, idx, LeaderboardRecord{game.name, game.board.score})
          leaderboard_place = idx
          l_offset = max(0, idx - 4)
          break
        }
      }
      if leaderboard_place == -1 {
        leaderboard_place = len(leaderboard)
        append(&leaderboard, LeaderboardRecord{game.name, game.board.score})
        l_offset = max(0, leaderboard_place - 4)
      }
      // TODO: write leaderboard
      new_game(&game)
      draw_leaderboard = true
    }
    free_all(context.temp_allocator)
  }

  // TODO: save game
  // TODO: write leaderboard
  strings.builder_destroy(&builder)
  rl.CloseWindow()
  rl.CloseAudioDevice()
}
