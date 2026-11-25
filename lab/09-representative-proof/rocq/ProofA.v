(* Experiment #9, Rocq M2, lemma (a): compiler invariants (FRAGMENT.md 8).
   The code of [comp r pc eid push] has length [clen r]; [code_at code pc l]
   says that [l] sits in [code] at address [pc]; the layout lemmas give
   the instructions of each construct at their addresses, as the
   simulation (ProofSim.v) reads them. *)

From Stdlib Require Import List Arith Lia.
Import ListNotations.
From S Require Import Syntax Compile.

Lemma length_comp : forall r pc eid push, length (comp r pc eid push) = clen r.
Proof.
  induction r; intros; simpl.
  - reflexivity.
  - destruct l; reflexivity.
  - rewrite length_app, IHr1, IHr2. reflexivity.
  - rewrite length_app. simpl. rewrite IHr1, IHr2. lia.
  - destruct (clen r) eqn:E; [reflexivity|].
    destruct (nullable r); simpl; rewrite length_app, IHr; simpl; lia.
  - rewrite length_app, IHr. simpl. lia.
Qed.

Lemma comp_star0 : forall a pc eid push, clen a = 0 ->
  comp (Star a) pc eid push = [] /\ clen (Star a) = 0 /\ nchecks (Star a) = 0.
Proof. intros a pc eid push H. simpl. rewrite H. auto. Qed.

Lemma comp_star_null : forall a pc eid push, clen a <> 0 -> nullable a = true ->
  comp (Star a) pc eid push
    = IPush (pc + clen a + 4) :: IEmptyStart eid
        :: comp a (pc + 2) (S eid) true ++ [IEmptyEnd eid; IJump pc]
  /\ clen (Star a) = clen a + 4 /\ nchecks (Star a) = S (nchecks a).
Proof.
  intros a pc eid push H N. simpl. destruct (clen a); [congruence|].
  rewrite N. repeat split; lia.
Qed.

Lemma comp_star_nn : forall a pc eid push, clen a <> 0 -> nullable a = false ->
  comp (Star a) pc eid push
    = IPush (pc + clen a + 2) :: comp a (S pc) eid true ++ [IJump pc]
  /\ clen (Star a) = clen a + 2 /\ nchecks (Star a) = nchecks a.
Proof.
  intros a pc eid push H N. simpl. destruct (clen a); [congruence|].
  rewrite N. repeat split; lia.
Qed.

Section CodeAt.
Variable code : list instr.

Definition code_at (pc : nat) (l : list instr) : Prop :=
  forall i x, nth_error l i = Some x -> nth_error code (pc + i) = Some x.

Lemma code_at_cons : forall pc x l, code_at pc (x :: l) ->
  nth_error code pc = Some x /\ code_at (S pc) l.
Proof.
  unfold code_at; intros pc x l H; split.
  - rewrite <- (Nat.add_0_r pc). apply H. reflexivity.
  - intros i y Hi. replace (S pc + i) with (pc + S i) by lia. apply (H (S i)). exact Hi.
Qed.

Lemma code_at_app : forall pc l1 l2, code_at pc (l1 ++ l2) ->
  code_at pc l1 /\ code_at (pc + length l1) l2.
Proof.
  unfold code_at; intros pc l1 l2 H; split; intros i y Hi.
  - apply H. rewrite nth_error_app1; [exact Hi|]. apply nth_error_Some. congruence.
  - rewrite <- Nat.add_assoc. apply H. rewrite nth_error_app2 by lia.
    replace (length l1 + i - length l1) with i by lia. exact Hi.
Qed.

(* layouts *)
Lemma code_alt : forall a b pc eid push, code_at pc (comp (Alt a b) pc eid push) ->
  nth_error code pc = Some (IPush (pc + clen a + 2))
  /\ code_at (S pc) (comp a (S pc) eid true)
  /\ nth_error code (S pc + clen a) = Some (IJump (pc + clen a + clen b + 2))
  /\ code_at (pc + clen a + 2) (comp b (pc + clen a + 2) (eid + nchecks a) true).
Proof.
  intros a b pc eid push H. simpl in H.
  apply code_at_cons in H as [H1 H]. apply code_at_app in H as [H2 H].
  rewrite length_comp in H. apply code_at_cons in H as [H3 H4].
  repeat split; auto.
  replace (S (S pc + clen a)) with (pc + clen a + 2) in H4 by lia. exact H4.
Qed.

Lemma code_cat : forall a b pc eid push, code_at pc (comp (Cat a b) pc eid push) ->
  code_at pc (comp a pc eid push)
  /\ code_at (pc + clen a) (comp b (pc + clen a) (eid + nchecks a) push).
Proof.
  intros a b pc eid push H. simpl in H. apply code_at_app in H as [H1 H2].
  rewrite length_comp in H2. auto.
Qed.

Lemma code_group : forall n a pc eid push, code_at pc (comp (Group n a) pc eid push) ->
  nth_error code pc = Some (if push then IMemStartPush n else IMemStart n)
  /\ code_at (S pc) (comp a (S pc) eid push)
  /\ nth_error code (S pc + clen a) = Some (IMemEnd n).
Proof.
  intros n a pc eid push H. simpl in H.
  apply code_at_cons in H as [H1 H]. apply code_at_app in H as [H2 H].
  rewrite length_comp in H. apply code_at_cons in H as [H3 _]. auto.
Qed.

Lemma code_lit : forall x l pc eid push, code_at pc (comp (Lit (x :: l)) pc eid push) ->
  nth_error code pc = Some (IStr (x :: l)).
Proof. intros x l pc eid push H. apply code_at_cons in H as [H _]. exact H. Qed.

Lemma code_star_null : forall a L eid push, clen a <> 0 -> nullable a = true ->
  code_at L (comp (Star a) L eid push) ->
  nth_error code L = Some (IPush (L + clen a + 4))
  /\ nth_error code (S L) = Some (IEmptyStart eid)
  /\ code_at (S (S L)) (comp a (S (S L)) (S eid) true)
  /\ nth_error code (L + 2 + clen a) = Some (IEmptyEnd eid)
  /\ nth_error code (L + 3 + clen a) = Some (IJump L).
Proof.
  intros a L eid push C N H. destruct (comp_star_null a L eid push C N) as [E _].
  rewrite E in H. clear E.
  apply code_at_cons in H as [H1 H]. apply code_at_cons in H as [H2 H].
  apply code_at_app in H as [H3 H]. rewrite length_comp in H.
  apply code_at_cons in H as [H4 H]. apply code_at_cons in H as [H5 _].
  replace (L + 2) with (S (S L)) in H3 by lia.
  replace (L + 2 + clen a) with (S (S L) + clen a) by lia.
  replace (S (S L) + clen a) with (S (S L + clen a)) in H4 by lia.
  replace (L + 3 + clen a) with (S (S (S L) + clen a)) by lia.
  auto.
Qed.

Lemma code_star_nn : forall a L eid push, clen a <> 0 -> nullable a = false ->
  code_at L (comp (Star a) L eid push) ->
  nth_error code L = Some (IPush (L + clen a + 2))
  /\ code_at (S L) (comp a (S L) eid true)
  /\ nth_error code (L + 1 + clen a) = Some (IJump L).
Proof.
  intros a L eid push C N H. destruct (comp_star_nn a L eid push C N) as [E _].
  rewrite E in H. clear E.
  apply code_at_cons in H as [H1 H].
  apply code_at_app in H as [H2 H]. rewrite length_comp in H.
  apply code_at_cons in H as [H3 _].
  replace (L + 1 + clen a) with (S L + clen a) by lia.
  auto.
Qed.

End CodeAt.

(* the whole program: the pattern's code at 0, then OP_END *)
Lemma code_compile : forall r,
  code_at (compile r) 0 (comp r 0 0 false)
  /\ nth_error (compile r) (clen r) = Some IEnd.
Proof.
  intros r. unfold compile. split.
  - intros i x H. simpl. rewrite nth_error_app1; [exact H|].
    apply nth_error_Some. congruence.
  - rewrite nth_error_app2; rewrite length_comp; [|lia].
    rewrite Nat.sub_diag. reflexivity.
Qed.
