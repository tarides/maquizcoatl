(* T_spec: the semantics alone; the table module is extracted and
   compiled beforehand (ExtractTables.v, untimed) and referenced here. *)
From Stdlib Require Import Extraction ExtrOcamlBasic ExtrOcamlNatInt ExtrOcamlZInt.
From S Require Import Tables Spec2.
Extract Constant Tables.fold_of => "Tables.fold_of".
Extract Constant Tables.in_prop => "Tables.in_prop".
Extraction "spec2.ml" run_case count passes fuel0.
