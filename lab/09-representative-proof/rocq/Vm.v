(* Experiment #9, Rocq: the backtracking VM (FRAGMENT.md 5), after
   match_at (upstream/src/regexec.c:3068) on the fragment's opcodes, with
   an explicit backtrack stack bottomed by the OP_FINISH sentinel
   (regexec.c:3074, 3277).  Captures are upstream's mem_start_stk /
   mem_end_stk pair; the stack pop is STACK_POP at
   STACK_POP_LEVEL_MEM_START (regexec.c:2295-2337), which restores the
   captures saved by OP_MEM_START_PUSH.  Terminates by fuel only: one
   unit per instruction executed. *)

From Stdlib Require Import List Arith.
Import ListNotations.
From S Require Import Syntax.

(* group k -> (start, end); absent = (None, None) (INVALID_STACK_INDEX) *)
Definition mcaps := list (nat * (option nat * option nat)).

Fixpoint mget (k : nat) (m : mcaps) : option nat * option nat :=
  match m with
  | [] => (None, None)
  | (k', v) :: t => if Nat.eqb k k' then v else mget k t
  end.

Definition mset (k : nat) (v : option nat * option nat) (m : mcaps) : mcaps := (k, v) :: m.

(* backtrack stack entries (upstream StackType) *)
Inductive entry : Type :=
| EFinish                                       (* bottom STK_ALT -> OP_FINISH *)
| EAlt (pc pos : nat)                           (* STK_ALT, from OP_PUSH *)
| EMemStart (k : nat) (prev : option nat * option nat)  (* STK_MEM_START *)
| EEmptyStart (id pos : nat).                   (* STK_EMPTY_CHECK_START *)

Inductive state : Type :=
| St (pc pos : nat) (m : mcaps) (stk : list entry).

(* STACK_POP: pop to the first alternative, restoring the captures of
   every STK_MEM_START on the way; [None] when it reaches the sentinel
   (OP_FINISH: no more alternatives) *)
Fixpoint pop (stk : list entry) (m : mcaps) : option state :=
  match stk with
  | [] => None
  | EFinish :: _ => None
  | EAlt pc pos :: t => Some (St pc pos m t)
  | EMemStart k prev :: t => pop t (mset k prev m)
  | EEmptyStart _ _ :: t => pop t m
  end.

(* EMPTY_CHECK_START_SEARCH (regexec.c:2409-2419): the start position
   of the innermost open iteration with this id *)
Fixpoint empty_start (id : nat) (stk : list entry) : option nat :=
  match stk with
  | [] => None
  | EEmptyStart id' p :: t => if Nat.eqb id id' then Some p else empty_start id t
  | _ :: t => empty_start id t
  end.

Inductive outcome : Type :=
| Next (st : state)
| Halt (r : option (nat * mcaps)).   (* OP_END: Some; OP_FINISH: None *)

Definition fail (stk : list entry) (m : mcaps) : outcome :=
  match pop stk m with
  | Some st => Next st
  | None => Halt None
  end.

Definition step (code : list instr) (s : list nat) (st : state) : outcome :=
  match st with
  | St pc pos m stk =>
    match nth_error code pc with
    | None => fail stk m                               (* outside the code: as OP_FAIL *)
    | Some i =>
      match i with
      | IStr l =>                                      (* regexec.c:3412-3480 *)
        if is_prefix l (skipn pos s) then Next (St (S pc) (pos + length l) m stk)
        else fail stk m
      | IPush a => Next (St (S pc) pos m (EAlt a pos :: stk))   (* :4310-4314 *)
      | IJump a => Next (St a pos m stk)               (* :4305-4308 *)
      | IFail => fail stk m                            (* :4668-4679 *)
      | IMemStart k =>                                 (* :4009-4013 *)
        Next (St (S pc) pos (mset k (Some pos, snd (mget k m)) m) stk)
      | IMemStartPush k =>                             (* :4003-4007, :2072-2082 *)
        Next (St (S pc) pos (mset k (Some pos, None) m) (EMemStart k (mget k m) :: stk))
      | IMemEnd k =>                                   (* :4021-4025 *)
        Next (St (S pc) pos (mset k (fst (mget k m), Some pos) m) stk)
      | IEmptyStart id =>                              (* :4221-4225 *)
        Next (St (S pc) pos m (EEmptyStart id pos :: stk))
      | IEmptyEnd id =>                                (* :4227-4257 *)
        (* empty iteration: skip the next instruction (the loop's JUMP) *)
        match empty_start id stk with
        | Some p0 => if Nat.eqb p0 pos then Next (St (S (S pc)) pos m stk)
                     else Next (St (S pc) pos m stk)
        | None => Next (St (S pc) pos m stk)
        end
      | IEnd => Halt (Some (pos, m))                   (* :3285-3357 *)
      end
    end
  end.

Fixpoint run (fuel : nat) (code : list instr) (s : list nat) (st : state)
  : option (option (nat * mcaps)) :=
  match fuel with
  | O => None
  | S f =>
    match step code s st with
    | Next st' => run f code s st'
    | Halt r => Some r
    end
  end.

(* region of a match (regexec.c:3347-3357): a group is set when its
   end is valid *)
Definition region (n : nat) (m : mcaps) : list span :=
  map (fun k => match mget k m with
                | (Some a, Some b) => Some (a, b)
                | _ => None
                end) (seq 1 n).

(* one match_at call at start position p on code of n groups *)
Definition vm (fuel : nat) (code : list instr) (n : nat) (s : list nat) (p : nat) : result :=
  match run fuel code s (St 0 p [] [EFinish]) with
  | None => OutOfFuel
  | Some None => NoMatch
  | Some (Some (e, m)) => Match e (region n m)
  end.
