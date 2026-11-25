// Experiment #9, Verus M2: facts about the reference semantics, after
// fstar/ProofSem.fst and rocq/ProofSem.v.  Fuel monotonicity and
// determinism of `compute_tree`, lemma (d) for the semantics (some fuel
// suffices, on the measure of FRAGMENT.md 4: remaining input, then the
// weight of the pending actions; `fuel_of` returns the fuel), and the
// elided star (a body of code length 0 matches only the empty string and
// changes no capture).
use vstd::prelude::*;
use crate::syntax::*;
use crate::sem::*;
use crate::compile::*;
use crate::proof_a::*;

verus! {

broadcast use group_lists;

pub proof fn ct_mono(f: nat, s: Seq<u8>, acts: Seq<Action>, pos: nat, g: GMap, f2: nat)
    requires compute_tree(f, s, acts, pos, g) is Some, f <= f2,
    ensures compute_tree(f2, s, acts, pos, g) == compute_tree(f, s, acts, pos, g),
    decreases f,
{
    let f1 = (f - 1) as nat;
    let f3 = (f2 - 1) as nat;
    if acts.len() != 0 {
        let k = acts.drop_last();
        match acts.last() {
            Action::ARe(r) => match r {
                Regex::Eps => ct_mono(f1, s, k, pos, g, f3),
                Regex::Lit(l) => {
                    if is_prefix_at(l, s, pos) {
                        ct_mono(f1, s, k, pos + l.len(), g, f3);
                    }
                }
                Regex::Cat(a, b) => ct_mono(f1, s, k.push(Action::ARe(*b)).push(Action::ARe(*a)), pos, g, f3),
                Regex::Alt(a, b) => {
                    ct_mono(f1, s, k.push(Action::ARe(*a)), pos, g, f3);
                    ct_mono(f1, s, k.push(Action::ARe(*b)), pos, g, f3);
                }
                Regex::Star(a) => {
                    ct_mono(f1, s, k.push(Action::ACheck(pos, *a)).push(Action::ARe(*a)), pos, g, f3);
                    ct_mono(f1, s, k, pos, g, f3);
                }
                Regex::Group(n, a) =>
                    ct_mono(f1, s, k.push(Action::AClose(n, pos)).push(Action::ARe(*a)), pos, g, f3),
            },
            Action::ACheck(p0, a) => {
                if pos == p0 {
                    ct_mono(f1, s, k, pos, g, f3);
                } else {
                    ct_mono(f1, s, k.push(Action::ARe(Regex::Star(Box::new(a)))), pos, g, f3);
                }
            }
            Action::AClose(n, p0) => ct_mono(f1, s, k, pos, gset(n, (p0, pos), g), f3),
        }
    }
}

pub proof fn ct_det(s: Seq<u8>, f1: nat, f2: nat, acts: Seq<Action>, pos: nat, g: GMap)
    requires compute_tree(f1, s, acts, pos, g) is Some, compute_tree(f2, s, acts, pos, g) is Some,
    ensures compute_tree(f1, s, acts, pos, g) == compute_tree(f2, s, acts, pos, g),
{
    ct_mono(f1, s, acts, pos, g, f1 + f2);
    ct_mono(f2, s, acts, pos, g, f1 + f2);
}

// FRAGMENT.md 4: the termination measure
pub open spec fn size(r: Regex) -> nat
    decreases r,
{
    match r {
        Regex::Eps => 1,
        Regex::Lit(_) => 1,
        Regex::Cat(a, b) => size(*a) + size(*b) + 1,
        Regex::Alt(a, b) => size(*a) + size(*b) + 1,
        Regex::Star(a) => size(*a) + 2,
        Regex::Group(_, a) => size(*a) + 2,
    }
}

pub open spec fn wa(pos: nat, x: Action) -> nat {
    match x {
        Action::ARe(r) => size(r),
        Action::AClose(_, _) => 1,
        Action::ACheck(p0, a) => if pos == p0 { 1 } else { size(a) + 3 },
    }
}

pub open spec fn ww(pos: nat, acts: Seq<Action>) -> nat
    decreases acts.len(),
{
    if acts.len() == 0 { 0 } else { wa(pos, acts.last()) + ww(pos, acts.drop_last()) }
}

pub open spec fn rem(s: Seq<u8>, pos: nat) -> nat {
    if pos <= s.len() { (s.len() - pos) as nat } else { 0 }
}

// lemma (d), semantics: a fuel that makes compute_tree finish
pub proof fn fuel_of(s: Seq<u8>, acts: Seq<Action>, pos: nat, g: GMap) -> (f: nat)
    ensures compute_tree(f, s, acts, pos, g) is Some,
    decreases rem(s, pos), ww(pos, acts),
{
    if acts.len() == 0 {
        1
    } else {
        let k = acts.drop_last();
        assert(ww(pos, acts) == wa(pos, acts.last()) + ww(pos, k));
        match acts.last() {
            Action::ARe(r) => match r {
                Regex::Eps => 1 + fuel_of(s, k, pos, g),
                Regex::Lit(l) => {
                    if is_prefix_at(l, s, pos) {
                        if l.len() != 0 {
                            assert(rem(s, pos + l.len()) < rem(s, pos));
                        }
                        1 + fuel_of(s, k, pos + l.len(), g)
                    } else {
                        1
                    }
                }
                Regex::Cat(a, b) => {
                    let k2 = k.push(Action::ARe(*b)).push(Action::ARe(*a));
                    assert(ww(pos, k.push(Action::ARe(*b))) == size(*b) + ww(pos, k));
                    assert(ww(pos, k2) == size(*a) + (size(*b) + ww(pos, k)));
                    1 + fuel_of(s, k2, pos, g)
                }
                Regex::Alt(a, b) => {
                    let ka = k.push(Action::ARe(*a));
                    let kb = k.push(Action::ARe(*b));
                    assert(ww(pos, ka) == size(*a) + ww(pos, k));
                    assert(ww(pos, kb) == size(*b) + ww(pos, k));
                    let f1 = fuel_of(s, ka, pos, g);
                    let f2 = fuel_of(s, kb, pos, g);
                    ct_mono(f1, s, ka, pos, g, f1 + f2);
                    ct_mono(f2, s, kb, pos, g, f1 + f2);
                    1 + (f1 + f2)
                }
                Regex::Star(a) => {
                    let ka = k.push(Action::ACheck(pos, *a)).push(Action::ARe(*a));
                    assert(ww(pos, k.push(Action::ACheck(pos, *a))) == 1 + ww(pos, k));
                    assert(ww(pos, ka) == size(*a) + (1 + ww(pos, k)));
                    let f1 = fuel_of(s, ka, pos, g);
                    let f2 = fuel_of(s, k, pos, g);
                    ct_mono(f1, s, ka, pos, g, f1 + f2);
                    ct_mono(f2, s, k, pos, g, f1 + f2);
                    1 + (f1 + f2)
                }
                Regex::Group(n, a) => {
                    let k2 = k.push(Action::AClose(n, pos)).push(Action::ARe(*a));
                    assert(ww(pos, k.push(Action::AClose(n, pos))) == 1 + ww(pos, k));
                    assert(ww(pos, k2) == size(*a) + (1 + ww(pos, k)));
                    1 + fuel_of(s, k2, pos, g)
                }
            },
            Action::ACheck(p0, a) => {
                if pos == p0 {
                    1 + fuel_of(s, k, pos, g)
                } else {
                    let k2 = k.push(Action::ARe(Regex::Star(Box::new(a))));
                    assert(ww(pos, k2) == size(a) + 2 + ww(pos, k));
                    1 + fuel_of(s, k2, pos, g)
                }
            }
            Action::AClose(n, p0) => 1 + fuel_of(s, k, pos, gset(n, (p0, pos), g)),
        }
    }
}

pub proof fn ct_total(s: Seq<u8>, acts: Seq<Action>, pos: nat, g: GMap)
    ensures exists|f: nat| (#[trigger] compute_tree(f, s, acts, pos, g)) is Some,
{
    let f = fuel_of(s, acts, pos, g);
    assert(compute_tree(f, s, acts, pos, g) is Some);
}

// a star whose body compiles to no code (FRAGMENT.md 3, tlen == 0): the
// body leaves the subject and the captures alone
pub proof fn clen0_fm(s: Seq<u8>, a: Regex, f: nat, k: Seq<Action>, pos: nat, g: GMap)
    requires clen(a) == 0, compute_tree(f, s, k.push(Action::ARe(a)), pos, g) is Some,
    ensures
        compute_tree(f, s, k, pos, g) is Some,
        first_match(compute_tree(f, s, k, pos, g)->Some_0)
            == first_match(compute_tree(f, s, k.push(Action::ARe(a)), pos, g)->Some_0),
    decreases a,
{
    let f1 = (f - 1) as nat;
    match a {
        Regex::Eps => ct_mono(f1, s, k, pos, g, f),
        Regex::Lit(l) => ct_mono(f1, s, k, pos, g, f),
        Regex::Cat(a1, a2) => {
            clen0_fm(s, *a1, f1, k.push(Action::ARe(*a2)), pos, g);
            clen0_fm(s, *a2, f1, k, pos, g);
            ct_mono(f1, s, k, pos, g, f);
        }
        Regex::Alt(_, _) => {}
        Regex::Star(a1) => {
            let kc = k.push(Action::ACheck(pos, *a1));
            clen0_fm(s, *a1, f1, kc, pos, g);
            let f2 = (f1 - 1) as nat;
            assert(compute_tree(f1, s, kc, pos, g) == compute_tree(f2, s, k, pos, g));
            ct_det(s, f2, f1, k, pos, g);
            ct_mono(f1, s, k, pos, g, f);
        }
        Regex::Group(_, _) => {}
    }
}

} // verus!
