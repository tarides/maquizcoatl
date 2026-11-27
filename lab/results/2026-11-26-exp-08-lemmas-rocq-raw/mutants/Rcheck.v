(* Run 2: the hypothesis rr <= length s of lemma 2 is needed.  At rr = 2
   on the empty subject, the direct matcher's AbsRep scans to the register
   (ends 2, 1, 0) while the desugared engine's AnyO step stops at the
   subject end (end 0). *)
From Stdlib Require Import List.
Import ListNotations.
From S Require Import Absent Desugar.
Eval vm_compute in (m [] 1000 1000 [R (AbsRep (Chr 7))] 0 2,
  match md [] 1000 [DR (fst (desugar (AbsRep (Chr 7)) 0))] 0 2 [] with
  | Some (rs, x) => Some (map (fun '(e, _, _) => e) rs, x) | None => None end).
