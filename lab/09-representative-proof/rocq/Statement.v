(* Experiment #9, Rocq: the statement of the main theorem (FRAGMENT.md 7),
   as a proposition; the proof is milestone M2's (runs 4-6).  Proving it
   means proving [main_theorem : main_theorem_statement]. *)

From Stdlib Require Import List Arith.
From S Require Import Syntax Sem Compile Vm.

Definition main_theorem_statement : Prop :=
  forall (r : regex) (s : list nat) (p : nat),
    p <= length s ->
    (* soundness: a VM result other than OutOfFuel is the semantics'
       result, for any fuel the semantics completes with *)
    (forall fv fs res,
        vm fv (compile r) (ncap r) s p = res -> res <> OutOfFuel ->
        sem fs r s p <> OutOfFuel ->
        sem fs r s p = res)
    /\
    (* completeness: some fuel makes the semantics and the VM finish *)
    (exists fs, sem fs r s p <> OutOfFuel)
    /\
    (exists fv, vm fv (compile r) (ncap r) s p <> OutOfFuel).
