(* Experiment #8 follow-up (issue #34), lemma plan (b): fuel monotonicity
   and determinism of mb, scan/cut, m (in both fuels f and g) and md,
   after experiment #9's ct_mono/ct_det
   (lab/09-representative-proof/rocq/ProofSem.v).
   Design: lab/08-discriminating-lemmas/LEMMAS.md, "Lemma plan". *)
From Stdlib Require Import List Arith Lia Bool.
Import ListNotations.
From S Require Import Absent Desugar.

Section Mono.
Variable s : list nat.

(* Each proof: rewrite each recursive call of the hypothesis at the
   larger fuel (by the induction hypothesis), then split on the remaining
   scrutinees. *)
Ltac mono_step H :=
  match type of H with
  | Some _ = Some _ => injection H as H
  | None = Some _ => discriminate H
  | context [match ?x with _ => _ end] => destruct x eqn:?
  end.

Lemma mb_mono : forall f f' ks i rr b, f <= f' -> mb s f ks i rr = Some b -> mb s f' ks i rr = Some b.
Proof.
  induction f as [|f IH]; intros f' ks i rr b Hle H; [discriminate|].
  destruct f' as [|f']; [lia|]. apply le_S_n in Hle.
  simpl in H |- *. unfold oor in *. cbv beta in *.
  repeat (first [ match type of H with
  | context [mb s f ?k ?j ?r] =>
      let E := fresh "E" in let v := fresh "v" in destruct (mb s f k j r) as [v|] eqn:E;
      [rewrite (IH f' k j r v Hle E)|]
  end
  | progress (cbv beta iota in H |- * )
  | mono_step H ]); subst; try congruence; auto.
Qed.

Lemma mb_det : forall f f' ks i rr b b', mb s f ks i rr = Some b -> mb s f' ks i rr = Some b' -> b = b'.
Proof.
  intros f f' ks i rr b b' H H'.
  apply (mb_mono f (max f f')) in H; [|lia]. apply (mb_mono f' (max f f')) in H'; [|lia]. congruence.
Qed.

Lemma scan_ext : forall (P Q : nat -> option bool) k p c,
  (forall q b, P q = Some b -> Q q = Some b) -> scan P k p = Some c -> scan Q k p = Some c.
Proof.
  induction k; intros p c HPQ H; simpl in *; auto.
  destruct (P p) as [[|]|] eqn:E.
  - rewrite (HPQ p true E). exact H.
  - rewrite (HPQ p false E). apply IHk; auto.
  - discriminate.
Qed.

Lemma cut_mono : forall g g' a i rr c, g <= g' -> cut s g a i rr = Some c -> cut s g' a i rr = Some c.
Proof.
  intros g g' a i rr c Hle H. unfold cut, occ in *. eapply scan_ext; [|exact H].
  intros q b E. eapply mb_mono; eauto.
Qed.

Lemma m_mono : forall f f' g g' ks i rr l, f <= f' -> g <= g' ->
  m s g f ks i rr = Some l -> m s g' f' ks i rr = Some l.
Proof.
  induction f as [|f IH]; intros f' g g' ks i rr l Hle Hg H; [discriminate|].
  destruct f' as [|f']; [lia|]. apply le_S_n in Hle.
  simpl in H |- *. unfold rep_ends, oapp in *.
  repeat (first [ match type of H with
  | context [m s g f ?k ?j ?r] =>
      let E := fresh "E" in let v := fresh "v" in destruct (m s g f k j r) as [v|] eqn:E;
      [rewrite (IH f' g g' k j r v Hle Hg E)|]
  | context [cut s g ?a ?j ?r] =>
      let E := fresh "E" in let v := fresh "v" in destruct (cut s g a j r) as [v|] eqn:E;
      [rewrite (cut_mono g g' a j r v Hg E)|]
  end
  | progress (cbv beta iota in H |- * )
  | mono_step H ]); subst; try congruence; auto.
Qed.

Lemma m_det : forall f f' g g' ks i rr l l',
  m s g f ks i rr = Some l -> m s g' f' ks i rr = Some l' -> l = l'.
Proof.
  intros f f' g g' ks i rr l l' H H'.
  apply (m_mono f (max f f') g (max g g')) in H; [|lia|lia].
  apply (m_mono f' (max f f') g' (max g g')) in H'; [|lia|lia]. congruence.
Qed.

Lemma md_mono : forall f f' ks i rr sv v, f <= f' ->
  md s f ks i rr sv = Some v -> md s f' ks i rr sv = Some v.
Proof.
  induction f as [|f IH]; intros f' ks i rr sv v Hle H; [discriminate|].
  destruct f' as [|f']; [lia|]. apply le_S_n in Hle.
  simpl in H |- *.
  repeat (first [ match type of H with
  | context [md s f ?k ?j ?r ?w] =>
      let E := fresh "E" in let v' := fresh "v" in destruct (md s f k j r w) as [v'|] eqn:E;
      [rewrite (IH f' k j r w v' Hle E)|]
  end
  | progress (cbv beta iota in H |- * )
  | mono_step H ]); subst; try congruence; auto.
Qed.

Lemma md_det : forall f f' ks i rr sv v v',
  md s f ks i rr sv = Some v -> md s f' ks i rr sv = Some v' -> v = v'.
Proof.
  intros f f' ks i rr sv v v' H H'.
  apply (md_mono f (max f f')) in H; [|lia]. apply (md_mono f' (max f f')) in H'; [|lia]. congruence.
Qed.
End Mono.
