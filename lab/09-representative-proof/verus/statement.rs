// Experiment #9, Verus: the statement of the main theorem (FRAGMENT.md 7),
// transcribed from fstar/Statement.fst, as a spec-level proposition over
// the spec fns; the proof is milestone M2's (runs 10-12).  Proving it
// means proving a `proof fn main_theorem() ensures main_theorem_statement()`.
// The hypothesis `groups(r).no_duplicates()` (distinct group numbers) is
// FRAGMENT.md 7's, added to Rocq's statement in run 4 and accepted by the
// maintainer (decision 5 of issue #4,
// https://github.com/tarides/maquizcoatl/issues/4#issuecomment-7165293346);
// `groups` is rocq/Statement.v's, `no_duplicates` vstd's NoDup on Seq.
use vstd::prelude::*;
use crate::syntax::*;
use crate::sem::*;
use crate::compile::*;
use crate::vm::*;

verus! {

// group numbers of a pattern, in order of their opening parenthesis
pub open spec fn groups(r: Regex) -> Seq<nat>
    decreases r,
{
    match r {
        Regex::Eps => Seq::empty(),
        Regex::Lit(_) => Seq::empty(),
        Regex::Cat(a, b) => groups(*a) + groups(*b),
        Regex::Alt(a, b) => groups(*a) + groups(*b),
        Regex::Star(a) => groups(*a),
        Regex::Group(k, a) => seq![k] + groups(*a),
    }
}

// The outer trigger (`sem` at fuel 0) only names a term with r, s and p
// that Verus accepts; M2's proof does not depend on it.
pub open spec fn main_theorem_statement() -> bool {
    forall|r: Regex, s: Seq<u8>, p: nat| #![trigger sem(0, r, s, p)]
        groups(r).no_duplicates() ==> p <= s.len() ==> {
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
