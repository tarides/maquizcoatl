/- Proofs.lean: the specifications of the Charon + Aeneas prototype of
   experiment 5, and their proofs.

   build.sh appends this file to Vu.lean, the Lean model that Aeneas
   generates from src/lib.rs, and checks the result with the Aeneas Lean
   library. The names below (char_len, callout_step, EncLen, ...) are
   those of the generated model.

   Each client C function is a trait of src/lib.rs, hence a structure
   of the model (EncLen, Callout, ApplyAll) that the verified functions
   take as a parameter. The theorems quantify over every value of these
   structures: nothing is assumed of a callee except where a theorem
   says so in a hypothesis. A callee's call is a Result: it may return
   (ok), panic (fail) or not terminate (div); the theorems about a
   callee's result take "it returned r" as a hypothesis, for every r. -/

namespace vu
open Aeneas Aeneas.Std Result

/-! ## 1. vu_char_len -/

/-- For every result r of the callee, char_len returns a value within
    the bounds, provided the bounds are ordered (proto.h requires
    1 <= min_enc_len <= max_enc_len). st is an input of the model and
    the callee is not given it, so it is unchanged by construction. -/
theorem char_len_spec {F : Type} (EncLenInst : EncLen F) (f : F)
    (p : ConstRawPtr Std.U8) (st : VuEncState) (r : Std.I32)
    (hcall : EncLenInst.enc_len f p = ok r)
    (hst : st.min_enc_len.val ≤ st.max_enc_len.val) :
    char_len EncLenInst f p st ⦃ y =>
      st.min_enc_len.val ≤ y.val ∧ y.val ≤ st.max_enc_len.val ⦄ := by
  unfold char_len
  simp only [hcall, bind_ok]
  -- No assumption on the shape of the code: whatever branches there
  -- are, each one must establish the bounds from hst alone.
  (try split_ifs) <;> simp only [WP.spec_ok] <;> scalar_tac

/-- A well-behaved callee's result is returned unchanged. -/
theorem char_len_in_bounds {F : Type} (EncLenInst : EncLen F) (f : F)
    (p : ConstRawPtr Std.U8) (st : VuEncState) (r : Std.I32)
    (hcall : EncLenInst.enc_len f p = ok r)
    (hr : st.min_enc_len.val ≤ r.val ∧ r.val ≤ st.max_enc_len.val) :
    char_len EncLenInst f p st = ok r := by
  unfold char_len
  simp only [hcall, bind_ok]
  try (split_ifs <;> first | rfl | scalar_tac)

/-! ## 2. vu_callout_step -/

/-- The branch rules (lab/results/2026-11-19-exp-05-harness.md), on
    upstream's values: ONIG_CALLOUT_SUCCESS = 0, ONIG_CALLOUT_FAIL = 1,
    ONIGERR_INVALID_ARGUMENT = -30; the actions are continue = 0 and
    backtrack = 1; dir is progress (0), retraction (1) or each-match
    (2). -/
def step_rule (dir r : Int) : Int :=
  if dir = 0 then
    -- progress, upstream/src/regexec.c:4616-4631
    if r = 1 then 1 else if r = 0 then 0 else if 0 < r then -30 else r
  else if dir = 1 then
    -- retraction, upstream/src/regexec.c:1218-1234
    if r = 1 ∨ r = 0 then 0 else if 0 < r then -30 else r
  else
    -- each-match, upstream/src/regexec.c:3387-3400
    if r < 0 then r else 1

def valid_dir (dir : Int) : Prop := dir = 0 ∨ dir = 1 ∨ dir = 2

/-- The verified side's state in a VuArgs: everything but the slots. -/
def same_engine_state (a b : VuArgs) : Prop :=
  a.subject = b.subject ∧ a.subject_len = b.subject_len ∧ a.pos = b.pos ∧
    a.num = b.num

/-- For a valid dir and every result (r, args1) of the callee, which may
    have written anything into args: the action is step_rule's, the
    verified side's state is the one before the call, and the slots are
    the callee's. -/
theorem callout_step_spec {F : Type} (CalloutInst : Callout F)
    (dir : Std.I32) (f : F) (args args1 : VuArgs) (r : Std.I32)
    (hdir : valid_dir dir.val)
    (hcall : CalloutInst.callout f args = ok (r, args1)) :
    callout_step CalloutInst dir f args ⦃ act args' =>
      act.val = step_rule dir.val r.val ∧ same_engine_state args' args ∧
        args'.slot = args1.slot ⦄ := by
  unfold callout_step
  simp only [hcall, bind_ok, DIR_PROGRESS,
    DIR_RETRACTION, DIR_EACH_MATCH, CALLOUT_FAIL, CALLOUT_SUCCESS,
    ACT_BACKTRACK, ACT_CONTINUE, ERR_INVALID_ARGUMENT]
  simp only [valid_dir] at hdir
  split_ifs <;> simp_all <;> (try split_ifs) <;>
    simp_all [WP.spec_ok, same_engine_state, step_rule] <;> scalar_tac

/-- For an invalid dir, the callee is not called (the result does not
    depend on it) and nothing changes. -/
theorem callout_step_invalid {F : Type} (CalloutInst : Callout F)
    (dir : Std.I32) (f : F) (args : VuArgs) (hdir : ¬ valid_dir dir.val) :
    callout_step CalloutInst dir f args ⦃ act args' =>
      act.val = -30 ∧ args' = args ⦄ := by
  unfold callout_step
  simp only [DIR_PROGRESS, DIR_RETRACTION, DIR_EACH_MATCH,
    ERR_INVALID_ARGUMENT]
  simp only [valid_dir] at hdir
  split_ifs <;> simp_all

/-! ## 3. vu_i_apply and vu_fold_all -/

/-- Closes a leaf of i_apply_spec: the post's own conditions are split,
    and each case is either contradictory or follows by simplification. -/
local macro "i_apply_leaf" : tactic =>
  `(tactic| (
    (try simp only [WP.spec_ok, WP.uncurry'])
    (try split_ifs) <;>
      first
      | (exfalso; scalar_tac)
      | (simp_all [Array.set]; done)
      | (simp_all [Array.set]; scalar_tac)))

/-- The effect of one i_apply call: calls saturates at i32::MAX, from is
    appended when 1 <= to_len <= 3 (VU_MAX_TO_LEN) and the record is not
    full (8 entries, VU_FOLD_REC_MAX). -/
theorem i_apply_spec (fr : Std.U32) (to_len : Std.I32) (rec : VuFoldRec) :
    i_apply fr to_len rec ⦃ r rec' =>
      r.val = 0 ∧
      rec'.calls.val =
        (if rec.calls.val < 2147483647 then rec.calls.val + 1
         else rec.calls.val) ∧
      (if 1 ≤ to_len.val ∧ to_len.val ≤ 3 ∧ 0 ≤ rec.recorded.val ∧
          rec.recorded.val < 8 then
        rec'.recorded.val = rec.recorded.val + 1 ∧
          rec'.from.val = rec.from.val.set rec.recorded.toNat fr
       else rec'.recorded = rec.recorded ∧ rec'.from = rec.from) ⦄ := by
  unfold i_apply
  simp only [MAX_TO_LEN, FOLD_REC_MAX]
  have hmax : core.num.I32.MAX.val = 2147483647 := rfl
  by_cases hc : rec.calls.val < 2147483647
  · have hlt : rec.calls < core.num.I32.MAX := by scalar_tac
    simp only [hlt, ite_true]
    step as ⟨c1, hc1⟩
    split_ifs with h1 h2 h3 h4
    · step with IScalar.hcast_inBounds_spec as ⟨i, hi⟩
      step as ⟨a, ha⟩
      step as ⟨n, hn⟩
      have hik : i.val = rec.recorded.toNat := by scalar_tac
      i_apply_leaf
    all_goals i_apply_leaf
  · have hlt : ¬ rec.calls < core.num.I32.MAX := by scalar_tac
    simp only [hlt, ite_false, bind_ok]
    split_ifs with h1 h2 h3 h4
    · step with IScalar.hcast_inBounds_spec as ⟨i, hi⟩
      step as ⟨a, ha⟩
      step as ⟨n, hn⟩
      have hik : i.val = rec.recorded.toNat := by scalar_tac
      i_apply_leaf
    all_goals i_apply_leaf

/-- The record is well formed: its count is within its capacity. -/
def rec_ok (rec : VuFoldRec) : Prop :=
  0 ≤ rec.recorded.val ∧ rec.recorded.val ≤ 8

theorem i_apply_rec_ok (fr : Std.U32) (to_len : Std.I32) (rec : VuFoldRec)
    (h : rec_ok rec) :
    i_apply fr to_len rec ⦃ _ rec' => rec_ok rec' ⦄ := by
  apply WP.spec_mono (i_apply_spec fr to_len rec)
  rintro ⟨r, rec'⟩ ⟨_, _, h'⟩
  simp only [rec_ok] at *
  split_ifs at h' <;> simp_all; scalar_tac

/-- fold_all hands i_apply to the client (re-entrancy shape (a)). -/
theorem fold_all_hands_out_i_apply {G : Type} (ApplyAllInst : ApplyAll G)
    (g : G) (rec : VuFoldRec) :
    fold_all ApplyAllInst g rec =
      ApplyAllInst.apply_all IApply.Insts.VuApply g rec := rfl

/-- The client contract of re-entrancy shape (a), assumed of the C
    client and checked nowhere: the client's apply-all function reaches
    the record only through the function it is given, so it preserves
    every property of the record that this function preserves. -/
def Respects {G : Type} (ApplyAllInst : ApplyAll G) (g : G) : Prop :=
  ∀ {A : Type} (ai : Apply A) (P : VuFoldRec → Prop),
    (∀ fr to_len rec, P rec → ai.apply fr to_len rec ⦃ _ rec' => P rec' ⦄) →
    ∀ rec, P rec → ApplyAllInst.apply_all ai g rec ⦃ _ rec' => P rec' ⦄

/-- Under the client contract, the record stays well formed. -/
theorem fold_all_rec_ok {G : Type} (ApplyAllInst : ApplyAll G) (g : G)
    (hg : Respects ApplyAllInst g) (rec : VuFoldRec) (h : rec_ok rec) :
    fold_all ApplyAllInst g rec ⦃ _ rec' => rec_ok rec' ⦄ :=
  hg IApply.Insts.VuApply rec_ok
    (fun fr to_len rec hr => i_apply_rec_ok fr to_len rec hr) rec h

/-- A model of caller.c's client_apply_all: it walks a table of
    (from, to_len) entries, calls the function it is given on each and
    stops at the first non-zero result. -/
def walk {A : Type} (ai : Apply A) :
    List (Std.U32 × Std.I32) → VuFoldRec → Result (Std.I32 × VuFoldRec)
  | [], acc => ok (0#i32, acc)
  | (fr, to_len) :: t, acc => do
    let res ← ai.apply fr to_len acc
    if res.1 = 0#i32 then walk ai t res.2 else ok res

def tableClient : ApplyAll (List (Std.U32 × Std.I32)) :=
  { apply_all := fun ai g rec => walk ai g rec }

/-- The model of caller.c's client meets the client contract, so the
    contract can be met. -/
theorem tableClient_respects (tbl : List (Std.U32 × Std.I32)) :
    Respects tableClient tbl := by
  intro A ai P hP rec hrec
  induction tbl generalizing rec with
  | nil => simp [tableClient, walk, WP.spec_ok, hrec]
  | cons hd t ih =>
    obtain ⟨fr, to_len⟩ := hd
    simp only [tableClient, walk]
    apply WP.spec_bind (hP fr to_len rec hrec)
    rintro ⟨r, rec1⟩ h1
    simp only [WP.uncurry'] at h1
    split
    · exact ih rec1 h1
    · simpa [WP.spec_ok, WP.uncurry'] using h1

/-! ## 4. vu_get_slot and vu_set_slot -/

def slot_ok (k : Int) : Prop := 0 ≤ k ∧ k < 5

/-- Closes what remains of a slot accessor's postcondition: each
    conjunct and implication is taken apart, then each piece is either
    contradictory or follows by simplification. -/
local macro "slot_leaf" : tactic =>
  `(tactic| (
    (try simp only [WP.spec_ok, WP.uncurry'])
    repeat' (first | (intro _) | (apply And.intro))
    all_goals first
      | rfl
      | (simp; done)
      | (exfalso; scalar_tac)
      | (simp_all [Array.set]; done)
      | scalar_tac))

theorem get_slot_spec (args : VuArgs) (k : Std.I32) (v : Std.I64) :
    get_slot args k v ⦃ r v' =>
      (slot_ok k.val → r.val = 0 ∧ args.slot.val[k.toNat]? = some v') ∧
      (¬ slot_ok k.val → r.val = -30 ∧ v' = v) ⦄ := by
  unfold get_slot
  simp only [SLOT_NUM, ERR_INVALID_ARGUMENT, slot_ok]
  split_ifs with h0 h5
  · step with IScalar.hcast_inBounds_spec as ⟨i, hi⟩
    step as ⟨v1, hv1⟩
    have hik : i.val = k.toNat := by scalar_tac
    have hget : args.slot.val[k.toNat]? = some v1 := by
      rw [← hik, hv1, List.getElem?_eq_getElem]
    slot_leaf
  all_goals slot_leaf

theorem set_slot_spec (args : VuArgs) (k : Std.I32) (v : Std.I64) :
    set_slot args k v ⦃ r args' =>
      same_engine_state args' args ∧
      (slot_ok k.val → r.val = 0 ∧ args'.slot.val = args.slot.val.set k.toNat v) ∧
      (¬ slot_ok k.val → r.val = -30 ∧ args'.slot = args.slot) ⦄ := by
  unfold set_slot
  simp only [SLOT_NUM, ERR_INVALID_ARGUMENT, slot_ok, same_engine_state]
  split_ifs with h0 h5
  · step with IScalar.hcast_inBounds_spec as ⟨i, hi⟩
    step as ⟨a, ha⟩
    have hik : i.val = k.toNat := by scalar_tac
    have hset : a.val = args.slot.val.set k.toNat v := by
      simp [ha, hik]
    slot_leaf
  all_goals slot_leaf

end vu

/-! Axioms: build.sh checks that each line below lists only Lean's
    standard axioms (propext, Classical.choice, Quot.sound). -/
#print axioms vu.char_len_spec
#print axioms vu.char_len_in_bounds
#print axioms vu.callout_step_spec
#print axioms vu.callout_step_invalid
#print axioms vu.i_apply_spec
#print axioms vu.i_apply_rec_ok
#print axioms vu.fold_all_rec_ok
#print axioms vu.tableClient_respects
#print axioms vu.get_slot_spec
#print axioms vu.set_slot_spec
