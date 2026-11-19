(* Experiment #7 driver for the Why3 OCaml target (Why3 int = Zarith Z.t). *)
module M = struct
  let ctype_mem a b = Why3_mem.ctype_mem (Z.of_int a) (Z.of_int b)
  let lookup_name s = Z.to_int (Why3_mem.lookup_name s)
end
