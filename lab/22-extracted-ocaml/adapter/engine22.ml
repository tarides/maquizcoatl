(* Issue #22: the harness side of an extracted VM (experiment #9's
   Rocq- or F*-extracted [vm]), as a module of experiment #12's ENGINE
   signature (lab/12-ffi-vs-native/bench/main.ml).

   Position loop (plan requirement 3): the extracted [search] is never
   called and no absolute position is passed.  At each start position p
   from [start] to [min range n], one byte at a time (the meaning of
   [search_from], lab/09-representative-proof/rocq/Syntax.v:69-79), the
   extracted [vm fuel code ncap suffix_p 0] runs on the subject suffix
   from p, and p is added back to the match end and to every capture
   bound.  The loop stops at the first result that is not [NoMatch].

   Subject conversion (requirement 4): in the per-call mode the suffix
   from [start] is converted inside each search or match call; in the
   scan mode each subject string is converted once (cache keyed by
   physical equality, holding every subject seen) with a cursor on the
   suffix at the last start position.

   Fuel and limits (requirement 5): [search] and [match_] use the
   largest fuel ([max_int], or [Z.of_int max_int]); [limit] and
   [stack_limit] are ignored.  Out of fuel is returned as code -2000
   (below every ONIGERR_* code).  A backward search (range < start) is
   outside the fragment subset and returns -2001. *)

let err_out_of_fuel = -2000
let err_backward = -2001

module type EXTRACTED = sig
  type elt
  type code
  (* the subject's bytes from [from] to the end, one element per byte *)
  val convert : string -> int -> elt list
  (* extracted compile of a fragment AST; also returns ncap *)
  val compile : Frag_parse.ast -> code * int
  (* one extracted [vm] call at position 0 of a suffix: returns the match
     end (relative to the suffix), -1 for NoMatch, -2 for OutOfFuel, and
     writes the relative bounds of groups 1..ncap into regs.(2k),
     regs.(2k+1) (-1 when unset) *)
  val vm : fuel:int -> code -> elt list -> int array -> int
end

module Make (X : EXTRACTED) (M : sig val name : string val scan : bool end) = struct
  type t = { code : X.code; ncap : int; regs : int array }

  let name = M.name

  let compile ~syntax ~options ~limit:_ ~stack_limit:_ pat =
    if not (Frag_parse.context_ok ~syntax ~options) then Error 1
    else match Frag_parse.recognise pat with
      | exception Frag_parse.Out _ -> Error 1
      | (ast, _) ->
        let code, ncap = X.compile ast in
        Ok { code; ncap; regs = Array.make (2 * (ncap + 1)) (-1) }

  (* scan mode: every subject seen, with a cursor *)
  type subj = { s : string; full : X.elt list; mutable cpos : int; mutable cur : X.elt list }
  let cache : subj list ref = ref []

  let rec drop k l = if k = 0 then l else match l with [] -> [] | _ :: t -> drop (k - 1) t

  let suffix s from =
    if not M.scan then X.convert s from
    else begin
      let e = match List.find_opt (fun e -> e.s == s) !cache with
        | Some e -> e
        | None ->
          let full = X.convert s 0 in
          let e = { s; full; cpos = 0; cur = full } in
          cache := e :: !cache; e in
      if from >= e.cpos then e.cur <- drop (from - e.cpos) e.cur
      else e.cur <- drop from e.full;
      e.cpos <- from;
      e.cur
    end

  let rebase t p e =
    let r = t.regs in
    for k = 1 to t.ncap do
      if r.(2 * k + 1) >= 0 then (r.(2 * k) <- r.(2 * k) + p; r.(2 * k + 1) <- r.(2 * k + 1) + p)
      else (r.(2 * k) <- -1; r.(2 * k + 1) <- -1)
    done;
    r.(0) <- p; r.(1) <- p + e

  let search_fuel ~fuel t s ~start ~range =
    let n = String.length s in
    if start < 0 || start > n then -1
    else if range < start then err_backward
    else begin
      let last = min range n in
      let rec go l p =
        let e = X.vm ~fuel t.code l t.regs in
        if e >= 0 then (rebase t p e; p)
        else if e = -2 then err_out_of_fuel
        else if p >= last then -1
        else match l with
          | _ :: l' -> go l' (p + 1)
          | [] -> -1
      in
      go (suffix s start) start
    end

  let search t s ~start ~range ~sopt:_ = search_fuel ~fuel:max_int t s ~start ~range

  let match_ t s ~at ~sopt:_ =
    if at < 0 || at > String.length s then -1
    else
      let e = X.vm ~fuel:max_int t.code (suffix s at) t.regs in
      if e >= 0 then (rebase t at e; e)
      else if e = -2 then err_out_of_fuel
      else -1

  let nregs t = t.ncap + 1
  let beg t k = t.regs.(2 * k)
  let end_ t k = t.regs.(2 * k + 1)
end
