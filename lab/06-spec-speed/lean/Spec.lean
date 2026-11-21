/-
Experiment #6, Lean 4: executable semantics of experiment #9's subset of
Oniguruma f95747b (concatenation, alternation, greedy star, capture
groups, character classes; UTF-8; forward search), transcribed from
stack G (lab/06-spec-speed/g/g.ml) as the same small-step machine as
the Rocq file (rocq/Spec.v): stack G's pending items plus an explicit
list of backtracking points, one machine step per call of stack G's
`step`, fuel structural on `Nat`.  No type indices or proofs in
executable definitions.
-/
namespace Spec

inductive Node where
  | eps
  | lit (bs : List Nat)                 -- bytes of one code point
  | cls (neg : Bool) (rs : List (Nat × Nat))
  | cat (a b : Node)
  | alt (a b : Node)
  | star (a : Node)                     -- greedy
  | group (k : Nat) (a : Node)
  deriving Inhabited

inductive Item where
  | node (n : Node)
  | close (k p : Nat)                   -- group, start position
  | loop (a : Node) (p : Nat)           -- star body, iteration start

abbrev Caps := List (Nat × (Nat × Nat))

-- backtracking point: items, position, rest of the subject, captures
abbrev Frame := List Item × Nat × List Nat × Caps

inductive State where
  | run (its : List Item) (pos : Nat) (rest : List Nat) (cs : Caps) (bt : List Frame)
  | matched (pos : Nat) (cs : Caps)
  | failed

-- UTF-8, as upstream/src/utf8.c (EncLen_UTF8, USE_RFC3629_RANGE)
def encLen (b : Nat) : Nat :=
  if b < 194 then 1 else if b < 224 then 2 else if b < 240 then 3
  else if b < 245 then 4 else 1

def take : Nat → List Nat → Option (List Nat × List Nat)
  | 0, l => some ([], l)
  | _ + 1, [] => none
  | n + 1, x :: t => match take n t with
    | some (a, r) => some (x :: a, r)
    | none => none

def leadMod : Nat → Nat
  | 2 => 32 | 3 => 16 | _ => 8

-- code point, encoded length, rest; none past the end (DATA_ENSURE)
def decode : List Nat → Option (Nat × Nat × List Nat)
  | [] => none
  | b :: t =>
    let l := encLen b
    if l == 1 then some (b, 1, t)
    else match take (l - 1) t with
      | some (tl, r) => some (tl.foldl (fun v d => v * 64 + d % 64) (b % leadMod l), l, r)
      | none => none

def pfx : List Nat → List Nat → Option (List Nat)
  | [], rest => some rest
  | x :: l, y :: r => if x == y then pfx l r else none
  | _ :: _, [] => none

def inRanges (c : Nat) (rs : List (Nat × Nat)) : Bool :=
  rs.any (fun r => r.1 ≤ c && c ≤ r.2)

def setCap (k : Nat) (v : Nat × Nat) : Caps → Caps
  | [] => [(k, v)]
  | (k', w) :: t => if k' == k then (k, v) :: t else (k', w) :: setCap k v t

def backtrack : List Frame → State
  | [] => .failed
  | (its, pos, rest, cs) :: bt => .run its pos rest cs bt

def step : State → State
  | .run its pos rest cs bt =>
    match its with
    | [] => .matched pos cs
    | .node .eps :: k => .run k pos rest cs bt
    | .node (.lit l) :: k =>
      match pfx l rest with
      | some r => .run k (pos + l.length) r cs bt
      | none => backtrack bt
    | .node (.cls ng rs) :: k =>
      match decode rest with
      | some (c, l, r) => if inRanges c rs == ng then backtrack bt else .run k (pos + l) r cs bt
      | none => backtrack bt
    | .node (.cat a b) :: k => .run (.node a :: .node b :: k) pos rest cs bt
    | .node (.alt a b) :: k => .run (.node a :: k) pos rest cs ((.node b :: k, pos, rest, cs) :: bt)
    | .node (.star a) :: k =>
      .run (.node a :: .loop a pos :: k) pos rest cs ((k, pos, rest, cs) :: bt)
    | .loop a p0 :: k =>
      if pos == p0 then .run k pos rest cs bt else .run (.node (.star a) :: k) pos rest cs bt
    | .node (.group i a) :: k => .run (.node a :: .close i pos :: k) pos rest cs bt
    | .close i p0 :: k => .run k pos rest (setCap i (p0, pos) cs) bt
  | st => st

-- at most `fuel` steps
def run : Nat → State → State
  | 0, st => st
  | f + 1, st@(.run ..) => run f (step st)
  | _ + 1, st => st

inductive Result where
  | rmatch (s e : Nat) (cs : Caps)
  | mismatch
  | limit

-- forward search: start positions 0..length, advanced by encLen
def searchFrom : Nat → Nat → Node → Nat → List Nat → Result
  | 0, _, _, _, _ => .mismatch
  | n + 1, fuel, re, pos, rest =>
    match run fuel (.run [.node re] pos rest [] []) with
    | .matched e cs => .rmatch pos e cs
    | .run .. => .limit
    | .failed =>
      match rest with
      | [] => .mismatch
      | b :: _ =>
        let l := encLen b
        match take l rest with
        | some (_, r) => searchFrom n fuel re (pos + l) r
        | none => .mismatch

def search (fuel : Nat) (re : Node) (s : List Nat) : Result :=
  searchFrom (s.length + 1) fuel re 0 s

def lookup (k : Nat) : Caps → Option (Nat × Nat)
  | [] => none
  | (k', v) :: t => if k == k' then some v else lookup k t

-- verdict as numbers: [0] no match, [2] limit, 1 :: s :: e :: groups,
-- each group [1, s, e] or [0] when unset
def encode (ncap : Nat) : Result → List Nat
  | .mismatch => [0]
  | .limit => [2]
  | .rmatch s e cs =>
    1 :: s :: e :: (List.range ncap).flatMap (fun i =>
      match lookup (i + 1) cs with
      | some (x, y) => [1, x, y]
      | none => [0])

def fuel0 : Nat := 10000000

def runCase (fuel ncap : Nat) (re : Node) (s : List Nat) : List Nat :=
  encode ncap (search fuel re s)

-- a case: number of groups, pattern, subject bytes, expected verdict
abbrev Case := Nat × Node × List Nat × List Nat

def agree (fuel : Nat) (c : Case) : Bool :=
  runCase fuel c.1 c.2.1 c.2.2.1 == c.2.2.2

def count (fuel : Nat) (cs : List Case) : Nat :=
  cs.foldl (fun acc c => if agree fuel c then acc + 1 else acc) 0

-- r passes; pass i uses fuel0 + i so that no pass can be shared
def passes : Nat → List Case → Nat → Nat
  | 0, _, acc => acc
  | r + 1, cs, acc => passes r cs (acc + count (fuel0 + r + 1) cs)

end Spec
