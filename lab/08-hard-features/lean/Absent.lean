/-
Experiment #8, Lean 4: the absent operator (non-nested).
Semantics fixed in lab/08-hard-features/SEMANTICS.md, section "Absent operator".
The state carries the right range `rr`; every consuming step checks i < rr.
-/
namespace Absent

inductive Re where
  | eps | chr (c : Nat) | any | anyO | seq (a b : Re) | alt (a b : Re) | star (a : Re)
  | absRep (a : Re) | absExp (a e : Re) | stopper (a : Re) | rclear
  deriving Repr, DecidableEq

inductive Item where
  | r (x : Re) | chk (i : Nat) (a : Re) | setrr (n : Nat) | ends (es : List Nat)

/-- Byte at `i` if it is below the right range. -/
def at? (s : List Nat) (i rr : Nat) : Option Nat := if i < rr then s[i]? else none

/-- Base matcher, absent-free patterns: does `ks` have a result at `i`? -/
def mb (s : List Nat) : Nat → List Item → Nat → Nat → Bool
  | 0, _, _, _ => false
  | _ + 1, [], _, _ => true
  | f + 1, .r .eps :: ks, i, rr => mb s f ks i rr
  | f + 1, .r (.chr c) :: ks, i, rr => if at? s i rr = some c then mb s f ks (i + 1) rr else false
  | f + 1, .r .any :: ks, i, rr =>
      match at? s i rr with
      | some c => if c = 10 then false else mb s f ks (i + 1) rr
      | none => false
  | f + 1, .r .anyO :: ks, i, rr => if (at? s i rr).isSome then mb s f ks (i + 1) rr else false
  | f + 1, .r (.seq a b) :: ks, i, rr => mb s f (.r a :: .r b :: ks) i rr
  | f + 1, .r (.alt a b) :: ks, i, rr => mb s f (.r a :: ks) i rr || mb s f (.r b :: ks) i rr
  | f + 1, .r (.star a) :: ks, i, rr => mb s f (.r a :: .chk i a :: ks) i rr || mb s f ks i rr
  | f + 1, .chk i0 a :: ks, i, rr =>
      if i = i0 then mb s f ks i rr else mb s f (.r (.star a) :: ks) i rr
  | f + 1, .setrr n :: ks, i, _ => mb s f ks i n
  | _ + 1, _ :: _, _, _ => false   -- absent constructors, `ends`: out of scope here

def fuel : Nat := 1000

/-- `occ a s p rr`: the absent pattern `a` has a match starting at `p`. -/
def occ (a : Re) (s : List Nat) (p rr : Nat) : Bool := mb s fuel [.r a] p rr

/-- First position from `p` (k more steps) where `a` occurs; `p + k` if none. -/
def scan (a : Re) (s : List Nat) (rr : Nat) : Nat → Nat → Nat
  | 0, p => p
  | k + 1, p => if occ a s p rr then p else scan a s rr k (p + 1)

def cut (a : Re) (s : List Nat) (i rr : Nat) : Nat := scan a s rr (rr - i) i

/-- `[i + n, ..., i]`, longest first. -/
def downs : Nat → Nat → List Nat
  | 0, i => [i]
  | n + 1, i => (i + n + 1) :: downs n i

/-- Ends of the absent repeater `(?~a)` started at `i` (direct semantics). -/
def repEnds (a : Re) (s : List Nat) (i rr : Nat) : List Nat := downs (cut a s i rr - i) i

def m (s : List Nat) : Nat → List Item → Nat → Nat → List Nat
  | 0, _, _, _ => []
  | _ + 1, [], i, _ => [i]
  | f + 1, .r .eps :: ks, i, rr => m s f ks i rr
  | f + 1, .r (.chr c) :: ks, i, rr => if at? s i rr = some c then m s f ks (i + 1) rr else []
  | f + 1, .r .any :: ks, i, rr =>
      match at? s i rr with
      | some c => if c = 10 then [] else m s f ks (i + 1) rr
      | none => []
  | f + 1, .r .anyO :: ks, i, rr => if (at? s i rr).isSome then m s f ks (i + 1) rr else []
  | f + 1, .r (.seq a b) :: ks, i, rr => m s f (.r a :: .r b :: ks) i rr
  | f + 1, .r (.alt a b) :: ks, i, rr => m s f (.r a :: ks) i rr ++ m s f (.r b :: ks) i rr
  | f + 1, .r (.star a) :: ks, i, rr => m s f (.r a :: .chk i a :: ks) i rr ++ m s f ks i rr
  | f + 1, .chk i0 a :: ks, i, rr =>
      if i = i0 then m s f ks i rr else m s f (.r (.star a) :: ks) i rr
  | f + 1, .setrr n :: ks, i, _ => m s f ks i n
  | f + 1, .r (.absRep a) :: ks, i, rr => m s f (.ends (repEnds a s i rr) :: ks) i rr
  | _ + 1, .ends [] :: _, _, _ => []
  | f + 1, .ends (e :: es) :: ks, i, rr => m s f ks e rr ++ m s f (.ends es :: ks) i rr
  | f + 1, .r (.absExp a e) :: ks, i, rr => m s f (.r e :: .setrr rr :: ks) i (cut a s i rr)
  | f + 1, .r (.stopper a) :: ks, i, rr => m s f ks i (cut a s i rr)
  | f + 1, .r .rclear :: ks, i, _ => m s f ks i s.length

def searchFrom (s : List Nat) (main : Re) : Nat → Nat → Option (Nat × Nat)
  | 0, _ => none
  | k + 1, st =>
      match m s fuel [.r main] st s.length with
      | e :: _ => some (st, e)
      | [] => searchFrom s main k (st + 1)

def search (main : Re) (s : List Nat) : Option (Nat × Nat) := searchFrom s main (s.length + 1) 0

/-! Main lemma (SEMANTICS.md, "Absent operator", lemma A). -/
theorem scan_ge (a : Re) (s : List Nat) (rr : Nat) : ∀ k p, p ≤ scan a s rr k p := by
  intro k
  induction k with
  | zero => intro p; simp [scan]
  | succ k ih =>
    intro p
    simp only [scan]
    split
    · exact Nat.le_refl p
    · exact Nat.le_trans (Nat.le_succ p) (ih (p + 1))

theorem scan_none (a : Re) (s : List Nat) (rr : Nat) :
    ∀ k p q, p ≤ q → q < scan a s rr k p → occ a s q rr = false := by
  intro k; induction k with
  | zero => intro p q h1 h2; simp [scan] at h2; omega
  | succ k ih =>
    intro p q h1 h2
    simp only [scan] at h2
    split at h2
    · omega
    · rename_i hocc
      by_cases hq : q = p
      · subst hq; simpa using hocc
      · exact ih (p + 1) q (by omega) h2

theorem downs_mem : ∀ n i e, e ∈ downs n i → i ≤ e ∧ e ≤ i + n := by
  intro n; induction n with
  | zero => intro i e h; simp [downs] at h; omega
  | succ n ih =>
    intro i e h; simp only [downs, List.mem_cons] at h
    rcases h with h | h
    · omega
    · have := ih i e h; omega

theorem absent_not_inside (a : Re) (s : List Nat) (i rr e : Nat) (he : e ∈ repEnds a s i rr) :
    ∀ p, i ≤ p → p < e → occ a s p rr = false := by
  intro p h1 h2
  have hd := downs_mem _ _ _ he
  have hc := scan_ge a s rr (rr - i) i
  exact scan_none a s rr (rr - i) i p h1 (by unfold cut at hd; omega)

/-! Test cases (cases/absent.tsv); a=97 b=98 c=99 x=120 y=121 z=122. -/
def lit : List Nat → Re
  | [] => .eps
  | [c] => .chr c
  | c :: cs => .seq (.chr c) (lit cs)
def abc := lit [97, 98, 99]
def oStar := Re.star .anyO
def dotStar := Re.star .any

theorem ab01 : search (.absRep (lit [97, 98])) [97, 98, 99] = some (0, 0) := by decide +kernel
theorem ab02 : search (.absRep abc) [97, 98, 99] = some (0, 0) := by decide +kernel
theorem ab03 : search (.absRep (.alt abc (lit [97, 98]))) [97, 98, 99] = some (0, 0) := by decide +kernel
theorem ab04 : search (.seq (lit [97, 97, 97, 97, 97]) (.absRep .eps)) (List.replicate 10 97) = some (0, 5) := by decide +kernel
theorem ab05 : search (.absExp abc oStar) [97, 98, 99] = some (0, 0) := by decide +kernel
theorem ab06 : search (.absRep abc) [120, 97, 98, 99, 120] = some (0, 1) := by decide +kernel
theorem ab07 : search (.absExp abc oStar) [120, 97, 98, 99, 120] = some (0, 1) := by decide +kernel
theorem ab08 : search (.seq (.absRep abc) (.chr 122)) [120, 97, 98, 122] = some (0, 4) := by decide +kernel
theorem ab09 : search (.seq (.absExp abc oStar) (.chr 122)) [120, 97, 98, 122] = some (0, 4) := by decide +kernel
theorem ab10 : search (.seq (.stopper abc) dotStar) [120, 120, 97, 98, 99, 121, 121] = some (0, 2) := by decide +kernel
theorem ab11 : search (.seq (.stopper abc) (.seq .rclear dotStar)) [120, 120, 97, 98, 99, 121, 121] = some (0, 7) := by decide +kernel

end Absent

#print axioms Absent.absent_not_inside
#print axioms Absent.ab07
#print axioms Absent.ab11
