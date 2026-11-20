(* verif_vu.v: VST proofs of the verified functions of experiment #5
   (vu.c, translated to Clight by clightgen as VU.vu).

   Each client C function pointer is a parameter whose precondition
   carries [func_ptr' spec f]: [spec] is the client contract (a VST
   funspec), assumed by the verified code and checked nowhere, since
   the client is C. VST's forward_call then reasons about the indirect
   call through that funspec. There is no shim and no axiom.

   The upstream rules modelled here are cited in ../proto.h and in
   lab/results/2026-11-19-exp-05-harness.md. *)

Require Import VST.floyd.proofauto.
Require Import VU.vu.
#[export] Instance CompSpecs : compspecs. make_compspecs prog. Defined.
Definition Vprog : varspecs. mk_varspecs prog. Defined.

Local Open Scope Z.

(* ------------------------------------------------------------------
   Constants of proto.h *)

Definition callout_success := 0.
Definition callout_fail := 1.
Definition err_invalid_argument := -30.
Definition dir_progress := 0.
Definition dir_retraction := 1.
Definition dir_each_match := 2.
Definition act_continue := 0.
Definition act_backtrack := 1.
Definition slot_num := 5.
Definition max_to_len := 3.
Definition fold_rec_max := 8.

(* ------------------------------------------------------------------
   C types of proto.h, as clightgen writes them *)

Definition t_enc := Tstruct _vu_enc_state noattr.
Definition t_args := Tstruct _vu_args noattr.
Definition t_rec := Tstruct _vu_fold_rec noattr.

Definition t_enc_len_fn :=
  tptr (Tfunction (tptr tuchar :: nil) tint cc_default).
Definition t_callout_fn :=
  tptr (Tfunction (tptr t_args :: tptr tvoid :: nil) tint cc_default).
Definition t_apply_fn :=
  tptr (Tfunction (tuint :: tptr tuint :: tint :: tptr tvoid :: nil) tint
          cc_default).
Definition t_apply_all_fn :=
  tptr (Tfunction (t_apply_fn :: tptr tvoid :: nil) tint cc_default).

(* ------------------------------------------------------------------
   Values of the structs *)

(* struct vu_args: the verified-side state (subject, subject_len, pos,
   num) and the data slots. *)
Definition args_rep (subj len pos num : val) (slots : list int64)
  : reptype t_args :=
  (subj, (len, (pos, (num, map Vlong slots)))).

(* vu_fold_rec *)
Definition rec_rep (calls recorded : Z) (froms : list val) : reptype t_rec :=
  (Vint (Int.repr calls), (Vint (Int.repr recorded), froms)).

Definition rec_wf (recorded : Z) : Prop := 0 <= recorded <= fold_rec_max.

(* ------------------------------------------------------------------
   Upstream's branch rules for a callout result r *)

(* upstream/src/regexec.c:4616-4631 *)
Definition progress_rule (r : Z) : Z :=
  if r =? callout_fail then act_backtrack
  else if r =? callout_success then act_continue
  else if 0 <? r then err_invalid_argument
  else r.

(* upstream/src/regexec.c:1218-1234 *)
Definition retraction_rule (r : Z) : Z :=
  if orb (r =? callout_fail) (r =? callout_success) then act_continue
  else if 0 <? r then err_invalid_argument
  else r.

(* upstream/src/regexec.c:3387-3400 *)
Definition each_match_rule (r : Z) : Z :=
  if r <? 0 then r else act_backtrack.

Definition step_result (dir r : Z) : Z :=
  if dir =? dir_progress then progress_rule r
  else if dir =? dir_retraction then retraction_rule r
  else if dir =? dir_each_match then each_match_rule r
  else err_invalid_argument.

Definition dir_valid (dir : Z) : bool :=
  andb (dir_progress <=? dir) (dir <=? dir_each_match).

(* ------------------------------------------------------------------
   vu_i_apply's effect on the record *)

Definition apply_calls (calls : Z) : Z :=
  if calls <? Int.max_signed then calls + 1 else calls.

Definition apply_records (to_len recorded : Z) : bool :=
  andb (andb (1 <=? to_len) (to_len <=? max_to_len))
       (andb (0 <=? recorded) (recorded <? fold_rec_max)).

Definition slot_ok (k : Z) : bool := andb (0 <=? k) (k <? slot_num).

(* ------------------------------------------------------------------
   Client contracts: the funspecs of the client's function pointers.
   CLIENT-CONTRACTS-BEGIN *)

(* vu_enc_len_fn: reads the byte at p through a read share, gives it
   back, and returns any int. *)
Definition enc_len_spec : funspec :=
  WITH shp : share, p : val, c : Z
  PRE [tptr tuchar]
    PROP (readable_share shp)
    PARAMS (p)
    SEP (data_at shp tuchar (Vint (Int.repr c)) p)
  POST [tint]
    EX r : Z,
    PROP (Int.min_signed <= r <= Int.max_signed)
    RETURN (Vint (Int.repr r))
    SEP (data_at shp tuchar (Vint (Int.repr c)) p).

(* vu_callout_fn: gets the whole args record with a writable share and
   gives it back with the verified-side state unchanged and any slots;
   returns any int. user_data stays the client's: no ownership of it
   passes through the verified code. *)
Definition callout_spec : funspec :=
  WITH sha : share, args : val, ud : val,
       subj : val, len : val, pos : val, num : val, slots : list int64
  PRE [tptr t_args, tptr tvoid]
    PROP (writable_share sha)
    PARAMS (args; ud)
    SEP (data_at sha t_args (args_rep subj len pos num slots) args)
  POST [tint]
    EX r : Z, EX slots' : list int64,
    PROP (Int.min_signed <= r <= Int.max_signed)
    RETURN (Vint (Int.repr r))
    SEP (data_at sha t_args (args_rep subj len pos num slots') args).

(* CLIENT-CONTRACTS-END *)

(* vu_i_apply's own specification, also the contract of the pointer to
   it that vu_fold_all hands to the client. *)
Definition i_apply_fs : funspec :=
  WITH shr : share, rec : val, calls : Z, recorded : Z, froms : list val,
       from : Z, to : val, to_len : Z
  PRE [tuint, tptr tuint, tint, tptr tvoid]
    PROP (writable_share shr; Int.min_signed <= calls <= Int.max_signed;
          Int.min_signed <= recorded <= Int.max_signed;
          0 <= from <= Int.max_unsigned;
          Int.min_signed <= to_len <= Int.max_signed)
    PARAMS (Vint (Int.repr from); to; Vint (Int.repr to_len); rec)
    SEP (data_at shr t_rec (rec_rep calls recorded froms) rec)
  POST [tint]
    PROP ()
    RETURN (Vint (Int.repr 0))
    SEP (data_at shr t_rec
           (if apply_records to_len recorded
            then rec_rep (apply_calls calls) (recorded + 1)
                   (upd_Znth recorded froms (Vint (Int.repr from)))
            else rec_rep (apply_calls calls) recorded froms) rec).

(* CLIENT-CONTRACTS-BEGIN *)

(* vu_apply_all_fn: gets a pointer meeting i_apply_fs and a well-formed
   record with a writable share, gives the record back well formed;
   returns any int. *)
Definition apply_all_spec : funspec :=
  WITH f : val, shr : share, rec : val, calls : Z, recorded : Z,
       froms : list val
  PRE [t_apply_fn, tptr tvoid]
    PROP (writable_share shr; Int.min_signed <= calls <= Int.max_signed;
          rec_wf recorded)
    PARAMS (f; rec)
    SEP (func_ptr' i_apply_fs f;
         data_at shr t_rec (rec_rep calls recorded froms) rec)
  POST [tint]
    EX r : int, EX calls' : Z, EX recorded' : Z, EX froms' : list val,
    PROP (Int.min_signed <= calls' <= Int.max_signed; rec_wf recorded')
    RETURN (Vint r)
    SEP (func_ptr' i_apply_fs f;
         data_at shr t_rec (rec_rep calls' recorded' froms') rec).

(* CLIENT-CONTRACTS-END *)

(* ------------------------------------------------------------------
   Specifications of the verified functions *)

(* The result is in [lo, hi] whatever the callee returns, and *st and
   *p are unchanged. *)
Definition vu_char_len_spec :=
  DECLARE _vu_char_len
  WITH f : val, p : val, st : val, shp : share, c : Z, shs : share,
       lo : Z, hi : Z
  PRE [t_enc_len_fn, tptr tuchar, tptr t_enc]
    PROP (readable_share shp; readable_share shs;
          1 <= lo <= hi; hi <= Int.max_signed)
    PARAMS (f; p; st)
    SEP (func_ptr' enc_len_spec f;
         data_at shp tuchar (Vint (Int.repr c)) p;
         data_at shs t_enc (Vint (Int.repr lo), Vint (Int.repr hi)) st)
  POST [tint]
    EX r : Z,
    PROP (lo <= r <= hi)
    RETURN (Vint (Int.repr r))
    SEP (func_ptr' enc_len_spec f;
         data_at shp tuchar (Vint (Int.repr c)) p;
         data_at shs t_enc (Vint (Int.repr lo), Vint (Int.repr hi)) st).

(* The result is step_result dir r, where r is the callee's result; the
   verified-side state of *args is unchanged, and so are the slots when
   dir is invalid (the callee is then not called). *)
Definition vu_callout_step_spec :=
  DECLARE _vu_callout_step
  WITH dir : Z, f : val, args : val, ud : val, sha : share,
       subj : val, len : val, pos : val, num : val, slots : list int64
  PRE [tint, t_callout_fn, tptr t_args, tptr tvoid]
    PROP (writable_share sha; Int.min_signed <= dir <= Int.max_signed)
    PARAMS (Vint (Int.repr dir); f; args; ud)
    SEP (func_ptr' callout_spec f;
         data_at sha t_args (args_rep subj len pos num slots) args)
  POST [tint]
    EX r : Z, EX slots' : list int64,
    PROP (Int.min_signed <= r <= Int.max_signed;
          dir_valid dir = false -> slots' = slots)
    RETURN (Vint (Int.repr (step_result dir r)))
    SEP (func_ptr' callout_spec f;
         data_at sha t_args (args_rep subj len pos num slots') args).

Definition vu_i_apply_spec := DECLARE _vu_i_apply i_apply_fs.

(* Re-entrancy (a): vu_i_apply is handed to the client, which must treat
   it according to i_apply_fs; the record comes back well formed. *)
Definition vu_fold_all_spec :=
  DECLARE _vu_fold_all
  WITH gv : globals, g : val, shr : share, rec : val, calls : Z,
       recorded : Z, froms : list val
  PRE [t_apply_all_fn, tptr t_rec]
    PROP (writable_share shr; Int.min_signed <= calls <= Int.max_signed;
          rec_wf recorded)
    PARAMS (g; rec) GLOBALS (gv)
    SEP (func_ptr' apply_all_spec g;
         data_at shr t_rec (rec_rep calls recorded froms) rec)
  POST [tint]
    EX r : int, EX calls' : Z, EX recorded' : Z, EX froms' : list val,
    PROP (Int.min_signed <= calls' <= Int.max_signed; rec_wf recorded')
    RETURN (Vint r)
    SEP (func_ptr' apply_all_spec g;
         data_at shr t_rec (rec_rep calls' recorded' froms') rec).

(* Re-entrancy (b): accessors called by name from a client callout. *)
Definition vu_get_slot_spec :=
  DECLARE _vu_get_slot
  WITH sha : share, args : val, subj : val, len : val, pos : val,
       num : val, slots : list int64, k : Z, shv : share, v : val, v0 : val
  PRE [tptr t_args, tint, tptr tlong]
    PROP (readable_share sha; writable_share shv;
          Int.min_signed <= k <= Int.max_signed)
    PARAMS (args; Vint (Int.repr k); v)
    SEP (data_at sha t_args (args_rep subj len pos num slots) args;
         data_at shv tlong v0 v)
  POST [tint]
    PROP ()
    RETURN (Vint (Int.repr (if slot_ok k then 0 else err_invalid_argument)))
    SEP (data_at sha t_args (args_rep subj len pos num slots) args;
         data_at shv tlong
           (if slot_ok k then Vlong (Znth k slots) else v0) v).

Definition vu_set_slot_spec :=
  DECLARE _vu_set_slot
  WITH sha : share, args : val, subj : val, len : val, pos : val,
       num : val, slots : list int64, k : Z, x : int64
  PRE [tptr t_args, tint, tlong]
    PROP (writable_share sha; Int.min_signed <= k <= Int.max_signed)
    PARAMS (args; Vint (Int.repr k); Vlong x)
    SEP (data_at sha t_args (args_rep subj len pos num slots) args)
  POST [tint]
    PROP ()
    RETURN (Vint (Int.repr (if slot_ok k then 0 else err_invalid_argument)))
    SEP (data_at sha t_args
           (args_rep subj len pos num
              (if slot_ok k then upd_Znth k slots x else slots)) args).

Definition Gprog : funspecs := ltac:(with_library prog [
  vu_char_len_spec; vu_callout_step_spec; vu_i_apply_spec;
  vu_fold_all_spec; vu_get_slot_spec; vu_set_slot_spec]).

(* ------------------------------------------------------------------
   Proofs *)

(* Prints a goal a proof leaves, with its pure hypotheses, and fails:
   only reached when a postcondition is not proved (the negative
   control). *)
Ltac unproved :=
  idtac "Unproved goal, with its pure hypotheses:";
  try (match goal with H : ?T |- _ =>
         match type of T with Prop => idtac "  " H ":" T end; fail
       end);
  match goal with |- ?G =>
    idtac "  goal:" G; fail 1 "postcondition not proved"
  end.

(* Turns the int equalities that forward_if leaves into Z equalities. *)
Ltac int_to_Z :=
  repeat match goal with
  | H : Int.repr ?a = Int.repr ?b |- _ =>
      apply repr_inj_signed in H; [ | rep_lia | rep_lia]
  | H : Int.repr ?a <> Int.repr ?b |- _ =>
      let E := fresh in
      assert (E : a <> b) by (intro; subst; contradiction); clear H
  end.

(* Decides the pure rules above by case analysis on their tests. *)
Ltac solve_rules :=
  int_to_Z;
  unfold step_result, progress_rule, retraction_rule, each_match_rule,
    dir_valid, apply_calls, apply_records, slot_ok,
    callout_success, callout_fail, err_invalid_argument, dir_progress,
    dir_retraction, dir_each_match, act_continue, act_backtrack,
    slot_num, max_to_len, fold_rec_max in *;
  repeat match goal with
  | |- context [?a =? ?b] => destruct (Z.eqb_spec a b)
  | |- context [?a <? ?b] => destruct (Z.ltb_spec a b)
  | |- context [?a <=? ?b] => destruct (Z.leb_spec a b)
  end;
  simpl; try rep_lia; try discriminate; try (intro; discriminate).

(* Reduces fst and snd of the tuple forward_call returns, in the goal and
   in the hypotheses that mention them (not in Delta). *)
Ltac simpl_pairs :=
  cbn [fst snd];
  repeat match goal with
  | H : context [fst (_, _)] |- _ => cbn [fst snd] in H
  | H : context [snd (_, _)] |- _ => cbn [fst snd] in H
  end.

(* Names L the length fact of the array that ends the struct whose
   value_fits hypothesis entailer! left. *)
Ltac array_length L :=
  match goal with H : value_fits _ _ |- _ =>
    simplify_value_fits in H;
    repeat match type of H with _ /\ _ => destruct H as [_ H] end;
    rewrite value_fits_eq in H; destruct H as [L _];
    unfold unfold_reptype in L; simpl in L
  end.

(* Rewrites the step_result in the goal to v, proved by solve_rules. *)
Ltac step_is v :=
  match goal with
  | |- context [step_result ?d ?x] =>
      replace (step_result d x) with v by solve_rules
  end.

Lemma body_vu_char_len : semax_body Vprog Gprog f_vu_char_len vu_char_len_spec.
Proof.
  start_function.
  forward_call (shp, p, c).
  Intros r.
  forward.
  forward.
  (* CLAMP-BEGIN *)
  forward_if.
  { forward. Exists lo. entailer!. }
  forward_if.
  { forward. Exists hi. entailer!. }
  (* CLAMP-END *)
  forward.
  Exists r.
  entailer!.
  all: try rep_lia.
  all: unproved.
Qed.

Lemma body_vu_callout_step :
  semax_body Vprog Gprog f_vu_callout_step vu_callout_step_spec.
Proof.
  start_function.
  forward_if.
  { forward. Exists 0 slots.
    step_is err_invalid_argument.
    entailer!. }
  forward_if.
  { forward. Exists 0 slots.
    step_is err_invalid_argument.
    entailer!. }
  assert (V : dir_valid dir = true) by solve_rules.
  forward_call (sha, args, ud, subj, len, pos, num, slots).
  Intros vret. destruct vret as [r slots']. simpl_pairs.
  forward_if.
  { forward. Exists r slots'.
    step_is r.
    entailer!; rewrite V in *; discriminate. }
  forward_if.
  { forward. Exists r slots'.
    step_is act_backtrack.
    entailer!; rewrite V in *; discriminate. }
  forward_if. (* r == 0: forward_if substitutes 0 for r *)
  { forward. Exists callout_success slots'.
    step_is act_continue.
    entailer!; rewrite V in *; discriminate. }
  forward_if. (* r == 1: forward_if substitutes 1 for r *)
  { forward_if.
    { forward. Exists callout_fail slots'.
      step_is act_backtrack.
      entailer!; rewrite V in *; discriminate. }
    { forward. Exists callout_fail slots'.
      step_is act_continue.
      entailer!; rewrite V in *; discriminate. } }
  forward. Exists r slots'.
  step_is err_invalid_argument.
  entailer!; rewrite V in *; discriminate.
Qed.

Lemma body_vu_i_apply : semax_body Vprog Gprog f_vu_i_apply vu_i_apply_spec.
Proof.
  start_function.
  unfold rec_rep.
  forward.
  forward.
  forward_if (PROP ()
    LOCAL (temp _rec rec; temp _from (Vint (Int.repr from));
           temp _to_len (Vint (Int.repr to_len)))
    SEP (data_at shr t_rec
           (Vint (Int.repr (apply_calls calls)),
            (Vint (Int.repr recorded), froms)) rec)).
  { forward. replace (apply_calls calls) with (calls + 1) by solve_rules.
    entailer!. }
  { forward. replace (apply_calls calls) with calls by solve_rules.
    entailer!. }
  forward.
  forward_if.
  { forward. replace (apply_records to_len recorded) with false
      by solve_rules. entailer!. }
  forward_if.
  { forward. replace (apply_records to_len recorded) with false
      by solve_rules. entailer!. }
  forward_if.
  { forward. replace (apply_records to_len recorded) with false
      by solve_rules. entailer!. }
  forward_if.
  { forward. replace (apply_records to_len recorded) with false
      by solve_rules. entailer!. }
  assert_PROP (Zlength froms = fold_rec_max).
  { entailer!. array_length L. exact L. }
  forward.
  forward.
  forward.
  replace (apply_records to_len recorded) with true by solve_rules.
  entailer!.
Qed.

Lemma body_vu_fold_all : semax_body Vprog Gprog f_vu_fold_all vu_fold_all_spec.
Proof.
  function_pointers.
  start_function.
  make_func_ptr _vu_i_apply.
  forward_call (gv _vu_i_apply, shr, rec, calls, recorded, froms).
  Intros vret. destruct vret as [[[r calls'] recorded'] froms']. simpl_pairs.
  forward.
  Exists r calls' recorded' froms'.
  entailer!.
  apply func_ptr'_emp.
Qed.

Lemma body_vu_get_slot : semax_body Vprog Gprog f_vu_get_slot vu_get_slot_spec.
Proof.
  start_function.
  unfold args_rep.
  forward_if.
  { forward. replace (slot_ok k) with false by solve_rules. entailer!. }
  forward_if.
  { forward. replace (slot_ok k) with false by solve_rules. entailer!. }
  assert_PROP (Zlength slots = slot_num).
  { entailer!. array_length L. rewrite Zlength_map in L. exact L. }
  assert (0 <= k < Zlength slots) by (unfold slot_num in *; lia).
  forward.
  forward.
  forward.
  replace (slot_ok k) with true by solve_rules.
  entailer!.
Qed.

Lemma body_vu_set_slot : semax_body Vprog Gprog f_vu_set_slot vu_set_slot_spec.
Proof.
  start_function.
  unfold args_rep.
  forward_if.
  { forward. replace (slot_ok k) with false by solve_rules. entailer!. }
  forward_if.
  { forward. replace (slot_ok k) with false by solve_rules. entailer!. }
  assert_PROP (Zlength slots = slot_num).
  { entailer!. array_length L. rewrite Zlength_map in L. exact L. }
  assert (0 <= k < Zlength slots) by (unfold slot_num in *; lia).
  forward.
  forward.
  replace (slot_ok k) with true by solve_rules.
  rewrite upd_Znth_map.
  entailer!.
Qed.

(* ------------------------------------------------------------------
   The six bodies together *)

#[local] Existing Instance NullExtension.Espec.

(* Gprog extended to every function of the program: CompCert's runtime
   functions and builtins get VST's vacuous funspec (precondition
   False), which assumes nothing. *)
Definition Gfull : funspecs :=
  ltac:(let pr := eval unfold prog in prog in
        let x := old_with_library' pr Gprog in exact x).

(* Every function of vu.c meets its funspec in Gprog, and each body is
   checked against Gprog. This closes the loop that vu_fold_all relies
   on: the funspec of vu_i_apply it hands to the client is the one
   body_vu_i_apply proves. *)
Lemma vu_funcs :
  semax_func Vprog Gprog (Genv.globalenv prog) (prog_funct prog) Gfull.
Proof.
  match goal with |- semax_func ?V ?G ?g ?D ?G2 =>
    let Gp := fresh "Gprog" in
    pose (Gp := @abbreviate _ G); change (semax_func V Gp g D G2)
  end.
  prove_semax_prog_setup_globalenv.
  unfold prog, prog_funct, Gfull; simpl.
  semax_func_cons body_vu_char_len.
  semax_func_cons body_vu_callout_step.
  semax_func_cons body_vu_i_apply.
  semax_func_cons body_vu_fold_all.
  semax_func_cons body_vu_get_slot.
  semax_func_cons body_vu_set_slot.
Qed.

(* The axioms the proofs rest on: build.sh checks that the list holds
   only the logical axioms of Rocq's library and VST's own, and no
   assumption about the client. *)
Print Assumptions vu_funcs.
