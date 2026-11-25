-- Experiment #6 milestone 2: driver for the Lean native build of the S2
-- semantics.  Prints one verdict per case, then times REPS passes of
-- `passes` (search only: the cases are ASTs built by the case module).
import Cases
open Spec2

def main (args : List String) : IO Unit := do
  let reps := args.head!.toNat!
  for c in cases do
    IO.println (" ".intercalate ((runCase fuel0 c.1 c.2.1 c.2.2.1 c.2.2.2.1).map toString))
  if reps > 0 then
    let nc := cases.length
    let t0 ← IO.monoNanosNow
    let n := passes reps cases 0
    IO.println s!"agree={n}"
    let t1 ← IO.monoNanosNow
    let s := (Float.ofNat (t1 - t0)) / 1e9
    IO.println s!"cases={nc} reps={reps} agree={n} search_s={s} search_cps={(Float.ofNat (nc * reps)) / s}"
