// Experiment #6 milestone 2, Verus: stub of the table module, with the
// interface of the generated tables2.rs (cases/gen2.py).  T_spec checks
// and compiles spec2.rs against it, so that it measures the semantics
// alone (the table module is excluded, as for the other rows).
use vstd::prelude::*;

verus! {

pub fn fold_of(c: u32) -> (r: (u32, u32, u32, usize))
    ensures r.3 <= 3,
{
    (c, 0, 0, 1)
}

pub fn in_prop(p: u32, c: u32) -> bool {
    false
}

} // verus!
