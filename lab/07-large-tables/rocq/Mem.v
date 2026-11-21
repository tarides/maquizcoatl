(* Experiment #7: membership, name lookup and sanity checker over Table. *)
From Stdlib Require Import ZArith List String Bool.
From T Require Import Table.
Import ListNotations.
Open Scope Z_scope.

Fixpoint mem (c : Z) (l : list (Z * Z)) : bool :=
  match l with
  | [] => false
  | (lo, hi) :: t => if c <? lo then false else if c <=? hi then true else mem c t
  end.

Definition ctype_mem (ct c : Z) : bool := mem c (nth (Z.to_nat ct) code_ranges []).

Fixpoint lookup (s : string) (l : list (string * Z)) : Z :=
  match l with
  | [] => -1
  | (n, ct) :: t => if String.eqb s n then ct else lookup s t
  end.

Definition lookup_name (s : string) : Z := lookup s names.

(* Sorted, disjoint, non-adjacent: lo <= hi and hi + 1 < next lo. *)
Fixpoint ok_list (l : list (Z * Z)) : bool :=
  match l with
  | [] => true
  | [(lo, hi)] => lo <=? hi
  | (lo, hi) :: ((((lo', _) :: _) as t)) => (lo <=? hi) && (hi + 1 <? lo') && ok_list t
  end.

Definition table_ok : bool := forallb ok_list code_ranges.

Inductive sorted_disjoint : list (Z * Z) -> Prop :=
| sd_nil : sorted_disjoint []
| sd_one lo hi : lo <= hi -> sorted_disjoint [(lo, hi)]
| sd_cons lo hi lo' hi' t : lo <= hi -> hi + 1 < lo' ->
    sorted_disjoint ((lo', hi') :: t) -> sorted_disjoint ((lo, hi) :: (lo', hi') :: t).

(* Soundness of the boolean checker, independent of the table. *)
Lemma ok_list_sound : forall l, ok_list l = true -> sorted_disjoint l.
Proof.
  induction l as [|[lo hi] t IH]; intros H; [constructor|].
  destruct t as [|[lo' hi'] t'].
  - constructor. now apply Z.leb_le.
  - simpl in H. apply andb_prop in H as [H H3]. apply andb_prop in H as [H1 H2].
    constructor; [now apply Z.leb_le | now apply Z.ltb_lt | now apply IH].
Qed.

Lemma table_ok_sound : table_ok = true -> forall l, In l code_ranges -> sorted_disjoint l.
Proof.
  intros H l Hl. apply ok_list_sound. unfold table_ok in H.
  rewrite forallb_forall in H. auto.
Qed.
