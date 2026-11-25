(* Experiment #9, Rocq: the statement of the main theorem (FRAGMENT.md 7),
   as a proposition; the proof is milestone M2's (runs 4-6).  Proving it
   means proving [main_theorem : main_theorem_statement].

   Run 4 added the hypothesis [NoDup (groups r)]: the parser numbers
   groups in order of their opening parenthesis, so no fragment pattern
   repeats a group number, but the AST type allows it, and the theorem is
   false without it (Proof.v, [nested_same_group_vm] and
   [nested_same_group_sem]: Group 1 (Cat (Lit a) (Group 1 (Lit b))) on
   "ab", where the VM reports 1=1-2 and the semantics 1=0-2). *)

From Stdlib Require Import List Arith.
From S Require Import Syntax Sem Compile Vm.

(* group numbers of a pattern, in order of their opening parenthesis *)
Fixpoint groups (r : regex) : list nat :=
  match r with
  | Eps | Lit _ => nil
  | Cat a b | Alt a b => groups a ++ groups b
  | Star a => groups a
  | Group k a => k :: groups a
  end.

Definition main_theorem_statement : Prop :=
  forall (r : regex) (s : list nat) (p : nat),
    NoDup (groups r) ->
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
