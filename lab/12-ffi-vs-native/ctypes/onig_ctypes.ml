(* Experiment #12: libonig through ctypes-foreign (libffi).
   The search goes through Foreign.foreign on onig_search_with_param with
   the subject passed as ocaml_string (no copy) and offsets by (+@) on
   ocaml_string_start; release_runtime_lock is left false.  The compiled
   regex, region and match param are created by the stubs (Onig.compile)
   and handed over as raw addresses; only the per-call path is ctypes. *)
open Ctypes

type region
let region : region structure typ = structure "re_registers"
let r_allocated = field region "allocated" int
let r_num_regs = field region "num_regs" int
let r_beg = field region "beg" (ptr int)
let r_end = field region "end" (ptr int)
let () = seal region
let _ = r_allocated

let search_fn =
  Foreign.foreign "onig_search_with_param"
    (ptr void @-> ocaml_string @-> ocaml_string @-> ocaml_string @-> ocaml_string
     @-> ptr region @-> uint @-> ptr void @-> returning int)

let match_fn =
  Foreign.foreign "onig_match_with_param"
    (ptr void @-> ocaml_string @-> ocaml_string @-> ocaml_string
     @-> ptr region @-> uint @-> ptr void @-> returning int)

type t = { h : Onig.h; reg : unit ptr; rg : region structure ptr; mp : unit ptr }

let of_onig h =
  let (a, b, c) = Onig.raw h in
  { h; reg = ptr_of_raw_address a;
    rg = from_voidp region (ptr_of_raw_address b);
    mp = ptr_of_raw_address c }

let search t s ~start ~range ~opt =
  let p = ocaml_string_start s in
  search_fn t.reg p (p +@ String.length s) (p +@ start) (p +@ range) t.rg
    (Unsigned.UInt.of_int opt) t.mp

let match_ t s ~at ~opt =
  let p = ocaml_string_start s in
  match_fn t.reg p (p +@ String.length s) (p +@ at) t.rg (Unsigned.UInt.of_int opt) t.mp

let nregs t = getf (!@ (t.rg)) r_num_regs
let beg t k = !@ (getf (!@ (t.rg)) r_beg +@ k)
let end_ t k = !@ (getf (!@ (t.rg)) r_end +@ k)
