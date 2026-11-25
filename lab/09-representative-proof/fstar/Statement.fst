module Statement
(* Experiment #9, F*: the statement of the main theorem (FRAGMENT.md 7),
   transcribed from rocq/Statement.v, as a proposition; the proof is
   milestone M2's (runs 7-9).  Proving it means proving
   [main_theorem : unit -> Lemma main_theorem_statement].
   The hypothesis [nodup (groups r)] (distinct group numbers) is
   FRAGMENT.md 7's, added to Rocq's statement in run 4 and accepted by
   the maintainer (decision 5 of issue #4,
   https://github.com/tarides/maquizcoatl/issues/4#issuecomment-7165293346);
   [groups] is rocq/Statement.v's, [nodup] Rocq's NoDup as a boolean. *)

open Syntax
open Sem
open Compile
open Vm

(* group numbers of a pattern, in order of their opening parenthesis *)
let rec groups (r:regex) : list nat =
  match r with
  | Eps | Lit _ -> []
  | Cat a b | Alt a b -> append (groups a) (groups b)
  | Star a -> groups a
  | Group k a -> k :: groups a

let rec mem (x:nat) (l:list nat) : bool =
  match l with [] -> false | y :: t -> x = y || mem x t

(* no number occurs twice (Rocq's NoDup) *)
let rec nodup (l:list nat) : bool =
  match l with [] -> true | x :: t -> not (mem x t) && nodup t

let main_theorem_statement : prop =
  forall (r:regex) (s:list nat) (p:nat).
    nodup (groups r) ==>
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
