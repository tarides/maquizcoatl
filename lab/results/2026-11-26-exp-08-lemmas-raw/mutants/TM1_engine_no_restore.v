(* Experiment #8 follow-up (issue #34): agreement of the C library, the
   direct semantics m (Absent.v) and the desugared model md (Desugar.v) on
   the absent corpus, by vm_compute at explicit fuels (no constant fuel in
   any lemma of the proofs; these fuels appear only here).
   Cases: lab/08-hard-features/cases/absent.tsv (ab01-ab11) and
   lab/08-discriminating-lemmas/cases/absent-restore.tsv (ab12-ab27).
   The expected value of each lemma is the C result, identical on the
   Debug and ASan/UBSan builds (lab/results/2026-11-26-exp-08-lemmas-cases.md).
   Patterns and subjects are in the two TSV files, by case id.
   Byte values: a=97 b=98 c=99 d=100 q=113 x=120 y=121 z=122. *)
From Stdlib Require Import List Arith.
Import ListNotations.
From S Require Import Absent DM1_engine_no_restore.

Fixpoint lit (l : list nat) : re :=
  match l with [] => Eps | [c] => Chr c | c :: cs => Seq (Chr c) (lit cs) end.
Definition abc := lit [97;98;99].
Definition ostar := Star AnyO.
Definition dotstar := Star Any.

(* Fuels: G for occ's inner matcher, F for m and md. *)
Definition G := 1000.
Definition F := 1000.

From Stdlib Require Import String Bool.
Open Scope string_scope.
Definition results := [("ab01", dsearch F (AbsRep (lit [97;98])) [97;98;99], Match 0 0);
 ("ab02", dsearch F (AbsRep abc) [97;98;99], Match 0 0);
 ("ab03", dsearch F (AbsRep (Alt abc (lit [97;98]))) [97;98;99], Match 0 0);
 ("ab04", dsearch F (Seq (lit [97;97;97;97;97]) (AbsRep Eps)) [97;97;97;97;97;97;97;97;97;97], Match 0 5);
 ("ab05", dsearch F (AbsExp abc ostar) [97;98;99], Match 0 0);
 ("ab06", dsearch F (AbsRep abc) [120;97;98;99;120], Match 0 1);
 ("ab07", dsearch F (AbsExp abc ostar) [120;97;98;99;120], Match 0 1);
 ("ab08", dsearch F (Seq (AbsRep abc) (Chr 122)) [120;97;98;122], Match 0 4);
 ("ab09", dsearch F (Seq (AbsExp abc ostar) (Chr 122)) [120;97;98;122], Match 0 4);
 ("ab10", dsearch F (Seq (Stopper abc) dotstar) [120;120;97;98;99;121;121], Match 0 2);
 ("ab11", dsearch F (Seq (Stopper abc) (Seq RClear dotstar)) [120;120;97;98;99;121;121], Match 0 7);
 ("ab12", dsearch F (Alt (Seq (AbsRep abc) (Chr 122)) dotstar) [120;97;98;99;121;121], Match 0 6);
 ("ab13", dsearch F (Alt (Seq (AbsExp abc ostar) (Chr 122)) dotstar) [120;97;98;99;121;121], Match 0 6);
 ("ab14", dsearch F (Alt (Seq (Stopper abc) (Chr 122)) dotstar) [120;97;98;99;121;121], Match 0 6);
 ("ab15", dsearch F (Alt (Seq (Stopper abc) (Seq ostar (Chr 122))) ostar) [120;97;98;99;122], Match 0 5);
 ("ab16", dsearch F (Seq (AbsRep abc) ostar) [120;97;98;99;121], Match 0 5);
 ("ab17", dsearch F (Seq (AbsExp abc (Star (Chr 120))) (Chr 97)) [120;120;120;97;98;99;121], Match 0 4);
 ("ab18", dsearch F (Alt (Seq (AbsExp abc (Star (Chr 120))) (Chr 122)) ostar) [120;120;97;98;99;122], Match 0 6);
 ("ab19", dsearch F (Seq (AbsExp abc (Star (Chr 120))) (Chr 121)) [120;120;120;97;98;99;121], Match 6 7);
 ("ab20", dsearch F (Seq (AbsExp abc (Alt (Chr 120) (Seq AnyO (Seq AnyO (Seq AnyO AnyO))))) (Chr 113)) [120;97;98;99;113;113;113], Match 2 7);
 ("ab21", dsearch F (Seq (AbsExp abc (Star (Alt (lit [120;120]) (Chr 120)))) (lit [120;97])) [120;120;120;97;98;99], Match 0 4);
 ("ab22", dsearch F (Seq (AbsExp abc (Star (Alt (Chr 120) (Chr 121)))) ostar) [120;121;97;98;99;120;121], Match 0 7);
 ("ab23", dsearch F (Seq (Stopper abc) (Alt (Seq RClear (Seq ostar (Chr 122))) ostar)) [120;120;97;98;99;121;121], Match 0 2);
 ("ab24", dsearch F (AbsExp (Alt (Chr 97) Eps) (Star (Alt (Chr 120) (Chr 121)))) [120;121;97], Match 0 0);
 ("ab25", dsearch F (Seq (AbsExp Eps ostar) (Chr 122)) [122], Match 0 1);
 ("ab26", dsearch F (Seq (AbsRep Eps) (Chr 122)) [120;122], Match 1 2);
 ("ab27", dsearch F (Seq (AbsExp (lit [97;98]) ostar) (Seq (AbsExp (lit [99;100]) ostar) (Chr 122))) [120;120;99;100;97;98;122], Match 0 7)].
Definition sres_eqb (a b : sres) := match a, b with Match x y, Match u v => Nat.eqb x u && Nat.eqb y v | NoMatch, NoMatch => true | OutOfFuel, OutOfFuel => true | _, _ => false end.
Definition ends_md (p : re) (s : list nat) (st : nat) := match md s F [DR (fst (desugar p 0))] st (List.length s) [] with Some (rs, _) => Some (map (fun '(e, _, _) => e) rs) | None => None end.
Definition ends_m (p : re) (s : list nat) (st : nat) := m s G F [R p] st (List.length s).
Fixpoint lists_from (p : re) (s : list nat) (k st : nat) : bool := match k with 0 => true | S k => match ends_m p s st, ends_md p s st with Some l1, Some l2 => if list_eq_dec Nat.eq_dec l1 l2 then lists_from p s k (S st) else false | _, _ => false end end.
Eval vm_compute in filter (fun '(_, r, e) => negb (sres_eqb r e)) results.
Definition lists_results := [("ab01", lists_from (AbsRep (lit [97;98])) [97;98;99] (S (List.length [97;98;99])) 0);
 ("ab02", lists_from (AbsRep abc) [97;98;99] (S (List.length [97;98;99])) 0);
 ("ab03", lists_from (AbsRep (Alt abc (lit [97;98]))) [97;98;99] (S (List.length [97;98;99])) 0);
 ("ab04", lists_from (Seq (lit [97;97;97;97;97]) (AbsRep Eps)) [97;97;97;97;97;97;97;97;97;97] (S (List.length [97;97;97;97;97;97;97;97;97;97])) 0);
 ("ab05", lists_from (AbsExp abc ostar) [97;98;99] (S (List.length [97;98;99])) 0);
 ("ab06", lists_from (AbsRep abc) [120;97;98;99;120] (S (List.length [120;97;98;99;120])) 0);
 ("ab07", lists_from (AbsExp abc ostar) [120;97;98;99;120] (S (List.length [120;97;98;99;120])) 0);
 ("ab08", lists_from (Seq (AbsRep abc) (Chr 122)) [120;97;98;122] (S (List.length [120;97;98;122])) 0);
 ("ab09", lists_from (Seq (AbsExp abc ostar) (Chr 122)) [120;97;98;122] (S (List.length [120;97;98;122])) 0);
 ("ab10", lists_from (Seq (Stopper abc) dotstar) [120;120;97;98;99;121;121] (S (List.length [120;120;97;98;99;121;121])) 0);
 ("ab11", lists_from (Seq (Stopper abc) (Seq RClear dotstar)) [120;120;97;98;99;121;121] (S (List.length [120;120;97;98;99;121;121])) 0);
 ("ab12", lists_from (Alt (Seq (AbsRep abc) (Chr 122)) dotstar) [120;97;98;99;121;121] (S (List.length [120;97;98;99;121;121])) 0);
 ("ab13", lists_from (Alt (Seq (AbsExp abc ostar) (Chr 122)) dotstar) [120;97;98;99;121;121] (S (List.length [120;97;98;99;121;121])) 0);
 ("ab14", lists_from (Alt (Seq (Stopper abc) (Chr 122)) dotstar) [120;97;98;99;121;121] (S (List.length [120;97;98;99;121;121])) 0);
 ("ab15", lists_from (Alt (Seq (Stopper abc) (Seq ostar (Chr 122))) ostar) [120;97;98;99;122] (S (List.length [120;97;98;99;122])) 0);
 ("ab16", lists_from (Seq (AbsRep abc) ostar) [120;97;98;99;121] (S (List.length [120;97;98;99;121])) 0);
 ("ab17", lists_from (Seq (AbsExp abc (Star (Chr 120))) (Chr 97)) [120;120;120;97;98;99;121] (S (List.length [120;120;120;97;98;99;121])) 0);
 ("ab18", lists_from (Alt (Seq (AbsExp abc (Star (Chr 120))) (Chr 122)) ostar) [120;120;97;98;99;122] (S (List.length [120;120;97;98;99;122])) 0);
 ("ab19", lists_from (Seq (AbsExp abc (Star (Chr 120))) (Chr 121)) [120;120;120;97;98;99;121] (S (List.length [120;120;120;97;98;99;121])) 0);
 ("ab20", lists_from (Seq (AbsExp abc (Alt (Chr 120) (Seq AnyO (Seq AnyO (Seq AnyO AnyO))))) (Chr 113)) [120;97;98;99;113;113;113] (S (List.length [120;97;98;99;113;113;113])) 0);
 ("ab21", lists_from (Seq (AbsExp abc (Star (Alt (lit [120;120]) (Chr 120)))) (lit [120;97])) [120;120;120;97;98;99] (S (List.length [120;120;120;97;98;99])) 0);
 ("ab22", lists_from (Seq (AbsExp abc (Star (Alt (Chr 120) (Chr 121)))) ostar) [120;121;97;98;99;120;121] (S (List.length [120;121;97;98;99;120;121])) 0);
 ("ab23", lists_from (Seq (Stopper abc) (Alt (Seq RClear (Seq ostar (Chr 122))) ostar)) [120;120;97;98;99;121;121] (S (List.length [120;120;97;98;99;121;121])) 0);
 ("ab24", lists_from (AbsExp (Alt (Chr 97) Eps) (Star (Alt (Chr 120) (Chr 121)))) [120;121;97] (S (List.length [120;121;97])) 0);
 ("ab25", lists_from (Seq (AbsExp Eps ostar) (Chr 122)) [122] (S (List.length [122])) 0);
 ("ab26", lists_from (Seq (AbsRep Eps) (Chr 122)) [120;122] (S (List.length [120;122])) 0);
 ("ab27", lists_from (Seq (AbsExp (lit [97;98]) ostar) (Seq (AbsExp (lit [99;100]) ostar) (Chr 122))) [120;120;99;100;97;98;122] (S (List.length [120;120;99;100;97;98;122])) 0)].
Eval vm_compute in map fst (filter (fun '(_, b) => negb b) lists_results).
