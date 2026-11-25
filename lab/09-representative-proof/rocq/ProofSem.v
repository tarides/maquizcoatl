(* Experiment #9, Rocq M2: facts about the reference semantics.
   Fuel monotonicity and determinism of [compute_tree], lemma (d) for the
   semantics (some fuel suffices, on the measure of FRAGMENT.md 4:
   remaining input, then the weight of the pending actions), and the
   elided star (a body of code length 0 matches only the empty string
   and changes no capture). *)

From Stdlib Require Import List Arith Lia.
Import ListNotations.
From S Require Import Syntax Sem Compile.

Section S.
Variable s : list nat.

Lemma ct_mono : forall f acts pos g t, compute_tree f s acts pos g = Some t ->
  forall f', f <= f' -> compute_tree f' s acts pos g = Some t.
Proof.
  induction f as [|f IH]; intros acts pos g t H f' Hle; [simpl in H; discriminate|].
  destruct f' as [|f']; [lia|]. assert (Hf : f <= f') by lia.
  destruct acts as [|[r|p0 a|n p0] k]; simpl in H |- *; auto.
  - destruct r; eauto.
    + destruct (is_prefix l (skipn pos s)); eauto.
    + destruct (compute_tree f s (ARe r1 :: k) pos g) eqn:E1; [|discriminate].
      destruct (compute_tree f s (ARe r2 :: k) pos g) eqn:E2; [|discriminate].
      rewrite (IH _ _ _ _ E1 _ Hf), (IH _ _ _ _ E2 _ Hf). exact H.
    + destruct (compute_tree f s (ARe r :: ACheck pos r :: k) pos g) eqn:E1; [|discriminate].
      destruct (compute_tree f s k pos g) eqn:E2; [|discriminate].
      rewrite (IH _ _ _ _ E1 _ Hf), (IH _ _ _ _ E2 _ Hf). exact H.
  - destruct (Nat.eqb pos p0); eauto.
Qed.

Lemma ct_det : forall f1 f2 acts pos g t1 t2,
  compute_tree f1 s acts pos g = Some t1 -> compute_tree f2 s acts pos g = Some t2 -> t1 = t2.
Proof.
  intros f1 f2 acts pos g t1 t2 H1 H2.
  pose proof (ct_mono _ _ _ _ _ H1 (f1 + f2) ltac:(lia)) as E1.
  pose proof (ct_mono _ _ _ _ _ H2 (f1 + f2) ltac:(lia)) as E2.
  congruence.
Qed.

(* FRAGMENT.md 4: the termination measure *)
Fixpoint size (r : regex) : nat :=
  match r with
  | Eps | Lit _ => 1
  | Cat a b | Alt a b => size a + size b + 1
  | Star a | Group _ a => size a + 2
  end.

Definition wa (pos : nat) (x : action) : nat :=
  match x with
  | ARe r => size r
  | AClose _ _ => 1
  | ACheck p0 a => if Nat.eqb pos p0 then 1 else size a + 3
  end.

Fixpoint W (pos : nat) (acts : list action) : nat :=
  match acts with
  | [] => 0
  | x :: k => wa pos x + W pos k
  end.

Lemma is_prefix_length : forall l x, is_prefix l x = true -> length l <= length x.
Proof.
  induction l as [|y l IH]; intros [|z x] H; simpl in *; try lia; try discriminate.
  apply andb_prop in H as [_ H]. apply IH in H. lia.
Qed.

Lemma length_skipn' : forall n (l : list nat), length (skipn n l) = length l - n.
Proof. induction n; intros [|x l]; simpl; auto; lia. Qed.

Lemma ct_total_aux : forall n w pos acts g, length s - pos < n -> W pos acts < w ->
  exists f t, compute_tree f s acts pos g = Some t.
Proof.
  induction n as [|n IHn]; intros w pos acts g Hn Hw; [lia|].
  revert pos acts g Hn Hw. induction w as [|w IHw]; intros pos acts g Hn Hw; [lia|].
  destruct acts as [|[r|p0 a|c p0] k].
  - exists 1, (TMatch pos g). reflexivity.
  - destruct r as [|l|a b|a b|a|c a]; simpl in Hw.
    + destruct (IHw pos k g) as (f & t & H); [lia|lia|].
      exists (S f), t. exact H.
    + destruct (is_prefix l (skipn pos s)) eqn:E.
      * destruct l as [|x l'].
        -- destruct (IHw pos k g) as (f & t & H); [lia|lia|].
           exists (S f), t. simpl. rewrite Nat.add_0_r. exact H.
        -- pose proof (is_prefix_length _ _ E) as Hl. rewrite length_skipn' in Hl.
           simpl in Hl.
           destruct (IHn (S (W (pos + length (x :: l')) k)) (pos + length (x :: l')) k g)
             as (f & t & H); [simpl; lia|lia|].
           exists (S f), t. simpl. simpl in E. rewrite E. exact H.
      * exists 1, TMismatch. simpl. rewrite E. reflexivity.
    + destruct (IHw pos (ARe a :: ARe b :: k) g) as (f & t & H); [lia|simpl; lia|].
      exists (S f), t. exact H.
    + destruct (IHw pos (ARe a :: k) g) as (f1 & t1 & H1); [lia|simpl; lia|].
      destruct (IHw pos (ARe b :: k) g) as (f2 & t2 & H2); [lia|simpl; lia|].
      exists (S (f1 + f2)), (TChoice t1 t2). simpl.
      rewrite (ct_mono _ _ _ _ _ H1 (f1 + f2)) by lia.
      rewrite (ct_mono _ _ _ _ _ H2 (f1 + f2)) by lia. reflexivity.
    + destruct (IHw pos (ARe a :: ACheck pos a :: k) g) as (f1 & t1 & H1);
        [lia|simpl; rewrite Nat.eqb_refl; lia|].
      destruct (IHw pos k g) as (f2 & t2 & H2); [lia|lia|].
      exists (S (f1 + f2)), (TChoice t1 t2). simpl.
      rewrite (ct_mono _ _ _ _ _ H1 (f1 + f2)) by lia.
      rewrite (ct_mono _ _ _ _ _ H2 (f1 + f2)) by lia. reflexivity.
    + destruct (IHw pos (ARe a :: AClose c pos :: k) g) as (f & t & H); [lia|simpl; lia|].
      exists (S f), t. exact H.
  - simpl in Hw. destruct (Nat.eqb pos p0) eqn:E.
    + destruct (IHw pos k g) as (f & t & H); [lia|lia|].
      exists (S f), t. simpl. rewrite E. exact H.
    + destruct (IHw pos (ARe (Star a) :: k) g) as (f & t & H); [lia|simpl; lia|].
      exists (S f), t. simpl. rewrite E. exact H.
  - simpl in Hw. destruct (IHw pos k (gset c (p0, pos) g)) as (f & t & H); [lia|lia|].
    exists (S f), t. exact H.
Qed.

(* lemma (d), semantics: some fuel makes compute_tree finish *)
Lemma ct_total : forall acts pos g, exists f t, compute_tree f s acts pos g = Some t.
Proof.
  intros acts pos g. apply (ct_total_aux (S (length s - pos)) (S (W pos acts))); lia.
Qed.

(* a star whose body compiles to no code (FRAGMENT.md 3, tlen == 0) *)
Lemma clen0_fm : forall a f k pos g t, clen a = 0 ->
  compute_tree f s (ARe a :: k) pos g = Some t ->
  exists f' t', compute_tree f' s k pos g = Some t' /\ first_match t' = first_match t.
Proof.
  induction a as [|l|a1 IH1 a2 IH2|a1 IH1 a2 IH2|a1 IH1|c a1 IH1];
    intros f k pos g t Hc H; (destruct f as [|f]; [simpl in H; discriminate|]);
    simpl in H, Hc.
  - eauto.
  - destruct l; [|discriminate]. simpl in H. rewrite Nat.add_0_r in H. eauto.
  - assert (H1 : clen a1 = 0) by lia. assert (H2 : clen a2 = 0) by lia.
    destruct (IH1 _ _ _ _ _ H1 H) as (f1 & t1 & E1 & F1).
    destruct (IH2 _ _ _ _ _ H2 E1) as (f2 & t2 & E2 & F2).
    exists f2, t2. split; congruence.
  - lia.
  - destruct (clen a1) eqn:Ca; [|simpl in Hc; discriminate].
    destruct (compute_tree f s (ARe a1 :: ACheck pos a1 :: k) pos g) as [ta|] eqn:E1;
      [|discriminate].
    destruct (compute_tree f s k pos g) as [tb|] eqn:E2; [|discriminate].
    injection H as <-.
    destruct (IH1 _ _ _ _ _ eq_refl E1) as (f1 & t1' & E1' & F1).
    destruct f1 as [|f1]; [simpl in E1'; discriminate|].
    simpl in E1'. rewrite Nat.eqb_refl in E1'.
    rewrite (ct_det _ _ _ _ _ _ _ E1' E2) in F1.
    exists f, tb. split; [exact E2|]. simpl. rewrite <- F1.
    destruct (first_match tb); reflexivity.
  - lia.
Qed.

End S.
