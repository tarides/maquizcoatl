(* Experiment #9, Rocq: extraction of the fragment's definitions for the
   OCaml driver (main.ml). *)
From Stdlib Require Import Extraction ExtrOcamlBasic ExtrOcamlNatInt.
From S Require Import Syntax Sem Compile Vm.
Extraction "frag.ml" compile vm sem ncap search.
