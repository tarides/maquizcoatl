/-
Experiment #8, Lean 4: ISO-8859-1 multi-character case folding.
Semantics fixed in lab/08-hard-features/SEMANTICS.md, section "ISO-8859-1 folding".
-/
namespace Fold

inductive Re where
  | eps | chr (c : Nat) | seq (a b : Re) | alt (a b : Re) | ilit (w : List Nat)
  deriving Repr, DecidableEq

/-- One-byte fold items of `get_case_fold_codes_by_str` (iso8859_1.c:116-215),
for a position that does not start a two-byte `ss` spelling. -/
def one (c : Nat) : List (List Nat) :=
  if Nat.ble 65 c && Nat.ble c 90 then [[c + 32]]
  else if Nat.ble 97 c && Nat.ble c 122 then [[c - 32]]
  else if Nat.ble 0xC0 c && Nat.ble c 0xCF then [[c + 32]]
  else if Nat.beq c 0xDF then [[115, 115], [83, 83], [115, 83], [83, 115]]
  else if Nat.ble 0xD0 c && Nat.ble c 0xDE && !Nat.beq c 0xD7 then [[c + 32]]
  else if Nat.ble 0xE0 c && Nat.ble c 0xEF then [[c - 32]]
  else if Nat.ble 0xF0 c && Nat.ble c 0xFE && !Nat.beq c 0xF7 then [[c - 32]]
  else []
-- written with Nat.ble/Nat.beq (Bool) throughout.

def isS (c : Nat) : Bool := c == 115 || c == 83

/-- Items of a two-byte `ss` spelling: 0xDF, then the other three spellings. -/
def ssItems (c d : Nat) : List (List Nat) :=
  [0xDF] :: [[83, 83], [83, 115], [115, 83], [115, 115]].filter
    (fun w => match w with | [x, y] => !(Nat.beq x c && Nat.beq y d) | _ => true)

/-- `unravel_case_fold_string`: one segment per pattern position, each the
list of alternatives, original bytes first. -/
def unr : Option Nat → List Nat → List (List (List Nat))
  | none, [] => []
  | some c, [] => [[c] :: one c]
  | none, c :: rest => unr (some c) rest
  | some c, d :: rest =>
      if isS c && isS d then ([c, d] :: ssItems c d) :: unr none rest
      else ([c] :: one c) :: unr (some d) rest

def unravel (w : List Nat) : List (List (List Nat)) := unr none w
-- help: written with a pending-byte accumulator so that Lean compiles it by
-- structural recursion; the direct two-byte lookahead (also with an
-- as-pattern) was compiled by well-founded recursion, irreducible, which
-- `decide +kernel` could not reduce.

inductive Item where
  | r (x : Re) | seg (alts : List (List Nat))

def prefixAt (s : List Nat) (i : Nat) : List Nat → Bool
  | [] => true
  | c :: w => s[i]? == some c && prefixAt s (i + 1) w

def m (s : List Nat) : Nat → List Item → Nat → List Nat
  | 0, _, _ => []
  | _ + 1, [], i => [i]
  | f + 1, .r .eps :: ks, i => m s f ks i
  | f + 1, .r (.chr c) :: ks, i => if s[i]? = some c then m s f ks (i + 1) else []
  | f + 1, .r (.seq a b) :: ks, i => m s f (.r a :: .r b :: ks) i
  | f + 1, .r (.alt a b) :: ks, i => m s f (.r a :: ks) i ++ m s f (.r b :: ks) i
  | f + 1, .r (.ilit w) :: ks, i => m s f ((unravel w).map .seg ++ ks) i
  | _ + 1, .seg [] :: _, _ => []
  | f + 1, .seg (w :: ws) :: ks, i =>
      (if prefixAt s i w then m s f ks (i + w.length) else []) ++ m s f (.seg ws :: ks) i

def fuel : Nat := 1000

def searchFrom (s : List Nat) (main : Re) : Nat → Nat → Option (Nat × Nat)
  | 0, _ => none
  | k + 1, st =>
      match m s fuel [.r main] st with
      | e :: _ => some (st, e)
      | [] => searchFrom s main k (st + 1)

def search (main : Re) (s : List Nat) : Option (Nat × Nat) := searchFrom s main (s.length + 1) 0

/-! Main lemma (SEMANTICS.md, lemma F): 0xDF matches each of ss, SS, sS, Ss, and back. -/
theorem sharp_s :
    ∀ w ∈ [[115, 115], [83, 83], [115, 83], [83, 115]],
      search (.ilit [0xDF]) w = some (0, 2) ∧ search (.ilit w) [0xDF] = some (0, 1) := by
  decide +kernel

/-! Test cases (cases/iso-fold.tsv). -/
theorem cf21 : search (.ilit [115, 115]) [0xDF] = some (0, 1) := by decide +kernel
theorem cf22 : search (.ilit [0xDF]) [115, 115] = some (0, 2) := by decide +kernel
theorem if01 : search (.ilit [0xDF]) [83, 83] = some (0, 2) := by decide +kernel
theorem if02 : search (.ilit [0xDF]) [115, 83] = some (0, 2) := by decide +kernel
theorem if03 : search (.ilit [0xDF]) [83, 115] = some (0, 2) := by decide +kernel
theorem if04 : search (.ilit [83, 83]) [0xDF] = some (0, 1) := by decide +kernel
theorem if05 : search (.ilit [115, 83]) [0xDF] = some (0, 1) := by decide +kernel
theorem if06 : search (.ilit [83, 115]) [0xDF] = some (0, 1) := by decide +kernel
theorem if07 : search (.ilit [83, 83, 98, 0xDF, 115, 115, 99]) [97, 0xDF, 98, 83, 83, 0xDF, 99, 100]
    = some (1, 7) := by decide +kernel
theorem if08 : search (.ilit [105, 115]) [105, 115, 115] = some (0, 2) := by decide +kernel

end Fold

#print axioms Fold.sharp_s
#print axioms Fold.if07
