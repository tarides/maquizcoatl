module Vm
(* Experiment #9, F*: the backtracking VM (FRAGMENT.md 5), transcribed
   from rocq/Vm.v, after match_at (upstream/src/regexec.c:3068) on the
   fragment's opcodes, with an explicit backtrack stack bottomed by the
   OP_FINISH sentinel (regexec.c:3074, 3277).  Captures are upstream's
   mem_start_stk / mem_end_stk pair; the stack pop is STACK_POP at
   STACK_POP_LEVEL_MEM_START (regexec.c:2295-2337).  Total F* over
   lists (the Pulse imperative VM is experiment #10's); terminates by
   fuel only: one unit per instruction executed. *)

open Syntax

(* group k -> (start, end); absent = (None, None) (INVALID_STACK_INDEX) *)
type mcaps = list (nat & (option nat & option nat))

let rec mget (k:nat) (m:mcaps) : option nat & option nat =
  match m with
  | [] -> (None, None)
  | (k', v) :: t -> if k = k' then v else mget k t

let mset (k:nat) (v:option nat & option nat) (m:mcaps) : mcaps = (k, v) :: m

(* backtrack stack entries (upstream StackType) *)
type entry =
  | EFinish                                              (* bottom STK_ALT -> OP_FINISH *)
  | EAlt : pc:nat -> pos:nat -> entry                    (* STK_ALT, from OP_PUSH *)
  | EMemStart : k:nat -> prev:(option nat & option nat) -> entry  (* STK_MEM_START *)
  | EEmptyStart : id:nat -> pos:nat -> entry             (* STK_EMPTY_CHECK_START *)

type state =
  | St : pc:nat -> pos:nat -> m:mcaps -> stk:list entry -> state

(* STACK_POP: pop to the first alternative, restoring the captures of
   every STK_MEM_START on the way; [None] when it reaches the sentinel
   (OP_FINISH: no more alternatives) *)
let rec pop (stk:list entry) (m:mcaps) : option state =
  match stk with
  | [] -> None
  | EFinish :: _ -> None
  | EAlt pc pos :: t -> Some (St pc pos m t)
  | EMemStart k prev :: t -> pop t (mset k prev m)
  | EEmptyStart _ _ :: t -> pop t m

(* EMPTY_CHECK_START_SEARCH (regexec.c:2409-2419): the start position
   of the innermost open iteration with this id *)
let rec empty_start (id:nat) (stk:list entry) : option nat =
  match stk with
  | [] -> None
  | EEmptyStart id' p :: t -> if id = id' then Some p else empty_start id t
  | _ :: t -> empty_start id t

type outcome =
  | Next : st:state -> outcome
  | Halt : r:option (nat & mcaps) -> outcome   (* OP_END: Some; OP_FINISH: None *)

let fail (stk:list entry) (m:mcaps) : outcome =
  match pop stk m with
  | Some st -> Next st
  | None -> Halt None

let step (code:list instr) (s:list nat) (st:state) : outcome =
  match st with
  | St pc pos m stk ->
    match nth code pc with
    | None -> fail stk m                                  (* outside the code: as OP_FAIL *)
    | Some i ->
      match i with
      | IStr l ->                                         (* regexec.c:3412-3480 *)
        if is_prefix l (skipn pos s) then Next (St (pc + 1) (pos + length l) m stk)
        else fail stk m
      | IPush a -> Next (St (pc + 1) pos m (EAlt a pos :: stk))     (* :4310-4314 *)
      | IJump a -> Next (St a pos m stk)                  (* :4305-4308 *)
      | IFail -> fail stk m                               (* :4668-4679 *)
      | IMemStart k ->                                    (* :4009-4013 *)
        let (_, e) = mget k m in
        Next (St (pc + 1) pos (mset k (Some pos, e) m) stk)
      | IMemStartPush k ->                                (* :4003-4007, :2072-2082 *)
        Next (St (pc + 1) pos (mset k (Some pos, None) m) (EMemStart k (mget k m) :: stk))
      | IMemEnd k ->                                      (* :4021-4025 *)
        let (b, _) = mget k m in
        Next (St (pc + 1) pos (mset k (b, Some pos) m) stk)
      | IEmptyStart id ->                                 (* :4221-4225 *)
        Next (St (pc + 1) pos m (EEmptyStart id pos :: stk))
      | IEmptyEnd id ->                                   (* :4227-4257 *)
        (* empty iteration: skip the next instruction (the loop's JUMP) *)
        (match empty_start id stk with
         | Some p0 -> if p0 = pos then Next (St (pc + 2) pos m stk)
                      else Next (St (pc + 1) pos m stk)
         | None -> Next (St (pc + 1) pos m stk))
      | IEnd -> Halt (Some (pos, m))                      (* :3285-3357 *)

let rec run (fuel:nat) (code:list instr) (s:list nat) (st:state)
  : Tot (option (option (nat & mcaps))) (decreases fuel) =
  if fuel = 0 then None
  else match step code s st with
    | Next st' -> run (fuel - 1) code s st'
    | Halt r -> Some r

(* region of a match (regexec.c:3347-3357): a group is set when its
   end is valid; groups k, k+1, ..., k+n-1 *)
let rec region_from (k n:nat) (m:mcaps) : Tot (list span) (decreases n) =
  if n = 0 then []
  else (match mget k m with
        | (Some a, Some b) -> Some (a, b)
        | _ -> None) :: region_from (k + 1) (n - 1) m

let region (n:nat) (m:mcaps) : list span = region_from 1 n m

(* one match_at call at start position p on code of n groups *)
let vm (fuel:nat) (code:list instr) (n:nat) (s:list nat) (p:nat) : result =
  match run fuel code s (St 0 p [] [EFinish]) with
  | None -> OutOfFuel
  | Some None -> NoMatch
  | Some (Some (e, m)) -> Match e (region n m)
