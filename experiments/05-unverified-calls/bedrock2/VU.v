(* VU.v: the Bedrock2 prototype of experiment #5 (run G). *)
From Stdlib Require Import ZArith Lia.
Require Import bedrock2.NotationsCustomEntry.
Import Syntax BinInt String List.ListNotations.
Local Open Scope string_scope. Local Open Scope Z_scope. Local Open Scope list_scope.

Definition b2_vu_char_len := func! (f, p, st) ~> r {
  io! r = vu_call_enc_len(f, p);
  mn = load4(st);
  if !(mn < $2147483648) { mn = mn - $4294967296 };
  mx = load4(st + $4);
  if !(mx < $2147483648) { mx = mx - $4294967296 }
  (* CLAMP-BEGIN *)
  ; if (r .< mn) { r = mn } else { if (mx .< r) { r = mx } }
  (* CLAMP-END *)
}.

Definition b2_vu_callout_step := func! (dir, f, a, ud) ~> r {
  if (dir == $0) {
    io! r = vu_call_callout(f, a, ud);
    if !(r .< $0) { if ($1 .< r) { r = $0 - $30 } }
  } else { if (dir == $1) {
    io! r = vu_call_callout(f, a, ud);
    if !(r .< $0) { if ($1 .< r) { r = $0 - $30 } else { r = $0 } }
  } else { if (dir == $2) {
    io! r = vu_call_callout(f, a, ud);
    if !(r .< $0) { r = $1 }
  } else {
    r = $0 - $30
  } } }
}.

Definition b2_vu_i_apply := func! (from, to, tl, a) ~> r {
  c = load4(a);
  if !(c == $2147483647) { store4(a, c + $1) };
  n = load4(a + $4);
  if ($0 .< tl) { if (tl .< $4) { if (n < $8) {
    if (n == $0) { store4(a + $8, from) } else {
    if (n == $1) { store4(a + $12, from) } else {
    if (n == $2) { store4(a + $16, from) } else {
    if (n == $3) { store4(a + $20, from) } else {
    if (n == $4) { store4(a + $24, from) } else {
    if (n == $5) { store4(a + $28, from) } else {
    if (n == $6) { store4(a + $32, from) } else {
      store4(a + $36, from) } } } } } } };
    store4(a + $4, n + $1)
  } } };
  r = $0
}.

Definition b2_vu_fold_all := func! (g, rc) ~> r {
  io! r = vu_call_apply_all(g, rc)
}.

Definition b2_vu_get_slot := func! (a, k, v) ~> r {
  r = $0;
  if (k .< $0) { r = $0 - $30 } else { if !(k .< $5) { r = $0 - $30 } else {
    if (k == $0) { store(v, load(a + $24)) } else {
    if (k == $1) { store(v, load(a + $32)) } else {
    if (k == $2) { store(v, load(a + $40)) } else {
    if (k == $3) { store(v, load(a + $48)) } else {
      store(v, load(a + $56)) } } } } } }
}.

Definition b2_vu_set_slot := func! (a, k, v) ~> r {
  r = $0;
  if (k .< $0) { r = $0 - $30 } else { if !(k .< $5) { r = $0 - $30 } else {
    if (k == $0) { store(a + $24, v) } else {
    if (k == $1) { store(a + $32, v) } else {
    if (k == $2) { store(a + $40, v) } else {
    if (k == $3) { store(a + $48, v) } else {
      store(a + $56, v) } } } } } }
}.

Definition b2_vu_get_subject_byte := func! (a, i) ~> r {
  s = load(a);
  len = load4(a + $8);
  if !(len < $2147483648) { len = len - $4294967296 };
  if (i .< $0) { r = $0 - $30 } else {
    (* READ-BEGIN *)
    if (i .< len) {
    (* READ-END *)
      r = load1(s + i)
    (* READ-BEGIN *)
    } else { r = $0 - $30 }
    (* READ-END *)
  }
}.

Definition vu_funcs : list (String.string * Syntax.func) := [
  ("b2_vu_char_len", b2_vu_char_len);
  ("b2_vu_callout_step", b2_vu_callout_step);
  ("b2_vu_i_apply", b2_vu_i_apply);
  ("b2_vu_fold_all", b2_vu_fold_all);
  ("b2_vu_get_slot", b2_vu_get_slot);
  ("b2_vu_set_slot", b2_vu_set_slot);
  ("b2_vu_get_subject_byte", b2_vu_get_subject_byte)].

Require Import bedrock2.WeakestPrecondition.
Require Import coqutil.Word.Bitwidth coqutil.Map.Interface bedrock2.Map.SeparationLogic.
Require Import bedrock2.Semantics bedrock2.BasicC64Semantics.
Require bedrock2.WeakestPreconditionProperties.
From coqutil.Tactics Require Import letexists eabstract rdelta.
Require Import bedrock2.ProgramLogic bedrock2.Scalars bedrock2.Array.
Require Import Stdlib.Lists.List. Import ListNotations.
Require Import coqutil.Byte.

Definition vu_env : Semantics.env := map.of_list vu_funcs.

(* Word helpers. *)
Notation "'w' z" := (bits.of_Z 64 z) (at level 10, z at level 9, only parsing).
(* The int a 32-bit field holds (its low 32 bits, two's complement). *)
Definition i32 (x : word) : Z :=
  let u := Zmod.unsigned x mod 2^32 in if u <? 2^31 then u else u - 2^32.

(* Memory layout of proto.h's structs (LP64). *)
Definition args_at (a s len pos num : word) (pad : list Byte.byte) (xs : list word)
  : mem -> Prop :=
  seps [scalar a s; scalar32 (Zmod.add a (w 8)) len;
        scalar32 (Zmod.add a (w 12)) pos; scalar32 (Zmod.add a (w 16)) num;
        array ptsto (w 1) (Zmod.add a (w 20)) pad;
        scalar (Zmod.add a (w 24)) (List.nth 0 xs (w 0));
        scalar (Zmod.add a (w 32)) (List.nth 1 xs (w 0));
        scalar (Zmod.add a (w 40)) (List.nth 2 xs (w 0));
        scalar (Zmod.add a (w 48)) (List.nth 3 xs (w 0));
        scalar (Zmod.add a (w 56)) (List.nth 4 xs (w 0))].

Definition subject_at (s : word) (bs : list Byte.byte) : mem -> Prop :=
  array ptsto (w 1) s bs.

Definition rec_at (a c n : word) (fr : list word) : mem -> Prop :=
  seps [scalar32 a c; scalar32 (Zmod.add a (w 4)) n;
        scalar32 (Zmod.add a (w 8)) (List.nth 0 fr (w 0));
        scalar32 (Zmod.add a (w 12)) (List.nth 1 fr (w 0));
        scalar32 (Zmod.add a (w 16)) (List.nth 2 fr (w 0));
        scalar32 (Zmod.add a (w 20)) (List.nth 3 fr (w 0));
        scalar32 (Zmod.add a (w 24)) (List.nth 4 fr (w 0));
        scalar32 (Zmod.add a (w 28)) (List.nth 5 fr (w 0));
        scalar32 (Zmod.add a (w 32)) (List.nth 6 fr (w 0));
        scalar32 (Zmod.add a (w 36)) (List.nth 7 fr (w 0))].

Definition rec_wf (n : word) (fr : list word) : Prop :=
  0 <= i32 n <= 8 /\ length fr = 8%nat.

Fixpoint upd (k : nat) (x : word) (l : list word) : list word :=
  match k, l with
  | O, _ :: l' => x :: l'
  | S k', y :: l' => y :: upd k' x l'
  | _, [] => []
  end.

(* The branch rules of vu_callout_step (caller/reference.c). *)
Definition callout_rule (dir r : Z) : Z :=
  if dir =? 0 then (if r <? 0 then r else if 1 <? r then -30 else r)
  else if dir =? 1 then (if r <? 0 then r else if 1 <? r then -30 else 0)
  else (if r <? 0 then r else 1).

Section VU.
  Context {ext_spec : ExtSpec}.
  (* The external world's specification is well formed (bedrock2's
     ext_spec.ok: the lent memory is determined by the call, and the
     postcondition can be weakened and intersected); bedrock2's program
     logic needs it to relate a function's proof to its execution. *)
  Context {ext_spec_ok : ext_spec.ok ext_spec}.

  (* Contract of the encoding callee, through the shim vu_call_enc_len:
     lent the byte at p, gives it back unchanged, returns an int. *)
  Context (enc_len_contract : forall t mGive f p b post,
    ptsto p b mGive ->
    (forall mR r, ptsto p b mR -> -2^31 <= Zmod.signed r < 2^31 -> post mR [r]) ->
    ext_spec t mGive "vu_call_enc_len" [f; p] post).

  (* Contract of the callout callee, through the shim vu_call_callout:
     lent the args record and the subject (whole: no read-only share);
     gives back the record with subject, subject_len, pos and num
     unchanged (any slots, any padding) and the subject with the same
     bytes; returns an int. *)
  Context (callout_contract : forall t mGive f a ud s len pos num pad xs bs post,
    sep (args_at a s len pos num pad xs) (subject_at s bs) mGive ->
    (forall mR r,
       (exists pad' xs', length pad' = 4%nat /\ length xs' = 5%nat /\
          sep (args_at a s len pos num pad' xs') (subject_at s bs) mR) ->
       -2^31 <= Zmod.signed r < 2^31 -> post mR [r]) ->
    ext_spec t mGive "vu_call_callout" [f; a; ud] post).

  (* Contract of the client's apply_all, through the shim
     vu_call_apply_all, which hands the client b2_vu_i_apply (as
     vu_i_apply, re-entrancy shape (a)): the client reaches the record
     only through that function, so it preserves every property of the
     record that every call of b2_vu_i_apply preserves. As Isabelle-LLVM's
     respects_i_apply; a hypothesis of b2_vu_fold_all's theorem. *)
  Definition respects_i_apply (g rc : word) : Prop :=
    forall P : word -> word -> list word -> Prop,
      (forall t m from to tl c n fr R,
         P c n fr -> sep (rec_at rc c n fr) R m ->
         -2^31 <= Zmod.signed tl < 2^31 ->
         WeakestPrecondition.call vu_env "b2_vu_i_apply" t m [from; to; tl; rc]
           (fun _ m' _ => exists c' n' fr', sep (rec_at rc c' n' fr') R m' /\ P c' n' fr')) ->
      forall t mGive c n fr post,
        rec_at rc c n fr mGive -> P c n fr ->
        (forall mR r, (exists c' n' fr', rec_at rc c' n' fr' mR /\ P c' n' fr') ->
           -2^31 <= Zmod.signed r < 2^31 -> post mR [r]) ->
        ext_spec t mGive "vu_call_apply_all" [g; rc] post.

  (* Proof tools. *)
  Lemma interact_sep fs binds action arges t m l post args (P R : mem -> Prop)
    (Hargs : dexprs m l arges args) (Hm : sep P R m)
    (Hext : forall mGive mKeep, P mGive -> R mKeep ->
       ext_spec t mGive action args (fun mR rets =>
         exists l0, map.putmany_of_list_zip binds rets l = Some l0 /\
         forall m', map.split m' mKeep mR ->
           post (cons ((mGive, action, args), (mR, rets)) t) m' l0))
    : WeakestPrecondition.cmd fs (cmd.interact binds action arges) t m l post.
  Proof.
    destruct Hm as (mP & mK & Hs & HP & HR).
    exists args; split; [exact Hargs|]. exists mK, mP.
    split; [apply Properties.map.split_comm; exact Hs|]. eapply Hext; eassumption.
  Qed.

  Lemma sep_of_split (P R : mem -> Prop) m mK mR :
    map.split m mK mR -> P mR -> R mK -> sep P R m.
  Proof. intros. exists mR, mK. split; [apply Properties.map.split_comm|split]; assumption. Qed.

  Lemma urange (x : word) : 0 <= Zmod.unsigned x < 2^64.
  Proof. pose proof (Zmod.unsigned_range x). cbn in *. lia. Qed.

  Lemma signed64 (x : word) :
    Zmod.signed x = if Zmod.unsigned x <? 2^63 then Zmod.unsigned x else Zmod.unsigned x - 2^64.
  Proof.
    pose proof (urange x). cbv [Zmod.signed]. rewrite Z.double_spec.
    rewrite (Z.abs_eq (Zmod.unsigned x)) by lia. change (Z.abs (2^64)) with (2^64).
    destruct (Z.ltb_spec (2 * Zmod.unsigned x) (2^64)), (Z.ltb_spec (Zmod.unsigned x) (2^63)); lia.
  Qed.

  Lemma unsigned_trunc4 (x : word) :
    Zmod.unsigned (truncate_word access_size.four x) = Zmod.unsigned x mod 2^32.
  Proof.
    cbv [truncate_word truncate_Z bytes_per]. rewrite bits.unsigned_of_Z.
    change (Z.of_nat 4 * 8) with 32. pose proof (urange x).
    rewrite Z.land_ones by lia. apply Z.mod_small.
    pose proof (Z.mod_pos_bound (Zmod.unsigned x) (2^32) ltac:(lia)). lia.
  Qed.

  Lemma unsigned_if (c : bool) (x y : word) :
    Zmod.unsigned (if c then x else y) = if c then Zmod.unsigned x else Zmod.unsigned y.
  Proof. destruct c; reflexivity. Qed.

  Lemma if10_true (c : bool) : (if c then 1 else 0) <> 0 -> c = true.
  Proof. destruct c; congruence. Qed.

  Lemma if10_false (c : bool) : (if c then 1 else 0) = 0 -> c = false.
  Proof. destruct c; congruence. Qed.

  Lemma signed_if (c : bool) (x y : word) :
    Zmod.signed (if c then x else y) = if c then Zmod.signed x else Zmod.signed y.
  Proof. destruct c; reflexivity. Qed.

  Ltac is_ground t := lazymatch t with
    | Z0 => idtac | Zpos ?p => is_ground_pos p | Zneg ?p => is_ground_pos p
    | Z.pow ?a ?b => is_ground a; is_ground b | Z.mul ?a ?b => is_ground a; is_ground b
    | Z.add ?a ?b => is_ground a; is_ground b | Z.sub ?a ?b => is_ground a; is_ground b
    | Z.opp ?a => is_ground a | Z.modulo ?a ?b => is_ground a; is_ground b
    end
  with is_ground_pos p := lazymatch p with xH => idtac | xO ?q => is_ground_pos q | xI ?q => is_ground_pos q end.

  (* Closes a goal of linear integer arithmetic over words: the facts are
     reverted into the goal, words become integers, and each remaining
     "mod" becomes a variable with its defining equation. *)
  Ltac wsolve :=
    repeat match goal with x := _ |- _ => subst x end;
    repeat match goal with
      | H : ?T |- _ =>
          lazymatch type of T with
          | Prop => lazymatch T with
                    | context[ext_spec] => clear H
                    | context[Zmod.unsigned _] => revert H
                    | context[Zmod.signed _] => revert H
                    | context[i32 _] => revert H
                    | context[length _] => revert H
                    | _ => clear H
                    end
          end
      end;
    cbv [i32 Zmod.eqb Semantics.lts Semantics.ltu];
    repeat progress (rewrite ?signed64, ?unsigned_if, ?unsigned_trunc4, ?Zmod.unsigned_sub,
      ?Zmod.unsigned_add, ?Zmod.unsigned_of_Z, ?bits.unsigned_of_Z, ?Zmod.unsigned_1,
      ?Zmod.unsigned_0);
    repeat match goal with
      | |- context[Zmod.unsigned ?x] =>
          assert_fails (match x with context[?y] => is_var y end);
          let c := eval vm_compute in (Zmod.unsigned x) in is_ground c;
          change (Zmod.unsigned x) with c
      end;
    repeat match goal with
      | |- context[Zmod.unsigned ?x mod 2 ^ 32] => is_var x;
          let u := fresh "u" in
          pose proof (Z.mod_pos_bound (Zmod.unsigned x) (2 ^ 32) ltac:(lia));
          generalize dependent (Zmod.unsigned x mod 2 ^ 32); intros u
      end;
    repeat match goal with
      | |- context[Zmod.unsigned ?x] => is_var x;
          let z := fresh "z" in
          pose proof (urange x); generalize dependent x; intro x;
          generalize (Zmod.unsigned x) as z; clear x; intros z
      end;
    repeat match goal with
      | |- context[?a mod ?b] => is_ground a; is_ground b;
          let c := eval vm_compute in (a mod b) in change (a mod b) with c
      | |- context[2 ^ ?n] => is_ground n;
          let c := eval vm_compute in (2 ^ n) in change (2 ^ n) with c
      end;
    repeat match goal with
      | |- context[?e mod ?m] => is_ground m;
          pose proof (Z.div_mod e m ltac:(lia)); pose proof (Z.mod_pos_bound e m ltac:(lia));
          generalize dependent (e mod m); generalize dependent (e / m);
          let q := fresh "q" in let y := fresh "y" in intros q y
      end;
    intros;
    repeat match goal with
      | H : (if ?c then 1 else 0) <> 0 |- _ => apply if10_true in H
      | H : (if ?c then 1 else 0) = 0 |- _ => apply if10_false in H
      end;
    repeat match goal with
      | H : (?a <? ?b) = true |- _ => apply Z.ltb_lt in H
      | H : (?a <? ?b) = false |- _ => apply Z.ltb_ge in H
      | H : (?a =? ?b) = true |- _ => apply Z.eqb_eq in H
      | H : (?a =? ?b) = false |- _ => apply Z.eqb_neq in H
      end;
    repeat match goal with
      | H: context[if ?a <? ?b then _ else _] |- _ => destruct (Z.ltb_spec a b)
      | |- context[if ?a <? ?b then _ else _] => destruct (Z.ltb_spec a b)
      | H: context[if ?a =? ?b then _ else _] |- _ => destruct (Z.eqb_spec a b)
      | |- context[if ?a =? ?b then _ else _] => destruct (Z.eqb_spec a b)
      | H: context[if ?c then _ else _] |- _ => destruct c eqn:?
      | |- context[if ?c then _ else _] => destruct c eqn:?
      end;
    lia.

  Ltac split_cond :=
    match goal with
    | |- WeakestPrecondition.cmd _ ?c _ _ _ _ =>
        let c := eval hnf in c in
        lazymatch c with
        | cmd.cond _ _ _ =>
            unfold1_cmd_goal; cbv beta match delta [cmd_body];
            letexists; split; [solve [repeat straightline]|split; intros]
        end
    end.
  Ltac step := straightline || split_cond.
  Ltac unfold_preds := cbv [args_at subject_at rec_at] in *; cbn [seps] in *.

  Instance spec_of_char_len : spec_of "b2_vu_char_len" := fun fs =>
    forall t m f p b st mn mx R,
      sep (ptsto p b) (sep (scalar32 st mn) (sep (scalar32 (Zmod.add st (w 4)) mx) R)) m ->
      1 <= i32 mn <= i32 mx ->
      WeakestPrecondition.call fs "b2_vu_char_len" t m [f; p; st]
        (fun t' m' rets => exists r, rets = [r] /\
           sep (ptsto p b) (sep (scalar32 st mn) (sep (scalar32 (Zmod.add st (w 4)) mx) R)) m' /\
           i32 mn <= Zmod.signed r <= i32 mx).

  Lemma b2_vu_char_len_ok : program_logic_goal_for_function! b2_vu_char_len.
  Proof.
    repeat straightline.
    eapply interact_sep with (args := [f; p]); [repeat straightline|exact H|].
    intros mG mK HG HK. eapply enc_len_contract; [exact HG|].
    intros mR r HR Hr. eexists; split; [reflexivity|].
    intros m' Hm'. pose proof (sep_of_split _ _ _ _ _ Hm' HR HK) as Hm.
    clear Hm' HR HK HG H.
    repeat step.
    all: split; [ecancel_assumption|].
    all: wsolve.
  Qed.

  Lemma hd_skipn (n : nat) (l : list Byte.byte) d : hd d (skipn n l) = List.nth n l d.
  Proof. revert l; induction n; destruct l; cbn; auto. Qed.

  (* Reading byte i of the subject, for 0 <= i < its length. *)
  Lemma load_subject_byte (s i : word) bs R m :
    sep (subject_at s bs) R m -> 0 <= Zmod.signed i < Z.of_nat (length bs) ->
    Memory.load access_size.one m (Zmod.add s i) =
      Some (w (byte.unsigned (List.nth (Z.to_nat (Zmod.signed i)) bs Byte.x00))).
  Proof.
    intros Hm Hi. cbv [subject_at] in Hm.
    seprewrite_in (array_index_nat_inbounds ptsto (w 1) (default := Byte.x00) bs s
                     (Z.to_nat (Zmod.signed i)) ltac:(lia)) Hm.
    rewrite hd_skipn in Hm.
    replace (Zmod.add s (w (Zmod.unsigned (w 1) * Z.of_nat (Z.to_nat (Zmod.signed i)))))
      with (Zmod.add s i) in Hm.
    { eapply Scalars.load_one_of_sep. ecancel_assumption. }
    f_equal. rewrite bits.unsigned_of_Z. change (1 mod 2 ^ 64) with 1.
    rewrite Z.mul_1_l, Z2Nat.id by lia. symmetry; apply Zmod.of_Z_signed.
  Qed.

  Ltac finish_sep := unfold_preds; cbn [upd List.nth] in *; ecancel_assumption.

  (* Re-entrancy (b): the slot accessors. *)
  Instance spec_of_get_slot : spec_of "b2_vu_get_slot" := fun fs =>
    forall t m a k v old s len pos num pad xs R,
      sep (args_at a s len pos num pad xs) (sep (scalar v old) R) m ->
      -2^31 <= Zmod.signed k < 2^31 ->
      WeakestPrecondition.call fs "b2_vu_get_slot" t m [a; k; v]
        (fun t' m' rets => exists r, rets = [r] /\ t' = t /\
           ((0 <= Zmod.signed k < 5 /\ Zmod.unsigned r = 0 /\
             sep (args_at a s len pos num pad xs)
               (sep (scalar v (List.nth (Z.to_nat (Zmod.signed k)) xs (w 0))) R) m') \/
            (~ (0 <= Zmod.signed k < 5) /\ Zmod.signed r = -30 /\ m' = m))).

  Ltac fix_index k :=
    first [ replace (Z.to_nat (Zmod.signed k)) with 0%nat by wsolve
          | replace (Z.to_nat (Zmod.signed k)) with 1%nat by wsolve
          | replace (Z.to_nat (Zmod.signed k)) with 2%nat by wsolve
          | replace (Z.to_nat (Zmod.signed k)) with 3%nat by wsolve
          | replace (Z.to_nat (Zmod.signed k)) with 4%nat by wsolve ].

  Lemma b2_vu_get_slot_ok : program_logic_goal_for_function! b2_vu_get_slot.
  Proof.
    repeat straightline. unfold_preds. repeat step.
    all: first
      [ right; split; [wsolve|]; split; [wsolve|]; reflexivity
      | left; split; [wsolve|]; split; [wsolve|]; fix_index k; finish_sep ].
  Qed.

  Instance spec_of_set_slot : spec_of "b2_vu_set_slot" := fun fs =>
    forall t m a k v s len pos num pad xs R,
      sep (args_at a s len pos num pad xs) R m -> length xs = 5%nat ->
      -2^31 <= Zmod.signed k < 2^31 ->
      WeakestPrecondition.call fs "b2_vu_set_slot" t m [a; k; v]
        (fun t' m' rets => exists r, rets = [r] /\ t' = t /\
           ((0 <= Zmod.signed k < 5 /\ Zmod.unsigned r = 0 /\
             sep (args_at a s len pos num pad (upd (Z.to_nat (Zmod.signed k)) v xs)) R m') \/
            (~ (0 <= Zmod.signed k < 5) /\ Zmod.signed r = -30 /\ m' = m))).

  Lemma b2_vu_set_slot_ok : program_logic_goal_for_function! b2_vu_set_slot.
  Proof.
    repeat straightline.
    destruct xs as [|x0 [|x1 [|x2 [|x3 [|x4 [|]]]]]]; try discriminate.
    unfold_preds. cbn [List.nth] in *. repeat step.
    all: first
      [ right; split; [wsolve|]; split; [wsolve|]; reflexivity
      | left; split; [wsolve|]; split; [wsolve|]; fix_index k; finish_sep ].
  Qed.

  (* Re-entrancy (b) with shared read access: the read accessor. *)
  Instance spec_of_get_subject_byte : spec_of "b2_vu_get_subject_byte" := fun fs =>
    forall t m a i s len pos num pad xs bs R,
      sep (args_at a s len pos num pad xs) (sep (subject_at s bs) R) m ->
      i32 len = Z.of_nat (length bs) ->
      -2^31 <= Zmod.signed i < 2^31 ->
      WeakestPrecondition.call fs "b2_vu_get_subject_byte" t m [a; i]
        (fun t' m' rets => exists r, rets = [r] /\ t' = t /\ m' = m /\
           ((0 <= Zmod.signed i < i32 len /\
             r = w (byte.unsigned (List.nth (Z.to_nat (Zmod.signed i)) bs Byte.x00))) \/
            (~ (0 <= Zmod.signed i < i32 len) /\ Zmod.signed r = -30))).

  Lemma b2_vu_get_subject_byte_ok : program_logic_goal_for_function! b2_vu_get_subject_byte.
  Proof.
    repeat straightline. unfold_preds. repeat step.
    all: try (match goal with |- exists v, dexpr _ _ _ v /\ _ => idtac end;
              eexists; split;
              [ repeat straightline; eexists; split;
                [ eapply load_subject_byte; [cbv [subject_at]; ecancel_assumption | wsolve]
                | reflexivity ]
              | ]).
    all: repeat step.
    all: first
      [ right; split; [wsolve|]; wsolve
      | left; split; [wsolve|]; reflexivity ].
  Qed.

  (* The callout: callee contract, branch rules. *)
  Instance spec_of_callout_step : spec_of "b2_vu_callout_step" := fun fs =>
    forall t m dir f a ud s len pos num pad xs bs R,
      sep (args_at a s len pos num pad xs) (sep (subject_at s bs) R) m ->
      -2^31 <= Zmod.signed dir < 2^31 ->
      WeakestPrecondition.call fs "b2_vu_callout_step" t m [dir; f; a; ud]
        (fun t' m' rets => exists res, rets = [res] /\
           ((0 <= Zmod.signed dir <= 2 /\
             exists mG mR r, t' = ((mG, "vu_call_callout", [f; a; ud]), (mR, [r])) :: t /\
               -2^31 <= Zmod.signed r < 2^31 /\
               Zmod.signed res = callout_rule (Zmod.signed dir) (Zmod.signed r) /\
               exists pad' xs', length pad' = 4%nat /\ length xs' = 5%nat /\
                 sep (args_at a s len pos num pad' xs') (sep (subject_at s bs) R) m') \/
            (~ (0 <= Zmod.signed dir <= 2) /\ t' = t /\ m' = m /\ Zmod.signed res = -30))).

  Ltac do_callout :=
    match goal with
    | H : sep (args_at ?a ?s ?len ?pos ?num ?pad ?xs) (sep (subject_at ?s ?bs) ?R) ?m
      |- WeakestPrecondition.cmd _ (cmd.interact _ _ _) _ ?m _ _ =>
        eapply interact_sep with
          (P := sep (args_at a s len pos num pad xs) (subject_at s bs)) (R := R);
        [repeat straightline | ecancel_assumption |];
        let mG := fresh "mG" in let mK := fresh "mK" in
        let HG := fresh "HG" in let HK := fresh "HK" in
        intros mG mK HG HK; eapply callout_contract; [exact HG|];
        let mR := fresh "mR" in let r := fresh "r" in
        let pad' := fresh "pad'" in let xs' := fresh "xs'" in
        let Hp := fresh "Hp" in let Hx := fresh "Hx" in let HR := fresh "HR" in
        let Hr := fresh "Hr" in
        intros mR r (pad' & xs' & Hp & Hx & HR) Hr;
        eexists; split; [reflexivity|];
        let m' := fresh "m'" in let Hm' := fresh "Hm'" in
        intros m' Hm';
        let Hm := fresh "Hm" in
        pose proof (sep_of_split _ _ _ _ _ Hm' HR HK) as Hm; clear Hm' HG HK HR H
    end.

  Lemma b2_vu_callout_step_ok : program_logic_goal_for_function! b2_vu_callout_step.
  Proof.
    repeat straightline.
    repeat (step || do_callout).
    all: first
      [ right; split; [wsolve|]; split; [reflexivity|]; split; [reflexivity|]; wsolve
      | left; split; [wsolve|]; do 3 eexists; split; [reflexivity|];
        split; [wsolve|]; split; [cbv [callout_rule]; wsolve|];
        do 2 eexists; split; [eassumption|]; split; [eassumption|];
        ecancel_assumption ].
  Qed.

  (* Re-entrancy (a): the function handed to the client. *)
  Instance spec_of_i_apply : spec_of "b2_vu_i_apply" := fun fs =>
    forall t m from to tl a c n fr R,
      sep (rec_at a c n fr) R m -> length fr = 8%nat ->
      -2^31 <= Zmod.signed tl < 2^31 ->
      WeakestPrecondition.call fs "b2_vu_i_apply" t m [from; to; tl; a]
        (fun t' m' rets => exists r, rets = [r] /\ Zmod.unsigned r = 0 /\ t' = t /\
           exists c' n' fr', sep (rec_at a c' n' fr') R m' /\ length fr' = 8%nat /\
             i32 c' = (if i32 c =? 2^31 - 1 then i32 c else i32 c + 1) /\
             ((1 <= Zmod.signed tl <= 3 /\ 0 <= i32 n < 8 /\ i32 n' = i32 n + 1 /\
               fr' = upd (Z.to_nat (i32 n)) from fr) \/
              (~ (1 <= Zmod.signed tl <= 3 /\ 0 <= i32 n < 8) /\ n' = n /\ fr' = fr))).

  Ltac fix_nat e :=
    first [ replace e with 0%nat by wsolve | replace e with 1%nat by wsolve
          | replace e with 2%nat by wsolve | replace e with 3%nat by wsolve
          | replace e with 4%nat by wsolve | replace e with 5%nat by wsolve
          | replace e with 6%nat by wsolve | replace e with 7%nat by wsolve ].

  Lemma b2_vu_i_apply_ok : program_logic_goal_for_function! b2_vu_i_apply.
  Proof.
    repeat straightline.
    destruct fr as [|f0 [|f1 [|f2 [|f3 [|f4 [|f5 [|f6 [|f7 [|]]]]]]]]]; try discriminate.
    unfold_preds. cbn [List.nth] in *. repeat step.
    all: split; [wsolve|]; split; [reflexivity|].
    all: do 2 eexists.
    all: first
      [ match goal with
        | H : Zmod.unsigned ?v <> 0 |- _ =>
            let body := rdelta v in
            lazymatch body with
            | if Zmod.eqb _ (Zmod.of_Z _ ?K) then _ else _ =>
                let small := eval vm_compute in (K <? 8) in
                constr_eq small true;
                let k := eval vm_compute in (Z.to_nat K) in
                exists (upd k from [f0; f1; f2; f3; f4; f5; f6; f7]); split; [finish_sep|]
            end
        end
      | exists [f0; f1; f2; f3; f4; f5; f6; f7]; split; [finish_sep|]
      | exists (upd 7 from [f0; f1; f2; f3; f4; f5; f6; f7]); split; [finish_sep|] ].
    all: split; [reflexivity|]; split; [wsolve|].
    all: first
      [ right; split; [wsolve|]; split; reflexivity
      | left; split; [wsolve|]; split; [wsolve|]; split; [wsolve|];
        match goal with |- _ = upd ?e _ _ => fix_nat e end; reflexivity ].
  Qed.

  (* Every call of b2_vu_i_apply keeps the record well formed: a
     consequence of b2_vu_i_apply_ok. *)
  Lemma i_apply_rec_wf : forall rc t m from to tl c n fr R,
    rec_wf n fr -> sep (rec_at rc c n fr) R m ->
    -2^31 <= Zmod.signed tl < 2^31 ->
    WeakestPrecondition.call vu_env "b2_vu_i_apply" t m [from; to; tl; rc]
      (fun _ m' _ => exists c' n' fr', sep (rec_at rc c' n' fr') R m' /\ rec_wf n' fr').
  Proof.
    intros * [Hn Hl] Hm Htl.
    eapply WeakestPreconditionProperties.Proper_call;
      [| eapply (b2_vu_i_apply_ok vu_env eq_refl); eassumption].
    intros t' m' rets (r & _ & _ & _ & c' & n' & fr' & Hm' & Hl' & _ & Hcase).
    exists c', n', fr'. split; [exact Hm'|]. split; [|exact Hl'].
    destruct Hcase as [(_ & Hn0 & Hn' & _) | (_ & -> & _)]; lia.
  Qed.

  Instance spec_of_fold_all : spec_of "b2_vu_fold_all" := fun fs =>
    forall t m g rc c n fr R,
      respects_i_apply g rc -> sep (rec_at rc c n fr) R m -> rec_wf n fr ->
      WeakestPrecondition.call fs "b2_vu_fold_all" t m [g; rc]
        (fun t' m' rets => exists r, rets = [r] /\ -2^31 <= Zmod.signed r < 2^31 /\
           exists c' n' fr', sep (rec_at rc c' n' fr') R m' /\ rec_wf n' fr').

  (* vu_fold_all's theorem rests on the client contract alone: the
     record invariant it needs is derived from respects_i_apply and
     b2_vu_i_apply_ok (i_apply_rec_wf). *)
  Lemma b2_vu_fold_all_ok : program_logic_goal_for_function! b2_vu_fold_all.
  Proof.
    repeat straightline.
    eapply interact_sep with (args := [g; rc]) (P := rec_at rc c n fr) (R := R);
      [repeat straightline | exact H0 |].
    intros mG mK HG HK.
    eapply (H (fun c n fr => rec_wf n fr)); [| exact HG | exact H1 |].
    { intros. eapply i_apply_rec_wf; eassumption. }
    intros mR r (c' & n' & fr' & HR & Hwf) Hr.
    eexists; split; [reflexivity|]. intros m' Hm'.
    pose proof (sep_of_split _ _ _ _ _ Hm' HR HK) as Hm.
    repeat straightline.
    split; [lia|]. exists c', n', fr'. split; [ecancel_assumption | assumption].
  Qed.
End VU.
