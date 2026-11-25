module Tables
(* Experiment #9: stand-in for experiment #6's generated table module,
   so that milestone 2's Spec2.fst (lab/06-spec-speed/fstar/Spec2.fst)
   can be checked and extracted for the transcription cross-check.  The
   fragment uses neither case folding nor properties, so neither
   definition is reached on its cases.  Copied to Tables.fst at build
   time. *)
let fold_of (c:int) : list int = [c]
let in_prop (p c:int) : bool = false
