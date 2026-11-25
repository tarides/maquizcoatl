(* Experiment #9, Rocq M2, lemmas (b) and (c): the VM simulates the
   backtracking tree (FRAGMENT.md 8).  [rep pc acts pos stk P X] says that
   the code at [pc] implements the pending actions [acts] (Linden's
   continuation argument, first-order): [ARe r] by [comp r], [AClose n] by
   OP_MEM_END, [ACheck p0 a] by the end of a star's iteration (its
   OP_EMPTY_CHECK_END, whose OP_EMPTY_CHECK_START entry with the start
   position p0 is the topmost one of its id on the stack, or for a body
   that cannot match the empty string, only the loop's OP_JUMP, with
   p0 < pos); OP_JUMPs may come in between.  P lists the empty-check ids
   that the pending checks need on the stack; X lists the non-push groups
   ([OP_MEM_START]) still to be entered, whose VM captures are stale and
   are rewritten on every path (FRAGMENT.md 6, open groups).  [sim] is
   proved by induction on the fuel of [compute_tree]; its Star and ACheck
   cases are lemma (c), the plain empty check. *)

From Stdlib Require Import List Arith Lia.
Import ListNotations.
From S Require Import Syntax Sem Compile Vm Statement ProofA ProofSem.

(* the capture a VM slot reports (Vm.region) *)
Definition rv (v : option nat * option nat) : span :=
  match v with
  | (Some a, Some b) => Some (a, b)
  | _ => None
  end.

(* the groups opened on the current path and not yet closed *)
Fixpoint cls (acts : list action) : list (nat * nat) :=
  match acts with
  | [] => []
  | AClose n p :: k => (n, p) :: cls k
  | ARe _ :: k => cls k
  | ACheck _ _ :: k => cls k
  end.

(* the captures relation: groups in X are free; an open group has its
   start; every other group has the semantics' span *)
Definition capsrel (m : mcaps) (g : gmap) (C : list (nat * nat)) (X : list nat) : Prop :=
  forall k, ~ In k X ->
    (forall p, In (k, p) C -> fst (mget k m) = Some p) /\
    ((forall p, ~ In (k, p) C) -> rv (mget k m) = gget k g).

(* what a failed attempt may leave changed in the captures *)
Definition meq (C : list (nat * nat)) (X : list nat) (m1 m : mcaps) : Prop :=
  forall k, mget k m1 = mget k m \/ In k X \/
            ((exists p, In (k, p) C) /\ fst (mget k m1) = fst (mget k m)).

(* group numbers: no group repeats on the pending path *)
Fixpoint gs (acts : list action) : list nat :=
  match acts with
  | [] => []
  | ARe r :: k => groups r ++ gs k
  | AClose n _ :: k => n :: gs k
  | ACheck _ _ :: k => gs k
  end.

Definition disj (l1 l2 : list nat) : Prop := forall x, In x l1 -> ~ In x l2.

Fixpoint uniq (acts : list action) : Prop :=
  match acts with
  | [] => True
  | ARe r :: k => NoDup (groups r) /\ disj (groups r) (gs k) /\ uniq k
  | ACheck _ a :: k => NoDup (groups a) /\ disj (groups a) (gs k) /\ uniq k
  | AClose n _ :: k => ~ In n (gs k) /\ uniq k
  end.

Fixpoint topg (r : regex) : list nat :=
  match r with
  | Eps | Lit _ | Alt _ _ | Star _ => []
  | Cat a b => topg a ++ topg b
  | Group n a => n :: topg a
  end.

Definition npg (r : regex) (push : bool) : list nat := if push then [] else topg r.

Definition fresh (eid n : nat) (P : list nat) : Prop :=
  forall i, In i P -> i < eid \/ eid + n <= i.

Lemma mget_mset_eq : forall k v m, mget k (mset k v m) = v.
Proof. intros. unfold mset; simpl. rewrite Nat.eqb_refl. reflexivity. Qed.

Lemma mget_mset_neq : forall k k' v m, k' <> k -> mget k' (mset k v m) = mget k' m.
Proof. intros k k' v m H. unfold mset; simpl. apply Nat.eqb_neq in H. rewrite H. reflexivity. Qed.

Lemma gget_gset_eq : forall k v g, gget k (gset k v g) = Some v.
Proof. intros. unfold gset; simpl. rewrite Nat.eqb_refl. reflexivity. Qed.

Lemma gget_gset_neq : forall k k' v g, k' <> k -> gget k' (gset k v g) = gget k' g.
Proof. intros k k' v g H. unfold gset; simpl. apply Nat.eqb_neq in H. rewrite H. reflexivity. Qed.

Lemma cls_gs : forall k n p, In (n, p) (cls k) -> In n (gs k).
Proof.
  induction k as [|[r|p0 a|c p0] k IH]; simpl; intros n p H; try tauto.
  - apply in_or_app. right. eauto.
  - eauto.
  - destruct H as [H|H]; [inversion H; subst; left; reflexivity|right; eauto].
Qed.

Lemma NoDup_app_disj : forall (l1 l2 : list nat), NoDup (l1 ++ l2) ->
  NoDup l1 /\ NoDup l2 /\ disj l1 l2.
Proof.
  induction l1 as [|y l1 IH]; simpl; intros l2 H.
  - repeat split; auto. constructor. intros x [].
  - inversion H as [|? ? Hn Hd]; subst. destruct (IH _ Hd) as (A & B & C).
    repeat split; auto.
    + constructor; auto. intro Hy. apply Hn. apply in_or_app. auto.
    + intros x [<-|Hx] Hx2; [apply Hn; apply in_or_app; auto|exact (C x Hx Hx2)].
Qed.

Lemma meq_refl : forall C X m, meq C X m m.
Proof. intros C X m k. left. reflexivity. Qed.

Lemma meq_trans : forall C X m2 m1 m, meq C X m2 m1 -> meq C X m1 m -> meq C X m2 m.
Proof.
  intros C X m2 m1 m H2 H1 k.
  destruct (H2 k) as [E2|[X2|[C2 F2]]]; destruct (H1 k) as [E1|[X1|[C1 F1]]];
    try (right; left; assumption).
  - left. congruence.
  - right; right. split; [assumption|congruence].
  - right; right. split; [assumption|congruence].
  - right; right. split; [assumption|congruence].
Qed.

Lemma capsrel_meq : forall m g C X m1, capsrel m g C X -> meq C X m1 m -> capsrel m1 g C X.
Proof.
  intros m g C X m1 H M k Hk. destruct (H k Hk) as [H1 H2].
  destruct (M k) as [E|[Xk|[[p Cp] F]]].
  - rewrite E. auto.
  - contradiction.
  - split.
    + intros p' Hp'. rewrite F. auto.
    + intros Hn. exfalso. exact (Hn p Cp).
Qed.

Section Sim.
Variable code : list instr.
Variable s : list nat.

Definition exec (st : state) (R : option (nat * mcaps)) : Prop :=
  exists n, run n code s st = Some R.

Definition fails (stk : list entry) (m : mcaps) (R : option (nat * mcaps)) : Prop :=
  match pop stk m with
  | Some st => exec st R
  | None => R = None
  end.

Lemma exec_next : forall st st' R, step code s st = Next st' -> exec st' R -> exec st R.
Proof. intros st st' R H [n Hn]. exists (S n). simpl. rewrite H. exact Hn. Qed.

Lemma exec_halt : forall st R, step code s st = Halt R -> exec st R.
Proof. intros st R H. exists 1. simpl. rewrite H. reflexivity. Qed.

Lemma exec_fail : forall st stk m R, step code s st = fail stk m -> fails stk m R -> exec st R.
Proof.
  intros st stk m R H HF. unfold fails, fail in *. destruct (pop stk m) eqn:E.
  - eapply exec_next; eauto.
  - subst R. apply exec_halt. exact H.
Qed.

Lemma run_mono : forall n st R, run n code s st = Some R ->
  forall n', n <= n' -> run n' code s st = Some R.
Proof.
  induction n as [|n IH]; intros st R H n' Hle; [simpl in H; discriminate|].
  destruct n' as [|n']; [lia|]. simpl in *.
  destruct (step code s st); auto. eapply IH; [exact H|lia].
Qed.

Lemma exec_det : forall st R1 R2, exec st R1 -> exec st R2 -> R1 = R2.
Proof.
  intros st R1 R2 [n1 H1] [n2 H2].
  pose proof (run_mono _ _ _ H1 (n1 + n2) ltac:(lia)) as E1.
  pose proof (run_mono _ _ _ H2 (n1 + n2) ltac:(lia)) as E2.
  congruence.
Qed.

Inductive rep : nat -> list action -> nat -> list entry -> list nat -> list nat -> Prop :=
| rep_jump : forall pc t acts pos stk P X,
    nth_error code pc = Some (IJump t) -> rep t acts pos stk P X -> rep pc acts pos stk P X
| rep_end : forall pc pos stk,
    nth_error code pc = Some IEnd -> rep pc [] pos stk [] []
| rep_re : forall pc r eid push k pos stk P X pc' pos',
    code_at code pc (comp r pc eid push) -> fresh eid (nchecks r) P ->
    pc' = pc + clen r -> pos' <= pos + minlen r ->
    rep pc' k pos' stk P X -> rep pc (ARe r :: k) pos stk P (npg r push ++ X)
| rep_close : forall pc n p0 k pos stk P X,
    nth_error code pc = Some (IMemEnd n) -> rep (S pc) k pos stk P X ->
    rep pc (AClose n p0 :: k) pos stk P X
| rep_chk_null : forall pc L a eid push p0 k pos stk P X pc' pos',
    code_at code L (comp (Star a) L eid push) -> clen a <> 0 -> nullable a = true ->
    fresh eid (nchecks (Star a)) P -> empty_start eid stk = Some p0 -> p0 <= pos ->
    pc = L + 2 + clen a -> pc' = L + clen (Star a) -> pos' <= p0 ->
    rep pc' k pos' stk P X -> rep pc (ACheck p0 a :: k) pos stk (eid :: P) X
| rep_chk_nn : forall pc L a eid push p0 k pos stk P X pc' pos',
    code_at code L (comp (Star a) L eid push) -> clen a <> 0 -> nullable a = false ->
    fresh eid (nchecks (Star a)) P -> p0 + minlen a <= pos ->
    pc = L + 1 + clen a -> pc' = L + clen (Star a) -> pos' <= p0 ->
    rep pc' k pos' stk P X -> rep pc (ACheck p0 a :: k) pos stk P X.

Lemma rep_re' : forall pc r eid push k pos stk P X pc' pos' X',
    code_at code pc (comp r pc eid push) -> fresh eid (nchecks r) P ->
    pc' = pc + clen r -> pos' <= pos + minlen r ->
    rep pc' k pos' stk P X -> X' = npg r push ++ X -> rep pc (ARe r :: k) pos stk P X'.
Proof. intros. subst X'. eapply rep_re; eauto. Qed.

Lemma rep_mono : forall pc acts pos stk P X, rep pc acts pos stk P X ->
  forall pos2 stk2, pos <= pos2 ->
  (forall i, In i P -> empty_start i stk2 = empty_start i stk) ->
  rep pc acts pos2 stk2 P X.
Proof.
  induction 1 as [pc tg acts pos stk P X Hj Hrep IH
                 | pc pos stk He
                 | pc r eid push k pos stk P X pc' pos' Hcode Hfr Hpc Hpos Hrep IH
                 | pc n p0 k pos stk P X Hme Hrep IH
                 | pc L a eid push p0 k pos stk P X pc' pos' Hcode Hc0 Hnu Hfr Hes Hp0 Hpc Hpc' Hpos Hrep IH
                 | pc L a eid push p0 k pos stk P X pc' pos' Hcode Hc0 Hnu Hfr Hp0 Hpc Hpc' Hpos Hrep IH];
    intros pos2 stk2 Hp Hs.
  - exact (rep_jump _ _ _ _ _ _ _ Hj (IH _ _ Hp Hs)).
  - apply rep_end; auto.
  - apply (rep_re pc r eid push k pos2 stk2 P X pc' pos' Hcode Hfr Hpc); [lia|].
    apply IH; auto.
  - exact (rep_close _ _ _ _ _ _ _ _ Hme (IH _ _ Hp Hs)).
  - refine (rep_chk_null pc L a eid push p0 k pos2 stk2 P X pc' pos' Hcode Hc0 Hnu Hfr
              _ _ Hpc Hpc' Hpos _).
    + rewrite Hs by (left; reflexivity). assumption.
    + lia.
    + apply IH; auto. intros i Hi. apply Hs. right. exact Hi.
  - refine (rep_chk_nn pc L a eid push p0 k pos2 stk2 P X pc' pos' Hcode Hc0 Hnu Hfr
              _ Hpc Hpc' Hpos _).
    + lia.
    + apply IH; auto.
Qed.

Definition simres (C : list (nat * nat)) (X : list nat) (pc pos : nat) (m : mcaps)
           (stk : list entry) (t : tree) : Prop :=
  match first_match t with
  | Some (e, g') => exists m', exec (St pc pos m stk) (Some (e, m'))
                               /\ forall k, rv (mget k m') = gget k g'
  | None => exists m1, meq C X m1 m /\ forall R, fails stk m1 R -> exec (St pc pos m stk) R
  end.

Lemma simres_fwd : forall C X pc pos pc2 pos2 m stk t,
  (forall R, exec (St pc2 pos2 m stk) R -> exec (St pc pos m stk) R) ->
  simres C X pc2 pos2 m stk t -> simres C X pc pos m stk t.
Proof.
  unfold simres; intros C X pc pos pc2 pos2 m stk t F H.
  destruct (first_match t) as [[e g']|].
  - destruct H as (m' & H1 & H2). eauto.
  - destruct H as (m1 & H1 & H2). eauto.
Qed.

Lemma simres_fm : forall C X pc pos m stk t t', first_match t = first_match t' ->
  simres C X pc pos m stk t' -> simres C X pc pos m stk t.
Proof. unfold simres; intros C X pc pos m stk t t' E H. rewrite E. exact H. Qed.

(* a choice point: OP_PUSH, then the first branch, then on its failure
   the second *)
Lemma simres_choice : forall C X pc pos m stk stk1 pcA pcB t1 t2,
  (forall R, exec (St pcA pos m stk1) R -> exec (St pc pos m stk) R) ->
  (forall m1 R, exec (St pcB pos m1 stk) R -> fails stk1 m1 R) ->
  simres C X pcA pos m stk1 t1 ->
  (forall m1, meq C X m1 m -> simres C X pcB pos m1 stk t2) ->
  simres C X pc pos m stk (TChoice t1 t2).
Proof.
  unfold simres; intros C X pc pos m stk stk1 pcA pcB t1 t2 FA FB H1 H2. simpl.
  destruct (first_match t1) as [[e g']|].
  - destruct H1 as (m' & E & G). eauto.
  - destruct H1 as (m1 & M1 & F1). specialize (H2 m1 M1).
    destruct (first_match t2) as [[e g']|].
    + destruct H2 as (m' & E & G). exists m'. split; auto.
    + destruct H2 as (m2 & M2 & F2). exists m2. split; [eapply meq_trans; eauto|].
      intros R HR. auto.
Qed.

Ltac step_at H := unfold step; rewrite H; try reflexivity.

Lemma fresh_sub : forall e n e' n' P, fresh e n P -> e <= e' -> e' + n' <= e + n ->
  fresh e' n' P.
Proof. unfold fresh; intros e n e' n' P H H1 H2 i Hi. destruct (H i Hi); lia. Qed.

Lemma npg_nil : forall r push X, topg r = [] -> npg r push ++ X = X.
Proof. intros r push X H. unfold npg. destruct push; [reflexivity|]. rewrite H. reflexivity. Qed.

Lemma capsrel_open : forall m g C X X' n pos v, capsrel m g C X ->
  (forall p, ~ In (n, p) C) -> fst v = Some pos ->
  (forall k, k <> n -> ~ In k X' -> ~ In k X) ->
  capsrel (mset n v m) g ((n, pos) :: C) X'.
Proof.
  intros m g C X X' n pos v H Hn Hv HX k Hk.
  destruct (Nat.eq_dec k n) as [->|Ne].
  - rewrite mget_mset_eq. split.
    + intros p [Hp|Hp]; [inversion Hp; subst; exact Hv|exfalso; exact (Hn p Hp)].
    + intros Hc. exfalso. apply (Hc pos). left. reflexivity.
  - rewrite mget_mset_neq by exact Ne. destruct (H k (HX k Ne Hk)) as [H1 H2]. split.
    + intros p [Hp|Hp]; [inversion Hp; subst; contradiction|auto].
    + intros Hc. apply H2. intros p Hp. apply (Hc p). right. exact Hp.
Qed.

Lemma meq_open : forall C X X' n pos v m m1,
  meq ((n, pos) :: C) X' m1 (mset n v m) ->
  (forall k, In k X' -> In k X) ->
  (forall k, k <> n -> mget k m1 = mget k m \/ In k X \/
     ((exists p, In (k, p) C) /\ fst (mget k m1) = fst (mget k m))).
Proof.
  intros C X X' n pos v m m1 M HX k Ne.
  rewrite <- (mget_mset_neq n k v m Ne).
  destruct (M k) as [E|[Xk|[[p Cp] F]]]; auto.
  right; right. split; auto. destruct Cp as [Cp|Cp]; [inversion Cp; subst; contradiction|eauto].
Qed.

Theorem sim : forall f acts pos g t, compute_tree f s acts pos g = Some t ->
  forall pc stk P X m, rep pc acts pos stk P X -> capsrel m g (cls acts) X -> uniq acts ->
  simres (cls acts) X pc pos m stk t.
Proof.
  induction f as [|f IHf]; intros acts pos g t Ht pc stk P X m Hrep.
  { simpl in Ht; discriminate. }
  revert m g t Ht.
  induction Hrep as [pc tg acts pos stk P X Hj Hrep IH
                    | pc pos stk He
                    | pc r eid push k pos stk P X pc' pos' Hcode Hfr Hpc Hpos Hrep IH
                    | pc n p0 k pos stk P X Hme Hrep IH
                    | pc L a eid push p0 k pos stk P X pc' pos' Hcode Hc0 Hnu Hfr Hes Hp0 Hpc Hpc' Hpos Hrep IH
                    | pc L a eid push p0 k pos stk P X pc' pos' Hcode Hc0 Hnu Hfr Hp0 Hpc Hpc' Hpos Hrep IH];
    intros m g t Ht Hc Hu.
  - (* jump *)
    eapply simres_fwd; [|eapply IH; eauto].
    intros R HR. eapply exec_next; [step_at Hj|exact HR].
  - (* end: OP_END *)
    simpl in Ht. injection Ht as <-. unfold simres; simpl.
    exists m. split.
    + apply exec_halt. step_at He.
    + intros k. destruct (Hc k (fun x => x)) as [_ H2]. apply H2. intros p [].
  - (* ARe r *)
    destruct r as [|l|a b|a b|a|n a].
    + (* Eps *)
      simpl in Ht, Hpc, Hpos. rewrite npg_nil by reflexivity. rewrite npg_nil in Hc by reflexivity.
      apply (IHf _ _ _ _ Ht _ _ P); [|exact Hc|apply Hu].
      rewrite Nat.add_0_r in Hpc. subst pc'.
        eapply rep_mono; [exact Hrep|lia|intros i _; reflexivity].
    + (* Lit *)
      rewrite npg_nil by reflexivity. rewrite npg_nil in Hc by reflexivity.
      destruct l as [|x l'].
      * simpl in Ht, Hpc, Hpos. rewrite Nat.add_0_r in Ht.
        apply (IHf _ _ _ _ Ht _ _ P); [|exact Hc|apply Hu].
        rewrite Nat.add_0_r in Hpc. subst pc'.
        eapply rep_mono; [exact Hrep|lia|intros i _; reflexivity].
      * pose proof (code_lit _ _ _ _ _ _ Hcode) as Hi.
        assert (Ht' : (if is_prefix (x :: l') (skipn pos s)
                       then compute_tree f s k (pos + length (x :: l')) g
                       else Some TMismatch) = Some t) by exact Ht.
        clear Ht; rename Ht' into Ht.
        simpl in Hpc, Hpos.
        destruct (is_prefix (x :: l') (skipn pos s)) eqn:E.
        -- eapply simres_fwd.
           ++ intros R HR.
              apply (exec_next _ (St (S pc) (pos + length (x :: l')) m stk)); [|exact HR].
              unfold step. rewrite Hi, E. reflexivity.
           ++ apply (IHf _ _ _ _ Ht _ _ P); [|exact Hc|apply Hu].
              replace (S pc) with pc' by lia.
              eapply rep_mono; [exact Hrep|simpl; lia|intros i _; reflexivity].
        -- injection Ht as <-. unfold simres; simpl. exists m. split; [apply meq_refl|].
           intros R HR. eapply exec_fail; [|exact HR]. unfold step. rewrite Hi, E. reflexivity.
    + (* Cat *)
      pose proof (code_cat _ _ _ _ _ _ Hcode) as [Ha Hb].
      simpl in Ht, Hpc, Hpos, Hfr.
      assert (Ex : npg (Cat a b) push ++ X = npg a push ++ npg b push ++ X)
        by (unfold npg; destruct push; simpl; [reflexivity|symmetry; apply app_assoc]).
      rewrite Ex in Hc |- *.
      apply (IHf _ _ _ _ Ht _ _ P); [|exact Hc|].
      * eapply rep_re with (pc' := pc + clen a) (pos' := pos + minlen a);
          [exact Ha|eapply fresh_sub; eauto; lia|reflexivity|apply le_n|].
        eapply rep_re with (pc' := pc') (pos' := pos');
          [exact Hb|eapply fresh_sub; eauto; lia|lia|lia|exact Hrep].
      * simpl in Hu |- *. destruct Hu as (N & D & U).
        apply NoDup_app_disj in N as (Na & Nb & Dab).
        repeat split; auto.
        -- intros x Hx Hx2. apply in_app_or in Hx2 as [Hx2|Hx2].
           ++ exact (Dab x Hx Hx2).
           ++ apply (D x); [apply in_or_app; left; exact Hx|exact Hx2].
        -- intros x Hx Hx2. apply (D x); [apply in_or_app; right; exact Hx|exact Hx2].
    + (* Alt *)
      pose proof (code_alt _ _ _ _ _ _ Hcode) as (H1 & Ha & H3 & Hb).
      simpl in Ht, Hpc, Hpos, Hfr.
      rewrite npg_nil by reflexivity. rewrite npg_nil in Hc by reflexivity.
      destruct (compute_tree f s (ARe a :: k) pos g) as [t1|] eqn:E1; [|discriminate].
      destruct (compute_tree f s (ARe b :: k) pos g) as [t2|] eqn:E2; [|discriminate].
      injection Ht as <-.
      simpl in Hu. destruct Hu as (N & D & U).
      apply NoDup_app_disj in N as (Na & Nb & Dab).
      eapply simres_choice with (stk1 := EAlt (pc + clen a + 2) pos :: stk)
                                (pcA := S pc) (pcB := pc + clen a + 2).
      * intros R HR. eapply exec_next; [step_at H1|exact HR].
      * intros m1 R HR. exact HR.
      * apply (IHf _ _ _ _ E1 _ _ P (npg a true ++ X)); [| exact Hc |].
        -- eapply rep_re; [exact Ha|eapply fresh_sub; eauto; lia|reflexivity|apply le_n|].
           eapply rep_jump; [exact H3|].
           replace (pc + clen a + clen b + 2) with pc' by lia.
           eapply rep_mono; [exact Hrep|lia|]. intros i _. reflexivity.
        -- simpl. split; [exact Na|split; [|exact U]].
           intros x Hx. apply D. apply in_or_app. left. exact Hx.
      * intros m1 M1.
        apply (IHf _ _ _ _ E2 _ _ P (npg b true ++ X)).
        -- eapply rep_re with (pc' := pc') (pos' := pos + minlen b);
             [exact Hb|eapply fresh_sub; eauto; lia|lia|apply le_n|].
           eapply rep_mono; [exact Hrep|lia|]. intros i _. reflexivity.
        -- eapply capsrel_meq; eauto.
        -- simpl. split; [exact Nb|split; [|exact U]].
           intros x Hx. apply D. apply in_or_app. right. exact Hx.
    + (* Star: lemma (c) *)
      rewrite npg_nil by reflexivity. rewrite npg_nil in Hc by reflexivity.
      simpl in Ht.
      destruct (compute_tree f s (ARe a :: ACheck pos a :: k) pos g) as [t1|] eqn:E1;
        [|discriminate].
      destruct (compute_tree f s k pos g) as [t2|] eqn:E2; [|discriminate].
      injection Ht as <-.
      assert (Hu1 : uniq (ARe a :: ACheck pos a :: k)) by (simpl in Hu |- *; tauto).
      assert (Hu2 : uniq k) by (simpl in Hu; tauto).
      simpl in Hpos.
      destruct (Nat.eq_dec (clen a) 0) as [C0|C0].
      * (* body of code length 0: elided *)
        destruct (comp_star0 a pc eid push C0) as (_ & Cl & _).
        destruct (clen0_fm s a _ _ _ _ _ C0 E1) as (f1 & t1' & E1' & F1).
        destruct f1 as [|f1]; [simpl in E1'; discriminate|].
        simpl in E1'. rewrite Nat.eqb_refl in E1'.
        rewrite (ct_det s _ _ _ _ _ _ _ E1' E2) in F1.
        apply (simres_fm _ _ _ _ _ _ _ t2).
        { simpl. rewrite <- F1. destruct (first_match t2); reflexivity. }
        apply (IHf _ _ _ _ E2 _ _ P); [|exact Hc|exact Hu2].
        rewrite Cl, Nat.add_0_r in Hpc. subst pc'. eapply rep_mono; eauto; lia.
      * destruct (nullable a) eqn:Nu.
        -- (* nullable body: OP_EMPTY_CHECK_START / _END *)
           destruct (comp_star_null a pc eid push C0 Nu) as (_ & Cl & Nc).
           destruct (code_star_null _ _ _ _ _ C0 Nu Hcode) as (H1 & H2 & Ha & H4 & H5).
           rewrite Nc in Hfr. rewrite Cl in Hpc.
           set (stk2 := EEmptyStart eid pos :: EAlt (pc + clen a + 4) pos :: stk).
           eapply simres_choice with (stk1 := stk2) (pcA := S (S pc)) (pcB := pc + clen a + 4).
           ++ intros R HR. eapply exec_next; [step_at H1|].
              eapply exec_next; [step_at H2|exact HR].
           ++ intros m1 R HR. exact HR.
           ++ apply (IHf _ _ _ _ E1 _ _ (eid :: P) (npg a true ++ X)); [|exact Hc|exact Hu1].
              eapply rep_re; [exact Ha| |reflexivity|apply le_n|].
              { intros i [<-|Hi]; [lia|destruct (Hfr i Hi); lia]. }
              refine (rep_chk_null _ pc a eid push pos k _ stk2 P X pc' pos' Hcode C0 Nu
                        _ _ _ _ _ _ _).
              ** rewrite Nc. exact Hfr.
              ** unfold stk2. simpl. rewrite Nat.eqb_refl. reflexivity.
              ** lia.
              ** lia.
              ** rewrite Cl. lia.
              ** lia.
              ** eapply rep_mono; [exact Hrep|lia|].
                 intros i Hi. unfold stk2. simpl.
                 destruct (Nat.eqb_spec i eid); [subst; destruct (Hfr eid Hi); lia|reflexivity].
           ++ intros m1 M1. apply (IHf _ _ _ _ E2 _ _ P); [|eapply capsrel_meq; eauto|exact Hu2].
              subst pc'. replace (pc + clen a + 4) with (pc + (clen a + 4)) by lia.
              eapply rep_mono; [exact Hrep|lia|]. intros i _. reflexivity.
        -- (* body that cannot match the empty string: no check *)
           destruct (comp_star_nn a pc eid push C0 Nu) as (_ & Cl & Nc).
           destruct (code_star_nn _ _ _ _ _ C0 Nu Hcode) as (H1 & Ha & H3).
           rewrite Nc in Hfr. rewrite Cl in Hpc.
           eapply simres_choice with (stk1 := EAlt (pc + clen a + 2) pos :: stk)
                                     (pcA := S pc) (pcB := pc + clen a + 2).
           ++ intros R HR. eapply exec_next; [step_at H1|exact HR].
           ++ intros m1 R HR. exact HR.
           ++ apply (IHf _ _ _ _ E1 _ _ P (npg a true ++ X)); [|exact Hc|exact Hu1].
              eapply rep_re; [exact Ha|exact Hfr|reflexivity|apply le_n|].
              refine (rep_chk_nn _ pc a eid push pos k _ _ P X pc' pos' Hcode C0 Nu
                        _ _ _ _ _ _).
              ** rewrite Nc. exact Hfr.
              ** lia.
              ** lia.
              ** rewrite Cl. lia.
              ** lia.
              ** eapply rep_mono; [exact Hrep|lia|]. intros i _. reflexivity.
           ++ intros m1 M1. apply (IHf _ _ _ _ E2 _ _ P); [|eapply capsrel_meq; eauto|exact Hu2].
              subst pc'. replace (pc + clen a + 2) with (pc + (clen a + 2)) by lia.
              eapply rep_mono; [exact Hrep|lia|]. intros i _. reflexivity.
    + (* Group *)
      pose proof (code_group _ _ _ _ _ _ Hcode) as (H1 & Ha & H3).
      simpl in Ht, Hpc, Hpos, Hfr.
      simpl in Hu. destruct Hu as (N & D & U).
      inversion N as [|? ? Nn Na]; subst.
      assert (Hu' : uniq (ARe a :: AClose n pos :: k)).
      { simpl. split; [exact Na|split; [|split; [|exact U]]].
        - intros x Hx [Hx2|Hx2]; [subst; contradiction|exact (D x (or_intror Hx) Hx2)].
        - intros Hn. exact (D n (or_introl eq_refl) Hn). }
      assert (Hnc : forall p, ~ In (n, p) (cls k)).
      { intros p Hp. apply cls_gs in Hp. exact (D n (or_introl eq_refl) Hp). }
      assert (Hrep' : forall stk', (forall i, In i P -> empty_start i stk' = empty_start i stk) ->
                rep (S pc) (ARe a :: AClose n pos :: k) pos stk' P (npg a push ++ X)).
      { intros stk' Hs. eapply rep_re; [exact Ha|exact Hfr|reflexivity|apply le_n|].
        eapply rep_close; [exact H3|].
        replace (S (S pc + clen a)) with (pc + (clen a + 2)) by lia.
        eapply rep_mono; [exact Hrep|lia|exact Hs]. }
      destruct push.
      * (* OP_MEM_START_PUSH *)
        simpl npg in Hc |- *.
        unfold simres.
        pose proof (IHf _ _ _ _ Ht (S pc) (EMemStart n (mget n m) :: stk) P X
                      (mset n (Some pos, None) m)
                      (Hrep' (EMemStart n (mget n m) :: stk) (fun i _ => eq_refl))) as IH1.
        assert (Hc' : capsrel (mset n (Some pos, None) m) g (cls (ARe a :: AClose n pos :: k)) X).
        { simpl. eapply capsrel_open; eauto. }
        specialize (IH1 Hc' Hu'). unfold simres in IH1. simpl cls in IH1.
        destruct (first_match t) as [[e g']|].
        -- destruct IH1 as (m' & E & G). exists m'. split; auto.
           eapply exec_next; [step_at H1|exact E].
        -- destruct IH1 as (m1 & M1 & F1).
           exists (mset n (mget n m) m1). split.
           ++ intros k'. destruct (Nat.eq_dec k' n) as [->|Ne].
              ** left. apply mget_mset_eq.
              ** rewrite mget_mset_neq by exact Ne.
                 exact (meq_open _ _ _ _ _ _ _ _ M1 (fun k H => H) k' Ne).
           ++ intros R HR. eapply exec_next; [step_at H1|]. apply F1. exact HR.
      * (* OP_MEM_START *)
        simpl npg in Hc |- *.
        unfold simres.
        pose proof (IHf _ _ _ _ Ht (S pc) stk P (topg a ++ X)
                      (mset n (Some pos, snd (mget n m)) m)
                      (Hrep' stk (fun i _ => eq_refl))) as IH1.
        assert (Hc' : capsrel (mset n (Some pos, snd (mget n m)) m) g
                        (cls (ARe a :: AClose n pos :: k)) (topg a ++ X)).
        { simpl. eapply capsrel_open; eauto.
          intros k' Ne Hk' [Hk2|Hk2]; [congruence|contradiction]. }
        specialize (IH1 Hc' Hu'). unfold simres in IH1. simpl cls in IH1.
        destruct (first_match t) as [[e g']|].
        -- destruct IH1 as (m' & E & G). exists m'. split; auto.
           eapply exec_next; [step_at H1|exact E].
        -- destruct IH1 as (m1 & M1 & F1).
           exists m1. split.
           ++ intros k'. destruct (Nat.eq_dec k' n) as [->|Ne].
              ** right. left. left. reflexivity.
              ** destruct (meq_open _ (n :: topg a ++ X) _ _ _ _ _ _ M1
                             (fun k H => or_intror H) k' Ne) as [E|[E|E]]; auto.
           ++ intros R HR. eapply exec_next; [step_at H1|]. apply F1. exact HR.
  - (* AClose: OP_MEM_END *)
    simpl in Ht. simpl in Hu. destruct Hu as (Nn & U).
    set (m' := mset n (fst (mget n m), Some pos) m).
    assert (Hc' : capsrel m' (gset n (p0, pos) g) (cls k) X).
    { intros k' Hk'. destruct (Hc k' Hk') as [C1 C2]. unfold m'.
      destruct (Nat.eq_dec k' n) as [->|Ne].
      - split.
        + intros p Hp. exfalso. apply Nn. eapply cls_gs; eauto.
        + intros _. rewrite mget_mset_eq, gget_gset_eq.
          rewrite (C1 p0 (or_introl eq_refl)). reflexivity.
      - rewrite mget_mset_neq, gget_gset_neq by exact Ne. split.
        + intros p Hp. apply C1. right. exact Hp.
        + intros Hn. apply C2. intros p [Hp|Hp]; [inversion Hp; congruence|exact (Hn p Hp)]. }
    pose proof (IHf _ _ _ _ Ht _ _ _ _ m' Hrep Hc' U) as IH1.
    unfold simres in IH1 |- *. simpl cls.
    destruct (first_match t) as [[e g']|].
    + destruct IH1 as (m'' & E & G). exists m''. split; auto.
      eapply exec_next; [step_at Hme|exact E].
    + destruct IH1 as (m1 & M1 & F1). exists m1. split.
      * intros k'. destruct (Nat.eq_dec k' n) as [->|Ne].
        -- destruct (M1 n) as [E|[E|[[p Cp] F]]].
           ++ right; right. split; [exists p0; left; reflexivity|].
              rewrite E. unfold m'. rewrite mget_mset_eq. reflexivity.
           ++ right; left; exact E.
           ++ right; right. split; [exists p; right; exact Cp|].
              rewrite F. unfold m'. rewrite mget_mset_eq. reflexivity.
        -- unfold m' in M1. destruct (M1 k') as [E|[E|[[p Cp] F]]].
           ++ left. rewrite E, mget_mset_neq by exact Ne. reflexivity.
           ++ right; left; exact E.
           ++ right; right. rewrite mget_mset_neq in F by exact Ne.
              split; [exists p; right; exact Cp|exact F].
      * intros R HR. eapply exec_next; [step_at Hme|]. apply F1. exact HR.
  - (* ACheck, nullable body: OP_EMPTY_CHECK_END *)
    destruct (comp_star_null a L eid push Hc0 Hnu) as (_ & Cl & Nc).
    destruct (code_star_null _ _ _ _ _ Hc0 Hnu Hcode) as (H1 & H2 & Ha & H4 & H5).
    simpl in Ht. simpl in Hu. destruct Hu as (Na & D & U).
    subst pc.
    destruct (Nat.eqb pos p0) eqn:E.
    + apply Nat.eqb_eq in E. subst p0.
      eapply simres_fwd.
      * intros R HR. apply (exec_next _ (St (S (S (L + 2 + clen a))) pos m stk)); [|exact HR].
        unfold step. rewrite H4, Hes, Nat.eqb_refl. reflexivity.
      * apply (IHf _ _ _ _ Ht _ _ P); [|exact Hc|exact U].
        replace (S (S (L + 2 + clen a))) with pc' by lia.
        eapply rep_mono; [exact Hrep|lia|]. intros i _. reflexivity.
    + apply Nat.eqb_neq in E.
      eapply simres_fwd.
      * intros R HR. apply (exec_next _ (St (S (L + 2 + clen a)) pos m stk)).
        { unfold step. rewrite H4, Hes. destruct (Nat.eqb_spec p0 pos); [lia|reflexivity]. }
        eapply exec_next; [|exact HR].
        replace (S (L + 2 + clen a)) with (L + 3 + clen a) by lia. step_at H5.
      * apply (IHf _ _ _ _ Ht _ _ P X).
        -- eapply rep_re' with (pc' := pc') (pos' := pos');
             [exact Hcode|exact Hfr|exact Hpc'|simpl; lia|exact Hrep|].
           rewrite npg_nil by reflexivity. reflexivity.
        -- exact Hc.
        -- simpl. tauto.
  - (* ACheck, body that cannot match the empty string: only OP_JUMP *)
    destruct (code_star_nn _ _ _ _ _ Hc0 Hnu Hcode) as (H1 & Ha & H3).
    simpl in Ht. simpl in Hu. destruct Hu as (Na & D & U).
    subst pc.
    assert (E : Nat.eqb pos p0 = false).
    { apply Nat.eqb_neq. unfold nullable in Hnu. apply Nat.eqb_neq in Hnu. lia. }
    rewrite E in Ht.
    eapply simres_fwd.
    + intros R HR. eapply exec_next; [step_at H3|exact HR].
    + apply (IHf _ _ _ _ Ht _ _ P X).
      * eapply rep_re' with (pc' := pc') (pos' := pos');
          [exact Hcode|exact Hfr|exact Hpc'|simpl; lia|exact Hrep|].
        rewrite npg_nil by reflexivity. reflexivity.
      * exact Hc.
      * simpl. tauto.
Qed.

End Sim.
