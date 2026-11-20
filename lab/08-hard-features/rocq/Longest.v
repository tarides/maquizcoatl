(* Experiment #8, Rocq: ONIG_OPTION_FIND_LONGEST (forward search).
   Semantics fixed in lab/08-hard-features/SEMANTICS.md, "FIND_LONGEST". *)
From Stdlib Require Import List Arith Lia Bool.
Import ListNotations.

Inductive re := Eps | Chr (c : nat) | Word | Seq (a b : re) | Alt (a b : re) | Star (a : re).
Inductive item := R (x : re) | Chk (i : nat) (a : re).

(* \w on ASCII: [0-9A-Za-z_] *)
Definition is_word (c : nat) : bool :=
  (Nat.leb 48 c && Nat.leb c 57) || (Nat.leb 65 c && Nat.leb c 90)
  || (Nat.leb 97 c && Nat.leb c 122) || Nat.eqb c 95.

Section M.
Variable s : list nat.

Fixpoint m (f : nat) (ks : list item) (i : nat) {struct f} : list nat :=
  match f with
  | 0 => []
  | S f =>
    match ks with
    | [] => [i]
    | R Eps :: ks => m f ks i
    | R (Chr c) :: ks =>
        match nth_error s i with Some c' => if Nat.eqb c c' then m f ks (S i) else [] | None => [] end
    | R Word :: ks =>
        match nth_error s i with Some c' => if is_word c' then m f ks (S i) else [] | None => [] end
    | R (Seq a b) :: ks => m f (R a :: R b :: ks) i
    | R (Alt a b) :: ks => m f (R a :: ks) i ++ m f (R b :: ks) i
    | R (Star a) :: ks => m f (R a :: Chk i a :: ks) i ++ m f ks i
    | Chk i0 a :: ks => if Nat.eqb i i0 then m f ks i else m f (R (Star a) :: ks) i
    end
  end.

Definition fuel := 1000.

(* help: the two searches are generic in the per-start results [res]; with
   m inlined, the kernel check (Qed) of the lemmas unfolded the 1000-step
   fuel and did not finish (killed after more than 60 s, twice). *)
Variable res : nat -> list nat.

(* First-match search. *)
Fixpoint search_from (k st : nat) : option (nat * nat) :=
  match k with
  | 0 => None
  | S k => match res st with
           | e :: _ => Some (st, e)
           | [] => search_from k (S st)
           end
  end.

Definition better (st e : nat) (b : option (nat * nat)) : bool :=
  match b with None => true | Some (s0, e0) => Nat.ltb (e0 - s0) (e - st) end.

Fixpoint pick (st : nat) (b : option (nat * nat)) (l : list nat) : option (nat * nat) :=
  match l with
  | [] => b
  | e :: es => pick st (if better st e b then Some (st, e) else b) es
  end.

(* FIND_LONGEST: every start, every result, the first of maximal length. *)
Fixpoint longest_from (b : option (nat * nat)) (k st : nat) : option (nat * nat) :=
  match k with
  | 0 => b
  | S k => longest_from (pick st b (res st)) k (S st)
  end.

Definition ge (b : option (nat * nat)) (n : nat) : Prop :=
  match b with None => False | Some (a, e) => n <= e - a end.

(* Main lemma (SEMANTICS.md, "FIND_LONGEST", lemma L). *)
Lemma pick_mono : forall st l b n, ge b n -> ge (pick st b l) n.
Proof.
  intros st l; induction l as [|e es IH]; intros b n H; simpl; [exact H|].
  apply IH. destruct (better st e b) eqn:E; [|exact H].
  destruct b as [[s0 e0]|]; simpl in *; [|contradiction].
  apply Nat.ltb_lt in E. lia.
Qed.

Lemma pick_mem : forall st l b e, In e l -> ge (pick st b l) (e - st).
Proof.
  intros st l; induction l as [|e' es IH]; intros b e H; simpl in H; [contradiction|].
  simpl. destruct H as [<-|H]; [|apply IH; exact H].
  apply pick_mono. destruct (better st e' b) eqn:E; simpl; [lia|].
  destruct b as [[s0 e0]|]; simpl in *; [|discriminate].
  apply Nat.ltb_ge in E. lia.
Qed.

Lemma longest_mono : forall k st b n, ge b n -> ge (longest_from b k st) n.
Proof.
  intros k; induction k; intros st b n H; simpl; [exact H|].
  apply IHk, pick_mono, H.
Qed.

Lemma longest_ge_first : forall k st b s1 e1,
  search_from k st = Some (s1, e1) -> ge (longest_from b k st) (e1 - s1).
Proof.
  intros k; induction k; intros st b s1 e1 H; simpl in H; [discriminate|].
  simpl. destruct (res st) as [|e rest] eqn:E.
  - apply IHk, H.
  - injection H as H1 H2; subst s1 e1. apply longest_mono, pick_mem. left. reflexivity.
Qed.
End M.

(* The fuel is a parameter here so that the kernel never sees the
   1000-step constant in the lemma (help, see above). *)
Definition results f s main st := m s f [R main] st.
Definition search_f f main s := search_from (results f s main) (S (length s)) 0.
Definition longest_f f main s := longest_from (results f s main) None (S (length s)) 0.
Definition search := search_f fuel.
Definition longest := longest_f fuel.

Theorem longest_no_shorter : forall f main s s1 e1, search_f f main s = Some (s1, e1) ->
  exists s2 e2, longest_f f main s = Some (s2, e2) /\ e1 - s1 <= e2 - s2.
Proof.
  intros f main s s1 e1 H. pose proof (longest_ge_first (results f s main) _ 0 None s1 e1 H) as G.
  unfold longest_f. revert G. generalize (longest_from (results f s main) None (S (length s)) 0).
  intros [[s2 e2]|] G; simpl in G; [exists s2, e2; split; [reflexivity|exact G]|contradiction].
Qed.

(* Test cases (cases/find-longest.tsv). *)
Definition w1 := Seq Word (Star Word).
Definition a := Chr 97.
Definition bcd := Seq (Chr 98) (Seq (Chr 99) (Chr 100)).
Definition ab := Seq (Chr 97) (Chr 98).
Definition s1 := [97;98;99;32;100;101;102;103;32;104;105;106].
Definition s2 := [97;98;32;99;100;32;101;102].

Lemma fl01 : longest w1 s1 = Some (4, 8). Proof. vm_compute. reflexivity. Qed.
Lemma fl02 : longest w1 s2 = Some (0, 2). Proof. vm_compute. reflexivity. Qed.
Lemma fl03 : longest (Alt a bcd) [97;98;99;100] = Some (1, 4). Proof. vm_compute. reflexivity. Qed.
Lemma fl04 : longest (Alt a ab) [97;98] = Some (0, 2). Proof. vm_compute. reflexivity. Qed.
Lemma fl05 : search (Alt a bcd) [97;98;99;100] = Some (0, 1). Proof. vm_compute. reflexivity. Qed.
Lemma fl06 : search (Alt a ab) [97;98] = Some (0, 1). Proof. vm_compute. reflexivity. Qed.

Print Assumptions longest_no_shorter.
Print Assumptions fl01.
