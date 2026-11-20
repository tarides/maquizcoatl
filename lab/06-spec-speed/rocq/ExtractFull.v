From Stdlib Require Import Extraction ExtrOcamlBasic ExtrOcamlNatInt ExtrOcamlZInt.
From S Require Import Spec Cases.
Extraction "full.ml" cases run_case passes fuel0.
