(* Experiment #8, Rocq: the absent operator (non-nested).
   Semantics fixed in lab/08-hard-features/SEMANTICS.md, "Absent operator".
   The state carries the right range rr; every consuming step checks i < rr. *)
From Stdlib Require Import List Arith Lia Bool.
Import ListNotations.

Inductive re := Eps | Chr (c : nat) | Any | AnyO | Seq (a b : re) | Alt (a b : re)
              | Star (a : re) | AbsRep (a : re) | AbsExp (a e : re) | Stopper (a : re)
              | RClear.
Inductive item := R (x : re) | Chk (i : nat) (a : re) | SetRR (n : nat) | Ends (es : list nat).

Section M.
Variable s : list nat.

Definition at_ (i rr : nat) : option nat := if Nat.ltb i rr then nth_error s i else None.

(* Base matcher, absent-free patterns: does ks have a result at i? *)
Fixpoint mb (f : nat) (ks : list item) (i rr : nat) {struct f} : bool :=
  match f with
  | 0 => false
  | S f =>
    match ks with
    | [] => true
    | R Eps :: ks => mb f ks i rr
    | R (Chr c) :: ks =>
        match at_ i rr with Some c' => if Nat.eqb c c' then mb f ks (S i) rr else false | None => false end
    | R Any :: ks =>
        match at_ i rr with Some c' => if Nat.eqb c' 10 then false else mb f ks (S i) rr | None => false end
    | R AnyO :: ks => match at_ i rr with Some _ => mb f ks (S i) rr | None => false end
    | R (Seq a b) :: ks => mb f (R a :: R b :: ks) i rr
    | R (Alt a b) :: ks => mb f (R a :: ks) i rr || mb f (R b :: ks) i rr
    | R (Star a) :: ks => mb f (R a :: Chk i a :: ks) i rr || mb f ks i rr
    | Chk i0 a :: ks => if Nat.eqb i i0 then mb f ks i rr else mb f (R (Star a) :: ks) i rr
    | SetRR n :: ks => mb f ks i n
    | _ :: _ => false (* absent constructors, Ends: out of scope here *)
    end
  end.

Definition fuel := 1000.
Definition occ (a : re) (p rr : nat) : bool := mb fuel [R a] p rr.

(* help: scan is generic in the predicate; with occ inlined, the kernel
   check of the scan lemmas unfolded the 1000-step fuel (over 60 s). *)
Fixpoint scan (P : nat -> bool) (k p : nat) : nat :=
  match k with
  | 0 => p
  | S k => if P p then p else scan P k (S p)
  end.
Definition cut (a : re) (i rr : nat) : nat := scan (fun p => occ a p rr) (rr - i) i.

Fixpoint downs (n i : nat) : list nat :=
  match n with 0 => [i] | S n => (i + S n) :: downs n i end.
Definition rep_ends (a : re) (i rr : nat) : list nat := downs (cut a i rr - i) i.

Fixpoint m (f : nat) (ks : list item) (i rr : nat) {struct f} : list nat :=
  match f with
  | 0 => []
  | S f =>
    match ks with
    | [] => [i]
    | R Eps :: ks => m f ks i rr
    | R (Chr c) :: ks =>
        match at_ i rr with Some c' => if Nat.eqb c c' then m f ks (S i) rr else [] | None => [] end
    | R Any :: ks =>
        match at_ i rr with Some c' => if Nat.eqb c' 10 then [] else m f ks (S i) rr | None => [] end
    | R AnyO :: ks => match at_ i rr with Some _ => m f ks (S i) rr | None => [] end
    | R (Seq a b) :: ks => m f (R a :: R b :: ks) i rr
    | R (Alt a b) :: ks => m f (R a :: ks) i rr ++ m f (R b :: ks) i rr
    | R (Star a) :: ks => m f (R a :: Chk i a :: ks) i rr ++ m f ks i rr
    | Chk i0 a :: ks => if Nat.eqb i i0 then m f ks i rr else m f (R (Star a) :: ks) i rr
    | SetRR n :: ks => m f ks i n
    | R (AbsRep a) :: ks => m f (Ends (rep_ends a i rr) :: ks) i rr
    | Ends [] :: _ => []
    | Ends (e :: es) :: ks => m f ks e rr ++ m f (Ends es :: ks) i rr
    | R (AbsExp a e) :: ks => m f (R e :: SetRR rr :: ks) i (cut a i rr)
    | R (Stopper a) :: ks => m f ks i (cut a i rr)
    | R RClear :: ks => m f ks i (length s)
    end
  end.

Fixpoint search_from (main : re) (k st : nat) : option (nat * nat) :=
  match k with
  | 0 => None
  | S k => match m fuel [R main] st (length s) with
           | e :: _ => Some (st, e)
           | [] => search_from main k (S st)
           end
  end.

(* Main lemma (SEMANTICS.md, "Absent operator", lemma A). *)
Lemma scan_ge : forall P k p, p <= scan P k p.
Proof.
  induction k; intros p; simpl; [lia|].
  destruct (P p); [lia|]. specialize (IHk (S p)). lia.
Qed.

Lemma scan_none : forall P k p q, p <= q -> q < scan P k p -> P q = false.
Proof.
  induction k; intros p q H1 H2; simpl in H2; [lia|].
  destruct (P p) eqn:E; [lia|].
  destruct (Nat.eq_dec q p) as [->|Hne]; [exact E|].
  apply (IHk (S p)); lia.
Qed.

Lemma downs_mem : forall n i e, In e (downs n i) -> i <= e <= i + n.
Proof.
  induction n; intros i e H; simpl in H.
  - destruct H as [<-|[]]; lia.
  - destruct H as [<-|H]; [lia|]. specialize (IHn i e H). lia.
Qed.

Lemma absent_not_inside : forall a i rr e, In e (rep_ends a i rr) ->
  forall p, i <= p -> p < e -> occ a p rr = false.
Proof.
  intros a i rr e He p H1 H2. unfold rep_ends, cut in He.
  apply downs_mem in He. pose proof (scan_ge (fun p => occ a p rr) (rr - i) i).
  apply (scan_none (fun p => occ a p rr) (rr - i) i p); lia.
Qed.
End M.

Definition search main s := search_from s main (S (length s)) 0.

(* Test cases (cases/absent.tsv); a=97 b=98 c=99 x=120 y=121 z=122. *)
Fixpoint lit (l : list nat) : re :=
  match l with [] => Eps | [c] => Chr c | c :: cs => Seq (Chr c) (lit cs) end.
Definition abc := lit [97;98;99].
Definition ostar := Star AnyO.
Definition dotstar := Star Any.

Lemma ab01 : search (AbsRep (lit [97;98])) [97;98;99] = Some (0, 0). Proof. vm_compute. reflexivity. Qed.
Lemma ab02 : search (AbsRep abc) [97;98;99] = Some (0, 0). Proof. vm_compute. reflexivity. Qed.
Lemma ab03 : search (AbsRep (Alt abc (lit [97;98]))) [97;98;99] = Some (0, 0). Proof. vm_compute. reflexivity. Qed.
Lemma ab04 : search (Seq (lit [97;97;97;97;97]) (AbsRep Eps)) (repeat 97 10) = Some (0, 5). Proof. vm_compute. reflexivity. Qed.
Lemma ab05 : search (AbsExp abc ostar) [97;98;99] = Some (0, 0). Proof. vm_compute. reflexivity. Qed.
Lemma ab06 : search (AbsRep abc) [120;97;98;99;120] = Some (0, 1). Proof. vm_compute. reflexivity. Qed.
Lemma ab07 : search (AbsExp abc ostar) [120;97;98;99;120] = Some (0, 1). Proof. vm_compute. reflexivity. Qed.
Lemma ab08 : search (Seq (AbsRep abc) (Chr 122)) [120;97;98;122] = Some (0, 4). Proof. vm_compute. reflexivity. Qed.
Lemma ab09 : search (Seq (AbsExp abc ostar) (Chr 122)) [120;97;98;122] = Some (0, 4). Proof. vm_compute. reflexivity. Qed.
Lemma ab10 : search (Seq (Stopper abc) dotstar) [120;120;97;98;99;121;121] = Some (0, 2). Proof. vm_compute. reflexivity. Qed.
Lemma ab11 : search (Seq (Stopper abc) (Seq RClear dotstar)) [120;120;97;98;99;121;121] = Some (0, 7). Proof. vm_compute. reflexivity. Qed.

Print Assumptions absent_not_inside.
Print Assumptions ab07.
Print Assumptions ab11.
