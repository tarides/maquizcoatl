module Extract
(* Experiment #9, F*: root module of the OCaml extraction (fstar.sh,
   --codegen OCaml with one --custard_entry per name the driver uses).
   It names Compile, Syntax and experiment #6's Spec2 so that they are
   loaded; Vm and Sem are not named here and are brought in by
   fstar.sh's --custard_entry flags (Vm.vm, Sem.sem). It has no content
   of its own. *)
let fuel = Spec2.fuel0
let code = Compile.compile Syntax.Eps
