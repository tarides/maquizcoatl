module Compile
(* Experiment #9, F*: the compiler (FRAGMENT.md 3), transcribed from
   rocq/Compile.v, after upstream's compile_tree
   (upstream/src/regcomp.c:2575-2598, alternation),
   compile_bag_memory_node (:1699-1776), compile_quantifier_node
   (:1399-1515, infinite greedy branch, lower = 0, no peephole) and
   compile_quant_body_with_empty_check (:958-1000). *)

open Syntax

let min (a b:nat) : nat = if a <= b then a else b

(* minimal length of a match (upstream node_min_byte_len,
   regcomp.c:5681-5689: the body needs the empty check when it is 0) *)
let rec minlen (r:regex) : nat =
  match r with
  | Eps -> 0
  | Lit l -> length l
  | Cat a b -> minlen a + minlen b
  | Alt a b -> min (minlen a) (minlen b)
  | Star _ -> 0
  | Group _ a -> minlen a

let nullable (r:regex) : bool = minlen r = 0

(* compiled length (upstream compile_length_tree) *)
let rec clen (r:regex) : nat =
  match r with
  | Eps -> 0
  | Lit l -> (match l with [] -> 0 | _ -> 1)
  | Cat a b -> clen a + clen b
  | Alt a b -> clen a + clen b + 2
  | Star a ->
    let n = clen a in
    if n = 0 then 0                                (* regcomp.c:1407, tlen == 0 *)
    else n + 2 + (if nullable a then 2 else 0)
  | Group _ a -> clen a + 2

(* number of empty-check ids the code of r uses (upstream
   reg->num_empty_check, incremented in pre-order, regcomp.c:971-974) *)
let rec nchecks (r:regex) : nat =
  match r with
  | Eps -> 0
  | Lit _ -> 0
  | Cat a b -> nchecks a + nchecks b
  | Alt a b -> nchecks a + nchecks b
  | Star a ->
    if clen a = 0 then 0
    else (if nullable a then 1 else 0) + nchecks a
  | Group _ a -> nchecks a

(* code of r placed at address pc, first free empty-check id eid;
   [push]: r is inside an alternation or a star, so its groups use
   OP_MEM_START_PUSH (upstream IN_ALT | IN_VAR_REPEAT, regcomp.c:5819-5821,
   push_mem_start = backtrack_mem, :7540) *)
let rec comp (r:regex) (pc eid:nat) (push:bool) : list instr =
  match r with
  | Eps -> []
  | Lit l -> (match l with [] -> [] | _ -> [IStr l])
  | Cat a b -> append (comp a pc eid push) (comp b (pc + clen a) (eid + nchecks a) push)
  | Alt a b ->
    (* PUSH L1; a; JUMP end; L1: b; end:  (n-ary upstream layout
       when alternations nest to the right, as the parser builds them) *)
    IPush (pc + clen a + 2)
      :: append (comp a (pc + 1) eid true)
           (IJump (pc + clen a + clen b + 2)
             :: comp b (pc + clen a + 2) (eid + nchecks a) true)
  | Star a ->
    let n = clen a in
    if n = 0 then []
    else if nullable a then
      (* L: PUSH out; EMPTY_CHECK_START id; a; EMPTY_CHECK_END id; JUMP L; out: *)
      IPush (pc + n + 4) :: IEmptyStart eid
        :: append (comp a (pc + 2) (eid + 1) true) [IEmptyEnd eid; IJump pc]
    else
      (* L: PUSH out; a; JUMP L; out: *)
      IPush (pc + n + 2) :: append (comp a (pc + 1) eid true) [IJump pc]
  | Group k a ->
    (if push then IMemStartPush k else IMemStart k)
      :: append (comp a (pc + 1) eid push) [IMemEnd k]

let compile (r:regex) : list instr = append (comp r 0 0 false) [IEnd]
