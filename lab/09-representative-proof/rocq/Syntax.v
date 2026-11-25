(* Experiment #9, Rocq: the fragment's abstract syntax, bytecode and
   results (lab/09-representative-proof/FRAGMENT.md, sections 1, 2, 6).
   Bytes, positions and group numbers are [nat] (extracted to OCaml
   [int] with ExtrOcamlNatInt).  Executable definitions carry no proofs
   and no type indices. *)

From Stdlib Require Import List Arith.
Import ListNotations.

(* FRAGMENT.md 1: patterns.  [Lit] is a string of ASCII bytes (one per
   character in the case files); [Star] is greedy; [Group k] is a plain
   capture group numbered k >= 1 by the parser. *)
Inductive regex : Type :=
| Eps
| Lit (l : list nat)
| Cat (a b : regex)
| Alt (a b : regex)
| Star (a : regex)
| Group (k : nat) (a : regex).

(* FRAGMENT.md 2: bytecode, after upstream/src/regint.h:496-597.  Jump
   and push targets are absolute instruction indices (upstream stores
   relative offsets; the compiler resolves them, so the two coincide).
   OP_FINISH is not an instruction here: it is the sentinel at the
   bottom of the VM's backtrack stack (Vm.EFinish). *)
Inductive instr : Type :=
| IStr (l : list nat)          (* OP_STR_1 .. OP_STR_N, collapsed *)
| IPush (target : nat)         (* OP_PUSH *)
| IJump (target : nat)         (* OP_JUMP *)
| IFail                        (* OP_FAIL (never emitted for the fragment) *)
| IMemStart (k : nat)          (* OP_MEM_START *)
| IMemStartPush (k : nat)      (* OP_MEM_START_PUSH *)
| IMemEnd (k : nat)            (* OP_MEM_END *)
| IEmptyStart (id : nat)       (* OP_EMPTY_CHECK_START *)
| IEmptyEnd (id : nat)         (* OP_EMPTY_CHECK_END *)
| IEnd.                        (* OP_END *)

(* A group's span, [None] when unset (upstream ONIG_REGION_NOTPOS). *)
Definition span := option (nat * nat).

(* FRAGMENT.md 6: the result of one match attempt at a start position:
   the match end and the spans of groups 1..ncap. *)
Inductive result : Type :=
| Match (e : nat) (caps : list span)
| NoMatch
| OutOfFuel.

(* Highest group number of a pattern (groups are numbered 1..ncap). *)
Fixpoint ncap (r : regex) : nat :=
  match r with
  | Eps | Lit _ => 0
  | Cat a b | Alt a b => Nat.max (ncap a) (ncap b)
  | Star a => ncap a
  | Group k a => Nat.max k (ncap a)
  end.

(* [l] is a prefix of [s] (upstream DATA_ENSURE plus the byte compare
   of OP_STR_N, upstream/src/regexec.c:3472-3480). *)
Fixpoint is_prefix (l s : list nat) : bool :=
  match l, s with
  | [], _ => true
  | x :: l', y :: s' => Nat.eqb x y && is_prefix l' s'
  | _ :: _, [] => false
  end.

(* Left-to-right search over start positions p, p+1, ..., p+n-1, as
   search_in_range without the optimiser: the first start position
   whose attempt does not return [NoMatch] (a match, or out of fuel). *)
Fixpoint search_from (m : nat -> result) (p n : nat) : option (nat * result) :=
  match n with
  | O => None
  | S n' =>
    match m p with
    | NoMatch => search_from m (S p) n'
    | r => Some (p, r)
    end
  end.

Definition search (m : nat -> result) (s : list nat) : option (nat * result) :=
  search_from m 0 (S (length s)).
