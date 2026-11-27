(* Issue #22: stand-ins for the extracted engines when the library
   extracted22 is absent (lab/12-ffi-vs-native built on its own, as in
   experiment #12's replay): compile answers Error 1, "unsupported by
   this engine". *)
module Stand_in (M : sig val name : string end) = struct
  type t = unit
  let name = M.name
  let compile ~syntax:_ ~options:_ ~limit:_ ~stack_limit:_ _ = Error 1
  let search () _ ~start:_ ~range:_ ~sopt:_ = -1
  let match_ () _ ~at:_ ~sopt:_ = -1
  let nregs () = 0
  let beg () _ = -1
  let end_ () _ = -1
end
module Rocq = Stand_in (struct let name = "rocq" end)
module Rocq_scan = Stand_in (struct let name = "rocq-scan" end)
module Fstar = Stand_in (struct let name = "fstar" end)
module Fstar_scan = Stand_in (struct let name = "fstar-scan" end)
