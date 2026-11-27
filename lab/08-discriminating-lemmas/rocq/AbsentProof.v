(* Experiment #8 follow-up (issue #34), lemma 2: absent desugaring
   equivalence.  Design: lab/08-discriminating-lemmas/LEMMAS.md, "Lemma 2"
   and "Lemma plan".  The direct semantics m (Absent.v) and the
   state-threaded matcher md on the C desugaring (Desugar.v) give the same
   complete lists of ends, each for some fuel, in both directions
   (decision 3), for AbsRep, AbsExp (simple and general path), the stopper
   and the range clear, with no absent construct inside an absent one. *)
From Stdlib Require Import List Arith Lia Bool Wf_nat.
Import ListNotations.
From S Require Import Absent Desugar AbsentMono.

(* ---------------------------------------------------------------- *)
(* Scope *)

Fixpoint core (r : re) : bool :=
  match r with
  | Eps | Chr _ | Any | AnyO => true
  | Seq a b | Alt a b => core a && core b
  | Star a => core a
  | _ => false
  end.

Fixpoint in_scope (r : re) : bool :=
  match r with
  | Eps | Chr _ | Any | AnyO | RClear => true
  | Seq a b | Alt a b => in_scope a && in_scope b
  | Star a => in_scope a
  | AbsRep a | Stopper a => core a
  | AbsExp a e => core a && core e
  end.

Lemma core_in_scope : forall r, core r = true -> in_scope r = true.
Proof.
  induction r; simpl; intros H; auto; try discriminate;
  apply andb_prop in H as [H1 H2]; rewrite IHr1, IHr2; auto.
Qed.

Lemma core_desugar : forall r n, core r = true -> desugar r n = (emb r, n).
Proof.
  induction r; intros n H; simpl in *; try discriminate; auto.
  - apply andb_prop in H as [H1 H2]. rewrite IHr1, IHr2; auto.
  - apply andb_prop in H as [H1 H2]. rewrite IHr1, IHr2; auto.
  - rewrite IHr; auto.
Qed.

Definition emb_item (it : item) : ditem :=
  match it with R x => DR (emb x) | Chk i x => DChk i (emb x) | _ => DR DFail end.
Definition core_item (it : item) : bool :=
  match it with R x => core x | Chk _ x => core x | _ => false end.

Fixpoint rsz (r : re) : nat :=
  match r with Seq a b | Alt a b => S (rsz a + rsz b) | Star a => S (S (rsz a)) | _ => 1 end.

Definition ends (rs : list dres) : list nat := map (fun '(e, _, _) => e) rs.

Section P.
Variable s : list nat.

(* The continuation of the absent pattern inside the engine:
   UpdRRFromS j; Fail (regparse.c:3013-3020). *)
Definition K (j : nat) (rest : list ditem) : list ditem :=
  DR (DSeq (DUpdRRFromS j) (DSeq DFail DEps)) :: rest.

Lemma md_K : forall j rest q rho sv p, lookup j sv = Some p ->
  md s 4 (K j rest) q rho sv = Some ([], p).
Proof. intros. simpl. rewrite H. reflexivity. Qed.

Lemma md_lift : forall f ks i rr sv v, md s f ks i rr sv = Some v ->
  forall f', f <= f' -> md s f' ks i rr sv = Some v.
Proof. intros. eapply md_mono; eauto. Qed.

Lemma md_alt_intro : forall f1 f2 a b k q rho sv r1 x1 r2 x2,
  md s f1 (DR a :: k) q rho sv = Some (r1, x1) -> md s f2 (DR b :: k) q x1 sv = Some (r2, x2) ->
  md s (S (f1 + f2)) (DR (DAlt a b) :: k) q rho sv = Some (r1 ++ r2, x2).
Proof.
  intros. simpl. rewrite (md_lift _ _ _ _ _ _ H (f1 + f2)) by lia.
  rewrite (md_lift _ _ _ _ _ _ H0 (f1 + f2)) by lia. reflexivity.
Qed.

Lemma md_star_intro : forall f1 f2 a k q rho sv r1 x1 r2 x2,
  md s f1 (DR a :: DChk q a :: k) q rho sv = Some (r1, x1) -> md s f2 k q x1 sv = Some (r2, x2) ->
  md s (S (f1 + f2)) (DR (DStar a) :: k) q rho sv = Some (r1 ++ r2, x2).
Proof.
  intros. simpl. rewrite (md_lift _ _ _ _ _ _ H (f1 + f2)) by lia.
  rewrite (md_lift _ _ _ _ _ _ H0 (f1 + f2)) by lia. reflexivity.
Qed.

(* (a), core part: on an absent-free stack followed by K, md never writes
   the register before K, and K sets it to p: md ends with p if the stack
   has a result (mb true), with the starting register otherwise. *)
Lemma core_K : forall j p rest f ks q rho sv r x,
  forallb core_item ks = true -> lookup j sv = Some p ->
  md s f (map emb_item ks ++ K j rest) q rho sv = Some (r, x) ->
  exists b, mb s f ks q rho = Some b /\ r = [] /\ x = if b then p else rho.
Proof.
  intros j p rest. induction f as [|f IH]; intros ks q rho sv r x Hc Hj H; [discriminate|].
  destruct ks as [|it ks].
  - unfold K in H; simpl in H. destruct f as [|f]; [discriminate|]. simpl in H. rewrite Hj in H.
    destruct f as [|f]; [discriminate|]. simpl in H. destruct f as [|f]; [discriminate|].
    simpl in H. injection H as <- <-. exists true. auto.
  - simpl in Hc. apply andb_prop in Hc as [Hy Hks].
    destruct it as [y|i0 y|n|es]; simpl in Hy; try discriminate.
    + destruct y; simpl in Hy; try discriminate; simpl in H |- *.
      * apply (IH _ _ _ _ _ _ Hks Hj H).
      * destruct (at_ s q rho) as [c'|]; [destruct (Nat.eqb c c')|];
          [apply (IH _ _ _ _ _ _ Hks Hj H)|injection H as <- <-; exists false; auto
          |injection H as <- <-; exists false; auto].
      * destruct (at_ s q rho) as [c'|]; [destruct (Nat.eqb c' 10)|];
          [injection H as <- <-; exists false; auto|apply (IH _ _ _ _ _ _ Hks Hj H)
          |injection H as <- <-; exists false; auto].
      * destruct (at_ s q rho) as [c'|];
          [apply (IH _ _ _ _ _ _ Hks Hj H)|injection H as <- <-; exists false; auto].
      * apply andb_prop in Hy as [Hy1 Hy2].
        apply (IH (R y1 :: R y2 :: ks) q rho sv r x); simpl; auto. rewrite Hy1, Hy2, Hks; reflexivity.
      * apply andb_prop in Hy as [Hy1 Hy2].
        destruct (md s f (DR (emb y1) :: map emb_item ks ++ K j rest) q rho sv) as [[r1 x1]|] eqn:E1; [|discriminate].
        destruct (md s f (DR (emb y2) :: map emb_item ks ++ K j rest) q x1 sv) as [[r2 x2]|] eqn:E2; [|discriminate].
        injection H as <- <-.
        destruct (IH (R y1 :: ks) q rho sv r1 x1) as (b1 & Hb1 & -> & ->); simpl; auto; [rewrite Hy1; auto|].
        destruct (IH (R y2 :: ks) q (if b1 then p else rho) sv r2 x2) as (b2 & Hb2 & -> & ->); simpl; auto; [rewrite Hy2; auto|].
        unfold oor. rewrite Hb1. destruct b1.
        -- exists true. destruct b2; auto.
        -- exists b2. rewrite Hb2. auto.
      * destruct (md s f (DR (emb y) :: DChk q (emb y) :: map emb_item ks ++ K j rest) q rho sv) as [[r1 x1]|] eqn:E1; [|discriminate].
        destruct (md s f (map emb_item ks ++ K j rest) q x1 sv) as [[r2 x2]|] eqn:E2; [|discriminate].
        injection H as <- <-.
        destruct (IH (R y :: Chk q y :: ks) q rho sv r1 x1) as (b1 & Hb1 & -> & ->); simpl; auto; [rewrite Hy; auto|].
        destruct (IH ks q (if b1 then p else rho) sv r2 x2) as (b2 & Hb2 & -> & ->); auto.
        unfold oor. rewrite Hb1. destruct b1.
        -- exists true. destruct b2; auto.
        -- exists b2. rewrite Hb2. auto.
    + simpl in H |- *. destruct (Nat.eqb q i0).
      * apply (IH _ _ _ _ _ _ Hks Hj H).
      * apply (IH (R (Star y) :: ks) q rho sv r x); simpl; auto. rewrite Hy, Hks; auto.
Qed.

(* Termination measure on absent-free stacks at a fixed position. *)
Definition w (it : item) (q : nat) : nat :=
  match it with R x => rsz x | Chk i0 x => if Nat.eqb i0 q then 1 else rsz x + 3 | _ => 1 end.
Fixpoint mu (ks : list item) (q : nat) : nat :=
  match ks with [] => 0 | it :: ks => w it q + mu ks q end.

Lemma rsz_pos : forall r, 1 <= rsz r.
Proof. destruct r; simpl; lia. Qed.

Lemma at_lt : forall i rr c, at_ s i rr = Some c -> i < rr.
Proof. unfold at_. intros i rr c H. destruct (Nat.ltb_spec i rr); [lia|discriminate]. Qed.

(* (b)/(c) support: md on an absent-free stack followed by K terminates,
   by induction on (rho - q, mu) lexicographically. *)
Lemma term_core : forall j p rest N M ks q rho sv,
  rho - q <= N -> mu ks q <= M -> forallb core_item ks = true -> lookup j sv = Some p -> p <= q ->
  exists f r x, md s f (map emb_item ks ++ K j rest) q rho sv = Some (r, x).
Proof.
  intros j p rest N. induction N as [N IHN] using (well_founded_induction lt_wf).
  intros M. induction M as [|M IHM]; intros ks q rho sv HN HM Hc Hj Hp.
  - destruct ks as [|it ks]; [exists 4; do 2 eexists; apply md_K; eauto|].
    simpl in HM. destruct it; simpl in HM; try (pose proof (rsz_pos x)); try destruct (Nat.eqb i q); lia.
  - destruct ks as [|it ks]; [exists 4; do 2 eexists; apply md_K; eauto|].
    simpl in Hc. apply andb_prop in Hc as [Hy Hks]. simpl in HM.
    destruct it as [y|i0 y|n|es]; simpl in Hy; try discriminate.
    + destruct y; simpl in Hy, HM; try discriminate.
      * destruct (IHM ks q rho sv) as (f & r & x & H); auto; [lia|].
        exists (S f), r, x. exact H.
      * destruct (at_ s q rho) as [c'|] eqn:Ea; [destruct (Nat.eqb c c') eqn:Ec|].
        -- destruct (IHN (rho - S q)) with (M := mu ks (S q)) (ks := ks) (q := S q) (rho := rho) (sv := sv)
             as (f & r & x & H); auto; try lia; [apply at_lt in Ea; lia|].
           exists (S f), r, x. simpl. rewrite Ea, Ec. exact H.
        -- exists 1, [], rho. simpl. rewrite Ea, Ec. reflexivity.
        -- exists 1, [], rho. simpl. rewrite Ea. reflexivity.
      * destruct (at_ s q rho) as [c'|] eqn:Ea; [destruct (Nat.eqb c' 10) eqn:Ec|].
        -- exists 1, [], rho. simpl. rewrite Ea, Ec. reflexivity.
        -- destruct (IHN (rho - S q)) with (M := mu ks (S q)) (ks := ks) (q := S q) (rho := rho) (sv := sv)
             as (f & r & x & H); auto; try lia; [apply at_lt in Ea; lia|].
           exists (S f), r, x. simpl. rewrite Ea, Ec. exact H.
        -- exists 1, [], rho. simpl. rewrite Ea. reflexivity.
      * destruct (at_ s q rho) as [c'|] eqn:Ea.
        -- destruct (IHN (rho - S q)) with (M := mu ks (S q)) (ks := ks) (q := S q) (rho := rho) (sv := sv)
             as (f & r & x & H); auto; try lia; [apply at_lt in Ea; lia|].
           exists (S f), r, x. simpl. rewrite Ea. exact H.
        -- exists 1, [], rho. simpl. rewrite Ea. reflexivity.
      * apply andb_prop in Hy as [Hy1 Hy2].
        destruct (IHM (R y1 :: R y2 :: ks) q rho sv) as (f & r & x & H); simpl; auto; [lia|rewrite Hy1, Hy2; auto|].
        exists (S f), r, x. exact H.
      * apply andb_prop in Hy as [Hy1 Hy2].
        destruct (IHM (R y1 :: ks) q rho sv) as (f1 & r1 & x1 & H1); simpl; auto; [lia|rewrite Hy1; auto|].
        destruct (core_K j p rest f1 (R y1 :: ks) q rho sv r1 x1) as (b1 & _ & _ & Hx1); simpl; auto; [rewrite Hy1; auto|].
        destruct (IHM (R y2 :: ks) q x1 sv) as (f2 & r2 & x2 & H2); simpl; auto; [destruct b1; lia|lia|rewrite Hy2; auto|].
        exists (S (f1 + f2)), (r1 ++ r2), x2. apply md_alt_intro with (x1 := x1); auto.
      * destruct (IHM (R y :: Chk q y :: ks) q rho sv) as (f1 & r1 & x1 & H1); simpl; auto;
          [rewrite Nat.eqb_refl; lia|rewrite Hy; auto|].
        destruct (core_K j p rest f1 (R y :: Chk q y :: ks) q rho sv r1 x1) as (b1 & _ & _ & Hx1); simpl; auto; [rewrite Hy; auto|].
        destruct (IHM ks q x1 sv) as (f2 & r2 & x2 & H2); auto; [destruct b1; lia|lia|].
        exists (S (f1 + f2)), (r1 ++ r2), x2. apply md_star_intro with (x1 := x1); auto.
    + simpl in HM. destruct (Nat.eqb i0 q) eqn:Eq.
      * apply Nat.eqb_eq in Eq; subst i0.
        destruct (IHM ks q rho sv) as (f & r & x & H); auto; [lia|].
        exists (S f), r, x. simpl. rewrite Nat.eqb_refl. exact H.
      * destruct (IHM (R (Star y) :: ks) q rho sv) as (f & r & x & H); simpl; auto; [lia|rewrite Hy; auto|].
        exists (S f), r, x. simpl. rewrite Nat.eqb_sym, Eq. exact H.
Qed.

(* mb terminates on absent-free stacks (some fuel gives a complete answer). *)
Lemma mb_term : forall ks q rho, forallb core_item ks = true -> exists f b, mb s f ks q rho = Some b.
Proof.
  intros ks q rho Hc.
  destruct (term_core 0 0 [] (rho - q) (mu ks q) ks q rho [(0, 0)]) as (f & r & x & H); auto; try lia.
  destruct (core_K 0 0 [] f ks q rho [(0, 0)] r x Hc eq_refl H) as (b & Hb & _). eauto.
Qed.

(* (c), one position of the engine's scan: the branch
   SaveS j; a; UpdRRFromS j; Fail at q leaves the register at q if a has a
   result at q (mb true), unchanged otherwise, and has no result. *)
Definition att (j : nat) (a : re) : dre := dseq [DSaveS j; emb a; DUpdRRFromS j; DFail].

Lemma attempt : forall j a q rho sv rest, core a = true ->
  exists F b, mb s F [R a] q rho = Some b /\
    forall f, F <= f -> md s f (DR (att j a) :: rest) q rho sv = Some ([], if b then q else rho).
Proof.
  intros j a q rho sv rest Ha.
  destruct (term_core j q rest (rho - q) (mu [R a] q) [R a] q rho ((j, q) :: sv)) as (f & r & x & H);
    [lia|lia|simpl; rewrite Ha; reflexivity|simpl; rewrite Nat.eqb_refl; reflexivity|lia|].
  destruct (core_K j q rest f [R a] q rho ((j, q) :: sv) r x) as (b & Hb & -> & ->);
    [simpl; rewrite Ha; reflexivity|simpl; rewrite Nat.eqb_refl; reflexivity|exact H|].
  exists (3 + f), b. split; [apply (mb_mono s f); [lia|exact Hb]|].
  intros f' Hf. apply md_lift with (f := 3 + f); [exact H|lia].
Qed.

Lemma attempt_inv : forall j a q rho sv rest f r x, core a = true ->
  md s f (DR (att j a) :: rest) q rho sv = Some (r, x) ->
  exists b, mb s f [R a] q rho = Some b /\ r = [] /\ x = if b then q else rho.
Proof.
  intros j a q rho sv rest f r x Ha H.
  destruct f as [|[|[|f]]]; try discriminate. unfold att, dseq in H; simpl in H.
  destruct (core_K j q rest f [R a] q rho ((j, q) :: sv) r x) as (b & Hb & -> & ->);
    [simpl; rewrite Ha; reflexivity|simpl; rewrite Nat.eqb_refl; reflexivity|exact H|].
  exists b. split; auto. apply (mb_mono s f); [lia|exact Hb].
Qed.

(* ---------------------------------------------------------------- *)
(* Unfolding equations *)

Definition body (j : nat) (a : re) (st : dre) : dre := DAlt (att j a) st.

Lemma md_star_eq : forall f B U q rho sv,
  md s (S f) (DR (DStar B) :: U) q rho sv =
  match md s f (DR B :: DChk q B :: U) q rho sv with
  | Some (r1, x1) => match md s f U q x1 sv with Some (r2, x2) => Some (r1 ++ r2, x2) | None => None end
  | None => None end.
Proof. reflexivity. Qed.

Lemma md_body_eq : forall f j a st k q rho sv,
  md s (S f) (DR (body j a st) :: k) q rho sv =
  match md s f (DR (att j a) :: k) q rho sv with
  | Some (r1, x1) => match md s f (DR st :: k) q x1 sv with Some (r2, x2) => Some (r1 ++ r2, x2) | None => None end
  | None => None end.
Proof. reflexivity. Qed.

Lemma md_chk_ne : forall f i0 B U q rho sv, q <> i0 ->
  md s (S f) (DChk i0 B :: U) q rho sv = md s f (DR (DStar B) :: U) q rho sv.
Proof. intros. simpl. apply Nat.eqb_neq in H. rewrite H. reflexivity. Qed.

Lemma downs_S : forall n q, downs (S n) q = downs n (S q) ++ [q].
Proof.
  induction n; intros q; [simpl; f_equal; lia|].
  change (downs (S (S n)) q) with ((q + S (S n)) :: downs (S n) q). rewrite IHn.
  simpl. f_equal. lia.
Qed.

Lemma downs_hd : forall d q, exists t, downs d q = (q + d) :: t.
Proof. destruct d; intros q; simpl; [exists []; rewrite Nat.add_0_r|eexists]; reflexivity. Qed.

Lemma Forall2_snoc_inv : forall {A B} (P : A -> B -> Prop) l x ys,
  Forall2 P (l ++ [x]) ys -> exists ys1 y, ys = ys1 ++ [y] /\ Forall2 P l ys1 /\ P x y.
Proof.
  intros A B P l x ys H. apply Forall2_app_inv_l in H as (ys1 & ys2 & H1 & H2 & ->).
  inversion H2 as [|? y ? ? Hy Hn]; subst. inversion Hn; subst. eauto.
Qed.

(* ---------------------------------------------------------------- *)
(* (c)/(d): the engine's scan, for a general step st (AnyO, or Chr c on the
   simple path), followed by a continuation U whose final register is
   h of the register it is entered with. *)

Section Scan.
Variables (j : nat) (a : re) (st : dre) (stp : nat -> nat -> bool) (U : list ditem)
          (h : nat -> nat) (sv : list (nat * nat)) (rho : nat).

Definition step_ok :=
  forall f q x rest sv', md s (S f) (DR st :: rest) q x sv' = if stp q x then md s f rest (S q) x sv' else Some ([], x).
Definition step_lt := forall q x, stp q x = true -> q < x.

Lemma scan_a : core a = true -> step_ok -> step_lt ->
  forall d q top bt Rs, top = q + d ->
  (forall p, q <= p < top -> (exists F, mb s F [R a] p rho = Some false) /\ stp p rho = true) ->
  (exists F, mb s F [R a] top rho = Some bt) ->
  stp top (if bt then top else rho) = false ->
  Forall2 (fun e R => forall x, x = (if bt then top else rho) \/ x = h (if bt then top else rho) ->
             exists F, md s F U e x sv = Some (R, h (if bt then top else rho))) (downs d q) Rs ->
  exists F, md s F (DR (DStar (body j a st)) :: U) q rho sv = Some (concat Rs, h (if bt then top else rho)).
Proof.
  intros Ha Hst Hlt d. induction d as [|d IH]; intros q top bt Rs Htop Hpre [Fb Hbt] Hstop HU.
  - rewrite Nat.add_0_r in Htop. subst top. simpl in HU.
    inversion HU as [|? Rq ? ? HR Hn]; subst. inversion Hn; subst.
    destruct (attempt j a q rho sv (DChk q (body j a st) :: U) Ha) as (Fa & b & Hb & Hatt).
    assert (b = bt) by (eapply mb_det; eauto). subst b.
    destruct (HR _ (or_introl eq_refl)) as [FU HFU].
    exists (S (S (S (S (Fa + FU))))). rewrite md_star_eq, md_body_eq.
    rewrite (Hatt (S (S (Fa + FU)))) by lia. rewrite Hst, Hstop.
    rewrite (md_lift _ _ _ _ _ _ HFU (S (S (S (Fa + FU))))) by lia.
    simpl. rewrite app_nil_r. reflexivity.
  - rewrite downs_S in HU. apply Forall2_snoc_inv in HU as (Rs1 & Rq & -> & HRs1 & HRq).
    destruct (Hpre q) as [[Fq Hq] Hsq]; [lia|].
    destruct (IH (S q) top bt Rs1) as [F1 H1]; auto; [lia|intros; apply Hpre; lia|eauto|].
    destruct (attempt j a q rho sv (DChk q (body j a st) :: U) Ha) as (Fa & b & Hb & Hatt).
    assert (b = false) by (eapply mb_det; eauto). subst b.
    destruct (HRq _ (or_intror eq_refl)) as [FU HFU].
    exists (S (S (S (S (Fa + F1 + FU))))). rewrite md_star_eq, md_body_eq.
    rewrite (Hatt (S (S (Fa + F1 + FU)))) by lia. rewrite Hst, Hsq.
    rewrite md_chk_ne by lia.
    rewrite (md_lift _ _ _ _ _ _ H1 (Fa + F1 + FU)) by lia.
    rewrite (md_lift _ _ _ _ _ _ HFU (S (S (S (Fa + F1 + FU))))) by lia.
    rewrite concat_app. simpl. rewrite app_nil_r. reflexivity.
Qed.

Lemma scan_b : core a = true -> step_ok -> step_lt -> (forall y, h (h y) = h y) ->
  forall F q r x, q <= rho -> md s F (DR (DStar (body j a st)) :: U) q rho sv = Some (r, x) ->
  (forall f e x0 R y, f < F -> e <= rho -> md s f U e x0 sv = Some (R, y) -> y = h x0) ->
  exists top bt Rs, q <= top
   /\ (forall p, q <= p < top -> mb s F [R a] p rho = Some false /\ stp p rho = true)
   /\ mb s F [R a] top rho = Some bt /\ stp top (if bt then top else rho) = false
   /\ Forall2 (fun e R => exists f x0, f < F
         /\ (x0 = (if bt then top else rho) \/ x0 = h (if bt then top else rho))
         /\ md s f U e x0 sv = Some (R, h (if bt then top else rho))) (downs (top - q) q) Rs
   /\ r = concat Rs /\ x = h (if bt then top else rho).
Proof.
  intros Ha Hst Hlt Hh F. induction F as [F IHF] using (well_founded_induction lt_wf).
  intros q r x Hq0 H HU.
  destruct F as [|F1]; [discriminate|]. rewrite md_star_eq in H.
  destruct (md s F1 (DR (body j a st) :: DChk q (body j a st) :: U) q rho sv) as [[r1 x1]|] eqn:E1; [|discriminate].
  destruct (md s F1 U q x1 sv) as [[r2 x2]|] eqn:E2; [|discriminate]. injection H as <- <-.
  destruct F1 as [|F2]; [discriminate|]. rewrite md_body_eq in E1.
  destruct (md s F2 (DR (att j a) :: DChk q (body j a st) :: U) q rho sv) as [[ra xa]|] eqn:Ea; [|discriminate].
  destruct (md s F2 (DR st :: DChk q (body j a st) :: U) q xa sv) as [[rb xb]|] eqn:Eb; [|discriminate].
  injection E1 as <- <-.
  destruct (attempt_inv j a q rho sv _ F2 ra xa Ha Ea) as (b & Hb & -> & ->).
  destruct F2 as [|F3]; [discriminate|]. rewrite Hst in Eb.
  destruct (stp q (if b then q else rho)) eqn:Es.
  - destruct b; [apply Hlt in Es; lia|].
    destruct F3 as [|F4]; [discriminate|]. rewrite md_chk_ne in Eb by lia.
    destruct (IHF F4 ltac:(lia) (S q) rb xb) as (top & bt & Rs & Hq & Hpre & Hbt & Hstop & HRs & -> & ->);
      [apply Hlt in Es; lia|exact Eb|intros f0 e0 x0 R0 y0 Hf0 He0 Hmd; eapply HU; [|exact He0|exact Hmd]; lia|].
    pose proof E2 as Hx2; apply HU in Hx2; [|lia|lia]. rewrite Hh in Hx2. subst x2.
    exists top, bt, (Rs ++ [r2]). repeat split; auto.
    + lia.
    + destruct (Nat.eq_dec p q) as [->|Hne]; [apply (mb_mono s (S (S F4))); [lia|exact Hb]|].
      apply (mb_mono s F4); [lia|apply Hpre; lia].
    + destruct (Nat.eq_dec p q) as [->|Hne]; [exact Es|apply Hpre; lia].
    + apply (mb_mono s F4); [lia|exact Hbt].
    + replace (top - q) with (S (top - S q)) by lia. rewrite downs_S.
      apply Forall2_app; [|constructor; [|constructor]].
      * eapply Forall2_impl; [|exact HRs]. intros e R (f & x0 & Hf & Hx0 & HR). exists f, x0. split; [lia|auto].
      * exists (S (S (S F4))), (h (if bt then top else rho)). split; [lia|split; auto].
    + rewrite concat_app. simpl. rewrite app_nil_r. reflexivity.
  - injection Eb as <- <-.
    pose proof E2 as Hx2; apply HU in Hx2; [|lia|lia]. subst x2.
    exists q, b, [r2].
    split; [lia|]. split; [intros; lia|]. split; [apply (mb_mono s (S F3)); [lia|exact Hb]|].
    split; [exact Es|]. split; [|split; [simpl; rewrite app_nil_r; reflexivity|reflexivity]].
    rewrite Nat.sub_diag. simpl. constructor; [|constructor].
    exists (S (S F3)), (if b then q else rho). split; [lia|split; auto].
Qed.
End Scan.

(* ---------------------------------------------------------------- *)
(* The direct side: cut, Ends and x* in experiment #8's m. *)

Lemma scan_spec : forall P k q c, scan P k q = Some c ->
  q <= c /\ (forall p, q <= p < c -> P p = Some false) /\ (c = q + k \/ (c < q + k /\ P c = Some true)).
Proof.
  induction k; intros q c H; simpl in H.
  - injection H as <-. split; [lia|split; [intros; lia|left; lia]].
  - destruct (P q) as [[|]|] eqn:E; try discriminate.
    + injection H as <-. split; [lia|split; [intros; lia|right; split; [lia|auto]]].
    + destruct (IHk (S q) c H) as (H1 & H2 & H3). split; [lia|split].
      * intros p Hp. destruct (Nat.eq_dec p q) as [->|]; auto. apply H2; lia.
      * destruct H3 as [H3|[H3 H4]]; [left; lia|right; split; [lia|auto]].
Qed.

Lemma scan_intro : forall P k q c, q <= c -> (forall p, q <= p < c -> P p = Some false) ->
  (c = q + k \/ (c < q + k /\ P c = Some true)) -> scan P k q = Some c.
Proof.
  induction k; intros q c H1 H2 H3; simpl.
  - f_equal. destruct H3 as [H3|[H3 _]]; lia.
  - destruct (Nat.eq_dec q c) as [<-|Hne].
    + destruct H3 as [H3|[_ H3]]; [lia|rewrite H3; reflexivity].
    + rewrite H2 by lia. apply IHk; auto; [lia|intros; apply H2; lia|].
      destruct H3 as [H3|[H3 H4]]; [left; lia|right; split; [lia|auto]].
Qed.

Lemma m_ends_a : forall g es f ks i rr l, m s g f (Ends es :: ks) i rr = Some l ->
  exists ls, Forall2 (fun e le => exists fe, fe < f /\ m s g fe ks e rr = Some le) es ls /\ l = concat ls.
Proof.
  intros g. induction es as [|e es IH]; intros f ks i rr l H; destruct f as [|f]; try discriminate.
  - injection H as <-. exists []. auto.
  - simpl in H. unfold oapp in H.
    destruct (m s g f ks e rr) as [l1|] eqn:E1; [|discriminate].
    destruct (m s g f (Ends es :: ks) i rr) as [l2|] eqn:E2; [|discriminate]. injection H as <-.
    destruct (IH f ks i rr l2 E2) as (ls & Hls & ->).
    exists (l1 :: ls). split; [constructor; [exists f; auto|]|reflexivity].
    eapply Forall2_impl; [|exact Hls]. intros e' le (fe & Hfe & He). exists fe. split; [lia|auto].
Qed.

Lemma m_ends_b : forall es ls ks i rr,
  Forall2 (fun e le => exists g f, m s g f ks e rr = Some le) es ls ->
  exists g f, m s g f (Ends es :: ks) i rr = Some (concat ls).
Proof.
  intros es ls ks i rr H. induction H as [|e le es ls (g1 & f1 & H1) _ (g2 & f2 & H2)].
  - exists 0, 1. reflexivity.
  - exists (max g1 g2), (S (max f1 f2)). simpl. unfold oapp.
    rewrite (m_mono s f1 (max f1 f2) g1 (max g1 g2) _ _ _ _ ltac:(lia) ltac:(lia) H1).
    rewrite (m_mono s f2 (max f1 f2) g2 (max g1 g2) _ _ _ _ ltac:(lia) ltac:(lia) H2).
    reflexivity.
Qed.

Lemma m_star_eq : forall g f a k q c,
  m s g (S f) (R (Star a) :: k) q c = oapp (m s g f (R a :: Chk q a :: k) q c) (m s g f k q c).
Proof. reflexivity. Qed.

Lemma m_chr_eq : forall g f ch k q c,
  m s g (S f) (R (Chr ch) :: k) q c =
  match at_ s q c with Some c' => if Nat.eqb ch c' then m s g f k (S q) c else Some [] | None => Some [] end.
Proof. reflexivity. Qed.

Lemma m_chk_ne : forall g f i0 a k q c, q <> i0 ->
  m s g (S f) (Chk i0 a :: k) q c = m s g f (R (Star a) :: k) q c.
Proof. intros. simpl. apply Nat.eqb_neq in H. rewrite H. reflexivity. Qed.

Section XStar.
Variable ch : nat.

Lemma mstar_a : forall g f k q c l, m s g f (R (Star (Chr ch)) :: k) q c = Some l ->
  exists top ls, q <= top /\ (forall p, q <= p < top -> at_ s p c = Some ch) /\ at_ s top c <> Some ch
   /\ Forall2 (fun e le => exists fe, fe < f /\ m s g fe k e c = Some le) (downs (top - q) q) ls
   /\ l = concat ls.
Proof.
  intros g f. induction f as [f IHf] using (well_founded_induction lt_wf). intros k q c l H.
  destruct f as [|f1]; [discriminate|]. simpl in H. unfold oapp in H.
  destruct (m s g f1 (R (Chr ch) :: Chk q (Chr ch) :: k) q c) as [l1|] eqn:E1; [|discriminate].
  destruct (m s g f1 k q c) as [l2|] eqn:E2; [|discriminate]. injection H as <-.
  destruct f1 as [|f2]; [discriminate|]. simpl in E1.
  destruct (at_ s q c) as [c'|] eqn:Ea; [destruct (Nat.eqb ch c') eqn:Ec|].
  - apply Nat.eqb_eq in Ec. subst c'.
    destruct f2 as [|f3]; [discriminate|]. rewrite m_chk_ne in E1 by lia.
    destruct (IHf f3 ltac:(lia) k (S q) c l1 E1) as (top & ls & Hq & Hpre & Htop & Hls & ->).
    exists top, (ls ++ [l2]). repeat split; auto.
    + lia.
    + intros p Hp. destruct (Nat.eq_dec p q) as [->|]; auto. apply Hpre; lia.
    + replace (top - q) with (S (top - S q)) by lia. rewrite downs_S.
      apply Forall2_app; [|constructor; [exists (S (S f3)); split; [lia|auto]|constructor]].
      eapply Forall2_impl; [|exact Hls]. intros e le (fe & Hfe & He). exists fe. split; [lia|auto].
    + rewrite concat_app. simpl. rewrite app_nil_r. reflexivity.
  - injection E1 as <-. exists q, [l2]. repeat split; try lia.
    + rewrite Ea. intros He. injection He as ->. rewrite Nat.eqb_refl in Ec. discriminate.
    + rewrite Nat.sub_diag. simpl. constructor; [exists (S f2); split; [lia|auto]|constructor].
    + simpl. rewrite app_nil_r. reflexivity.
  - injection E1 as <-. exists q, [l2]. repeat split; try lia.
    + rewrite Ea. discriminate.
    + rewrite Nat.sub_diag. simpl. constructor; [exists (S f2); split; [lia|auto]|constructor].
    + simpl. rewrite app_nil_r. reflexivity.
Qed.

Lemma mstar_b : forall d q top k c ls, top = q + d ->
  (forall p, q <= p < top -> at_ s p c = Some ch) -> at_ s top c <> Some ch ->
  Forall2 (fun e le => exists g f, m s g f k e c = Some le) (downs d q) ls ->
  exists g f, m s g f (R (Star (Chr ch)) :: k) q c = Some (concat ls).
Proof.
  induction d as [|d IH]; intros q top k c ls Htop Hpre Hnot H.
  - rewrite Nat.add_0_r in Htop. subst top. simpl in H.
    inversion H as [|? lq ? ? (g & f & Hq) Hn]; subst. inversion Hn; subst.
    exists g, (S (S f)). rewrite m_star_eq, m_chr_eq. unfold oapp.
    destruct (at_ s q c) as [c'|] eqn:Ea.
    + replace (Nat.eqb ch c') with false by (symmetry; apply Nat.eqb_neq; intros ->; auto).
      rewrite (m_mono s f (S f) g g _ _ _ _ ltac:(lia) ltac:(lia) Hq). simpl. rewrite app_nil_r. reflexivity.
    + rewrite (m_mono s f (S f) g g _ _ _ _ ltac:(lia) ltac:(lia) Hq). simpl. rewrite app_nil_r. reflexivity.
  - rewrite downs_S in H. apply Forall2_snoc_inv in H as (ls1 & lq & -> & Hls1 & (gq & fq & Hq)).
    destruct (IH (S q) top k c ls1) as (g1 & f1 & H1); auto; [lia|intros; apply Hpre; lia|].
    exists (max g1 gq), (S (S (S (S (f1 + fq))))). rewrite m_star_eq, m_chr_eq. unfold oapp.
    rewrite (Hpre q) by lia. rewrite Nat.eqb_refl. rewrite m_chk_ne by lia.
    rewrite (m_mono s f1 (S (f1 + fq)) g1 (max g1 gq) _ _ _ _ ltac:(lia) ltac:(lia) H1).
    rewrite (m_mono s fq (S (S (S (f1 + fq)))) gq (max g1 gq) _ _ _ _ ltac:(lia) ltac:(lia) Hq).
    rewrite concat_app. simpl. rewrite app_nil_r. reflexivity.
Qed.
End XStar.

Lemma scan_term : forall a rr, core a = true -> forall k q,
  exists G c, scan (fun p => mb s G [R a] p rr) k q = Some c.
Proof.
  intros a rr Ha. induction k as [|k IH]; intros q; [exists 0, q; reflexivity|].
  destruct (mb_term [R a] q rr) as (Fq & b & Hq); [simpl; rewrite Ha; auto|].
  destruct (IH (S q)) as (G1 & c1 & H1).
  exists (max Fq G1). simpl. rewrite (mb_mono s Fq (max Fq G1) _ _ _ _ ltac:(lia) Hq).
  destruct b; [eauto|]. exists c1. eapply scan_ext; [|exact H1].
  intros p b' Hp. eapply mb_mono; [|exact Hp]. lia.
Qed.

Lemma cut_term : forall a i rr, core a = true -> exists G c, cut s G a i rr = Some c.
Proof. intros. unfold cut, occ. apply scan_term; auto. Qed.

(* ---------------------------------------------------------------- *)
(* Lemma 2: the stack relation and the per-construct equations of md *)

Fixpoint noset (ks : list item) : bool :=
  match ks with [] => true | SetRR _ :: _ | Ends _ :: _ => false | _ :: ks => noset ks end.

(* A direct item stack and a desugared one.  An absent construct is only
   followed by a stack with no SetRR (no absent construct inside an absent
   one); a SetRR (the end of AbsExp's exp) is only preceded by absent-free
   items, and its tail looks up the register saved at the construct's
   start. *)
Inductive rel (sv : list (nat * nat)) (rho : nat) : list item -> list ditem -> Prop :=
| r_nil : rel sv rho [] []
| r_R : forall x n ks dks, in_scope x = true -> core x = true \/ noset ks = true ->
    rel sv rho ks dks -> rel sv rho (R x :: ks) (DR (fst (desugar x n)) :: dks)
| r_Chk : forall i x n ks dks, in_scope x = true -> core x = true \/ noset ks = true ->
    rel sv rho ks dks -> rel sv rho (Chk i x :: ks) (DChk i (fst (desugar x n)) :: dks)
| r_set : forall k n n3 ks dks, noset ks = true -> rel sv rho ks dks -> lookup n sv = Some k ->
    n3 <> n -> rho <= k -> k <= length s ->
    rel sv rho (SetRR k :: ks) (DR (DSeq (tail n n3) DEps) :: dks).

Lemma rel_free : forall sv rho ks dks, rel sv rho ks dks -> noset ks = true ->
  forall sv' rho', rel sv' rho' ks dks.
Proof. induction 1; intros Hn sv' rho'; simpl in Hn; try discriminate; constructor; auto. Qed.

Lemma ds_seq : forall a b n,
  fst (desugar (Seq a b) n) = DSeq (fst (desugar a n)) (fst (desugar b (snd (desugar a n)))).
Proof. intros. simpl. destruct (desugar a n) as [da n1]. simpl. destruct (desugar b n1). reflexivity. Qed.
Lemma ds_alt : forall a b n,
  fst (desugar (Alt a b) n) = DAlt (fst (desugar a n)) (fst (desugar b (snd (desugar a n)))).
Proof. intros. simpl. destruct (desugar a n) as [da n1]. simpl. destruct (desugar b n1). reflexivity. Qed.
Lemma ds_star : forall a n, fst (desugar (Star a) n) = DStar (fst (desugar a n)).
Proof. intros. simpl. destruct (desugar a n). reflexivity. Qed.

Lemma simple_step_eq : forall e c, simple_step e = Some c -> e = Star (Chr c).
Proof. destruct e; try discriminate. destruct e; try discriminate. intros c' H. injection H as ->. reflexivity. Qed.

Lemma ds_gen : forall a e n, simple_step e = None ->
  fst (desugar (AbsExp a e) n) =
  dseq [DSaveRR n; DSaveS (S n); engine n (n + 2) (emb a) DAnyO true;
        DUpdSFromStack (S n); emb e; tail n (n + 3)].
Proof. intros a e n H. simpl. rewrite H. reflexivity. Qed.

Lemma or_two : forall a b ks, core a && core b = true \/ noset ks = true ->
  (core a = true \/ noset ks = true) /\ (core b = true \/ noset ks = true).
Proof. intros a b ks [H|H]; [apply andb_prop in H|]; intuition. Qed.

Definition Ur (n : nat) (dks : list ditem) : list ditem := DR (DSeq (DUpdRRFromStack n) DEps) :: dks.
Definition rst (n : nat) : dre := dseq [DUpdRRFromStack n; DFail].

Lemma md_rst : forall f n k i x sv y, lookup n sv = Some y ->
  md s (S (S (S (S f)))) (DR (rst n) :: k) i x sv = Some ([], y).
Proof. intros. simpl. rewrite H. reflexivity. Qed.

Lemma md_rst_inv : forall f n k i x sv y r z, lookup n sv = Some y ->
  md s f (DR (rst n) :: k) i x sv = Some (r, z) -> r = [] /\ z = y.
Proof.
  intros f n k i x sv y r z Hy H. unfold rst, dseq in H.
  destruct f as [|[|[|[|f]]]]; simpl in H; rewrite ?Hy in H; simpl in H; try discriminate.
  injection H as <- <-. auto.
Qed.

Lemma md_Ur : forall f n dks e x sv y, lookup n sv = Some y ->
  md s (S (S (S f))) (Ur n dks) e x sv = md s f dks e y sv.
Proof. intros. simpl. rewrite H. reflexivity. Qed.

Lemma md_Ur_inv : forall f n dks e x sv y v, lookup n sv = Some y ->
  md s f (Ur n dks) e x sv = Some v -> exists f', f' < f /\ md s f' dks e y sv = Some v.
Proof.
  intros f n dks e x sv y v Hy H.
  destruct f as [|[|[|f]]]; [discriminate|discriminate|simpl in H; rewrite Hy in H; discriminate|].
  rewrite md_Ur with (y := y) in H by exact Hy. exists f. split; [lia|exact H].
Qed.

Lemma md_simple_eq : forall F n a st dks i rr sv,
  md s (S (S (S (S F)))) (DR (dseq [DSaveRR n; engine n (S n) (emb a) st false; DUpdRRFromStack n]) :: dks) i rr sv =
  match md s F (DR (DStar (body (S n) a st)) :: Ur n dks) i rr ((n, rr) :: sv) with
  | Some (r1, x1) => match md s F (DR (rst n) :: Ur n dks) i x1 ((n, rr) :: sv) with
                     | Some (r2, x2) => Some (r1 ++ r2, x2) | None => None end
  | None => None end.
Proof. reflexivity. Qed.

Definition sv1 (n i rr : nat) (sv : list (nat * nat)) := (S n, i) :: (n, rr) :: sv.

Lemma md_gen_eq : forall F n a REST dks i rr sv,
  md s (S (S (S (S (S (S F))))))
    (DR (DSeq (DSaveRR n) (DSeq (DSaveS (S n)) (DSeq (engine n (n + 2) (emb a) DAnyO true)
       (DSeq (DUpdSFromStack (S n)) REST)))) :: dks) i rr sv =
  match md s F (DR (DAtomic (DStar (body (n + 2) a DAnyO))) :: DR (DSeq (DUpdSFromStack (S n)) REST) :: dks)
          i rr (sv1 n i rr sv) with
  | Some (r1, x1) => match md s F (DR (rst n) :: DR (DSeq (DUpdSFromStack (S n)) REST) :: dks) i x1 (sv1 n i rr sv) with
                     | Some (r2, x2) => Some (r1 ++ r2, x2) | None => None end
  | None => None end.
Proof. reflexivity. Qed.

Lemma md_atomic_eq : forall F X k i rr sv,
  md s (S F) (DR (DAtomic X) :: k) i rr sv =
  match md s F [DR X] i rr sv with
  | Some ((e, rr', sv') :: _, _) => md s F k e rr' sv'
  | Some ([], rr') => Some ([], rr')
  | None => None end.
Proof. reflexivity. Qed.

Lemma lookup_sv1_n : forall n i rr sv, lookup n (sv1 n i rr sv) = Some rr.
Proof.
  intros. assert (H : Nat.eqb (S n) n = false) by (apply Nat.eqb_neq; lia).
  unfold sv1. cbn -[Nat.eqb]. rewrite H, Nat.eqb_refl. reflexivity.
Qed.
Lemma lookup_sv1_Sn : forall n i rr sv, lookup (S n) (sv1 n i rr sv) = Some i.
Proof. intros. simpl. rewrite Nat.eqb_refl. reflexivity. Qed.

Lemma md_U2 : forall F n REST dks e x i sv, lookup (S n) sv = Some i ->
  md s (S (S (S F))) (DR (DSeq (DUpdSFromStack (S n)) REST) :: dks) e x sv = md s (S F) (DR REST :: dks) i x sv.
Proof. intros. simpl. rewrite H. reflexivity. Qed.

Lemma md_tail_eq : forall F n n3 dks i rr sv,
  md s (S (S (S (S F)))) (DR (DSeq (tail n n3) DEps) :: dks) i rr sv =
  match md s F (DR (DUpdRRFromStack n) :: DR DEps :: dks) i rr ((n3, rr) :: sv) with
  | Some (r1, x1) => match md s F (DR (rst n3) :: DR DEps :: dks) i x1 ((n3, rr) :: sv) with
                     | Some (r2, x2) => Some (r1 ++ r2, x2) | None => None end
  | None => None end.
Proof. reflexivity. Qed.

Lemma md_upd_eps : forall F n dks i x sv y, lookup n sv = Some y ->
  md s (S (S F)) (DR (DUpdRRFromStack n) :: DR DEps :: dks) i x sv = md s F dks i y sv.
Proof. intros. simpl. rewrite H. reflexivity. Qed.

Lemma md_rclear_eq : forall F n dks i rr sv,
  md s (S (S (S (S F)))) (DR (fst (desugar RClear n)) :: dks) i rr sv =
  match md s F (DR DRRInit :: DR DEps :: dks) i rr ((n, rr) :: sv) with
  | Some (r1, x1) => match md s F (DR (rst n) :: DR DEps :: dks) i x1 ((n, rr) :: sv) with
                     | Some (r2, x2) => Some (r1 ++ r2, x2) | None => None end
  | None => None end.
Proof. reflexivity. Qed.

Lemma md_rrinit : forall F dks i x sv,
  md s (S (S F)) (DR DRRInit :: DR DEps :: dks) i x sv = md s F dks i (length s) sv.
Proof. reflexivity. Qed.

Lemma lookup_cons_ne : forall n n3 v sv, n3 <> n -> lookup n ((n3, v) :: sv) = lookup n sv.
Proof.
  intros. assert (H' : Nat.eqb n3 n = false) by (apply Nat.eqb_neq; lia).
  cbn -[Nat.eqb]. rewrite H'. reflexivity.
Qed.

Lemma ends_app : forall a b, ends (a ++ b) = ends a ++ ends b.
Proof. intros. unfold ends. apply map_app. Qed.
Lemma ends_concat : forall Rs, ends (concat Rs) = concat (map ends Rs).
Proof. induction Rs; simpl; auto. rewrite ends_app, IHRs. reflexivity. Qed.

Lemma at_some : forall p rr, p < rr -> rr <= length s -> exists c, at_ s p rr = Some c.
Proof.
  intros p rr H1 H2. unfold at_. destruct (Nat.ltb_spec p rr); [|lia].
  destruct (nth_error s p) eqn:E; [eauto|apply nth_error_None in E; lia].
Qed.

Lemma at_mono : forall p c rr, p < c -> c <= rr -> at_ s p rr = at_ s p c.
Proof.
  intros. unfold at_. destruct (Nat.ltb_spec p rr); destruct (Nat.ltb_spec p c); auto; lia.
Qed.

Lemma at_none_self : forall p, at_ s p p = None.
Proof. intros. unfold at_. rewrite Nat.ltb_irrefl. reflexivity. Qed.

(* Steps of the two engines: AnyO (AbsRep, general path, stopper) and
   Chr c (simple path of AbsExp). *)
Definition stpO (q x : nat) : bool := match at_ s q x with Some _ => true | None => false end.
Definition stpC (ch q x : nat) : bool := match at_ s q x with Some c' => Nat.eqb ch c' | None => false end.

Lemma stpO_ok : step_ok DAnyO stpO.
Proof. intros f q x rest sv'. simpl. unfold stpO. destruct (at_ s q x); reflexivity. Qed.
Lemma stpO_lt : step_lt stpO.
Proof. intros q x H. unfold stpO in H. destruct (at_ s q x) eqn:E; [|discriminate]. eapply at_lt; eauto. Qed.
Lemma stpC_ok : forall ch, step_ok (DChr ch) (stpC ch).
Proof. intros ch f q x rest sv'. simpl. unfold stpC. destruct (at_ s q x); [destruct (Nat.eqb ch n)|]; reflexivity. Qed.
Lemma stpC_lt : forall ch, step_lt (stpC ch).
Proof. intros ch q x H. unfold stpC in H. destruct (at_ s q x) eqn:E; [|discriminate]. eapply at_lt; eauto. Qed.

Lemma stp_self : forall ch q, stpO q q = false /\ stpC ch q q = false.
Proof. intros. unfold stpO, stpC. rewrite at_none_self. auto. Qed.

(* The cut seen from the direct side: the register value the engine leaves
   at the cut position is the cut itself. *)
Lemma cut_top : forall g a i rr c, core a = true -> i <= rr ->
  cut s g a i rr = Some c ->
  i <= c /\ c <= rr /\ (forall p, i <= p < c -> mb s g [R a] p rr = Some false)
  /\ exists bt, (exists F, mb s F [R a] c rr = Some bt) /\ (if bt then c else rr) = c.
Proof.
  intros g a i rr c Ha Hi Hc. unfold cut, occ in Hc. apply scan_spec in Hc as (H1 & H2 & H3).
  split; [lia|split; [destruct H3 as [H3|[H3 _]]; lia|split; [exact H2|]]].
  destruct H3 as [H3|[H3 H4]].
  - destruct (mb_term [R a] c rr) as (F & bt & Hbt); [simpl; rewrite Ha; auto|].
    exists bt. split; eauto. destruct bt; lia.
  - exists true. eauto.
Qed.

Lemma F2_lift : forall {A B C} (P : A -> B -> Prop) (Q : A -> C -> Prop) (fn : C -> B) l1 l2,
  Forall2 P l1 l2 -> (forall x y, In x l1 -> P x y -> exists z, Q x z /\ fn z = y) ->
  exists l3, Forall2 Q l1 l3 /\ l2 = map fn l3.
Proof.
  intros A B C P Q fn l1 l2 H. induction H as [|x y l1 l2 Hxy H IH]; intros HQ; [exists []; auto|].
  destruct (HQ x y (or_introl eq_refl) Hxy) as (z & Hz & <-).
  destruct IH as (l3 & H3 & ->); [intros x' y' Hin Hp; apply HQ; [right; exact Hin|exact Hp]|].
  exists (z :: l3). split; [constructor; auto|reflexivity].
Qed.

Lemma Forall2_map_r : forall {A B} (P : A -> B -> Prop) (fn : A -> B) l,
  (forall x, In x l -> P x (fn x)) -> Forall2 P l (map fn l).
Proof. intros A B P fn l H. induction l; simpl; constructor; auto. apply H; left; auto. apply IHl. intros; apply H; right; auto. Qed.

Lemma simple_intro : forall Fs n a st dks i rr sv rs,
  md s Fs (DR (DStar (body (S n) a st)) :: Ur n dks) i rr ((n, rr) :: sv) = Some (rs, rr) ->
  exists F, md s F (DR (dseq [DSaveRR n; engine n (S n) (emb a) st false; DUpdRRFromStack n]) :: dks) i rr sv = Some (rs, rr).
Proof.
  intros. exists (S (S (S (S (S (S (S (S Fs)))))))). rewrite md_simple_eq.
  rewrite (md_lift _ _ _ _ _ _ H (S (S (S (S Fs))))) by lia.
  rewrite md_rst with (y := rr) by (simpl; rewrite Nat.eqb_refl; reflexivity).
  rewrite app_nil_r. reflexivity.
Qed.

Lemma gen_intro : forall Fs Fk n a REST dks i rr sv t y rs c,
  md s Fs [DR (DStar (body (n + 2) a DAnyO))] i rr (sv1 n i rr sv) = Some ((c, c, sv1 n i rr sv) :: t, y) ->
  md s Fk (DR REST :: dks) i c (sv1 n i rr sv) = Some (rs, c) ->
  exists F, md s F (DR (DSeq (DSaveRR n) (DSeq (DSaveS (S n)) (DSeq (engine n (n + 2) (emb a) DAnyO true)
       (DSeq (DUpdSFromStack (S n)) REST)))) :: dks) i rr sv = Some (rs, rr).
Proof.
  intros Fs Fk n a REST dks i rr sv t y rs c H H0.
  exists (S (S (S (S (S (S (S (S (S (S (Fs + Fk))))))))))).
  rewrite md_gen_eq, md_atomic_eq. rewrite (md_lift _ _ _ _ _ _ H (S (S (S (Fs + Fk))))) by lia.
  rewrite md_U2 with (i := i) by apply lookup_sv1_Sn.
  rewrite (md_lift _ _ _ _ _ _ H0 (S (Fs + Fk))) by lia.
  rewrite md_rst with (y := rr) by apply lookup_sv1_n. rewrite app_nil_r. reflexivity.
Qed.

Lemma rclear_intro : forall Fe n dks i rr sv rs y,
  md s Fe dks i (length s) ((n, rr) :: sv) = Some (rs, y) ->
  exists F, md s F (DR (fst (desugar RClear n)) :: dks) i rr sv = Some (rs, rr).
Proof.
  intros. exists (S (S (S (S (S (S (S (S Fe)))))))). rewrite md_rclear_eq.
  rewrite (md_rrinit (S (S Fe))). rewrite (md_lift _ _ _ _ _ _ H (S (S Fe))) by lia.
  rewrite md_rst with (y := rr) by (simpl; rewrite Nat.eqb_refl; reflexivity).
  rewrite app_nil_r. reflexivity.
Qed.

Lemma tail_intro : forall Fe n n3 dks i rr sv k rs y, lookup n sv = Some k -> n3 <> n ->
  md s Fe dks i k ((n3, rr) :: sv) = Some (rs, y) ->
  exists F, md s F (DR (DSeq (tail n n3) DEps) :: dks) i rr sv = Some (rs, rr).
Proof.
  intros Fe n n3 dks i rr sv k rs y Hk Hn H. exists (S (S (S (S (S (S (S (S Fe)))))))).
  rewrite md_tail_eq. rewrite (md_upd_eps (S (S Fe)) n dks i rr ((n3, rr) :: sv) k) by (rewrite lookup_cons_ne; auto).
  rewrite (md_lift _ _ _ _ _ _ H (S (S Fe))) by lia.
  rewrite md_rst with (y := rr) by (simpl; rewrite Nat.eqb_refl; reflexivity).
  rewrite app_nil_r. reflexivity.
Qed.

(* (g), direction (2a): a complete list of the direct matcher is the list
   of ends of md on the desugared stack for some fuel, and md ends with
   the register it started with. *)
Theorem sim_a : forall g f ks i rr l, m s g f ks i rr = Some l ->
  forall dks sv, rel sv rr ks dks -> i <= rr -> rr <= length s ->
  exists F rs, md s F dks i rr sv = Some (rs, rr) /\ ends rs = l.
Proof.
  intros g f. induction f as [f IH] using (well_founded_induction lt_wf).
  intros ks i rr l Hm dks sv Hrel Hi Hrr.
  destruct f as [|f]; [discriminate|].
  destruct Hrel as [|x n ks dks Hx Hor Hrel|i0 x n ks dks Hx Hor Hrel|k n n3 ks dks Hns Hrel Hk Hn3 Hrk Hkl].
  - simpl in Hm. injection Hm as <-. exists 1, [(i, rr, sv)]. split; reflexivity.
  - destruct x as [|c| | |a b|a b|a|a|a e|a|]; simpl in Hx.
    + (* Eps *)
      simpl in Hm. destruct (IH f ltac:(lia) ks i rr l Hm dks sv Hrel Hi Hrr) as (F & rs & H & He).
      exists (S F), rs. split; [exact H|exact He].
    + (* Chr *)
      simpl in Hm. destruct (at_ s i rr) as [c'|] eqn:Ea; [destruct (Nat.eqb c c') eqn:Ec|].
      * destruct (IH f ltac:(lia) ks (S i) rr l Hm dks sv Hrel) as (F & rs & H & He); [apply at_lt in Ea; lia|auto|].
        exists (S F), rs. split; [simpl; rewrite Ea, Ec; exact H|exact He].
      * injection Hm as <-. exists 1, []. split; [simpl; rewrite Ea, Ec; reflexivity|reflexivity].
      * injection Hm as <-. exists 1, []. split; [simpl; rewrite Ea; reflexivity|reflexivity].
    + (* Any *)
      simpl in Hm. destruct (at_ s i rr) as [c'|] eqn:Ea; [destruct (Nat.eqb c' 10) eqn:Ec|].
      * injection Hm as <-. exists 1, []. split; [simpl; rewrite Ea, Ec; reflexivity|reflexivity].
      * destruct (IH f ltac:(lia) ks (S i) rr l Hm dks sv Hrel) as (F & rs & H & He); [apply at_lt in Ea; lia|auto|].
        exists (S F), rs. split; [simpl; rewrite Ea, Ec; exact H|exact He].
      * injection Hm as <-. exists 1, []. split; [simpl; rewrite Ea; reflexivity|reflexivity].
    + (* AnyO *)
      simpl in Hm. destruct (at_ s i rr) as [c'|] eqn:Ea.
      * destruct (IH f ltac:(lia) ks (S i) rr l Hm dks sv Hrel) as (F & rs & H & He); [apply at_lt in Ea; lia|auto|].
        exists (S F), rs. split; [simpl; rewrite Ea; exact H|exact He].
      * injection Hm as <-. exists 1, []. split; [simpl; rewrite Ea; reflexivity|reflexivity].
    + (* Seq *)
      apply or_two in Hor as [Ha Hb]. apply andb_prop in Hx as [Hxa Hxb]. simpl in Hm.
      destruct (IH f ltac:(lia) (R a :: R b :: ks) i rr l Hm
        (DR (fst (desugar a n)) :: DR (fst (desugar b (snd (desugar a n)))) :: dks) sv) as (F & rs & H & He); auto.
      { apply r_R; [exact Hxa|destruct Ha; [left|right]; auto|apply r_R; auto]. }
      exists (S F), rs. rewrite ds_seq. split; [exact H|exact He].
    + (* Alt *)
      apply or_two in Hor as [Ha Hb]. apply andb_prop in Hx as [Hxa Hxb]. simpl in Hm. unfold oapp in Hm.
      destruct (m s g f (R a :: ks) i rr) as [l1|] eqn:E1; [|discriminate].
      destruct (m s g f (R b :: ks) i rr) as [l2|] eqn:E2; [|discriminate]. injection Hm as <-.
      destruct (IH f ltac:(lia) (R a :: ks) i rr l1 E1 (DR (fst (desugar a n)) :: dks) sv) as (F1 & rs1 & H1 & He1); auto.
      { apply r_R; auto. }
      destruct (IH f ltac:(lia) (R b :: ks) i rr l2 E2 (DR (fst (desugar b (snd (desugar a n)))) :: dks) sv) as (F2 & rs2 & H2 & He2); auto.
      { apply r_R; auto. }
      exists (S (F1 + F2)), (rs1 ++ rs2). rewrite ds_alt.
      split; [apply md_alt_intro with (x1 := rr); auto|rewrite ends_app; congruence].
    + (* Star *)
      simpl in Hm. unfold oapp in Hm.
      destruct (m s g f (R a :: Chk i a :: ks) i rr) as [l1|] eqn:E1; [|discriminate].
      destruct (m s g f ks i rr) as [l2|] eqn:E2; [|discriminate]. injection Hm as <-.
      destruct (IH f ltac:(lia) (R a :: Chk i a :: ks) i rr l1 E1
        (DR (fst (desugar a n)) :: DChk i (fst (desugar a n)) :: dks) sv) as (F1 & rs1 & H1 & He1); auto.
      { apply r_R; [exact Hx|destruct Hor; [left|right]; auto|apply r_Chk; auto]. }
      destruct (IH f ltac:(lia) ks i rr l2 E2 dks sv) as (F2 & rs2 & H2 & He2); auto.
      exists (S (F1 + F2)), (rs1 ++ rs2). rewrite ds_star.
      split; [apply md_star_intro with (x1 := rr); auto|rewrite ends_app; congruence].
    + (* AbsRep *)
      destruct Hor as [Hor|Hns]; [discriminate|].
      simpl in Hm. unfold rep_ends in Hm.
      destruct (cut s g a i rr) as [c|] eqn:Ec; [|discriminate].
      apply m_ends_a in Hm as (ls & Hls & ->).
      destruct (cut_top g a i rr c Hx Hi Ec) as (Hic & Hcr & Hpre & bt & Hbt & Hxt).
      set (sv' := (n, rr) :: sv).
      destruct (F2_lift _ (fun e R => exists F, md s F dks e rr sv' = Some (R, rr)) ends _ _ Hls) as (Rs & HRs & ->).
      { intros e le He (fe & Hfe & Hme). apply downs_mem in He.
        destruct (IH fe ltac:(lia) ks e rr le Hme dks sv') as (F & rs & H & He'); [apply rel_free with sv rr; auto|lia|auto|].
        exists rs. split; eauto. }
      destruct (scan_a (S n) a DAnyO stpO (Ur n dks) (fun _ => rr) sv' rr Hx stpO_ok stpO_lt (c - i) i c bt Rs) as [Fs Hs].
      * lia.
      * intros p Hp. split; [exists g; apply Hpre; lia|].
        destruct (at_some p rr) as [c' Hc']; [lia|auto|]. unfold stpO. rewrite Hc'. reflexivity.
      * exact Hbt.
      * rewrite Hxt. exact (proj1 (stp_self 0 c)).
      * eapply Forall2_impl; [|exact HRs]. intros e R [F H] x _. exists (S (S (S F))).
        rewrite md_Ur with (y := rr) by (simpl; rewrite Nat.eqb_refl; reflexivity). exact H.
      * destruct (simple_intro Fs n a DAnyO dks i rr sv (concat Rs) Hs) as [F HF].
        exists F, (concat Rs). split; [exact HF|apply ends_concat].
    + (* AbsExp *)
      apply andb_prop in Hx as [Ha He]. destruct Hor as [Hor|Hns]; [discriminate|].
      simpl in Hm. destruct (cut s g a i rr) as [c|] eqn:Ec; [|discriminate].
      destruct (cut_top g a i rr c Ha Hi Ec) as (Hic & Hcr & Hpre & bt0 & Hbt0 & Hxt0).
      destruct (simple_step e) as [ch|] eqn:Ess.
      * (* simple path *)
        apply simple_step_eq in Ess. subst e.
        apply (mstar_a ch) in Hm as (top & ls & Hit & Hch & Htop & Hls & ->).
        assert (Htc : top <= c).
        { destruct (Nat.le_gt_cases top c) as [|Hlt]; auto. specialize (Hch c ltac:(lia)). apply at_lt in Hch. lia. }
        set (sv' := (n, rr) :: sv).
        destruct (F2_lift _ (fun e R => exists F, md s F dks e rr sv' = Some (R, rr)) ends _ _ Hls) as (Rs & HRs & ->).
        { intros e le Hin (fe & Hfe & Hme). apply downs_mem in Hin.
          destruct fe as [|fe]; [discriminate|]. simpl in Hme.
          destruct (IH fe ltac:(lia) ks e rr le Hme dks sv') as (F & rs & H & He'); [apply rel_free with sv rr; auto|lia|auto|].
          exists rs. split; eauto. }
        assert (Hbt : exists bt, (exists F, mb s F [R a] top rr = Some bt) /\ stpC ch top (if bt then top else rr) = false).
        { destruct (Nat.eq_dec top c) as [->|Hne].
          - exists bt0. split; auto. rewrite Hxt0. exact (proj2 (stp_self ch c)).
          - exists false. split; [exists g; apply Hpre; lia|].
            unfold stpC. rewrite (at_mono top c rr) by lia. destruct (at_ s top c) as [c'|] eqn:Ea; auto.
            destruct (Nat.eqb_spec ch c'); [subst; contradiction|reflexivity]. }
        destruct Hbt as (bt & Hbt & Hstop).
        destruct (scan_a (S n) a (DChr ch) (stpC ch) (Ur n dks) (fun _ => rr) sv' rr Ha (stpC_ok ch) (stpC_lt ch)
                    (top - i) i top bt Rs) as [Fs Hs].
        -- lia.
        -- intros p Hp. split; [exists g; apply Hpre; lia|]. unfold stpC.
           rewrite (at_mono p c rr) by lia. rewrite Hch by lia. apply Nat.eqb_refl.
        -- exact Hbt.
        -- exact Hstop.
        -- eapply Forall2_impl; [|exact HRs]. intros e R [F H] x _. exists (S (S (S F))).
           rewrite md_Ur with (y := rr) by (simpl; rewrite Nat.eqb_refl; reflexivity). exact H.
        -- destruct (simple_intro Fs n a (DChr ch) dks i rr sv (concat Rs) Hs) as [F HF].
           exists F, (concat Rs). split; [exact HF|apply ends_concat].
      * (* general path *)
        set (s1 := sv1 n i rr sv).
        destruct (IH f ltac:(lia) (R e :: SetRR rr :: ks) i c l Hm
          (DR (fst (desugar e 0)) :: DR (DSeq (tail n (n + 3)) DEps) :: dks) s1) as (Fe & rs & H & He'); [|lia|lia|].
        { apply r_R; [apply core_in_scope; auto|left; auto|].
          apply r_set; auto; [apply rel_free with sv rr; auto|apply lookup_sv1_n|lia]. }
        rewrite core_desugar in H by auto. simpl fst in H.
        destruct (downs_hd (c - i) i) as [tl Htl].
        destruct (scan_a (n + 2) a DAnyO stpO [] (fun x => x) s1 rr Ha stpO_ok stpO_lt (c - i) i c bt0
                    (map (fun e0 => [(e0, c, s1)]) (downs (c - i) i))) as [Fs Hs].
        -- lia.
        -- intros p Hp. split; [exists g; apply Hpre; lia|].
           destruct (at_some p rr) as [c' Hc']; [lia|auto|]. unfold stpO. rewrite Hc'. reflexivity.
        -- exact Hbt0.
        -- rewrite Hxt0. exact (proj1 (stp_self 0 c)).
        -- apply Forall2_map_r. intros e0 _ x Hx0. cbv beta in *. rewrite Hxt0 in *.
           exists 1. destruct Hx0 as [-> | ->]; reflexivity.
        -- rewrite Htl in Hs. simpl in Hs. rewrite Hxt0 in Hs. replace (i + (c - i)) with c in Hs by lia.
           destruct (gen_intro Fs (S Fe) n a (DSeq (emb e) (DSeq (tail n (n + 3)) DEps)) dks i rr sv _ _ rs c Hs H) as [F HF].
           exists F, rs. split; [|exact He']. rewrite ds_gen by exact Ess. exact HF.
    + (* Stopper *)
      destruct Hor as [Hor|Hns]; [discriminate|].
      simpl in Hm. destruct (cut s g a i rr) as [c|] eqn:Ec; [|discriminate].
      destruct (cut_top g a i rr c Hx Hi Ec) as (Hic & Hcr & Hpre & bt0 & Hbt0 & Hxt0).
      set (s1 := sv1 n i rr sv).
      destruct (IH f ltac:(lia) ks i c l Hm dks s1) as (Fe & rs & H & He'); [apply rel_free with sv rr; auto|lia|lia|].
      destruct (downs_hd (c - i) i) as [tl Htl].
      destruct (scan_a (n + 2) a DAnyO stpO [] (fun x => x) s1 rr Hx stpO_ok stpO_lt (c - i) i c bt0
                  (map (fun e0 => [(e0, c, s1)]) (downs (c - i) i))) as [Fs Hs].
      * lia.
      * intros p Hp. split; [exists g; apply Hpre; lia|].
        destruct (at_some p rr) as [c' Hc']; [lia|auto|]. unfold stpO. rewrite Hc'. reflexivity.
      * exact Hbt0.
      * rewrite Hxt0. exact (proj1 (stp_self 0 c)).
      * apply Forall2_map_r. intros e0 _ x Hx0. cbv beta in *. rewrite Hxt0 in *.
        exists 1. destruct Hx0 as [-> | ->]; reflexivity.
      * rewrite Htl in Hs. simpl in Hs. rewrite Hxt0 in Hs. replace (i + (c - i)) with c in Hs by lia.
        destruct (gen_intro Fs (S Fe) n a DEps dks i rr sv _ _ rs c Hs H) as [F HF].
        exists F, rs. split; [exact HF|exact He'].
    + (* RClear *)
      destruct Hor as [Hor|Hns]; [discriminate|]. simpl in Hm.
      destruct (IH f ltac:(lia) ks i (length s) l Hm dks ((n, rr) :: sv)) as (Fe & rs & H & He');
        [apply rel_free with sv rr; auto|lia|lia|].
      destruct (rclear_intro Fe n dks i rr sv rs (length s) H) as [F HF].
      exists F, rs. split; [exact HF|exact He'].
  - (* Chk *)
    simpl in Hm. destruct (Nat.eqb i i0) eqn:E.
    + destruct (IH f ltac:(lia) ks i rr l Hm dks sv Hrel Hi Hrr) as (F & rs & H & He).
      exists (S F), rs. split; [simpl; rewrite E; exact H|exact He].
    + destruct (IH f ltac:(lia) (R (Star x) :: ks) i rr l Hm (DR (fst (desugar (Star x) n)) :: dks) sv)
        as (F & rs & H & He); auto; [apply r_R; auto|].
      rewrite ds_star in H. exists (S F), rs. split; [simpl; rewrite E; exact H|exact He].
  - (* SetRR *)
    simpl in Hm.
    destruct (IH f ltac:(lia) ks i k l Hm dks ((n3, rr) :: sv)) as (Fe & rs & H & He');
      [apply rel_free with sv rr; auto|lia|lia|].
    destruct (tail_intro Fe n n3 dks i rr sv k rs k Hk Hn3 H) as [F HF].
    exists F, rs. split; [exact HF|exact He'].
Qed.

(* ---------------------------------------------------------------- *)
(* Direction (2b): inversion lemmas *)

Lemma Forall2_map_impl : forall {A B C} (P : A -> B -> Prop) (Q : A -> C -> Prop) (fn : B -> C) l1 l2,
  Forall2 P l1 l2 -> (forall x y, In x l1 -> P x y -> Q x (fn y)) -> Forall2 Q l1 (map fn l2).
Proof.
  intros A B C P Q fn l1 l2 H. induction H; intros HQ; simpl; constructor.
  - apply HQ; [left|]; auto.
  - apply IHForall2. intros; apply HQ; [right|]; auto.
Qed.

Lemma simple_inv : forall F n a st dks i rr sv rs x,
  md s F (DR (dseq [DSaveRR n; engine n (S n) (emb a) st false; DUpdRRFromStack n]) :: dks) i rr sv = Some (rs, x) ->
  exists F' x1, F' < F /\ md s F' (DR (DStar (body (S n) a st)) :: Ur n dks) i rr ((n, rr) :: sv) = Some (rs, x1) /\ x = rr.
Proof.
  intros F n a st dks i rr sv rs x H. destruct F as [|[|[|[|F]]]]; try discriminate.
  rewrite md_simple_eq in H.
  destruct (md s F (DR (DStar (body (S n) a st)) :: Ur n dks) i rr ((n, rr) :: sv)) as [[r1 x1]|] eqn:E1; [|discriminate].
  destruct (md s F (DR (rst n) :: Ur n dks) i x1 ((n, rr) :: sv)) as [[r2 x2]|] eqn:E2; [|discriminate].
  injection H as <- <-. apply md_rst_inv with (y := rr) in E2 as [-> ->]; [|simpl; rewrite Nat.eqb_refl; reflexivity].
  exists F, x1. rewrite app_nil_r. split; [lia|auto].
Qed.

Lemma gen_inv : forall F n a REST dks i rr sv rs x,
  md s F (DR (DSeq (DSaveRR n) (DSeq (DSaveS (S n)) (DSeq (engine n (n + 2) (emb a) DAnyO true)
       (DSeq (DUpdSFromStack (S n)) REST)))) :: dks) i rr sv = Some (rs, x) ->
  x = rr /\ exists F' ra xa, F' < F /\ md s F' [DR (DStar (body (n + 2) a DAnyO))] i rr (sv1 n i rr sv) = Some (ra, xa) /\
    match ra with
    | (e0, r', sv'') :: _ => exists x1, md s F' (DR (DSeq (DUpdSFromStack (S n)) REST) :: dks) e0 r' sv'' = Some (rs, x1)
    | [] => rs = [] end.
Proof.
  intros F n a REST dks i rr sv rs x H. destruct F as [|[|[|[|[|[|F]]]]]]; try discriminate.
  rewrite md_gen_eq in H.
  destruct (md s F (DR (DAtomic (DStar (body (n + 2) a DAnyO))) :: DR (DSeq (DUpdSFromStack (S n)) REST) :: dks) i rr (sv1 n i rr sv))
    as [[r1 x1]|] eqn:E1; [|discriminate].
  destruct (md s F (DR (rst n) :: DR (DSeq (DUpdSFromStack (S n)) REST) :: dks) i x1 (sv1 n i rr sv)) as [[r2 x2]|] eqn:E2; [|discriminate].
  injection H as <- <-. apply md_rst_inv with (y := rr) in E2 as [-> ->]; [|apply lookup_sv1_n].
  split; [reflexivity|]. destruct F as [|F]; [discriminate|]. rewrite md_atomic_eq in E1.
  destruct (md s F [DR (DStar (body (n + 2) a DAnyO))] i rr (sv1 n i rr sv)) as [[ra xa]|] eqn:Ea; [|discriminate].
  exists F, ra, xa. split; [lia|split; [exact Ea|]].
  destruct ra as [|[[e0 r'] sv''] tl].
  - injection E1 as <- <-. reflexivity.
  - exists x1. rewrite app_nil_r. exact E1.
Qed.

Lemma md_U2_inv : forall f n REST dks e x sv i0 v, lookup (S n) sv = Some i0 ->
  md s f (DR (DSeq (DUpdSFromStack (S n)) REST) :: dks) e x sv = Some v ->
  exists f', f' < f /\ md s f' (DR REST :: dks) i0 x sv = Some v.
Proof.
  intros f n REST dks e x sv i0 v Hl H. destruct f as [|[|f]]; [discriminate|discriminate|].
  simpl in H. rewrite Hl in H. exists f. split; [lia|exact H].
Qed.

Lemma md_upd_eps_inv : forall f n dks i x sv y v, lookup n sv = Some y ->
  md s f (DR (DUpdRRFromStack n) :: DR DEps :: dks) i x sv = Some v ->
  exists f', f' < f /\ md s f' dks i y sv = Some v.
Proof.
  intros f n dks i x sv y v Hl H. destruct f as [|[|f]]; [discriminate| |].
  - simpl in H. rewrite Hl in H. discriminate.
  - simpl in H. rewrite Hl in H. exists f. split; [lia|exact H].
Qed.

Lemma tail_inv : forall F n n3 dks i rr sv k rs x, lookup n sv = Some k -> n3 <> n ->
  md s F (DR (DSeq (tail n n3) DEps) :: dks) i rr sv = Some (rs, x) ->
  x = rr /\ exists F' y, F' < F /\ md s F' dks i k ((n3, rr) :: sv) = Some (rs, y).
Proof.
  intros F n n3 dks i rr sv k rs x Hk Hn H. destruct F as [|[|[|[|F]]]]; try discriminate.
  rewrite md_tail_eq in H.
  destruct (md s F (DR (DUpdRRFromStack n) :: DR DEps :: dks) i rr ((n3, rr) :: sv)) as [[r1 x1]|] eqn:E1; [|discriminate].
  destruct (md s F (DR (rst n3) :: DR DEps :: dks) i x1 ((n3, rr) :: sv)) as [[r2 x2]|] eqn:E2; [|discriminate].
  injection H as <- <-. apply md_rst_inv with (y := rr) in E2 as [-> ->]; [|simpl; rewrite Nat.eqb_refl; reflexivity].
  split; [reflexivity|].
  apply md_upd_eps_inv with (y := k) in E1 as (f' & Hf' & E1); [|rewrite lookup_cons_ne; auto].
  exists f', x1. rewrite app_nil_r. split; [lia|exact E1].
Qed.

Lemma rclear_inv : forall F n dks i rr sv rs x,
  md s F (DR (fst (desugar RClear n)) :: dks) i rr sv = Some (rs, x) ->
  x = rr /\ exists F' y, F' < F /\ md s F' dks i (length s) ((n, rr) :: sv) = Some (rs, y).
Proof.
  intros F n dks i rr sv rs x H. destruct F as [|[|[|[|F]]]]; try discriminate.
  rewrite md_rclear_eq in H.
  destruct (md s F (DR DRRInit :: DR DEps :: dks) i rr ((n, rr) :: sv)) as [[r1 x1]|] eqn:E1; [|discriminate].
  destruct (md s F (DR (rst n) :: DR DEps :: dks) i x1 ((n, rr) :: sv)) as [[r2 x2]|] eqn:E2; [|discriminate].
  injection H as <- <-. apply md_rst_inv with (y := rr) in E2 as [-> ->]; [|simpl; rewrite Nat.eqb_refl; reflexivity].
  split; [reflexivity|]. destruct F as [|[|F]]; [discriminate|discriminate|].
  rewrite md_rrinit in E1. exists F, x1. rewrite app_nil_r. split; [lia|exact E1].
Qed.

Lemma m_absrep_eq : forall g f a ks i rr,
  m s g (S f) (R (AbsRep a) :: ks) i rr =
  match cut s g a i rr with Some c => m s g f (Ends (downs (c - i) i) :: ks) i rr | None => None end.
Proof. intros. simpl. unfold rep_ends. destruct (cut s g a i rr); reflexivity. Qed.
Lemma m_absexp_eq : forall g f a e ks i rr,
  m s g (S f) (R (AbsExp a e) :: ks) i rr =
  match cut s g a i rr with Some c => m s g f (R e :: SetRR rr :: ks) i c | None => None end.
Proof. reflexivity. Qed.
Lemma m_stopper_eq : forall g f a ks i rr,
  m s g (S f) (R (Stopper a) :: ks) i rr =
  match cut s g a i rr with Some c => m s g f ks i c | None => None end.
Proof. reflexivity. Qed.

(* The cut seen from the desugared side (AnyO step): the scan stops at the
   cut, and the register it leaves there is the cut. *)
Lemma cut_from_scan : forall G a i rr top bt, i <= rr -> rr <= length s -> i <= top ->
  (forall p, i <= p < top -> mb s G [R a] p rr = Some false /\ stpO p rr = true) ->
  mb s G [R a] top rr = Some bt -> stpO top (if bt then top else rr) = false ->
  cut s G a i rr = Some top /\ (if bt then top else rr) = top /\ top <= rr.
Proof.
  intros G a i rr top bt Hi Hrr Hit Hpre Hbt Hstop.
  assert (Htr : top <= rr).
  { destruct (Nat.eq_dec top i) as [->|]; [lia|]. destruct (Hpre (top - 1)) as [_ Hs]; [lia|].
    apply stpO_lt in Hs. lia. }
  assert (Hxt : (if bt then top else rr) = top).
  { destruct bt; auto. destruct (Nat.eq_dec top rr) as [->|Hne]; auto.
    destruct (at_some top rr) as [c' Hc']; [lia|auto|]. unfold stpO in Hstop. rewrite Hc' in Hstop. discriminate. }
  split; [|split; auto].
  unfold cut, occ. apply scan_intro; auto.
  - intros p Hp. apply Hpre; auto.
  - destruct bt.
    + destruct (Nat.eq_dec top rr) as [->|]; [left; lia|right; split; [lia|auto]].
    + left. lia.
Qed.

(* The same for the simple path (Chr ch step): the scan may stop before
   the cut, at the first position that is not ch. *)
Lemma simple_top : forall G a i rr top bt c ch, i <= rr -> i <= top ->
  (forall p, i <= p < top -> mb s G [R a] p rr = Some false /\ stpC ch p rr = true) ->
  mb s G [R a] top rr = Some bt -> stpC ch top (if bt then top else rr) = false ->
  cut s G a i rr = Some c ->
  top <= c /\ c <= rr /\ (forall p, i <= p < top -> at_ s p c = Some ch) /\ at_ s top c <> Some ch.
Proof.
  intros G a i rr top bt c ch Hi Hit Hpre Hbt Hstop Hc.
  unfold cut, occ in Hc. apply scan_spec in Hc as (Hic & Hpc & H3).
  assert (Hcr : c <= rr) by (destruct H3 as [H3|[H3 _]]; lia).
  assert (Htc : top <= c).
  { destruct (Nat.le_gt_cases top c) as [|Hlt]; auto.
    destruct (Hpre c) as [Hf Hs]; [lia|]. apply stpC_lt in Hs.
    destruct H3 as [H3|[_ H3]]; [lia|congruence]. }
  split; [exact Htc|split; [exact Hcr|split]].
  - intros p Hp. destruct (Hpre p Hp) as [_ Hs]. unfold stpC in Hs.
    destruct (at_ s p rr) as [c'|] eqn:Ea; [|discriminate]. apply Nat.eqb_eq in Hs. subst c'.
    rewrite <- (at_mono p c rr) by lia. exact Ea.
  - destruct (Nat.eq_dec top c) as [->|Hne]; [rewrite at_none_self; discriminate|].
    assert (bt = false) by (rewrite (Hpc top) in Hbt by lia; congruence). subst bt.
    rewrite <- (at_mono top c rr) by lia. intros Ea. unfold stpC in Hstop. rewrite Ea, Nat.eqb_refl in Hstop. discriminate.
Qed.

(* (g), direction (2b): a complete result of md on the desugared stack
   ends with the starting register, and its list of ends is a complete
   list of the direct matcher for some fuels. *)
Theorem sim_b : forall F dks i rr sv rs x, md s F dks i rr sv = Some (rs, x) ->
  forall ks, rel sv rr ks dks -> i <= rr -> rr <= length s ->
  x = rr /\ exists g f, m s g f ks i rr = Some (ends rs).
Proof.
  intros F. induction F as [F IH] using (well_founded_induction lt_wf).
  intros dks i rr sv rs x H ks Hrel Hi Hrr.
  destruct F as [|F]; [discriminate|].
  destruct Hrel as [|x0 n ks dks Hx Hor Hrel|i0 x0 n ks dks Hx Hor Hrel|k n n3 ks dks Hns Hrel Hk Hn3 Hrk Hkl].
  - simpl in H. injection H as <- <-. split; [reflexivity|]. exists 0, 1. reflexivity.
  - destruct x0 as [|c| | |a b|a b|a|a|a e|a|]; simpl in Hx.
    + (* Eps *)
      simpl in H. destruct (IH F ltac:(lia) dks i rr sv rs x H ks Hrel Hi Hrr) as [-> (g & f & Hm)].
      split; [reflexivity|]. exists g, (S f). exact Hm.
    + (* Chr *)
      simpl in H. destruct (at_ s i rr) as [c'|] eqn:Ea; [destruct (Nat.eqb c c') eqn:Ec|].
      * destruct (IH F ltac:(lia) dks (S i) rr sv rs x H ks Hrel) as [-> (g & f & Hm)]; [apply at_lt in Ea; lia|auto|].
        split; [reflexivity|]. exists g, (S f). simpl. rewrite Ea, Ec. exact Hm.
      * injection H as <- <-. split; [reflexivity|]. exists 0, 1. simpl. rewrite Ea, Ec. reflexivity.
      * injection H as <- <-. split; [reflexivity|]. exists 0, 1. simpl. rewrite Ea. reflexivity.
    + (* Any *)
      simpl in H. destruct (at_ s i rr) as [c'|] eqn:Ea; [destruct (Nat.eqb c' 10) eqn:Ec|].
      * injection H as <- <-. split; [reflexivity|]. exists 0, 1. simpl. rewrite Ea, Ec. reflexivity.
      * destruct (IH F ltac:(lia) dks (S i) rr sv rs x H ks Hrel) as [-> (g & f & Hm)]; [apply at_lt in Ea; lia|auto|].
        split; [reflexivity|]. exists g, (S f). simpl. rewrite Ea, Ec. exact Hm.
      * injection H as <- <-. split; [reflexivity|]. exists 0, 1. simpl. rewrite Ea. reflexivity.
    + (* AnyO *)
      simpl in H. destruct (at_ s i rr) as [c'|] eqn:Ea.
      * destruct (IH F ltac:(lia) dks (S i) rr sv rs x H ks Hrel) as [-> (g & f & Hm)]; [apply at_lt in Ea; lia|auto|].
        split; [reflexivity|]. exists g, (S f). simpl. rewrite Ea. exact Hm.
      * injection H as <- <-. split; [reflexivity|]. exists 0, 1. simpl. rewrite Ea. reflexivity.
    + (* Seq *)
      apply or_two in Hor as [Ha Hb]. apply andb_prop in Hx as [Hxa Hxb].
      rewrite ds_seq in H. simpl in H.
      destruct (IH F ltac:(lia) _ i rr sv rs x H (R a :: R b :: ks)) as [-> (g & f & Hm)]; auto.
      { apply r_R; [exact Hxa|destruct Ha; [left|right]; auto|apply r_R; auto]. }
      split; [reflexivity|]. exists g, (S f). exact Hm.
    + (* Alt *)
      apply or_two in Hor as [Ha Hb]. apply andb_prop in Hx as [Hxa Hxb].
      rewrite ds_alt in H. simpl in H.
      destruct (md s F (DR (fst (desugar a n)) :: dks) i rr sv) as [[r1 x1]|] eqn:E1; [|discriminate].
      destruct (md s F (DR (fst (desugar b (snd (desugar a n)))) :: dks) i x1 sv) as [[r2 x2]|] eqn:E2; [|discriminate].
      injection H as <- <-.
      destruct (IH F ltac:(lia) _ i rr sv r1 x1 E1 (R a :: ks)) as [-> (g1 & f1 & Hm1)]; auto; [apply r_R; auto|].
      destruct (IH F ltac:(lia) _ i rr sv r2 x2 E2 (R b :: ks)) as [-> (g2 & f2 & Hm2)]; auto; [apply r_R; auto|].
      split; [reflexivity|]. exists (max g1 g2), (S (max f1 f2)). simpl. unfold oapp.
      rewrite (m_mono s f1 (max f1 f2) g1 (max g1 g2) _ _ _ _ ltac:(lia) ltac:(lia) Hm1).
      rewrite (m_mono s f2 (max f1 f2) g2 (max g1 g2) _ _ _ _ ltac:(lia) ltac:(lia) Hm2).
      rewrite ends_app. reflexivity.
    + (* Star *)
      rewrite ds_star in H. simpl in H.
      destruct (md s F (DR (fst (desugar a n)) :: DChk i (fst (desugar a n)) :: dks) i rr sv) as [[r1 x1]|] eqn:E1; [|discriminate].
      destruct (md s F dks i x1 sv) as [[r2 x2]|] eqn:E2; [|discriminate].
      injection H as <- <-.
      destruct (IH F ltac:(lia) _ i rr sv r1 x1 E1 (R a :: Chk i a :: ks)) as [-> (g1 & f1 & Hm1)]; auto.
      { apply r_R; [exact Hx|destruct Hor; [left|right]; auto|apply r_Chk; auto]. }
      destruct (IH F ltac:(lia) _ i rr sv r2 x2 E2 ks) as [-> (g2 & f2 & Hm2)]; auto.
      split; [reflexivity|]. exists (max g1 g2), (S (max f1 f2)). simpl. unfold oapp.
      rewrite (m_mono s f1 (max f1 f2) g1 (max g1 g2) _ _ _ _ ltac:(lia) ltac:(lia) Hm1).
      rewrite (m_mono s f2 (max f1 f2) g2 (max g1 g2) _ _ _ _ ltac:(lia) ltac:(lia) Hm2).
      rewrite ends_app. reflexivity.
    + (* AbsRep *)
      destruct Hor as [Hor|Hns]; [discriminate|].
      change (fst (desugar (AbsRep a) n)) with (dseq [DSaveRR n; engine n (S n) (emb a) DAnyO false; DUpdRRFromStack n]) in H.
      destruct (simple_inv _ _ _ _ _ _ _ _ _ _ H) as (F' & x1 & HF' & Hs & ->).
      set (sv' := (n, rr) :: sv).
      assert (Hl : lookup n sv' = Some rr) by (simpl; rewrite Nat.eqb_refl; reflexivity).
      destruct (scan_b (S n) a DAnyO stpO (Ur n dks) (fun _ => rr) sv' rr Hx stpO_ok stpO_lt (fun y => eq_refl)
                  F' i rs x1 Hi Hs) as (top & bt & Rs & Hit & Hpre & Hbt & Hstop & HRs & -> & _).
      { intros f e x0 R y Hf He Hmd. apply md_Ur_inv with (y := rr) in Hmd as (f' & Hf' & Hmd); [|exact Hl].
        destruct (IH f' ltac:(lia) _ _ _ _ _ _ Hmd ks) as [-> _]; auto. apply rel_free with sv rr; auto. }
      destruct (cut_from_scan F' a i rr top bt Hi Hrr Hit Hpre Hbt Hstop) as (Hcut & Hxt & Htr).
      assert (HL : Forall2 (fun e le => exists g f, m s g f ks e rr = Some le) (downs (top - i) i) (map ends Rs)).
      { apply Forall2_map_impl with (1 := HRs). intros e R Hin (f & x0 & Hf & _ & Hmd). apply downs_mem in Hin.
        apply md_Ur_inv with (y := rr) in Hmd as (f' & Hf' & Hmd); [|exact Hl].
        destruct (IH f' ltac:(lia) _ _ _ _ _ _ Hmd ks) as [_ Hm]; auto; [apply rel_free with sv rr; auto|lia]. }
      destruct (m_ends_b _ _ ks i rr HL) as (g1 & f1 & Hm1).
      split; [reflexivity|]. exists (max g1 F'), (S f1). rewrite m_absrep_eq.
      rewrite (cut_mono s F' (max g1 F') a i rr top ltac:(lia) Hcut).
      rewrite (m_mono s f1 f1 g1 (max g1 F') _ _ _ _ ltac:(lia) ltac:(lia) Hm1).
      rewrite ends_concat. reflexivity.
    + (* AbsExp *)
      apply andb_prop in Hx as [Ha He]. destruct Hor as [Hor|Hns]; [discriminate|].
      destruct (simple_step e) as [ch|] eqn:Ess.
      * (* simple path *)
        apply simple_step_eq in Ess. subst e.
        change (fst (desugar (AbsExp a (Star (Chr ch))) n))
          with (dseq [DSaveRR n; engine n (S n) (emb a) (DChr ch) false; DUpdRRFromStack n]) in H.
        destruct (simple_inv _ _ _ _ _ _ _ _ _ _ H) as (F' & x1 & HF' & Hs & ->).
        set (sv' := (n, rr) :: sv).
        assert (Hl : lookup n sv' = Some rr) by (simpl; rewrite Nat.eqb_refl; reflexivity).
        destruct (scan_b (S n) a (DChr ch) (stpC ch) (Ur n dks) (fun _ => rr) sv' rr Ha (stpC_ok ch) (stpC_lt ch)
                    (fun y => eq_refl) F' i rs x1 Hi Hs) as (top & bt & Rs & Hit & Hpre & Hbt & Hstop & HRs & -> & _).
        { intros f e x0 R y Hf He' Hmd. apply md_Ur_inv with (y := rr) in Hmd as (f' & Hf' & Hmd); [|exact Hl].
          destruct (IH f' ltac:(lia) _ _ _ _ _ _ Hmd ks) as [-> _]; auto. apply rel_free with sv rr; auto. }
        destruct (cut_term a i rr Ha) as (G & c & Hc).
        assert (Hc' : cut s (max G F') a i rr = Some c) by (eapply cut_mono; [|exact Hc]; lia).
        destruct (simple_top (max G F') a i rr top bt c ch Hi Hit) as (Htc & Hcr & Hch & Htop); auto.
        { intros p Hp. destruct (Hpre p Hp) as [H1 H2]. split; auto. eapply mb_mono; [|exact H1]; lia. }
        { eapply mb_mono; [|exact Hbt]; lia. }
        assert (HL : Forall2 (fun e le => exists g f, m s g f (SetRR rr :: ks) e c = Some le) (downs (top - i) i) (map ends Rs)).
        { apply Forall2_map_impl with (1 := HRs). intros e R Hin (f & x0 & Hf & _ & Hmd). apply downs_mem in Hin.
          apply md_Ur_inv with (y := rr) in Hmd as (f' & Hf' & Hmd); [|exact Hl].
          destruct (IH f' ltac:(lia) _ _ _ _ _ _ Hmd ks) as [_ (g & f0 & Hm)]; auto; [apply rel_free with sv rr; auto|lia|].
          exists g, (S f0). exact Hm. }
        destruct (mstar_b ch (top - i) i top (SetRR rr :: ks) c (map ends Rs)) as (g2 & f2 & Hm2); auto; [lia|].
        split; [reflexivity|]. exists (max g2 (max G F')), (S f2). rewrite m_absexp_eq.
        rewrite (cut_mono s (max G F') (max g2 (max G F')) a i rr c ltac:(lia) Hc').
        rewrite (m_mono s f2 f2 g2 (max g2 (max G F')) _ _ _ _ ltac:(lia) ltac:(lia) Hm2).
        rewrite ends_concat. reflexivity.
      * (* general path *)
        rewrite ds_gen in H by exact Ess.
        destruct (gen_inv _ n a (DSeq (emb e) (DSeq (tail n (n + 3)) DEps)) dks i rr sv rs x H)
          as [-> (F' & ra & xa & HF' & Ea & Hra)].
        set (s1 := sv1 n i rr sv).
        destruct (scan_b (n + 2) a DAnyO stpO [] (fun y => y) s1 rr Ha stpO_ok stpO_lt (fun y => eq_refl)
                    F' i ra xa Hi Ea) as (top & bt & Rs & Hit & Hpre & Hbt & Hstop & HRs & Hra' & _).
        { intros f e0 x0 R y _ _ Hmd. destruct f; [discriminate|]. simpl in Hmd. injection Hmd as _ <-. reflexivity. }
        destruct (cut_from_scan F' a i rr top bt Hi Hrr Hit Hpre Hbt Hstop) as (Hcut & Hxt & Htr).
        destruct (downs_hd (top - i) i) as [tl Htl]. rewrite Htl in HRs.
        inversion HRs as [|? R0 ? Rs' (f0 & x0 & _ & Hx0 & Hmd0) _ HE1 HE2]; subst.
        destruct f0; [discriminate|]. simpl in Hmd0. injection Hmd0 as <- Hx0'.
        rewrite Hxt in Hx0'. subst x0. replace (i + (top - i)) with top in Hra by lia.
        simpl in Hra. destruct Hra as (x1 & Hu).
        apply md_U2_inv with (i0 := i) in Hu as (f1 & Hf1 & Hu); [|apply lookup_sv1_Sn].
        destruct f1 as [|f1]; [discriminate|]. simpl in Hu.
        replace (emb e) with (fst (desugar e 0)) in Hu by (rewrite core_desugar; auto).
        destruct (IH f1 ltac:(lia) _ _ _ _ _ _ Hu (R e :: SetRR rr :: ks)) as [_ (g1 & fe & Hm)]; [|lia|lia|].
        { apply r_R; [apply core_in_scope; auto|left; auto|].
          apply r_set; auto; [apply rel_free with sv rr; auto|apply lookup_sv1_n|lia]. }
        split; [reflexivity|]. exists (max g1 F'), (S fe). rewrite m_absexp_eq.
        rewrite (cut_mono s F' (max g1 F') a i rr top ltac:(lia) Hcut).
        rewrite (m_mono s fe fe g1 (max g1 F') _ _ _ _ ltac:(lia) ltac:(lia) Hm). reflexivity.
    + (* Stopper *)
      destruct Hor as [Hor|Hns]; [discriminate|].
      destruct (gen_inv _ n a DEps dks i rr sv rs x H) as [-> (F' & ra & xa & HF' & Ea & Hra)].
      set (s1 := sv1 n i rr sv).
      destruct (scan_b (n + 2) a DAnyO stpO [] (fun y => y) s1 rr Hx stpO_ok stpO_lt (fun y => eq_refl)
                  F' i ra xa Hi Ea) as (top & bt & Rs & Hit & Hpre & Hbt & Hstop & HRs & Hra' & _).
      { intros f e0 x0 R y _ _ Hmd. destruct f; [discriminate|]. simpl in Hmd. injection Hmd as _ <-. reflexivity. }
      destruct (cut_from_scan F' a i rr top bt Hi Hrr Hit Hpre Hbt Hstop) as (Hcut & Hxt & Htr).
      destruct (downs_hd (top - i) i) as [tl Htl]. rewrite Htl in HRs.
      inversion HRs as [|? R0 ? Rs' (f0 & x0 & _ & Hx0 & Hmd0) _ HE1 HE2]; subst.
      destruct f0; [discriminate|]. simpl in Hmd0. injection Hmd0 as <- Hx0'.
      rewrite Hxt in Hx0'. subst x0. replace (i + (top - i)) with top in Hra by lia.
      simpl in Hra. destruct Hra as (x1 & Hu).
      apply md_U2_inv with (i0 := i) in Hu as (f1 & Hf1 & Hu); [|apply lookup_sv1_Sn].
      destruct f1 as [|f1]; [discriminate|]. simpl in Hu.
      destruct (IH f1 ltac:(lia) _ _ _ _ _ _ Hu ks) as [_ (g1 & fe & Hm)]; [apply rel_free with sv rr; auto|lia|lia|].
      split; [reflexivity|]. exists (max g1 F'), (S fe). rewrite m_stopper_eq.
      rewrite (cut_mono s F' (max g1 F') a i rr top ltac:(lia) Hcut).
      rewrite (m_mono s fe fe g1 (max g1 F') _ _ _ _ ltac:(lia) ltac:(lia) Hm). reflexivity.
    + (* RClear *)
      destruct Hor as [Hor|Hns]; [discriminate|].
      destruct (rclear_inv _ _ _ _ _ _ _ _ H) as [-> (F' & y & HF' & Hu)].
      destruct (IH F' ltac:(lia) _ _ _ _ _ _ Hu ks) as [_ (g & f & Hm)]; [apply rel_free with sv rr; auto|lia|lia|].
      split; [reflexivity|]. exists g, (S f). exact Hm.
  - (* Chk *)
    simpl in H. destruct (Nat.eqb i i0) eqn:E.
    + destruct (IH F ltac:(lia) dks i rr sv rs x H ks Hrel Hi Hrr) as [-> (g & f & Hm)].
      split; [reflexivity|]. exists g, (S f). simpl. rewrite E. exact Hm.
    + rewrite <- ds_star in H.
      destruct (IH F ltac:(lia) _ i rr sv rs x H (R (Star x0) :: ks)) as [-> (g & f & Hm)]; auto; [apply r_R; auto|].
      split; [reflexivity|]. exists g, (S f). simpl. rewrite E. exact Hm.
  - (* SetRR *)
    destruct (tail_inv _ _ _ _ _ _ _ _ _ _ Hk Hn3 H) as [-> (F' & y & HF' & Hu)].
    destruct (IH F' ltac:(lia) _ _ _ _ _ _ Hu ks) as [_ (g & f & Hm)]; [apply rel_free with sv rr; auto|lia|lia|].
    split; [reflexivity|]. exists g, (S f). exact Hm.
Qed.

End P.

(* Main lemma (LEMMAS.md, lemma 2): for every pattern r built from the
   core, AbsRep, AbsExp (simple and general path), the stopper and the
   range clear, with no absent construct inside an absent one, every
   subject s, position i and register rr with i <= rr <= length s:
   (2a) every complete list of ends of the direct matcher (some fuels g, f)
        is the list of ends of md on the desugared tree for some fuel, and
        md ends with the register it started with;
   (2b) every complete result of md is a complete list of the direct
        matcher for some fuels g, f. *)
Theorem absent_desugar_eq : forall s r i rr, in_scope r = true -> i <= rr -> rr <= length s ->
  (forall g f l, m s g f [R r] i rr = Some l ->
     exists f' rs, md s f' [DR (fst (desugar r 0))] i rr [] = Some (rs, rr) /\ ends rs = l)
  /\ (forall f' rs x, md s f' [DR (fst (desugar r 0))] i rr [] = Some (rs, x) ->
     x = rr /\ exists g f, m s g f [R r] i rr = Some (ends rs)).
Proof.
  intros s r i rr Hr Hi Hrr.
  assert (Hrel : rel s [] rr [R r] [DR (fst (desugar r 0))]) by (apply r_R; auto; constructor).
  split.
  - intros g f l Hm. eapply sim_a; eauto.
  - intros f' rs x H. eapply sim_b; eauto.
Qed.

Print Assumptions absent_desugar_eq.

(* ---------------------------------------------------------------- *)
(* Termination of the direct matcher (issue #34, decision 8, run 5):
   on an in-scope pattern, m returns a complete list at some fuels g, f;
   with direction (2a), md on the desugared tree returns one too, and
   lemma 2 holds without assuming either side complete.
   Item stacks: in-scope R and Chk items, and SetRR k items whose k is at
   most max q (length s) (an AbsExp's restore; no Ends below the top).
   Measure: (length s - q, tmu) lexicographically, as term_core's, with
   AbsExp weighed by its exp; an AbsRep's Ends branches either stay at q
   (the rest of the stack, a smaller tmu) or move forward, below the
   subject length since the cut is at most the register. *)
Fixpoint tsz (r : re) : nat :=
  match r with
  | Seq a b | Alt a b => S (tsz a + tsz b)
  | Star a => S (S (tsz a))
  | AbsExp _ e => S (S (tsz e))
  | _ => 1
  end.
Definition tw (it : item) (q : nat) : nat :=
  match it with R x => tsz x | Chk i0 x => if Nat.eqb i0 q then 1 else tsz x + 3 | _ => 1 end.
Fixpoint tmu (ks : list item) (q : nat) : nat :=
  match ks with [] => 0 | it :: ks => tw it q + tmu ks q end.
Definition tok (b : nat) (it : item) : bool :=
  match it with R x | Chk _ x => in_scope x | SetRR k => Nat.leb k b | Ends _ => false end.

Lemma tsz_pos : forall r, 1 <= tsz r.
Proof. destruct r; simpl; lia. Qed.

Lemma toks_mono : forall ks b b', b <= b' -> forallb (tok b) ks = true -> forallb (tok b') ks = true.
Proof.
  induction ks as [|it ks IH]; intros b b' Hb H; simpl in *; auto.
  apply andb_prop in H as [H1 H2]. rewrite (IH b b' Hb H2), andb_true_r.
  destruct it; simpl in *; auto. apply Nat.leb_le. apply Nat.leb_le in H1. lia.
Qed.

Lemma at_len : forall s i rr c, at_ s i rr = Some c -> i < length s.
Proof.
  unfold at_. intros s i rr c H. destruct (Nat.ltb i rr); [|discriminate].
  apply nth_error_Some. congruence.
Qed.

Lemma scan_le : forall P k p c, scan P k p = Some c -> c <= p + k.
Proof.
  induction k; intros p c H; simpl in H; [injection H; lia|].
  destruct (P p) as [[|]|]; [injection H; lia| |discriminate].
  specialize (IHk (S p) c H). lia.
Qed.

(* The Ends item of an AbsRep: complete if each end's branch is. *)
Lemma ends_term : forall s es ks i rr,
  (forall e, In e es -> exists g f l, m s g f ks e rr = Some l) ->
  exists g f l, m s g f (Ends es :: ks) i rr = Some l.
Proof.
  intros s es ks i rr. induction es as [|e es IH]; intros H; [exists 0, 1, []; reflexivity|].
  destruct (H e (or_introl eq_refl)) as (g1 & f1 & l1 & H1).
  destruct IH as (g2 & f2 & l2 & H2); [intros e' He'; apply H; right; exact He'|].
  exists (max g1 g2), (S (f1 + f2)), (l1 ++ l2). simpl.
  rewrite (m_mono s f1 (f1 + f2) g1 (max g1 g2) _ _ _ _ ltac:(lia) ltac:(lia) H1).
  rewrite (m_mono s f2 (f1 + f2) g2 (max g1 g2) _ _ _ _ ltac:(lia) ltac:(lia) H2). reflexivity.
Qed.

Lemma oapp_term : forall s g1 f1 k1 g2 f2 k2 q r1 r2 l1 l2,
  m s g1 f1 k1 q r1 = Some l1 -> m s g2 f2 k2 q r2 = Some l2 ->
  oapp (m s (max g1 g2) (f1 + f2) k1 q r1) (m s (max g1 g2) (f1 + f2) k2 q r2) = Some (l1 ++ l2).
Proof.
  intros s g1 f1 k1 g2 f2 k2 q r1 r2 l1 l2 H1 H2.
  rewrite (m_mono s f1 (f1 + f2) g1 (max g1 g2) _ _ _ _ ltac:(lia) ltac:(lia) H1).
  rewrite (m_mono s f2 (f1 + f2) g2 (max g1 g2) _ _ _ _ ltac:(lia) ltac:(lia) H2). reflexivity.
Qed.

Section T.
Variable s : list nat.

Lemma m_term_stack : forall N M ks q rr, length s - q <= N -> tmu ks q <= M ->
  rr <= max q (length s) -> forallb (tok (max q (length s))) ks = true ->
  exists g f l, m s g f ks q rr = Some l.
Proof.
  intros N. induction N as [N IHN] using (well_founded_induction lt_wf).
  intros M. induction M as [|M IHM]; intros ks q rr HN HM Hr Hk.
  - destruct ks as [|it ks]; [exists 0, 1, [q]; reflexivity|].
    simpl in HM. destruct it; simpl in HM; try (pose proof (tsz_pos x)); try destruct (Nat.eqb i q); lia.
  - destruct ks as [|it ks]; [exists 0, 1, [q]; reflexivity|].
    simpl in Hk. apply andb_prop in Hk as [Hy Hks]. simpl in HM. unfold tw in HM.
    (* a consuming step: the position moves forward, below length s *)
    assert (Hfwd : forall c, at_ s q rr = Some c -> exists g f l, m s g f ks (S q) rr = Some l).
    { intros c Ea. pose proof (at_len s q rr c Ea) as Hl.
      apply (IHN (length s - S q) ltac:(lia) (tmu ks (S q)) ks (S q) rr); auto; try lia.
      apply (toks_mono ks (max q (length s))); auto. lia. }
    destruct it as [y|i0 y|n|es]; simpl in Hy; try discriminate.
    + destruct y as [|c| | |a b|a b|a|a|a e|a|]; simpl in Hy, HM.
      * destruct (IHM ks q rr) as (g & f & l & H); auto; [lia|].
        exists g, (S f), l. exact H.
      * destruct (at_ s q rr) as [c'|] eqn:Ea; [destruct (Nat.eqb c c') eqn:Ec|].
        -- destruct (Hfwd c' eq_refl) as (g & f & l & H).
           exists g, (S f), l. simpl. rewrite Ea, Ec. exact H.
        -- exists 0, 1, []. simpl. rewrite Ea, Ec. reflexivity.
        -- exists 0, 1, []. simpl. rewrite Ea. reflexivity.
      * destruct (at_ s q rr) as [c'|] eqn:Ea; [destruct (Nat.eqb c' 10) eqn:Ec|].
        -- exists 0, 1, []. simpl. rewrite Ea, Ec. reflexivity.
        -- destruct (Hfwd c' eq_refl) as (g & f & l & H).
           exists g, (S f), l. simpl. rewrite Ea, Ec. exact H.
        -- exists 0, 1, []. simpl. rewrite Ea. reflexivity.
      * destruct (at_ s q rr) as [c'|] eqn:Ea.
        -- destruct (Hfwd c' eq_refl) as (g & f & l & H).
           exists g, (S f), l. simpl. rewrite Ea. exact H.
        -- exists 0, 1, []. simpl. rewrite Ea. reflexivity.
      * apply andb_prop in Hy as [Hy1 Hy2].
        destruct (IHM (R a :: R b :: ks) q rr) as (g & f & l & H); simpl; auto; [lia|rewrite Hy1, Hy2; auto|].
        exists g, (S f), l. exact H.
      * apply andb_prop in Hy as [Hy1 Hy2].
        destruct (IHM (R a :: ks) q rr) as (g1 & f1 & l1 & H1); simpl; auto; [lia|rewrite Hy1; auto|].
        destruct (IHM (R b :: ks) q rr) as (g2 & f2 & l2 & H2); simpl; auto; [lia|rewrite Hy2; auto|].
        exists (max g1 g2), (S (f1 + f2)), (l1 ++ l2). simpl. apply oapp_term; auto.
      * destruct (IHM (R a :: Chk q a :: ks) q rr) as (g1 & f1 & l1 & H1); simpl;
          [lia|rewrite Nat.eqb_refl; lia|auto|rewrite Hy; auto|].
        destruct (IHM ks q rr) as (g2 & f2 & l2 & H2); auto; [lia|].
        exists (max g1 g2), (S (f1 + f2)), (l1 ++ l2). simpl. apply oapp_term; auto.
      * (* AbsRep *)
        destruct (cut_term s a q rr Hy) as (G & c & Hc).
        assert (Hcl : c <= q + (rr - q)) by (unfold cut in Hc; exact (scan_le _ _ _ _ Hc)).
        assert (Hcg : q <= c) by (unfold cut in Hc; exact (scan_ge _ _ _ _ Hc)).
        destruct (ends_term s (downs (c - q) q) ks q rr) as (g1 & f1 & l1 & H1).
        { intros e He. apply downs_mem in He.
          destruct (Nat.eq_dec e q) as [->|Hne].
          - apply (IHM ks q rr); auto. lia.
          - apply (IHN (length s - e) ltac:(lia) (tmu ks e) ks e rr); auto; try lia.
            apply (toks_mono ks (max q (length s))); auto. lia. }
        exists (max G g1), (S f1), l1. rewrite m_absrep_eq.
        rewrite (cut_mono s G (max G g1) a q rr c ltac:(lia) Hc).
        exact (m_mono s f1 f1 g1 (max G g1) _ _ _ _ ltac:(lia) ltac:(lia) H1).
      * (* AbsExp *)
        apply andb_prop in Hy as [Hya Hye].
        destruct (cut_term s a q rr Hya) as (G & c & Hc).
        assert (Hcl : c <= q + (rr - q)) by (unfold cut in Hc; exact (scan_le _ _ _ _ Hc)).
        destruct (IHM (R e :: SetRR rr :: ks) q c) as (g1 & f1 & l1 & H1); simpl;
          [lia|lia|lia|rewrite (core_in_scope e Hye); apply Nat.leb_le in Hr; rewrite Hr; auto|].
        exists (max G g1), (S f1), l1. rewrite m_absexp_eq.
        rewrite (cut_mono s G (max G g1) a q rr c ltac:(lia) Hc).
        exact (m_mono s f1 f1 g1 (max G g1) _ _ _ _ ltac:(lia) ltac:(lia) H1).
      * (* Stopper *)
        destruct (cut_term s a q rr Hy) as (G & c & Hc).
        assert (Hcl : c <= q + (rr - q)) by (unfold cut in Hc; exact (scan_le _ _ _ _ Hc)).
        destruct (IHM ks q c) as (g1 & f1 & l1 & H1); auto; [lia|lia|].
        exists (max G g1), (S f1), l1. rewrite m_stopper_eq.
        rewrite (cut_mono s G (max G g1) a q rr c ltac:(lia) Hc).
        exact (m_mono s f1 f1 g1 (max G g1) _ _ _ _ ltac:(lia) ltac:(lia) H1).
      * (* RClear *)
        destruct (IHM ks q (length s)) as (g & f & l & H); auto; [lia|lia|].
        exists g, (S f), l. exact H.
    + destruct (Nat.eqb i0 q) eqn:Eq; cbv iota in HM.
      * apply Nat.eqb_eq in Eq; subst i0.
        destruct (IHM ks q rr) as (g & f & l & H); auto; [lia|].
        exists g, (S f), l. simpl. rewrite Nat.eqb_refl. exact H.
      * destruct (IHM (R (Star y) :: ks) q rr) as (g & f & l & H); simpl; auto; [lia|rewrite Hy; auto|].
        exists g, (S f), l. simpl. rewrite Nat.eqb_sym, Eq. exact H.
    + apply Nat.leb_le in Hy.
      destruct (IHM ks q n) as (g & f & l & H); auto; [lia|].
      exists g, (S f), l. exact H.
Qed.
End T.

(* Decision 8: the direct matcher terminates on every in-scope pattern. *)
Theorem m_term : forall s r i rr, in_scope r = true -> i <= rr -> rr <= length s ->
  exists g f l, m s g f [R r] i rr = Some l.
Proof.
  intros s r i rr Hr Hi Hrr.
  apply (m_term_stack s (length s - i) (tsz r) [R r] i rr); simpl; auto; try lia.
  rewrite Hr. reflexivity.
Qed.

(* Lemma 2 without its condition: on every in-scope pattern, the direct
   matcher and md on the desugared tree both return a complete result,
   with the same list of ends, md ending with the register it started
   with (m_term, then direction (2a) of absent_desugar_eq). *)
Theorem absent_desugar_total : forall s r i rr, in_scope r = true -> i <= rr -> rr <= length s ->
  exists g f l f' rs, m s g f [R r] i rr = Some l
    /\ md s f' [DR (fst (desugar r 0))] i rr [] = Some (rs, rr) /\ ends rs = l.
Proof.
  intros s r i rr Hr Hi Hrr.
  destruct (m_term s r i rr Hr Hi Hrr) as (g & f & l & H).
  destruct (proj1 (absent_desugar_eq s r i rr Hr Hi Hrr) g f l H) as (f' & rs & H' & He).
  exists g, f, l, f', rs. auto.
Qed.

Print Assumptions m_term.
Print Assumptions absent_desugar_total.
