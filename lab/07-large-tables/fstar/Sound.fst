(* Experiment #7: soundness of the boolean sanity checker, independent of the table. *)
module Sound
open Mem

let rec sorted_disjoint (l:list (int & int)) : prop =
  match l with
  | [] -> True
  | [(lo, hi)] -> lo <= hi
  | (lo, hi) :: (lo', hi') :: t -> lo <= hi /\ hi + 1 < lo' /\ sorted_disjoint ((lo', hi') :: t)

let rec ok_list_sound (l:list (int & int))
  : Lemma (requires ok_list l) (ensures sorted_disjoint l) =
  match l with
  | [] | [_] -> ()
  | _ :: tl -> ok_list_sound tl

let table_ok_sound (l:list (int & int))
  : Lemma (requires table_ok /\ List.Tot.memP l Table.code_ranges) (ensures sorted_disjoint l) =
  List.Tot.for_all_mem ok_list Table.code_ranges;
  List.Tot.mem_memP l Table.code_ranges;
  ok_list_sound l
