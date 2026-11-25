(* Experiment #9, Rocq M2, lemma (d) for the VM and lemma (e): the main
   theorem (Statement.v), from the simulation (ProofSim.sim) at the
   empty continuation (code OP_END, stack [EFinish]) and the totality of
   the semantics (ProofSem.ct_total).  The VM's completeness comes out of
   the simulation itself: [exec] is "some fuel makes [run] return". *)

From Stdlib Require Import List Arith Lia.
Import ListNotations.
From S Require Import Syntax Sem Compile Vm Statement ProofA ProofSem ProofSim.

Lemma vm_det : forall n1 n2 code k s p r1 r2,
  vm n1 code k s p = r1 -> r1 <> OutOfFuel ->
  vm n2 code k s p = r2 -> r2 <> OutOfFuel -> r1 = r2.
Proof.
  unfold vm. intros n1 n2 code k s p r1 r2 H1 N1 H2 N2.
  destruct (run n1 code s (St 0 p [] [EFinish])) as [o1|] eqn:E1; [|subst; contradiction].
  destruct (run n2 code s (St 0 p [] [EFinish])) as [o2|] eqn:E2; [|subst; contradiction].
  assert (o1 = o2) as <- by (eapply exec_det; [exists n1; exact E1|exists n2; exact E2]).
  congruence.
Qed.

Lemma region_rv : forall n m, region n m = map (fun k => rv (mget k m)) (seq 1 n).
Proof. reflexivity. Qed.

(* the VM on [compile r] finishes with the semantics' result *)
Lemma vm_complete : forall r s p f t, NoDup (groups r) ->
  compute_tree f s [ARe r] p [] = Some t ->
  exists n, vm n (compile r) (ncap r) s p
            = match first_match t with
              | None => NoMatch
              | Some (e, g) => Match e (spans (ncap r) g)
              end.
Proof.
  intros r s p f t Nd Ht.
  destruct (code_compile r) as [Hcode Hend].
  assert (Hrep : rep (compile r) 0 [ARe r] p [EFinish] [] (npg r false ++ [])).
  { eapply rep_re with (pc' := clen r) (pos' := p);
      [exact Hcode|intros i []|reflexivity|lia|].
    apply rep_end. exact Hend. }
  assert (Hc : capsrel [] [] (cls [ARe r]) (npg r false ++ [])).
  { intros k _. split; [intros q []|intros _; reflexivity]. }
  assert (Hu : uniq [ARe r]).
  { simpl. split; [exact Nd|split; [intros x _ []|exact I]]. }
  pose proof (sim (compile r) s f [ARe r] p [] t Ht 0 [EFinish] [] _ [] Hrep Hc Hu) as H.
  unfold simres in H. unfold vm.
  destruct (first_match t) as [[e g]|].
  - destruct H as (m' & [n Hn] & G). exists n. rewrite Hn.
    rewrite region_rv. unfold spans. f_equal. apply map_ext. exact G.
  - destruct H as (m1 & _ & F). destruct (F None eq_refl) as [n Hn].
    exists n. rewrite Hn. reflexivity.
Qed.

Theorem main_theorem : main_theorem_statement.
Proof.
  intros r s p Nd _.
  destruct (ct_total s [ARe r] p []) as (f0 & t0 & H0).
  destruct (vm_complete r s p f0 t0 Nd H0) as (n0 & Hn0).
  assert (Hs : forall fs, sem fs r s p <> OutOfFuel ->
            sem fs r s p = match first_match t0 with
                           | None => NoMatch
                           | Some (e, g) => Match e (spans (ncap r) g)
                           end).
  { intros fs Hfs. unfold sem in *.
    destruct (compute_tree fs s [ARe r] p []) as [t|] eqn:E; [|contradiction].
    rewrite (ct_det s _ _ _ _ _ _ _ E H0). reflexivity. }
  assert (N0 : vm n0 (compile r) (ncap r) s p <> OutOfFuel).
  { rewrite Hn0. destruct (first_match t0) as [[e g]|]; discriminate. }
  split; [|split].
  - intros fv fs res Hv Hres Hfs. rewrite (Hs fs Hfs), <- Hn0.
    eapply vm_det; [reflexivity|exact N0|exact Hv|exact Hres].
  - exists f0. unfold sem. rewrite H0. destruct (first_match t0) as [[e g]|]; discriminate.
  - exists n0. exact N0.
Qed.

(* Why Statement.v needs [NoDup (groups r)]: a group nested in a group
   with the same number (no parser writes it; the AST type allows it).
   The VM keeps the inner group's start, the semantics the outer one's. *)
Example nested_same_group_vm :
  vm 100 (compile (Group 1 (Cat (Lit [97]) (Group 1 (Lit [98]))))) 1 [97; 98] 0
  = Match 2 [Some (1, 2)].
Proof. reflexivity. Qed.

Example nested_same_group_sem :
  sem 100 (Group 1 (Cat (Lit [97]) (Group 1 (Lit [98])))) [97; 98] 0
  = Match 2 [Some (0, 2)].
Proof. reflexivity. Qed.
