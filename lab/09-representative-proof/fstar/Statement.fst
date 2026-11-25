module Statement
(* Experiment #9, F*: the statement of the main theorem (FRAGMENT.md 7),
   transcribed from rocq/Statement.v, as a proposition; the proof is
   milestone M2's (runs 7-9).  Proving it means proving
   [main_theorem : unit -> Lemma main_theorem_statement]. *)

open Syntax
open Sem
open Compile
open Vm

let main_theorem_statement : prop =
  forall (r:regex) (s:list nat) (p:nat).
    p <= length s ==>
    (* soundness: a VM result other than OutOfFuel is the semantics'
       result, for any fuel the semantics completes with *)
    ((forall (fv fs:nat).
        (vm fv (compile r) (ncap r) s p <> OutOfFuel /\ sem fs r s p <> OutOfFuel) ==>
        sem fs r s p == vm fv (compile r) (ncap r) s p)
    /\
    (* completeness: some fuel makes the semantics and the VM finish *)
    (exists (fs:nat). sem fs r s p <> OutOfFuel)
    /\
    (exists (fv:nat). vm fv (compile r) (ncap r) s p <> OutOfFuel))
