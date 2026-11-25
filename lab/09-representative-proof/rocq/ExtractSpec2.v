(* Experiment #9: extraction of experiment #6's milestone-2 semantics
   (Spec2.v, unchanged) for the transcription cross-check. *)
From Stdlib Require Import Extraction ExtrOcamlBasic ExtrOcamlNatInt ExtrOcamlZInt.
From S Require Import Spec2.
Extraction "spec2.ml" search search_from lookup fuel0.
