module ProofA
(* Experiment #9, F* M2, lemma (a): compiler invariants (FRAGMENT.md 8),
   after rocq/ProofA.v.  The code of [comp r pc eid push] has length
   [clen r]; [code_at code pc l] says that [l] sits in [code] at address
   [pc]; the layout lemmas give the instructions of each construct at
   their addresses, as the simulation (ProofSim.fst) reads them. *)

open Syntax
open Compile

#push-options "--fuel 2 --ifuel 1 --z3rlimit 10"

let rec length_append (#a:Type) (l1 l2:list a)
  : Lemma (length (append l1 l2) == length l1 + length l2)
          [SMTPat (length (append l1 l2))]
  = match l1 with [] -> () | _ :: t -> length_append t l2

let rec append_assoc (#a:Type) (l1 l2 l3:list a)
  : Lemma (append l1 (append l2 l3) == append (append l1 l2) l3)
  = match l1 with [] -> () | _ :: t -> append_assoc t l2 l3

#push-options "--fuel 4"
let rec length_comp (r:regex) (pc eid:nat) (push:bool)
  : Lemma (length (comp r pc eid push) == clen r)
          [SMTPat (length (comp r pc eid push))]
  = match r with
    | Eps -> ()
    | Lit _ -> ()
    | Cat a b ->
      length_comp a pc eid push; length_comp b (pc + clen a) (eid + nchecks a) push;
      length_append (comp a pc eid push) (comp b (pc + clen a) (eid + nchecks a) push)
    | Alt a b ->
      length_comp a (pc + 1) eid true; length_comp b (pc + clen a + 2) (eid + nchecks a) true;
      length_append (comp a (pc + 1) eid true)
        (IJump (pc + clen a + clen b + 2) :: comp b (pc + clen a + 2) (eid + nchecks a) true)
    | Star a ->
      if clen a = 0 then ()
      else if nullable a then begin
        length_comp a (pc + 2) (eid + 1) true;
        length_append (comp a (pc + 2) (eid + 1) true) [IEmptyEnd eid; IJump pc]
      end else begin
        length_comp a (pc + 1) eid true;
        length_append (comp a (pc + 1) eid true) [IJump pc]
      end
    | Group k a ->
      length_comp a (pc + 1) eid push;
      length_append (comp a (pc + 1) eid push) [IMemEnd k]
#pop-options

(* [l] sits in [code] at address [pc] *)
let rec code_at (code:list instr) (pc:nat) (l:list instr) : Tot prop (decreases l) =
  match l with
  | [] -> True
  | x :: t -> nth code pc == Some x /\ code_at code (pc + 1) t

let rec code_at_app (code:list instr) (pc:nat) (l1 l2:list instr)
  : Lemma (code_at code pc (append l1 l2) <==>
           (code_at code pc l1 /\ code_at code (pc + length l1) l2))
          (decreases l1)
  = match l1 with [] -> () | _ :: t -> code_at_app code (pc + 1) t l2

(* layouts *)
let code_alt (code:list instr) (a b:regex) (pc eid:nat) (push:bool)
  : Lemma (requires code_at code pc (comp (Alt a b) pc eid push))
          (ensures nth code pc == Some (IPush (pc + clen a + 2)) /\
                   code_at code (pc + 1) (comp a (pc + 1) eid true) /\
                   nth code (pc + 1 + clen a) == Some (IJump (pc + clen a + clen b + 2)) /\
                   code_at code (pc + clen a + 2) (comp b (pc + clen a + 2) (eid + nchecks a) true))
  = code_at_app code (pc + 1) (comp a (pc + 1) eid true)
      (IJump (pc + clen a + clen b + 2) :: comp b (pc + clen a + 2) (eid + nchecks a) true)

let code_cat (code:list instr) (a b:regex) (pc eid:nat) (push:bool)
  : Lemma (requires code_at code pc (comp (Cat a b) pc eid push))
          (ensures code_at code pc (comp a pc eid push) /\
                   code_at code (pc + clen a) (comp b (pc + clen a) (eid + nchecks a) push))
  = code_at_app code pc (comp a pc eid push) (comp b (pc + clen a) (eid + nchecks a) push)

let code_group (code:list instr) (n:nat) (a:regex) (pc eid:nat) (push:bool)
  : Lemma (requires code_at code pc (comp (Group n a) pc eid push))
          (ensures nth code pc == Some (if push then IMemStartPush n else IMemStart n) /\
                   code_at code (pc + 1) (comp a (pc + 1) eid push) /\
                   nth code (pc + 1 + clen a) == Some (IMemEnd n))
  = code_at_app code (pc + 1) (comp a (pc + 1) eid push) [IMemEnd n]

let code_lit (code:list instr) (l:list nat) (pc eid:nat) (push:bool)
  : Lemma (requires Cons? l /\ code_at code pc (comp (Lit l) pc eid push))
          (ensures nth code pc == Some (IStr l))
  = ()

let code_star_null (code:list instr) (a:regex) (l eid:nat) (push:bool)
  : Lemma (requires clen a <> 0 /\ nullable a /\ code_at code l (comp (Star a) l eid push))
          (ensures nth code l == Some (IPush (l + clen a + 4)) /\
                   nth code (l + 1) == Some (IEmptyStart eid) /\
                   code_at code (l + 2) (comp a (l + 2) (eid + 1) true) /\
                   nth code (l + 2 + clen a) == Some (IEmptyEnd eid) /\
                   nth code (l + 3 + clen a) == Some (IJump l) /\
                   clen (Star a) == clen a + 4 /\ nchecks (Star a) == nchecks a + 1)
  = code_at_app code (l + 2) (comp a (l + 2) (eid + 1) true) [IEmptyEnd eid; IJump l]

let code_star_nn (code:list instr) (a:regex) (l eid:nat) (push:bool)
  : Lemma (requires clen a <> 0 /\ not (nullable a) /\ code_at code l (comp (Star a) l eid push))
          (ensures nth code l == Some (IPush (l + clen a + 2)) /\
                   code_at code (l + 1) (comp a (l + 1) eid true) /\
                   nth code (l + 1 + clen a) == Some (IJump l) /\
                   clen (Star a) == clen a + 2 /\ nchecks (Star a) == nchecks a)
  = code_at_app code (l + 1) (comp a (l + 1) eid true) [IJump l]

let rec code_at_shift (y:instr) (c:list instr) (pc:nat) (l:list instr)
  : Lemma (ensures code_at (y :: c) (pc + 1) l <==> code_at c pc l) (decreases l)
  = match l with [] -> () | _ :: t -> code_at_shift y c (pc + 1) t

let rec code_at_prefix (l1 l2:list instr) : Lemma (code_at (append l1 l2) 0 l1) =
  match l1 with
  | [] -> ()
  | x :: t -> code_at_prefix t l2; code_at_shift x (append t l2) 0 t

let rec nth_append_len (#a:Type) (l1 l2:list a)
  : Lemma (nth (append l1 l2) (length l1) == nth l2 0)
  = match l1 with [] -> () | _ :: t -> nth_append_len t l2

(* the whole program: the pattern's code at 0, then OP_END *)
let code_compile (r:regex)
  : Lemma (code_at (compile r) 0 (comp r 0 0 false) /\ nth (compile r) (clen r) == Some IEnd)
  = code_at_prefix (comp r 0 0 false) [IEnd];
    nth_append_len (comp r 0 0 false) [IEnd]

#pop-options
