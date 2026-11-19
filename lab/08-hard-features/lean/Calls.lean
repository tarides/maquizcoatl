/-
Experiment #8, Lean 4: subexpression calls with the nest limit.
Semantics fixed in lab/08-hard-features/SEMANTICS.md, section "Calls".
First-order backtracking matcher over an explicit stack of pending items
(defunctionalised continuation), priority-ordered list of results.
-/
namespace Calls

inductive Re where
  | eps | chr (c : Nat) | any | seq (a b : Re) | alt (a b : Re) | star (a : Re)
  | call (n : Nat) | bos | eos
  deriving Repr, DecidableEq

inductive Item where
  | r (x : Re) | ret | chk (i : Nat) (a : Re)

/-- `m lim defs s f ks i d mx`: results (end, max depth) of running the
pending items `ks` at position `i`, nest depth `d` (live call frames),
running maximum depth `mx`, with fuel `f`. -/
def m (lim : Nat) (defs : List Re) (s : List Nat) :
    Nat → List Item → Nat → Nat → Nat → List (Nat × Nat)
  | 0, _, _, _, _ => []
  | _ + 1, [], i, _, mx => [(i, mx)]
  | f + 1, .r .eps :: ks, i, d, mx => m lim defs s f ks i d mx
  | f + 1, .r (.chr c) :: ks, i, d, mx =>
      if s[i]? = some c then m lim defs s f ks (i + 1) d mx else []
  | f + 1, .r .any :: ks, i, d, mx =>
      match s[i]? with
      | some c => if c = 10 then [] else m lim defs s f ks (i + 1) d mx
      | none => []
  | f + 1, .r (.seq a b) :: ks, i, d, mx => m lim defs s f (.r a :: .r b :: ks) i d mx
  | f + 1, .r (.alt a b) :: ks, i, d, mx =>
      m lim defs s f (.r a :: ks) i d mx ++ m lim defs s f (.r b :: ks) i d mx
  | f + 1, .r (.star a) :: ks, i, d, mx =>
      m lim defs s f (.r a :: .chk i a :: ks) i d mx ++ m lim defs s f ks i d mx
  | f + 1, .chk i0 a :: ks, i, d, mx =>
      if i = i0 then m lim defs s f ks i d mx else m lim defs s f (.r (.star a) :: ks) i d mx
  | f + 1, .r (.call n) :: ks, i, d, mx =>
      if lim ≤ d then []
      else match defs[n]? with
        | some b => m lim defs s f (.r b :: .ret :: ks) i (d + 1) (max mx (d + 1))
        | none => []
  | f + 1, .ret :: ks, i, d, mx => m lim defs s f ks i (d - 1) mx
  | f + 1, .r .bos :: ks, i, d, mx => if i = 0 then m lim defs s f ks i d mx else []
  | f + 1, .r .eos :: ks, i, d, mx => if i = s.length then m lim defs s f ks i d mx else []

/-- Forward search over start positions `st, st+1, ...` (k of them). -/
def searchFrom (lim : Nat) (defs : List Re) (s : List Nat) (f : Nat) (main : Re) :
    Nat → Nat → Option (Nat × Nat)
  | 0, _ => none
  | k + 1, st =>
      match m lim defs s f [.r main] st 0 0 with
      | (e, _) :: _ => some (st, e)
      | [] => searchFrom lim defs s f main k (st + 1)

def defaultLimit : Nat := 20
def fuel : Nat := 1000

def search (lim : Nat) (defs : List Re) (main : Re) (s : List Nat) : Option (Nat × Nat) :=
  searchFrom lim defs s fuel main (s.length + 1) 0

/-! Main lemma (SEMANTICS.md, "Calls", lemma C): every result is produced
with nest depth at most the limit at every step. -/
theorem depth_bound (lim : Nat) (defs : List Re) (s : List Nat) :
    ∀ f ks i d mx p, d ≤ lim → mx ≤ lim → p ∈ m lim defs s f ks i d mx → p.2 ≤ lim := by
  intro f
  induction f with
  | zero => intro ks i d mx p _ _ hp; simp [m] at hp
  | succ f ih =>
    intro ks i d mx p hd hmx hp
    match ks with
    | [] => simp [m] at hp; subst hp; exact hmx
    | .r .eps :: ks => simp only [m] at hp; exact ih _ _ _ _ _ hd hmx hp
    | .r (.chr c) :: ks =>
      simp only [m] at hp; split at hp
      · exact ih _ _ _ _ _ hd hmx hp
      · simp at hp
    | .r .any :: ks =>
      simp only [m] at hp; split at hp
      · split at hp
        · simp at hp
        · exact ih _ _ _ _ _ hd hmx hp
      · simp at hp
    | .r (.seq a b) :: ks => simp only [m] at hp; exact ih _ _ _ _ _ hd hmx hp
    | .r (.alt a b) :: ks =>
      simp only [m, List.mem_append] at hp
      rcases hp with hp | hp <;> exact ih _ _ _ _ _ hd hmx hp
    | .r (.star a) :: ks =>
      simp only [m, List.mem_append] at hp
      rcases hp with hp | hp <;> exact ih _ _ _ _ _ hd hmx hp
    | .chk i0 a :: ks =>
      simp only [m] at hp; split at hp <;> exact ih _ _ _ _ _ hd hmx hp
    | .r (.call n) :: ks =>
      simp only [m] at hp; split at hp
      · simp at hp
      · split at hp
        · exact ih _ _ _ _ _ (by omega) (by omega) hp
        · simp at hp
    | .ret :: ks => simp only [m] at hp; exact ih _ _ _ _ _ (by omega) hmx hp
    | .r .bos :: ks =>
      simp only [m] at hp; split at hp
      · exact ih _ _ _ _ _ hd hmx hp
      · simp at hp
    | .r .eos :: ks =>
      simp only [m] at hp; split at hp
      · exact ih _ _ _ _ _ hd hmx hp
      · simp at hp

/-- Corollary at the top level: a search run's results stay within the limit. -/
theorem depth_bound_top (lim : Nat) (defs : List Re) (s : List Nat) (f : Nat) (main : Re)
    (st : Nat) (p : Nat × Nat) (hp : p ∈ m lim defs s f [.r main] st 0 0) : p.2 ≤ lim :=
  depth_bound lim defs s f _ _ _ _ p (Nat.zero_le _) (Nat.zero_le _) hp

/-! Test cases (lab/08-hard-features/cases/calls.tsv, nest.tsv). Characters
are byte codes: a=97, b=98, (=40, )=41. Expected results are the C results
(Debug = ASan) of corpus run r1. -/
def a := Re.chr 97
def b := Re.chr 98
def lp := Re.chr 40
def rp := Re.chr 41
-- (a)\g<1>
def p1 : List Re × Re := ([a], .seq (.call 0) (.call 0))
-- (?<name_2>ab)\g<name_2>
def p2 : List Re × Re := ([.seq a b], .seq (.call 0) (.call 0))
-- \A(?<n>(a\g<n>)|)\z
def p3 : List Re × Re := ([.alt (.seq a (.call 0)) .eps], .seq .bos (.seq (.call 0) .eos))
-- (?<foo>a|\(\g<foo>\))
def p4 : List Re × Re := ([.alt a (.seq lp (.seq (.call 0) rp))], .call 0)
-- \A(?<n>a\g<n>|b)\z
def p5 : List Re × Re := ([.alt (.seq a (.call 0)) b], .seq .bos (.seq (.call 0) .eos))
def s4 : List Nat := [40,40,40,40,40,40,97,41,41,41,41,41,41]

theorem ca01 : search defaultLimit p1.1 p1.2 [97,97] = some (0, 2) := by decide +kernel
theorem ca02 : search defaultLimit p2.1 p2.2 [97,98,97,98] = some (0, 4) := by decide +kernel
theorem ca03 : search defaultLimit p3.1 p3.2 [97,97,97,97] = some (0, 4) := by decide +kernel
theorem ca04 : search defaultLimit p4.1 p4.2 s4 = some (0, 13) := by decide +kernel
theorem ca05 : search defaultLimit p5.1 p5.2 [97,97,97,98] = some (0, 4) := by decide +kernel
theorem nc01 : search 2 p5.1 p5.2 [97,97,97,98] = none := by decide +kernel
theorem nc02 : search 20 p5.1 p5.2 [97,97,97,98] = some (0, 4) := by decide +kernel
theorem nc03 : search 2 p4.1 p4.2 s4 = some (5, 8) := by decide +kernel
theorem nc04 : search 0 p1.1 p1.2 [97,97] = none := by decide +kernel
theorem ns01_3 : search 3 p5.1 p5.2 [97,97,97,98] = none := by decide +kernel
theorem ns01_4 : search 4 p5.1 p5.2 [97,97,97,98] = some (0, 4) := by decide +kernel
theorem ns02_1 : search 1 p4.1 p4.2 s4 = some (6, 7) := by decide +kernel
theorem ns02_6 : search 6 p4.1 p4.2 s4 = some (1, 12) := by decide +kernel
theorem ns02_7 : search 7 p4.1 p4.2 s4 = some (0, 13) := by decide +kernel

end Calls

#print axioms Calls.depth_bound
#print axioms Calls.depth_bound_top
#print axioms Calls.ca04
#print axioms Calls.nc03
