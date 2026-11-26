(* Experiment #8 follow-up (issue #34): agreement of the C library, the
   direct semantics m (Absent.v) and the desugared model md (Desugar.v) on
   the absent corpus, by vm_compute at explicit fuels (no constant fuel in
   any lemma of the proofs; these fuels appear only here).
   Cases: lab/08-hard-features/cases/absent.tsv (ab01-ab11) and
   lab/08-discriminating-lemmas/cases/absent-restore.tsv (ab12-ab29).
   The expected value of each lemma is the C result, identical on the
   Debug and ASan/UBSan builds (lab/results/2026-11-26-exp-08-lemmas-cases.md).
   Patterns and subjects are in the two TSV files, by case id.
   Byte values: a=97 b=98 c=99 d=100 q=113 x=120 y=121 z=122. *)
From Stdlib Require Import List Arith.
Import ListNotations.
From S Require Import Absent Desugar.

Fixpoint lit (l : list nat) : re :=
  match l with [] => Eps | [c] => Chr c | c :: cs => Seq (Chr c) (lit cs) end.
Definition abc := lit [97;98;99].
Definition ostar := Star AnyO.
Definition dotstar := Star Any.

(* Fuels: G for occ's inner matcher, F for m and md. *)
Definition G := 1000.
Definition F := 1000.

(* The whole priority-ordered list of ends at one start, both matchers
   (C reports only the first match; lemma 2 is about the lists). *)
Definition ends_m (p : re) (s : list nat) (st : nat) : option (list nat) :=
  m s G F [R p] st (length s).
Definition ends_md (p : re) (s : list nat) (st : nat) : option (list nat) :=
  match md s F [DR (fst (desugar p 0))] st (length s) [] with
  | Some (rs, _) => Some (map (fun '(e, _, _) => e) rs)
  | None => None
  end.
Fixpoint lists_from (p : re) (s : list nat) (k st : nat) : bool :=
  match k with
  | 0 => true
  | S k => match ends_m p s st, ends_md p s st with
           | Some l1, Some l2 => if list_eq_dec Nat.eq_dec l1 l2 then lists_from p s k (S st) else false
           | _, _ => false
           end
  end.
Definition lists_agree (p : re) (s : list nat) : bool := lists_from p s (S (length s)) 0.

(* One case: C's result r agrees with m and with md on the desugared tree,
   and m and md give the same complete list of ends at every start. *)
Definition agree (p : re) (s : list nat) (r : sres) : Prop :=
  search G F p s = r /\ dsearch F p s = r /\ lists_agree p s = true.

(* ab01, C: M 0-0 *)
Lemma ab01 : agree (AbsRep (lit [97;98])) [97;98;99] (Match 0 0).
Proof. repeat split; vm_compute; reflexivity. Qed.

(* ab02, C: M 0-0 *)
Lemma ab02 : agree (AbsRep abc) [97;98;99] (Match 0 0).
Proof. repeat split; vm_compute; reflexivity. Qed.

(* ab03, C: M 0-0 *)
Lemma ab03 : agree (AbsRep (Alt abc (lit [97;98]))) [97;98;99] (Match 0 0).
Proof. repeat split; vm_compute; reflexivity. Qed.

(* ab04, C: M 0-5 *)
Lemma ab04 : agree (Seq (lit [97;97;97;97;97]) (AbsRep Eps)) [97;97;97;97;97;97;97;97;97;97] (Match 0 5).
Proof. repeat split; vm_compute; reflexivity. Qed.

(* ab05, C: M 0-0 *)
Lemma ab05 : agree (AbsExp abc ostar) [97;98;99] (Match 0 0).
Proof. repeat split; vm_compute; reflexivity. Qed.

(* ab06, C: M 0-1 *)
Lemma ab06 : agree (AbsRep abc) [120;97;98;99;120] (Match 0 1).
Proof. repeat split; vm_compute; reflexivity. Qed.

(* ab07, C: M 0-1 *)
Lemma ab07 : agree (AbsExp abc ostar) [120;97;98;99;120] (Match 0 1).
Proof. repeat split; vm_compute; reflexivity. Qed.

(* ab08, C: M 0-4 *)
Lemma ab08 : agree (Seq (AbsRep abc) (Chr 122)) [120;97;98;122] (Match 0 4).
Proof. repeat split; vm_compute; reflexivity. Qed.

(* ab09, C: M 0-4 *)
Lemma ab09 : agree (Seq (AbsExp abc ostar) (Chr 122)) [120;97;98;122] (Match 0 4).
Proof. repeat split; vm_compute; reflexivity. Qed.

(* ab10, C: M 0-2 *)
Lemma ab10 : agree (Seq (Stopper abc) dotstar) [120;120;97;98;99;121;121] (Match 0 2).
Proof. repeat split; vm_compute; reflexivity. Qed.

(* ab11, C: M 0-7 *)
Lemma ab11 : agree (Seq (Stopper abc) (Seq RClear dotstar)) [120;120;97;98;99;121;121] (Match 0 7).
Proof. repeat split; vm_compute; reflexivity. Qed.

(* ab12, C: M 0-6 *)
Lemma ab12 : agree (Alt (Seq (AbsRep abc) (Chr 122)) dotstar) [120;97;98;99;121;121] (Match 0 6).
Proof. repeat split; vm_compute; reflexivity. Qed.

(* ab13, C: M 0-6 *)
Lemma ab13 : agree (Alt (Seq (AbsExp abc ostar) (Chr 122)) dotstar) [120;97;98;99;121;121] (Match 0 6).
Proof. repeat split; vm_compute; reflexivity. Qed.

(* ab14, C: M 0-6 *)
Lemma ab14 : agree (Alt (Seq (Stopper abc) (Chr 122)) dotstar) [120;97;98;99;121;121] (Match 0 6).
Proof. repeat split; vm_compute; reflexivity. Qed.

(* ab15, C: M 0-5 *)
Lemma ab15 : agree (Alt (Seq (Stopper abc) (Seq ostar (Chr 122))) ostar) [120;97;98;99;122] (Match 0 5).
Proof. repeat split; vm_compute; reflexivity. Qed.

(* ab16, C: M 0-5 *)
Lemma ab16 : agree (Seq (AbsRep abc) ostar) [120;97;98;99;121] (Match 0 5).
Proof. repeat split; vm_compute; reflexivity. Qed.

(* ab17, C: M 0-4 *)
Lemma ab17 : agree (Seq (AbsExp abc (Star (Chr 120))) (Chr 97)) [120;120;120;97;98;99;121] (Match 0 4).
Proof. repeat split; vm_compute; reflexivity. Qed.

(* ab18, C: M 0-6 *)
Lemma ab18 : agree (Alt (Seq (AbsExp abc (Star (Chr 120))) (Chr 122)) ostar) [120;120;97;98;99;122] (Match 0 6).
Proof. repeat split; vm_compute; reflexivity. Qed.

(* ab19, C: M 6-7 *)
Lemma ab19 : agree (Seq (AbsExp abc (Star (Chr 120))) (Chr 121)) [120;120;120;97;98;99;121] (Match 6 7).
Proof. repeat split; vm_compute; reflexivity. Qed.

(* ab20, C: M 2-7 *)
Lemma ab20 : agree (Seq (AbsExp abc (Alt (Chr 120) (Seq AnyO (Seq AnyO (Seq AnyO AnyO))))) (Chr 113)) [120;97;98;99;113;113;113] (Match 2 7).
Proof. repeat split; vm_compute; reflexivity. Qed.

(* ab21, C: M 0-4 *)
Lemma ab21 : agree (Seq (AbsExp abc (Star (Alt (lit [120;120]) (Chr 120)))) (lit [120;97])) [120;120;120;97;98;99] (Match 0 4).
Proof. repeat split; vm_compute; reflexivity. Qed.

(* ab22, C: M 0-7 *)
Lemma ab22 : agree (Seq (AbsExp abc (Star (Alt (Chr 120) (Chr 121)))) ostar) [120;121;97;98;99;120;121] (Match 0 7).
Proof. repeat split; vm_compute; reflexivity. Qed.

(* ab23, C: M 0-2 *)
Lemma ab23 : agree (Seq (Stopper abc) (Alt (Seq RClear (Seq ostar (Chr 122))) ostar)) [120;120;97;98;99;121;121] (Match 0 2).
Proof. repeat split; vm_compute; reflexivity. Qed.

(* ab24, C: M 0-0 *)
Lemma ab24 : agree (AbsExp (Alt (Chr 97) Eps) (Star (Alt (Chr 120) (Chr 121)))) [120;121;97] (Match 0 0).
Proof. repeat split; vm_compute; reflexivity. Qed.

(* ab25, C: M 0-1 *)
Lemma ab25 : agree (Seq (AbsExp Eps ostar) (Chr 122)) [122] (Match 0 1).
Proof. repeat split; vm_compute; reflexivity. Qed.

(* ab26, C: M 1-2 *)
Lemma ab26 : agree (Seq (AbsRep Eps) (Chr 122)) [120;122] (Match 1 2).
Proof. repeat split; vm_compute; reflexivity. Qed.

(* ab27, C: M 0-7 *)
Lemma ab27 : agree (Seq (AbsExp (lit [97;98]) ostar) (Seq (AbsExp (lit [99;100]) ostar) (Chr 122))) [120;120;99;100;97;98;122] (Match 0 7).
Proof. repeat split; vm_compute; reflexivity. Qed.

(* ab28, C: M 0-4 *)
Lemma ab28 : agree (Star (Seq (AbsRep (lit [97;98])) (Chr 99))) [120;99;120;99;97;98;99] (Match 0 4).
Proof. repeat split; vm_compute; reflexivity. Qed.

(* ab29, C: M 0-6 *)
Lemma ab29 : agree (Seq (Star (Seq (Stopper (lit [97;98])) (Chr 99))) ostar) [120;99;97;98;99;99] (Match 0 6).
Proof. repeat split; vm_compute; reflexivity. Qed.

Print Assumptions ab11.
Print Assumptions ab29.
