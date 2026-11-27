(* Experiment #8, Rocq: the absent operator (non-nested).
   Semantics fixed in lab/08-hard-features/SEMANTICS.md, "Absent operator".
   The state carries the right range rr; every consuming step checks i < rr.

   Experiment #8 follow-up (issue #34), changes to experiment #8's file
   (lab/08-hard-features/rocq/Absent.v, main at 6630262), recorded in
   lab/08-discriminating-lemmas/LEMMAS.md, section "Changes to experiment
   #8's definitions":
   C1 mb returns option bool (None: out of fuel), so that occ's fuel
      exhaustion is observable;
   C2 occ takes its fuel g as a parameter (was the constant fuel);
   C3 scan, cut and rep_ends return options and propagate None;
   C4 m returns option (list nat) (None: out of fuel, or an occ out of
      fuel) and takes g;
   C5 search takes both fuels and returns a three-way result;
   C6 lemma A (absent_not_inside) restated for the option cut.
   The equations are otherwise experiment #8's. *)
From Stdlib Require Import List Arith Lia Bool.
Import ListNotations.

Inductive re := Eps | Chr (c : nat) | Any | AnyO | Seq (a b : re) | Alt (a b : re)
              | Star (a : re) | AbsRep (a : re) | AbsExp (a e : re) | Stopper (a : re)
              | RClear.
Inductive item := R (x : re) | Chk (i : nat) (a : re) | SetRR (n : nat) | Ends (es : list nat).

Section M.
Variable s : list nat.

Definition at_ (i rr : nat) : option nat := if Nat.ltb i rr then nth_error s i else None.

(* Option "or", left first: a true left branch decides (C1). *)
Definition oor (x : option bool) (y : unit -> option bool) : option bool :=
  match x with Some true => Some true | Some false => y tt | None => None end.

(* Base matcher, absent-free patterns: does ks have a result at i?
   None: out of fuel (C1). *)
Fixpoint mb (f : nat) (ks : list item) (i rr : nat) {struct f} : option bool :=
  match f with
  | 0 => None
  | S f =>
    match ks with
    | [] => Some true
    | R Eps :: ks => mb f ks i rr
    | R (Chr c) :: ks =>
        match at_ i rr with Some c' => if Nat.eqb c c' then mb f ks (S i) rr else Some false | None => Some false end
    | R Any :: ks =>
        match at_ i rr with Some c' => if Nat.eqb c' 10 then Some false else mb f ks (S i) rr | None => Some false end
    | R AnyO :: ks => match at_ i rr with Some _ => mb f ks (S i) rr | None => Some false end
    | R (Seq a b) :: ks => mb f (R a :: R b :: ks) i rr
    | R (Alt a b) :: ks => oor (mb f (R a :: ks) i rr) (fun _ => mb f (R b :: ks) i rr)
    | R (Star a) :: ks => oor (mb f (R a :: Chk i a :: ks) i rr) (fun _ => mb f ks i rr)
    | Chk i0 a :: ks => if Nat.eqb i i0 then mb f ks i rr else mb f (R (Star a) :: ks) i rr
    | SetRR n :: ks => mb f ks i n
    | _ :: _ => Some false (* absent constructors, Ends: out of scope here *)
    end
  end.

Variable g : nat. (* occ's fuel (C2) *)
Definition occ (a : re) (p rr : nat) : option bool := mb g [R a] p rr.

(* help: scan is generic in the predicate; with occ inlined, the kernel
   check of the scan lemmas unfolded the 1000-step fuel (over 60 s). *)
Fixpoint scan (P : nat -> option bool) (k p : nat) : option nat :=
  match k with
  | 0 => Some p
  | S k => match P p with Some true => Some p | Some false => scan P k (S p) | None => None end
  end.
Definition cut (a : re) (i rr : nat) : option nat := scan (fun p => occ a p rr) (rr - i) i.

Fixpoint downs (n i : nat) : list nat :=
  match n with 0 => [i] | S n => (i + S n) :: downs n i end.
Definition rep_ends (a : re) (i rr : nat) : option (list nat) :=
  match cut a i rr with Some c => Some (downs (c - i) i) | None => None end.

(* Option append: both sides complete (C4). *)
Definition oapp (x y : option (list nat)) : option (list nat) :=
  match x, y with Some l1, Some l2 => Some (l1 ++ l2) | _, _ => None end.

Fixpoint m (f : nat) (ks : list item) (i rr : nat) {struct f} : option (list nat) :=
  match f with
  | 0 => None
  | S f =>
    match ks with
    | [] => Some [i]
    | R Eps :: ks => m f ks i rr
    | R (Chr c) :: ks =>
        match at_ i rr with Some c' => if Nat.eqb c c' then m f ks (S i) rr else Some [] | None => Some [] end
    | R Any :: ks =>
        match at_ i rr with Some c' => if Nat.eqb c' 10 then Some [] else m f ks (S i) rr | None => Some [] end
    | R AnyO :: ks => match at_ i rr with Some _ => m f ks (S i) rr | None => Some [] end
    | R (Seq a b) :: ks => m f (R a :: R b :: ks) i rr
    | R (Alt a b) :: ks => oapp (m f (R a :: ks) i rr) (m f (R b :: ks) i rr)
    | R (Star a) :: ks => oapp (m f (R a :: Chk i a :: ks) i rr) (m f ks i rr)
    | Chk i0 a :: ks => if Nat.eqb i i0 then m f ks i rr else m f (R (Star a) :: ks) i rr
    | SetRR n :: ks => m f ks i n
    | R (AbsRep a) :: ks =>
        match rep_ends a i rr with Some es => m f (Ends es :: ks) i rr | None => None end
    | Ends [] :: _ => Some []
    | Ends (e :: es) :: ks => oapp (m f ks e rr) (m f (Ends es :: ks) i rr)
    | R (AbsExp a e) :: ks =>
        match cut a i rr with Some c => m f (R e :: SetRR rr :: ks) i c | None => None end
    | R (Stopper a) :: ks =>
        match cut a i rr with Some c => m f ks i c | None => None end
    | R RClear :: ks => m f ks i (length s)
    end
  end.

(* Search result (C5): the first start with a result, no match, or out of
   fuel at some start. *)
Inductive sres := Match (st e : nat) | NoMatch | OutOfFuel.

Fixpoint search_from (f : nat) (main : re) (k st : nat) : sres :=
  match k with
  | 0 => NoMatch
  | S k => match m f [R main] st (length s) with
           | Some (e :: _) => Match st e
           | Some [] => search_from f main k (S st)
           | None => OutOfFuel
           end
  end.

(* Main lemma (SEMANTICS.md, "Absent operator", lemma A). *)
Lemma scan_ge : forall P k p c, scan P k p = Some c -> p <= c.
Proof.
  induction k; intros p c H; simpl in H; [injection H; lia|].
  destruct (P p) as [[|]|]; [injection H; lia| |discriminate].
  specialize (IHk (S p) c H). lia.
Qed.

Lemma scan_none : forall P k p q c, scan P k p = Some c -> p <= q -> q < c -> P q = Some false.
Proof.
  induction k; intros p q c H H1 H2; simpl in H; [injection H; lia|].
  destruct (P p) as [[|]|] eqn:E; [injection H; lia| |discriminate].
  destruct (Nat.eq_dec q p) as [->|Hne]; [exact E|].
  apply (IHk (S p) q c H); lia.
Qed.

Lemma downs_mem : forall n i e, In e (downs n i) -> i <= e <= i + n.
Proof.
  induction n; intros i e H; simpl in H.
  - destruct H as [<-|[]]; lia.
  - destruct H as [<-|H]; [lia|]. specialize (IHn i e H). lia.
Qed.

(* C6: lemma A for the option cut; occ is complete (Some false) below e. *)
Lemma absent_not_inside : forall a i rr es e, rep_ends a i rr = Some es -> In e es ->
  forall p, i <= p -> p < e -> occ a p rr = Some false.
Proof.
  intros a i rr es e Hr He p H1 H2. unfold rep_ends in Hr.
  destruct (cut a i rr) as [c|] eqn:Hc; [|discriminate]. injection Hr as <-.
  apply downs_mem in He. unfold cut in Hc. pose proof (scan_ge _ _ _ _ Hc).
  apply (scan_none _ _ _ _ _ Hc); lia.
Qed.
End M.

Definition search g f main s := search_from s g f main (S (length s)) 0.

(* C5: experiment #8's case lemmas ab01-ab11 and their Print Assumptions
   moved to Cases.v, which runs them at explicit fuels together with the
   desugared model; lit, abc, ostar and dotstar moved with them. *)
Print Assumptions absent_not_inside.
