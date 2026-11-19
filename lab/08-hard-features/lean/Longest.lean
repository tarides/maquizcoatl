/-
Experiment #8, Lean 4: ONIG_OPTION_FIND_LONGEST (forward search).
Semantics fixed in lab/08-hard-features/SEMANTICS.md, section "FIND_LONGEST".
-/
namespace Longest

inductive Re where
  | eps | chr (c : Nat) | word | seq (a b : Re) | alt (a b : Re) | star (a : Re)
  deriving Repr, DecidableEq

inductive Item where
  | r (x : Re) | chk (i : Nat) (a : Re)

/-- `\w` on ASCII: [0-9A-Za-z_]. -/
def isWord (c : Nat) : Bool :=
  (48 ≤ c && c ≤ 57) || (65 ≤ c && c ≤ 90) || (97 ≤ c && c ≤ 122) || c == 95

/-- Ends of the pending items `ks` at `i`, in priority order. -/
def m (s : List Nat) : Nat → List Item → Nat → List Nat
  | 0, _, _ => []
  | _ + 1, [], i => [i]
  | f + 1, .r .eps :: ks, i => m s f ks i
  | f + 1, .r (.chr c) :: ks, i => if s[i]? = some c then m s f ks (i + 1) else []
  | f + 1, .r .word :: ks, i =>
      match s[i]? with
      | some c => if isWord c then m s f ks (i + 1) else []
      | none => []
  | f + 1, .r (.seq a b) :: ks, i => m s f (.r a :: .r b :: ks) i
  | f + 1, .r (.alt a b) :: ks, i => m s f (.r a :: ks) i ++ m s f (.r b :: ks) i
  | f + 1, .r (.star a) :: ks, i => m s f (.r a :: .chk i a :: ks) i ++ m s f ks i
  | f + 1, .chk i0 a :: ks, i => if i = i0 then m s f ks i else m s f (.r (.star a) :: ks) i

def fuel : Nat := 1000

/-- First-match search. -/
def searchFrom (s : List Nat) (main : Re) : Nat → Nat → Option (Nat × Nat)
  | 0, _ => none
  | k + 1, st =>
      match m s fuel [.r main] st with
      | e :: _ => some (st, e)
      | [] => searchFrom s main k (st + 1)

def search (main : Re) (s : List Nat) : Option (Nat × Nat) := searchFrom s main (s.length + 1) 0

/-- Is the result `[st, e)` strictly longer than the best so far? -/
def better (st e : Nat) : Option (Nat × Nat) → Bool
  | none => true
  | some (s0, e0) => e0 - s0 < e - st

/-- Fold over the results of one start, in priority order. -/
def pick (st : Nat) : Option (Nat × Nat) → List Nat → Option (Nat × Nat)
  | b, [] => b
  | b, e :: es => pick st (if better st e b then some (st, e) else b) es

/-- FIND_LONGEST search: every start, every result, first of maximal length. -/
def longestFrom (s : List Nat) (main : Re) : Option (Nat × Nat) → Nat → Nat → Option (Nat × Nat)
  | b, 0, _ => b
  | b, k + 1, st => longestFrom s main (pick st b (m s fuel [.r main] st)) k (st + 1)

def longest (main : Re) (s : List Nat) : Option (Nat × Nat) :=
  longestFrom s main none (s.length + 1) 0

/-- `ge b n`: there is a best result and it is at least `n` long. -/
def ge : Option (Nat × Nat) → Nat → Prop
  | none, _ => False
  | some (a, b), n => n ≤ b - a

/-! Main lemma (SEMANTICS.md, "FIND_LONGEST", lemma L). -/
theorem pick_mono (st : Nat) : ∀ l b n, ge b n → ge (pick st b l) n := by
  intro l; induction l with
  | nil => intro b n h; exact h
  | cons e es ih =>
    intro b n h; simp only [pick]; apply ih
    split
    · rename_i hb
      match b, hb, h with
      | some (s0, e0), hb, h => simp [better, ge] at hb h ⊢; omega
    · exact h

theorem pick_mem (st : Nat) : ∀ l b e, e ∈ l → ge (pick st b l) (e - st) := by
  intro l; induction l with
  | nil => intro b e h; simp at h
  | cons e' es ih =>
    intro b e h; simp only [pick]
    rcases List.mem_cons.mp h with h | h
    · subst h; apply pick_mono
      split
      · simp [ge]
      · rename_i hb
        match b, hb with
        | none, hb => simp [better] at hb
        | some (s0, e0), hb => simp [better, ge] at hb ⊢; omega
    · exact ih _ _ h

theorem longest_mono (s : List Nat) (main : Re) : ∀ k st b n, ge b n → ge (longestFrom s main b k st) n := by
  intro k; induction k with
  | zero => intro st b n h; exact h
  | succ k ih => intro st b n h; simp only [longestFrom]; exact ih _ _ _ (pick_mono _ _ _ _ h)

theorem longest_ge_first (s : List Nat) (main : Re) :
    ∀ k st b s1 e1, searchFrom s main k st = some (s1, e1) → ge (longestFrom s main b k st) (e1 - s1) := by
  intro k; induction k with
  | zero => intro st b s1 e1 h; simp [searchFrom] at h
  | succ k ih =>
    intro st b s1 e1 h
    simp only [searchFrom] at h
    simp only [longestFrom]
    split at h
    · rename_i e rest hm
      simp at h; obtain ⟨h1, h2⟩ := h
      rw [← h1, ← h2]
      apply longest_mono
      exact pick_mem st (m s fuel [.r main] st) b e (by rw [hm]; simp)
    · exact ih _ _ _ _ h

theorem longest_no_shorter (main : Re) (s : List Nat) (s1 e1 : Nat) (h : search main s = some (s1, e1)) :
    ∃ s2 e2, longest main s = some (s2, e2) ∧ e1 - s1 ≤ e2 - s2 := by
  have hg := longest_ge_first s main (s.length + 1) 0 none s1 e1 h
  unfold longest
  revert hg
  cases longestFrom s main none (s.length + 1) 0 with
  | none => simp [ge]
  | some p => intro hg; exact ⟨p.1, p.2, rfl, by simpa [ge] using hg⟩

/-! Test cases (cases/find-longest.tsv). -/
def w1 := Re.seq .word (.star .word)   -- \w+
def a := Re.chr 97
def bcd := Re.seq (.chr 98) (.seq (.chr 99) (.chr 100))
def ab := Re.seq (.chr 97) (.chr 98)
-- "abc defg hij", "ab cd ef"
def s1 : List Nat := [97, 98, 99, 32, 100, 101, 102, 103, 32, 104, 105, 106]
def s2 : List Nat := [97, 98, 32, 99, 100, 32, 101, 102]

theorem fl01 : longest w1 s1 = some (4, 8) := by decide +kernel
theorem fl02 : longest w1 s2 = some (0, 2) := by decide +kernel
theorem fl03 : longest (.alt a bcd) [97, 98, 99, 100] = some (1, 4) := by decide +kernel
theorem fl04 : longest (.alt a ab) [97, 98] = some (0, 2) := by decide +kernel
theorem fl05 : search (.alt a bcd) [97, 98, 99, 100] = some (0, 1) := by decide +kernel
theorem fl06 : search (.alt a ab) [97, 98] = some (0, 1) := by decide +kernel

end Longest

#print axioms Longest.longest_no_shorter
#print axioms Longest.fl01
