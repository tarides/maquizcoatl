module Extract
(* Experiment #9, F*: root module of the OCaml extraction (fstar.sh,
   --codegen OCaml with one --custard_entry per name the driver uses).
   It names the fragment's modules and experiment #6's Spec2 so that
   they are loaded; it has no content of its own. *)
let fuel = Spec2.fuel0
let code = Compile.compile Syntax.Eps
