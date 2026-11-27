(* Issue #22: the four engines registered in experiment #12's harness.
   rocq, fstar: subject suffix converted inside each call (short shape,
   agreement, catastrophic); rocq-scan, fstar-scan: each subject
   converted once (large shape and the long-PHP row). *)

module Frag_parse = Frag_parse
module Engine22 = Engine22
module Rocq22 = Rocq22
module Fstar22 = Fstar22

module Rocq = Engine22.Make (Rocq22) (struct let name = "rocq" let scan = false end)
module Rocq_scan = Engine22.Make (Rocq22) (struct let name = "rocq-scan" let scan = true end)
module Fstar = Engine22.Make (Fstar22) (struct let name = "fstar" let scan = false end)
module Fstar_scan = Engine22.Make (Fstar22) (struct let name = "fstar-scan" let scan = true end)
