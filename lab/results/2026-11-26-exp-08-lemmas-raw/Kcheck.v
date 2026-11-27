From Stdlib Require Import List.
Import ListNotations.
From S Require Import Fold.
Eval vm_compute in (m [115;115] 6 [R (ILit [223])] 0, m [115;115] 7 [R (ILit [223])] 0, m [83;115] 6 [R (ILit [223])] 0, m [83;115] 7 [R (ILit [223])] 0).
Eval vm_compute in (m [223] 6 [R (ILit [115;115])] 0, m [223] 7 [R (ILit [115;115])] 0, m [83;83] 6 [R (ILit [115;83])] 0, m [83;83] 7 [R (ILit [115;83])] 0, unravel [223], unravel [115;83]).
