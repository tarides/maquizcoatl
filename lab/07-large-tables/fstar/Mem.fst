(* Experiment #7: membership, name lookup and sanity checker over Table. *)
module Mem
open Table

let rec mem (c:int) (l:list (int & int)) : bool =
  match l with
  | [] -> false
  | (lo, hi) :: t -> if c < lo then false else if c <= hi then true else mem c t

let rec nth_or_nil (n:int) (l:list (list (int & int))) : Tot (list (int & int)) (decreases l) =
  match l with
  | [] -> []
  | x :: t -> if n = 0 then x else nth_or_nil (n - 1) t

let ctype_mem (ct c:int) : bool = mem c (nth_or_nil ct code_ranges)

let rec lookup (s:string) (l:list (string & int)) : int =
  match l with
  | [] -> -1
  | (n, c) :: t -> if s = n then c else lookup s t

let lookup_name (s:string) : int = lookup s names

(* Sorted, disjoint, non-adjacent: lo <= hi and hi + 1 < next lo. *)
let rec ok_list (l:list (int & int)) : bool =
  match l with
  | [] -> true
  | (lo, hi) :: tl ->
    lo <= hi && (match tl with [] -> true | (lo', _) :: _ -> hi + 1 < lo') && ok_list tl

let table_ok : bool = List.Tot.for_all ok_list code_ranges
