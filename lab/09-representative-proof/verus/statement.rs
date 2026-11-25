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

// The statement for one pattern r, subject s and start position p.
// Run 10 (M2) named it so that the outer quantifier can be triggered on
// it: run 3's outer trigger `sem(0, r, s, p)` occurs nowhere in the body
// outside a quantifier, so no proof could instantiate the statement at
// the arbitrary r, s, p of its own negation and the statement could not
// be proved in Verus.  Triggers carry no logical meaning; the body below
// is run 3's (with decision 5's hypothesis), unchanged.
pub open spec fn main_theorem_at(r: Regex, s: Seq<u8>, p: nat) -> bool {
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

pub open spec fn main_theorem_statement() -> bool {
    forall|r: Regex, s: Seq<u8>, p: nat| #[trigger] main_theorem_at(r, s, p)
}

} // verus!
