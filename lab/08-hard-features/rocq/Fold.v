(* Experiment #8, Rocq: ISO-8859-1 multi-character case folding.
   Semantics fixed in lab/08-hard-features/SEMANTICS.md, "ISO-8859-1 folding". *)
From Stdlib Require Import List Arith Bool.
Import ListNotations.

Inductive re := Eps | Chr (c : nat) | Seq (a b : re) | Alt (a b : re) | ILit (w : list nat).

(* One-byte fold items of get_case_fold_codes_by_str (iso8859_1.c:116-215),
   for a position that does not start a two-byte ss spelling. *)
Definition one (c : nat) : list (list nat) :=
  if Nat.leb 65 c && Nat.leb c 90 then [[c + 32]]
  else if Nat.leb 97 c && Nat.leb c 122 then [[c - 32]]
  else if Nat.leb 192 c && Nat.leb c 207 then [[c + 32]]
  else if Nat.eqb c 223 then [[115;115]; [83;83]; [115;83]; [83;115]]
  else if Nat.leb 208 c && Nat.leb c 222 && negb (Nat.eqb c 215) then [[c + 32]]
  else if Nat.leb 224 c && Nat.leb c 239 then [[c - 32]]
  else if Nat.leb 240 c && Nat.leb c 254 && negb (Nat.eqb c 247) then [[c - 32]]
  else [].

Definition is_s (c : nat) : bool := Nat.eqb c 115 || Nat.eqb c 83.

(* Items of a two-byte ss spelling: 0xDF, then the other three spellings. *)
Definition ss_items (c d : nat) : list (list nat) :=
  [223] :: filter (fun w => match w with
                            | [x; y] => negb (Nat.eqb x c && Nat.eqb y d)
                            | _ => true end)
                  [[83;83]; [83;115]; [115;83]; [115;115]].

(* unravel_case_fold_string: one segment per pattern position, each the
   list of alternatives, original bytes first. *)
Fixpoint unr (prev : option nat) (w : list nat) : list (list (list nat)) :=
  match prev, w with
  | None, [] => []
  | Some c, [] => [[c] :: one c]
  | None, c :: rest => unr (Some c) rest
  | Some c, d :: rest =>
      if is_s c && is_s d then ([c; d] :: ss_items c d) :: unr None rest
      else ([c] :: one c) :: unr (Some d) rest
  end.
Definition unravel (w : list nat) := unr None w.

Inductive item := R (x : re) | Seg (alts : list (list nat)).

Section M.
Variable s : list nat.

Fixpoint prefix_at (i : nat) (w : list nat) : bool :=
  match w with
  | [] => true
  | c :: w => match nth_error s i with Some c' => Nat.eqb c c' && prefix_at (S i) w | None => false end
  end.

Fixpoint m (f : nat) (ks : list item) (i : nat) {struct f} : list nat :=
  match f with
  | 0 => []
  | S f =>
    match ks with
    | [] => [i]
    | R Eps :: ks => m f ks i
    | R (Chr c) :: ks =>
        match nth_error s i with Some c' => if Nat.eqb c c' then m f ks (S i) else [] | None => [] end
    | R (Seq a b) :: ks => m f (R a :: R b :: ks) i
    | R (Alt a b) :: ks => m f (R a :: ks) i ++ m f (R b :: ks) i
    | R (ILit w) :: ks => m f (map Seg (unravel w) ++ ks) i
    | Seg [] :: _ => []
    | Seg (w :: ws) :: ks =>
        (if prefix_at i w then m f ks (i + length w) else []) ++ m f (Seg ws :: ks) i
    end
  end.

Definition fuel := 1000.

Fixpoint search_from (main : re) (k st : nat) : option (nat * nat) :=
  match k with
  | 0 => None
  | S k => match m fuel [R main] st with
           | e :: _ => Some (st, e)
           | [] => search_from main k (S st)
           end
  end.
End M.

Definition search main s := search_from s main (S (length s)) 0.

(* Main lemma (SEMANTICS.md, lemma F): 0xDF matches each of ss, SS, sS, Ss, and back. *)
Theorem sharp_s : forall w, In w [[115;115]; [83;83]; [115;83]; [83;115]] ->
  search (ILit [223]) w = Some (0, 2) /\ search (ILit w) [223] = Some (0, 1).
Proof.
  intros w H; simpl in H.
  repeat (destruct H as [<-|H]; [split; vm_compute; reflexivity|]); contradiction.
Qed.

(* Test cases (cases/iso-fold.tsv). *)
Lemma cf21 : search (ILit [115;115]) [223] = Some (0, 1). Proof. vm_compute. reflexivity. Qed.
Lemma cf22 : search (ILit [223]) [115;115] = Some (0, 2). Proof. vm_compute. reflexivity. Qed.
Lemma if01 : search (ILit [223]) [83;83] = Some (0, 2). Proof. vm_compute. reflexivity. Qed.
Lemma if02 : search (ILit [223]) [115;83] = Some (0, 2). Proof. vm_compute. reflexivity. Qed.
Lemma if03 : search (ILit [223]) [83;115] = Some (0, 2). Proof. vm_compute. reflexivity. Qed.
Lemma if04 : search (ILit [83;83]) [223] = Some (0, 1). Proof. vm_compute. reflexivity. Qed.
Lemma if05 : search (ILit [115;83]) [223] = Some (0, 1). Proof. vm_compute. reflexivity. Qed.
Lemma if06 : search (ILit [83;115]) [223] = Some (0, 1). Proof. vm_compute. reflexivity. Qed.
Lemma if07 : search (ILit [83;83;98;223;115;115;99]) [97;223;98;83;83;223;99;100] = Some (1, 7).
Proof. vm_compute. reflexivity. Qed.
Lemma if08 : search (ILit [105;115]) [105;115;115] = Some (0, 2). Proof. vm_compute. reflexivity. Qed.

Print Assumptions sharp_s.
Print Assumptions if07.
