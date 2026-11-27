(* Experiment #8 follow-up (issue #34), lemma 1: lemma F over a symbolic
   subject.  Design: lab/08-discriminating-lemmas/LEMMAS.md, "Lemma 1".
   On m of Fold.v (experiment #8's file, unchanged), under IGNORECASE,
   for every subject s, position i and fuel 7 + f:
   (F1) i + 2 is an end of [R (ILit [0xDF])] at i iff s[i..i+2) is one of
        ss, SS, sS, Ss;
   (F2) for each such spelling w, i + 1 is an end of [R (ILit w)] at i iff
        s[i] = 0xDF.
   The constant fuel of Fold.v appears in no statement or proof. *)
From Stdlib Require Import List Arith Lia Bool.
Import ListNotations.
From S Require Import Fold.

(* The four two-byte spellings of ss: ss, SS, sS, Ss. *)
Definition SS : list (list nat) := [[115;115]; [83;83]; [115;83]; [83;115]].

Lemma prefix_at_cons : forall s i c w,
  prefix_at s i (c :: w) = true <-> nth_error s i = Some c /\ prefix_at s (S i) w = true.
Proof.
  intros s i c w; simpl. destruct (nth_error s i) as [c'|].
  - rewrite andb_true_iff, Nat.eqb_eq. split; intros [H1 H2]; [subst|injection H1 as ->]; auto.
  - split; [discriminate|intros [H _]; discriminate].
Qed.

Lemma prefix1 : forall s i a, prefix_at s i [a] = true <-> nth_error s i = Some a.
Proof. intros. rewrite prefix_at_cons. simpl. tauto. Qed.

Lemma prefix2 : forall s i a b,
  prefix_at s i [a; b] = true <-> nth_error s i = Some a /\ nth_error s (S i) = Some b.
Proof. intros. rewrite prefix_at_cons, prefix1. tauto. Qed.

Lemma in_if : forall (x y : nat) (b : bool) (l : list nat),
  In x ((if b then [y] else []) ++ l) <-> (b = true /\ x = y) \/ In x l.
Proof. intros x y [|] l; simpl; intuition congruence. Qed.

Lemma m_df : forall s i f, m s (7 + f) [R (ILit [223])] i =
  (if prefix_at s i [223] then [i + 1] else []) ++
  (if prefix_at s i [115;115] then [i + 2] else []) ++
  (if prefix_at s i [83;83] then [i + 2] else []) ++
  (if prefix_at s i [115;83] then [i + 2] else []) ++
  (if prefix_at s i [83;115] then [i + 2] else []) ++ [].
Proof. intros. reflexivity. Qed.

(* unravel [x; y] for a spelling of ss: the spelling, 0xDF, then the other
   three spellings, in ss_items' order. *)
Lemma m_ss : forall s i f x y, In [x; y] SS ->
  exists l, m s (7 + f) [R (ILit [x; y])] i =
    (if prefix_at s i [x; y] then [i + 2] else []) ++
    (if prefix_at s i [223] then [i + 1] else []) ++ l
  /\ forall e, In e l -> e = i + 2.
Proof.
  intros s i f x y H; unfold SS in H; simpl in H.
  repeat (destruct H as [H|H]; [injection H as <- <-;
    eexists; split; [reflexivity|];
    intros e He; cbn -[prefix_at] in He; repeat (rewrite in_if in He; destruct He as [[_ ->]|He]; [reflexivity|]);
    destruct He|]); destruct H.
Qed.

(* Main lemma (LEMMAS.md, lemma 1): F1 and F2 together. *)
Theorem sharp_s_sym : forall s i f,
  (In (i + 2) (m s (7 + f) [R (ILit [223])] i) <->
     exists a b, nth_error s i = Some a /\ nth_error s (S i) = Some b /\ In [a; b] SS)
  /\ (forall w, In w SS ->
       (In (i + 1) (m s (7 + f) [R (ILit w)] i) <-> nth_error s i = Some 223)).
Proof.
  intros s i f; split.
  - rewrite m_df. repeat rewrite in_if. rewrite !prefix2, prefix1. simpl. split.
    + intros [[_ H]|[[[H1 H2] _]|[[[H1 H2] _]|[[[H1 H2] _]|[[[H1 H2] _]|[]]]]]];
        [lia| |  | |]; do 2 eexists; (split; [exact H1|split; [exact H2|]]); simpl; intuition auto.
    + intros (a & b & H1 & H2 & H). rewrite H1, H2.
      destruct H as [H|[H|[H|[H|[]]]]]; injection H as <- <-; intuition auto.
  - intros w Hw. assert (Hw' := Hw). unfold SS in Hw'.
    assert (exists x y, w = [x; y]) as (x & y & ->)
      by (repeat (destruct Hw' as [<-|Hw']; [do 2 eexists; reflexivity|]); destruct Hw').
    destruct (m_ss s i f x y Hw) as (l & -> & Hl).
    rewrite !in_if, prefix1. split.
    + intros [[_ H]|[[H _]|H]]; [lia|exact H|apply Hl in H; lia].
    + intros H. right; left. split; [exact H|reflexivity].
Qed.

Print Assumptions sharp_s_sym.

(* Stretch (decision 6, LEMMAS.md "Stretch"): the one-level fold statement
   for every literal w.  e is an end of [R (ILit w)] at i iff s[i..e) is a
   concatenation of one alternative per segment of unravel w.  Proved for
   any list of segments (the induction is on the segments and their
   alternatives, not on w), at every fuel above the number of
   alternatives plus 2 (7 for [0xDF], the bound of lemma F). *)
Inductive fold_rel (s : list nat) : nat -> list (list (list nat)) -> nat -> Prop :=
| fr_nil : forall i, fold_rel s i [] i
| fr_cons : forall i u alts segs e, In u alts -> prefix_at s i u = true ->
    fold_rel s (i + length u) segs e -> fold_rel s i (alts :: segs) e.

Fixpoint cost (segs : list (list (list nat))) : nat :=
  match segs with [] => 1 | alts :: segs => length alts + cost segs end.

Lemma cost_pos : forall segs, 1 <= cost segs.
Proof. induction segs; simpl; lia. Qed.

Lemma segs_m : forall s segs f i e, cost segs <= f ->
  (In e (m s f (map Seg segs) i) <-> fold_rel s i segs e).
Proof.
  intros s segs. induction segs as [|alts segs IH]; intros f i e Hf.
  - destruct f as [|f]; [simpl in Hf; lia|]. simpl. split.
    + intros [<-|[]]. constructor.
    + intros H. inversion H; subst. left; reflexivity.
  - simpl in Hf.
    assert (Halts : forall alts' f, length alts' + cost segs <= f ->
      (In e (m s f (Seg alts' :: map Seg segs) i) <->
       exists u, In u alts' /\ prefix_at s i u = true /\ fold_rel s (i + length u) segs e)).
    { induction alts' as [|u alts' IHa]; intros f' Hf'.
      - destruct f' as [|f']; simpl; split; try tauto; intros (u & [] & _).
      - destruct f' as [|f']; [simpl in Hf'; lia|]. simpl in Hf'. simpl.
        rewrite in_app_iff, IHa by lia. split.
        + intros [H|(u' & Hu' & Hp & Hr)].
          * destruct (prefix_at s i u) eqn:Ep; [|destruct H].
            rewrite IH in H by lia. exists u. split; [left; auto|auto].
          * exists u'. split; [right; auto|auto].
        + intros (u' & [<-|Hu'] & Hp & Hr).
          * left. rewrite Hp. rewrite IH by lia. exact Hr.
          * right. exists u'. auto. }
    simpl. rewrite (Halts alts f Hf). split.
    + intros (u & Hu & Hp & Hr). econstructor; eauto.
    + intros H. inversion H; subst. eauto.
Qed.

Theorem fold_lit : forall s w i e f, cost (unravel w) <= f ->
  (In e (m s (S f) [R (ILit w)] i) <-> fold_rel s i (unravel w) e).
Proof.
  intros s w i e f Hf. change (m s (S f) [R (ILit w)] i) with (m s f (map Seg (unravel w) ++ []) i).
  rewrite app_nil_r. apply segs_m. exact Hf.
Qed.

Lemma cost_df : cost (unravel [223]) = 6.
Proof. reflexivity. Qed.

Print Assumptions fold_lit.
