(* Experiment #8, Rocq: subexpression calls with the nest limit.
   Semantics fixed in lab/08-hard-features/SEMANTICS.md, section "Calls".
   First-order backtracking matcher over an explicit stack of pending
   items (defunctionalised continuation), priority-ordered results. *)
From Stdlib Require Import List Arith Lia.
Import ListNotations.

Inductive re := Eps | Chr (c : nat) | Any | Seq (a b : re) | Alt (a b : re)
              | Star (a : re) | Call (n : nat) | Bos | Eos.
Inductive item := R (x : re) | Ret | Chk (i : nat) (a : re).

Section M.
Variables (lim : nat) (defs : list re) (s : list nat).

(* m f ks i d mx: results (end, max depth) of the pending items ks at
   position i, nest depth d (live call frames), running maximum mx. *)
Fixpoint m (f : nat) (ks : list item) (i d mx : nat) {struct f} : list (nat * nat) :=
  match f with
  | 0 => []
  | S f =>
    match ks with
    | [] => [(i, mx)]
    | R Eps :: ks => m f ks i d mx
    | R (Chr c) :: ks =>
        match nth_error s i with
        | Some c' => if Nat.eqb c c' then m f ks (S i) d mx else []
        | None => []
        end
    | R Any :: ks =>
        match nth_error s i with
        | Some c' => if Nat.eqb c' 10 then [] else m f ks (S i) d mx
        | None => []
        end
    | R (Seq a b) :: ks => m f (R a :: R b :: ks) i d mx
    | R (Alt a b) :: ks => m f (R a :: ks) i d mx ++ m f (R b :: ks) i d mx
    | R (Star a) :: ks => m f (R a :: Chk i a :: ks) i d mx ++ m f ks i d mx
    | Chk i0 a :: ks =>
        if Nat.eqb i i0 then m f ks i d mx else m f (R (Star a) :: ks) i d mx
    | R (Call n) :: ks =>
        if Nat.leb lim d then []
        else match nth_error defs n with
             | Some b => m f (R b :: Ret :: ks) i (S d) (Nat.max mx (S d))
             | None => []
             end
    | Ret :: ks => m f ks i (pred d) mx
    | R Bos :: ks => if Nat.eqb i 0 then m f ks i d mx else []
    | R Eos :: ks => if Nat.eqb i (length s) then m f ks i d mx else []
    end
  end.

Fixpoint search_from (f : nat) (main : re) (k st : nat) : option (nat * nat) :=
  match k with
  | 0 => None
  | S k =>
    match m f [R main] st 0 0 with
    | (e, _) :: _ => Some (st, e)
    | [] => search_from f main k (S st)
    end
  end.

(* Main lemma (SEMANTICS.md, "Calls", lemma C). *)
Lemma depth_bound : forall f ks i d mx e x,
  d <= lim -> mx <= lim -> In (e, x) (m f ks i d mx) -> x <= lim.
Proof.
  induction f as [|f IH]; intros ks i d mx e x Hd Hmx H; simpl in H; [contradiction|].
  destruct ks as [|[r| |i0 a] ks].
  - destruct H as [H|[]]; injection H; intros; subst; assumption.
  - destruct r; simpl in H;
      repeat match goal with
      | H : In _ (_ ++ _) |- _ => apply in_app_or in H; destruct H as [H|H]
      | H : In _ [] |- _ => destruct H
      | H : In _ (match ?x with _ => _ end) |- _ => destruct x eqn:?
      | H : In _ (if ?b then _ else _) |- _ => destruct b eqn:?
      end;
      try solve [refine (IH _ _ _ _ _ _ _ _ H); lia].
    (* Call: the frame is pushed only below the limit *)
    apply Nat.leb_gt in Heqb. refine (IH _ _ _ _ _ _ _ _ H); lia.
  - refine (IH _ _ _ _ _ _ _ _ H); lia.
  - destruct (Nat.eqb i i0); refine (IH _ _ _ _ _ _ _ _ H); lia.
Qed.

Definition default_limit := 20.
Definition fuel := 1000.
End M.

Definition search lim defs main s :=
  search_from lim defs s fuel main (S (length s)) 0.

(* Test cases (cases/calls.tsv, nest.tsv); a=97 b=98 (=40 )=41. *)
Definition a := Chr 97. Definition b := Chr 98.
Definition lp := Chr 40. Definition rp := Chr 41.
Definition d1 := [a].                            (* (a)\g<1> *)
Definition m1 := Seq (Call 0) (Call 0).
Definition d2 := [Seq a b].                      (* (?<name_2>ab)\g<name_2> *)
Definition d3 := [Alt (Seq a (Call 0)) Eps].     (* \A(?<n>(a\g<n>)|)\z *)
Definition m3 := Seq Bos (Seq (Call 0) Eos).
Definition d4 := [Alt a (Seq lp (Seq (Call 0) rp))]. (* (?<foo>a|\(\g<foo>\)) *)
Definition d5 := [Alt (Seq a (Call 0)) b].       (* \A(?<n>a\g<n>|b)\z *)
Definition s4 := [40;40;40;40;40;40;97;41;41;41;41;41;41].

Lemma ca01 : search default_limit d1 m1 [97;97] = Some (0, 2). Proof. vm_compute. reflexivity. Qed.
Lemma ca02 : search default_limit d2 m1 [97;98;97;98] = Some (0, 4). Proof. vm_compute. reflexivity. Qed.
Lemma ca03 : search default_limit d3 m3 [97;97;97;97] = Some (0, 4). Proof. vm_compute. reflexivity. Qed.
Lemma ca04 : search default_limit d4 (Call 0) s4 = Some (0, 13). Proof. vm_compute. reflexivity. Qed.
Lemma ca05 : search default_limit d5 m3 [97;97;97;98] = Some (0, 4). Proof. vm_compute. reflexivity. Qed.
Lemma nc01 : search 2 d5 m3 [97;97;97;98] = None. Proof. vm_compute. reflexivity. Qed.
Lemma nc02 : search 20 d5 m3 [97;97;97;98] = Some (0, 4). Proof. vm_compute. reflexivity. Qed.
Lemma nc03 : search 2 d4 (Call 0) s4 = Some (5, 8). Proof. vm_compute. reflexivity. Qed.
Lemma nc04 : search 0 d1 m1 [97;97] = None. Proof. vm_compute. reflexivity. Qed.
Lemma ns01_3 : search 3 d5 m3 [97;97;97;98] = None. Proof. vm_compute. reflexivity. Qed.
Lemma ns01_4 : search 4 d5 m3 [97;97;97;98] = Some (0, 4). Proof. vm_compute. reflexivity. Qed.
Lemma ns02_1 : search 1 d4 (Call 0) s4 = Some (6, 7). Proof. vm_compute. reflexivity. Qed.
Lemma ns02_6 : search 6 d4 (Call 0) s4 = Some (1, 12). Proof. vm_compute. reflexivity. Qed.
Lemma ns02_7 : search 7 d4 (Call 0) s4 = Some (0, 13). Proof. vm_compute. reflexivity. Qed.

Print Assumptions depth_bound.
Print Assumptions ca04.
Print Assumptions nc03.
