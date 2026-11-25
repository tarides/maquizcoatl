module Syntax
(* Experiment #9, F*: the fragment's abstract syntax, bytecode and
   results (lab/09-representative-proof/FRAGMENT.md, sections 1, 2, 6),
   transcribed from rocq/Syntax.v.  Bytes, positions and group numbers
   are [nat].  Total F* over lists; the list functions are defined here
   so that the extracted OCaml needs Prims only (as experiment #6). *)

(* FRAGMENT.md 1: patterns.  [Lit] is a string of ASCII bytes (one per
   character in the case files); [Star] is greedy; [Group k] is a plain
   capture group numbered k >= 1 by the parser. *)
type regex =
  | Eps
  | Lit : l:list nat -> regex
  | Cat : a:regex -> b:regex -> regex
  | Alt : a:regex -> b:regex -> regex
  | Star : a:regex -> regex
  | Group : k:nat -> a:regex -> regex

(* FRAGMENT.md 2: bytecode, after upstream/src/regint.h:496-597.  Jump
   and push targets are absolute instruction indices.  OP_FINISH is not
   an instruction here: it is the sentinel at the bottom of the VM's
   backtrack stack (Vm.EFinish). *)
type instr =
  | IStr : l:list nat -> instr          (* OP_STR_1 .. OP_STR_N, collapsed *)
  | IPush : target:nat -> instr         (* OP_PUSH *)
  | IJump : target:nat -> instr         (* OP_JUMP *)
  | IFail                               (* OP_FAIL (never emitted for the fragment) *)
  | IMemStart : k:nat -> instr          (* OP_MEM_START *)
  | IMemStartPush : k:nat -> instr      (* OP_MEM_START_PUSH *)
  | IMemEnd : k:nat -> instr            (* OP_MEM_END *)
  | IEmptyStart : id:nat -> instr       (* OP_EMPTY_CHECK_START *)
  | IEmptyEnd : id:nat -> instr         (* OP_EMPTY_CHECK_END *)
  | IEnd                                (* OP_END *)

(* A group's span, [None] when unset (upstream ONIG_REGION_NOTPOS). *)
type span = option (nat & nat)

(* FRAGMENT.md 6: the result of one match attempt at a start position:
   the match end and the spans of groups 1..ncap. *)
type result =
  | Match : e:nat -> caps:list span -> result
  | NoMatch
  | OutOfFuel

let rec length (#a:Type) (l:list a) : nat =
  match l with [] -> 0 | _ :: t -> 1 + length t

let rec append (#a:Type) (l1 l2:list a) : list a =
  match l1 with [] -> l2 | x :: t -> x :: append t l2

let rec skipn (#a:Type) (n:nat) (l:list a) : list a =
  if n = 0 then l else match l with [] -> [] | _ :: t -> skipn (n - 1) t

let rec nth (#a:Type) (l:list a) (n:nat) : option a =
  match l with
  | [] -> None
  | x :: t -> if n = 0 then Some x else nth t (n - 1)

let max (a b:nat) : nat = if a >= b then a else b

(* Highest group number of a pattern (groups are numbered 1..ncap). *)
let rec ncap (r:regex) : nat =
  match r with
  | Eps -> 0
  | Lit _ -> 0
  | Cat a b -> max (ncap a) (ncap b)
  | Alt a b -> max (ncap a) (ncap b)
  | Star a -> ncap a
  | Group k a -> max k (ncap a)

(* [l] is a prefix of [s] (upstream DATA_ENSURE plus the byte compare
   of OP_STR_N, upstream/src/regexec.c:3472-3480). *)
let rec is_prefix (l s:list nat) : bool =
  match l, s with
  | [], _ -> true
  | x :: l', y :: s' -> x = y && is_prefix l' s'
  | _ :: _, [] -> false

(* Left-to-right search over start positions p, p+1, ..., p+n-1, as
   search_in_range without the optimiser: the first start position
   whose attempt does not return [NoMatch] (a match, or out of fuel). *)
let rec search_from (m:nat -> result) (p n:nat) : Tot (option (nat & result)) (decreases n) =
  if n = 0 then None
  else match m p with
    | NoMatch -> search_from m (p + 1) (n - 1)
    | r -> Some (p, r)

let search (m:nat -> result) (s:list nat) : option (nat & result) =
  search_from m 0 (length s + 1)
