From Stdlib Require Import Extraction ExtrOcamlBasic ExtrOcamlNatInt ExtrOcamlZInt.
From S Require Import Spec.
Extraction "spec.ml" run_case count passes fuel0.
