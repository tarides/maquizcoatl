(* Experiment #9, Rocq: the compiler (FRAGMENT.md 3), after upstream's
   compile_tree (upstream/src/regcomp.c:2575-2598, alternation),
   compile_bag_memory_node (:1699-1776), compile_quantifier_node
   (:1399-1515, infinite greedy branch, lower = 0, no peephole) and
   compile_quant_body_with_empty_check (:958-1000). *)

From Stdlib Require Import List Arith.
Import ListNotations.
From S Require Import Syntax.

(* minimal length of a match (upstream node_min_byte_len,
   regcomp.c:5681-5689: the body needs the empty check when it is 0) *)
Fixpoint minlen (r : regex) : nat :=
  match r with
  | Eps => 0
  | Lit l => length l
  | Cat a b => minlen a + minlen b
  | Alt a b => Nat.min (minlen a) (minlen b)
  | Star _ => 0
  | Group _ a => minlen a
  end.

Definition nullable (r : regex) : bool := Nat.eqb (minlen r) 0.

(* compiled length (upstream compile_length_tree) *)
Fixpoint clen (r : regex) : nat :=
  match r with
  | Eps => 0
  | Lit l => match l with [] => 0 | _ => 1 end
  | Cat a b => clen a + clen b
  | Alt a b => clen a + clen b + 2
  | Star a =>
    match clen a with
    | O => 0                                        (* regcomp.c:1407, tlen == 0 *)
    | n => n + 2 + (if nullable a then 2 else 0)
    end
  | Group _ a => clen a + 2
  end.

(* number of empty-check ids the code of r uses (upstream
   reg->num_empty_check, incremented in pre-order, regcomp.c:972-974) *)
Fixpoint nchecks (r : regex) : nat :=
  match r with
  | Eps | Lit _ => 0
  | Cat a b | Alt a b => nchecks a + nchecks b
  | Star a =>
    match clen a with
    | O => 0
    | _ => (if nullable a then 1 else 0) + nchecks a
    end
  | Group _ a => nchecks a
  end.

(* code of r placed at address pc, first free empty-check id eid;
   [push]: r is inside an alternation or a star, so its groups use
   OP_MEM_START_PUSH (upstream IN_ALT | IN_VAR_REPEAT, regcomp.c:5819-5821,
   push_mem_start = backtrack_mem, :7540) *)
Fixpoint comp (r : regex) (pc eid : nat) (push : bool) : list instr :=
  match r with
  | Eps => []
  | Lit l => match l with [] => [] | _ => [IStr l] end
  | Cat a b => comp a pc eid push ++ comp b (pc + clen a) (eid + nchecks a) push
  | Alt a b =>
    (* PUSH L1; a; JUMP end; L1: b; end:  (n-ary upstream layout
       when alternations nest to the right, as the parser builds them) *)
    IPush (pc + clen a + 2)
      :: comp a (S pc) eid true
      ++ IJump (pc + clen a + clen b + 2)
      :: comp b (pc + clen a + 2) (eid + nchecks a) true
  | Star a =>
    match clen a with
    | O => []
    | n =>
      if nullable a then
        (* L: PUSH out; EMPTY_CHECK_START id; a; EMPTY_CHECK_END id; JUMP L; out: *)
        IPush (pc + n + 4) :: IEmptyStart eid
          :: comp a (pc + 2) (S eid) true ++ [IEmptyEnd eid; IJump pc]
      else
        (* L: PUSH out; a; JUMP L; out: *)
        IPush (pc + n + 2) :: comp a (S pc) eid true ++ [IJump pc]
    end
  | Group k a =>
    (if push then IMemStartPush k else IMemStart k)
      :: comp a (S pc) eid push ++ [IMemEnd k]
  end.

Definition compile (r : regex) : list instr := comp r 0 0 false ++ [IEnd].
