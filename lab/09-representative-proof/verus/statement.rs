// Experiment #9, Verus: the statement of the main theorem (FRAGMENT.md 7),
// transcribed from fstar/Statement.fst, as a spec-level proposition over
// the spec fns; the proof is milestone M2's (runs 10-12).  Proving it
// means proving a `proof fn main_theorem() ensures main_theorem_statement()`.
use vstd::prelude::*;
use crate::syntax::*;
use crate::sem::*;
use crate::compile::*;
use crate::vm::*;

verus! {

// The outer trigger (`sem` at fuel 0) only names a term with r, s and p
// that Verus accepts; M2's proof does not depend on it.
pub open spec fn main_theorem_statement() -> bool {
    forall|r: Regex, s: Seq<u8>, p: nat| #![trigger sem(0, r, s, p)]
        p <= s.len() ==> {
            // soundness: a VM result other than OutOfFuel is the
            // semantics' result, for any fuel the semantics completes with
            &&& forall|fv: nat, fs: nat| #![trigger vm(fv, compile(r), ncap(r), s, p), sem(fs, r, s, p)]
                    (vm(fv, compile(r), ncap(r), s, p) != Res::OutOfFuel && sem(fs, r, s, p) != Res::OutOfFuel)
                    ==> sem(fs, r, s, p) == vm(fv, compile(r), ncap(r), s, p)
            // completeness: some fuel makes the semantics and the VM finish
            &&& exists|fs: nat| #[trigger] sem(fs, r, s, p) != Res::OutOfFuel
            &&& exists|fv: nat| #[trigger] vm(fv, compile(r), ncap(r), s, p) != Res::OutOfFuel
        }
}

} // verus!
