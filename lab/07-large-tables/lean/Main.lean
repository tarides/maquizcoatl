-- Experiment #7: answer the query sample (queries file, names file, output file).
import Mem

def main (args : List String) : IO Unit := do
  let qs ← IO.FS.lines args[0]!
  let ns ← IO.FS.lines args[1]!
  let h ← IO.FS.Handle.mk args[2]! .write
  for l in qs do
    match l.splitOn " " with
    | [a, b] => h.putStrLn (if ctypeMem a.toNat! b.toNat!.toUInt32 then "1" else "0")
    | _ => pure ()
  for n in ns do h.putStrLn (toString (lookupName n))
