From Stdlib Require Import Extraction ExtrOcamlBasic ExtrOcamlNatInt ExtrOcamlZInt.
From S Require Import Tables Spec2 Cases.
Extraction "full2.ml" cases run_case passes fuel0.
