-- Experiment #7: membership, name lookup and sanity checker over Table.
import Table
open Table

/-- Binary search over sorted disjoint ranges, with fuel (64 > log2 of any size). -/
def bsearch (a : Array (UInt32 × UInt32)) (c : UInt32) : Nat → Nat → Nat → Bool
  | 0, _, _ => false
  | fuel + 1, lo, hi =>
    if lo < hi then
      let m := (lo + hi) / 2
      let r := a[m]!
      if c < r.1 then bsearch a c fuel lo m
      else if c ≤ r.2 then true
      else bsearch a c fuel (m + 1) hi
    else false

def memArr (a : Array (UInt32 × UInt32)) (c : UInt32) : Bool := bsearch a c 64 0 a.size

def ctypeMem (ct : Nat) (c : UInt32) : Bool := memArr (codeRanges[ct]!) c

def lookupName (s : String) : Int :=
  match names.find? (·.1 == s) with
  | some (_, c) => c
  | none => -1

/-- Sorted, disjoint, non-adjacent: lo ≤ hi and hi + 1 < next lo. -/
def okList : List (UInt32 × UInt32) → Bool
  | [] => true
  | (lo, hi) :: tl =>
    decide (lo ≤ hi) &&
    (match tl with
     | [] => true
     | (lo', _) :: _ => decide (hi.toNat + 1 < lo'.toNat)) &&
    okList tl

def tableOk : Bool := codeRanges.all (fun a => okList a.toList)

/-- Same checker through `Array.toList` and `List.all` (structural, kernel-reducible). -/
def tableOkL : Bool := codeRanges.toList.all (fun a => okList a.toList)
