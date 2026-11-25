(* Experiment #9: stand-in for experiment #6's generated table module,
   so that milestone 2's Spec2.v (lab/06-spec-speed/rocq/Spec2.v) can be
   compiled for the transcription cross-check.  The fragment uses
   neither case folding nor properties, so neither definition is
   reached on its cases.  Copied to Tables.v at build time. *)
From Stdlib Require Import List NArith.
Import ListNotations.
Definition fold_of (c : N) : list N := [c].
Definition in_prop (p c : N) : bool := false.
