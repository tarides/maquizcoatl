module Spec
(* Experiment #6, F*: executable semantics of experiment #9's subset of
   Oniguruma f95747b (concatenation, alternation, greedy star, capture
   groups, character classes; UTF-8; forward search), transcribed from
   stack G (lab/06-spec-speed/g/g.ml) as the same small-step machine as
   rocq/Spec.v: stack G's pending items plus an explicit list of
   backtracking points, one machine step per call of stack G's [step],
   fuel a [nat] with a [decreases] clause.  No refinements beyond [nat]
   in executable definitions. *)

(* no FStar.List.Tot: the extracted OCaml then needs only Prims *)

let rec len (l:list int) : nat = match l with [] -> 0 | _ :: t -> 1 + len t

type node =
  | Eps
  | Lit : bs:list int -> node                 (* bytes of one code point *)
  | Cls : neg:bool -> rs:list (int & int) -> node
  | Cat : a:node -> b:node -> node
  | Alt : a:node -> b:node -> node
  | Star : a:node -> node                     (* greedy *)
  | Group : k:int -> a:node -> node

type item =
  | INode : n:node -> item
  | IClose : k:int -> p:int -> item           (* group, start position *)
  | ILoop : a:node -> p:int -> item           (* star body, iteration start *)

type caps = list (int & (int & int))

(* backtracking point: items, position, rest of the subject, captures *)
type frame = list item & int & list int & caps

type state =
  | Run : its:list item -> pos:int -> rest:list int -> cs:caps -> bt:list frame -> state
  | Matched : pos:int -> cs:caps -> state
  | Failed

(* UTF-8, as upstream/src/utf8.c (EncLen_UTF8, USE_RFC3629_RANGE) *)
let enc_len (b:int) : nat =
  if b < 194 then 1 else if b < 224 then 2 else if b < 240 then 3
  else if b < 245 then 4 else 1

let rec take (n:nat) (l:list int) : Tot (option (list int & list int)) (decreases n) =
  if n = 0 then Some ([], l)
  else match l with
    | [] -> None
    | x :: t ->
      (match take (n - 1) t with
       | Some (a, r) -> Some (x :: a, r)
       | None -> None)

let lead_mod (l:nat) : int = if l = 2 then 32 else if l = 3 then 16 else 8

let rec fold_code (v:int) (l:list int) : Tot int (decreases l) =
  match l with
  | [] -> v
  | d :: t -> fold_code (v * 64 + d % 64) t

(* code point, encoded length, rest; None past the end (DATA_ENSURE) *)
let decode (rest:list int) : option (int & nat & list int) =
  match rest with
  | [] -> None
  | b :: t ->
    let l = enc_len b in
    if l = 1 then Some (b, 1, t)
    else match take (l - 1) t with
      | Some (tl, r) -> Some (fold_code (b % lead_mod l) tl, l, r)
      | None -> None

let rec prefix (l rest:list int) : option (list int) =
  match l, rest with
  | [], _ -> Some rest
  | x :: l', y :: r -> if x = y then prefix l' r else None
  | _, [] -> None

let rec in_ranges (c:int) (rs:list (int & int)) : bool =
  match rs with
  | [] -> false
  | (lo, hi) :: t -> (lo <= c && c <= hi) || in_ranges c t

let rec set_cap (k:int) (v:int & int) (cs:caps) : caps =
  match cs with
  | [] -> [(k, v)]
  | (k', w) :: t -> if k' = k then (k, v) :: t else (k', w) :: set_cap k v t

let backtrack (bt:list frame) : state =
  match bt with
  | [] -> Failed
  | (its, pos, rest, cs) :: bt' -> Run its pos rest cs bt'

let step (st:state) : state =
  match st with
  | Run its pos rest cs bt ->
    (match its with
     | [] -> Matched pos cs
     | INode Eps :: k -> Run k pos rest cs bt
     | INode (Lit l) :: k ->
       (match prefix l rest with
        | Some r -> Run k (pos + len l) r cs bt
        | None -> backtrack bt)
     | INode (Cls ng rs) :: k ->
       (match decode rest with
        | Some (c, l, r) -> if in_ranges c rs = ng then backtrack bt else Run k (pos + l) r cs bt
        | None -> backtrack bt)
     | INode (Cat a b) :: k -> Run (INode a :: INode b :: k) pos rest cs bt
     | INode (Alt a b) :: k -> Run (INode a :: k) pos rest cs ((INode b :: k, pos, rest, cs) :: bt)
     | INode (Star a) :: k -> Run (INode a :: ILoop a pos :: k) pos rest cs ((k, pos, rest, cs) :: bt)
     | ILoop a p0 :: k ->
       if pos = p0 then Run k pos rest cs bt else Run (INode (Star a) :: k) pos rest cs bt
     | INode (Group i a) :: k -> Run (INode a :: IClose i pos :: k) pos rest cs bt
     | IClose i p0 :: k -> Run k pos rest (set_cap i (p0, pos) cs) bt)
  | _ -> st

(* at most [fuel] steps *)
let rec run (fuel:nat) (st:state) : Tot state (decreases fuel) =
  if fuel = 0 then st
  else match st with
    | Run _ _ _ _ _ -> run (fuel - 1) (step st)
    | _ -> st

type result =
  | RMatch : s:int -> e:int -> cs:caps -> result
  | RMismatch
  | RLimit

(* forward search: start positions 0..length, advanced by enc_len *)
let rec search_from (n fuel:nat) (re:node) (pos:int) (rest:list int) : Tot result (decreases n) =
  if n = 0 then RMismatch
  else match run fuel (Run [INode re] pos rest [] []) with
    | Matched e cs -> RMatch pos e cs
    | Run _ _ _ _ _ -> RLimit
    | Failed ->
      (match rest with
       | [] -> RMismatch
       | b :: _ ->
         let l = enc_len b in
         (match take l rest with
          | Some (_, r) -> search_from (n - 1) fuel re (pos + l) r
          | None -> RMismatch))

let search (fuel:nat) (re:node) (s:list int) : result =
  search_from (len s + 1) fuel re 0 s

let rec lookup (k:int) (cs:caps) : option (int & int) =
  match cs with
  | [] -> None
  | (k', v) :: t -> if k = k' then Some v else lookup k t

let rec groups (k:nat) (cs:caps) (acc:list int) : Tot (list int) (decreases k) =
  if k = 0 then acc
  else groups (k - 1) cs (match lookup k cs with
                          | Some (x, y) -> 1 :: x :: y :: acc
                          | None -> 0 :: acc)

(* verdict as numbers: [0] no match, [2] limit, 1 :: s :: e :: groups,
   each group [1; s; e] or [0] when unset *)
let encode (ncap:nat) (r:result) : list int =
  match r with
  | RMismatch -> [0]
  | RLimit -> [2]
  | RMatch s e cs -> 1 :: s :: e :: groups ncap cs []

let fuel0 : nat = 10000000

let run_case (fuel ncap:nat) (re:node) (s:list int) : list int =
  encode ncap (search fuel re s)

(* a case: number of groups, pattern, subject bytes, expected verdict *)
type case = nat & node & list int & list int

let agree (fuel:nat) (c:case) : bool =
  let (ncap, re, s, exp) = c in run_case fuel ncap re s = exp

let rec count_acc (fuel:nat) (cs:list case) (acc:nat) : Tot nat (decreases cs) =
  match cs with
  | [] -> acc
  | c :: t -> count_acc fuel t (if agree fuel c then acc + 1 else acc)

let count (fuel:nat) (cs:list case) : nat = count_acc fuel cs 0

(* r passes; pass i uses fuel0 + i so that no pass can be shared *)
let rec passes (r:nat) (cs:list case) (acc:nat) : Tot nat (decreases r) =
  if r = 0 then acc else passes (r - 1) cs (acc + count (fuel0 + r) cs)
