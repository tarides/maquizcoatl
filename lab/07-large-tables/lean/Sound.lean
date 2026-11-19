-- Experiment #7: soundness of the boolean sanity checker, independent of the table.
import Mem
open Table

inductive SortedDisjoint : List (UInt32 × UInt32) → Prop
  | nil : SortedDisjoint []
  | one (lo hi : UInt32) : lo ≤ hi → SortedDisjoint [(lo, hi)]
  | cons (lo hi lo' hi' : UInt32) (t : List (UInt32 × UInt32)) :
      lo ≤ hi → hi.toNat + 1 < lo'.toNat → SortedDisjoint ((lo', hi') :: t) →
      SortedDisjoint ((lo, hi) :: (lo', hi') :: t)

theorem okList_sound : ∀ l, okList l = true → SortedDisjoint l
  | [], _ => .nil
  | [(lo, hi)], h => by
      simp [okList] at h
      exact .one lo hi h
  | (lo, hi) :: (lo', hi') :: t, h => by
      have h' : (decide (lo ≤ hi) && decide (hi.toNat + 1 < lo'.toNat) &&
          okList ((lo', hi') :: t)) = true := h
      simp only [Bool.and_eq_true, decide_eq_true_eq] at h'
      exact .cons lo hi lo' hi' t h'.1.1 h'.1.2 (okList_sound _ h'.2)

theorem tableOkL_sound (h : tableOkL = true) :
    ∀ a ∈ codeRanges.toList, SortedDisjoint a.toList := by
  intro a ha
  simp only [tableOkL, List.all_eq_true] at h
  exact okList_sound _ (h a ha)
