// Experiment #8 follow-up (issue #34), lemma 1: lemma F over a symbolic
// subject; transcription of rocq/FoldProof.v.  Design:
// lab/08-discriminating-lemmas/LEMMAS.md, "Lemma 1".
// On m of fold.rs (experiment #8's file, unchanged), under IGNORECASE,
// for every subject s, position i and fuel f >= 7:
// (F1) i + 2 is an end of [R (ILit [0xDF])] at i iff s[i..i+2) is one of
//      ss, SS, sS, Ss;
// (F2) for each such spelling w, i + 1 is an end of [R (ILit w)] at i iff
//      s[i] = 0xDF.
// The constant fuel() of fold.rs appears in no statement or proof.
use vstd::prelude::*;
use crate::fold::*;

verus! {

pub open spec fn memn(x: nat, l: L<nat>) -> bool decreases l {
    match l { L::Nil => false, L::Cons(y, t) => y == x || memn(x, *t) }
}

// The four two-byte spellings of ss: ss, SS, sS, Ss.
pub open spec fn is_ss(a: nat, b: nat) -> bool {
    (a == 115 && b == 115) || (a == 83 && b == 83) || (a == 115 && b == 83) || (a == 83 && b == 115)
}

pub open spec fn pick(b: bool, e: nat) -> L<nat> { if b { cons(e, L::Nil) } else { L::Nil } }

// The ends of one segment of alternatives followed by the empty stack.
pub open spec fn seg_ends(s: L<nat>, i: nat, alts: L<L<nat>>) -> L<nat> decreases alts {
    match alts {
        L::Nil => L::Nil,
        L::Cons(w, ws) => app(pick(prefix_at(s, i, w), i + len(w)), seg_ends(s, i, *ws)),
    }
}

pub proof fn memn_app(x: nat, a: L<nat>, b: L<nat>)
    ensures memn(x, app(a, b)) == (memn(x, a) || memn(x, b)),
    decreases a
{
    match a { L::Nil => {}, L::Cons(_, t) => memn_app(x, *t, b) }
}

pub proof fn m_seg(s: L<nat>, f: nat, alts: L<L<nat>>, i: nat)
    requires f >= len(alts) + 1,
    ensures m(s, f, cons(Item::Seg(alts), L::Nil), i) == seg_ends(s, i, alts),
    decreases alts
{
    let f1 = (f - 1) as nat;
    match alts {
        L::Nil => {},
        L::Cons(w, ws) => {
            m_seg(s, f1, *ws, i);
            if prefix_at(s, i, w) {
                assert(m(s, f1, L::Nil, i + len(w)) == cons(i + len(w), L::Nil));
            }
        }
    }
}

pub proof fn prefix2(s: L<nat>, i: nat, a: nat, b: nat)
    ensures prefix_at(s, i, two(a, b)) == (nth(s, i) == Some(a) && nth(s, i + 1) == Some(b)),
{
    reveal_with_fuel(prefix_at, 3);
}

pub proof fn prefix1(s: L<nat>, i: nat, a: nat)
    ensures prefix_at(s, i, cons(a, L::Nil)) == (nth(s, i) == Some(a)),
{
    reveal_with_fuel(prefix_at, 2);
}

// unravel [0xDF]: one segment, 0xDF then the four spellings.
pub open spec fn alts_df() -> L<L<nat>> {
    cons(cons(223, L::Nil), cons(two(115, 115), cons(two(83, 83), cons(two(115, 83), cons(two(83, 115), L::Nil)))))
}

pub proof fn m_df(s: L<nat>, i: nat, f: nat)
    requires f >= 7,
    ensures m(s, f, cons(Item::R(Re::ILit(cons(223, L::Nil))), L::Nil), i) == seg_ends(s, i, alts_df()),
{
    assert(unravel(cons(223, L::Nil)) == cons(alts_df(), L::Nil)) by (compute_only);
    assert(segs(cons(alts_df(), L::Nil), L::Nil) == cons(Item::Seg(alts_df()), L::Nil)) by { reveal_with_fuel(segs, 2); }
    assert(len(alts_df()) == 5) by (compute_only);
    m_seg(s, (f - 1) as nat, alts_df(), i);
}

// unravel [x; y] for a spelling of ss: the spelling, 0xDF, then the other
// three spellings, in ss_items' order.
pub open spec fn alts_ss(x: nat, y: nat) -> L<L<nat>> { cons(two(x, y), ss_items(x, y)) }

pub proof fn m_ss(s: L<nat>, i: nat, f: nat, x: nat, y: nat)
    requires f >= 7, is_ss(x, y),
    ensures m(s, f, cons(Item::R(Re::ILit(two(x, y))), L::Nil), i) == seg_ends(s, i, alts_ss(x, y)),
            len(alts_ss(x, y)) == 5,
{
    if x == 115 && y == 115 {
        assert(unravel(two(115, 115)) == cons(alts_ss(115, 115), L::Nil) && len(alts_ss(115, 115)) == 5) by (compute_only);
    } else if x == 83 && y == 83 {
        assert(unravel(two(83, 83)) == cons(alts_ss(83, 83), L::Nil) && len(alts_ss(83, 83)) == 5) by (compute_only);
    } else if x == 115 && y == 83 {
        assert(unravel(two(115, 83)) == cons(alts_ss(115, 83), L::Nil) && len(alts_ss(115, 83)) == 5) by (compute_only);
    } else {
        assert(unravel(two(83, 115)) == cons(alts_ss(83, 115), L::Nil) && len(alts_ss(83, 115)) == 5) by (compute_only);
    }
    assert(segs(cons(alts_ss(x, y), L::Nil), L::Nil) == cons(Item::Seg(alts_ss(x, y)), L::Nil)) by { reveal_with_fuel(segs, 2); }
    m_seg(s, (f - 1) as nat, alts_ss(x, y), i);
}

pub open spec fn mem_w(w: L<nat>, l: L<L<nat>>) -> bool decreases l {
    match l { L::Nil => false, L::Cons(y, t) => y == w || mem_w(w, *t) }
}

// The ends of the alternatives after the first two are all i + 2.
pub proof fn drop2_ends(s: L<nat>, i: nat, l: L<L<nat>>, x: nat, y: nat, e: nat)
    requires forall|w: L<nat>| mem_w(w, l) ==> len(w) == 2,
    ensures memn(e, seg_ends(s, i, drop2(x, y, l))) ==> e == i + 2,
    decreases l
{
    match l {
        L::Nil => {},
        L::Cons(w, t) => {
            assert(mem_w(w, l));
            assert forall|w2: L<nat>| mem_w(w2, *t) implies len(w2) == 2 by { assert(mem_w(w2, l)); }
            drop2_ends(s, i, *t, x, y, e);
            if w != two(x, y) {
                memn_app(e, pick(prefix_at(s, i, w), i + len(w)), seg_ends(s, i, drop2(x, y, *t)));
                reveal_with_fuel(memn, 2);
            }
        }
    }
}

// Main lemma (LEMMAS.md, lemma 1): F1 and F2 together.
pub proof fn sharp_s_sym(s: L<nat>, i: nat, f: nat)
    requires f >= 7,
    ensures
        memn(i + 2, m(s, f, cons(Item::R(Re::ILit(cons(223, L::Nil))), L::Nil), i)) <==>
            (exists|a: nat, b: nat| nth(s, i) == Some(a) && nth(s, i + 1) == Some(b) && is_ss(a, b)),
        forall|x: nat, y: nat| is_ss(x, y) ==>
            (memn(i + 1, m(s, f, cons(Item::R(Re::ILit(two(x, y))), L::Nil), i)) <==> nth(s, i) == Some(223nat)),
{
    // (F1)
    m_df(s, i, f);
    let a0 = cons(223nat, L::Nil);
    let p0 = prefix_at(s, i, a0);
    let p1 = prefix_at(s, i, two(115, 115));
    let p2 = prefix_at(s, i, two(83, 83));
    let p3 = prefix_at(s, i, two(115, 83));
    let p4 = prefix_at(s, i, two(83, 115));
    let e = i + 2;
    assert(len(a0) == 1 && len(two(115nat, 115nat)) == 2 && len(two(83nat, 83nat)) == 2
           && len(two(115nat, 83nat)) == 2 && len(two(83nat, 115nat)) == 2) by { reveal_with_fuel(len, 3); }
    let t4 = seg_ends(s, i, cons(two(83, 115), L::Nil));
    let t3 = seg_ends(s, i, cons(two(115, 83), cons(two(83, 115), L::Nil)));
    let t2 = seg_ends(s, i, cons(two(83, 83), cons(two(115, 83), cons(two(83, 115), L::Nil))));
    let t1 = seg_ends(s, i, cons(two(115, 115), cons(two(83, 83), cons(two(115, 83), cons(two(83, 115), L::Nil)))));
    assert(seg_ends(s, i, L::Nil) == L::<nat>::Nil);
    assert(t4 == app(pick(p4, e), L::Nil));
    assert(t3 == app(pick(p3, e), t4));
    assert(t2 == app(pick(p2, e), t3));
    assert(t1 == app(pick(p1, e), t2));
    assert(seg_ends(s, i, alts_df()) == app(pick(p0, i + 1), t1));
    memn_app(e, pick(p4, e), L::Nil);
    memn_app(e, pick(p3, e), t4);
    memn_app(e, pick(p2, e), t3);
    memn_app(e, pick(p1, e), t2);
    memn_app(e, pick(p0, i + 1), t1);
    reveal_with_fuel(memn, 2);
    prefix2(s, i, 115, 115);
    prefix2(s, i, 83, 83);
    prefix2(s, i, 115, 83);
    prefix2(s, i, 83, 115);
    assert(memn(e, m(s, f, cons(Item::R(Re::ILit(a0)), L::Nil), i)) == (p1 || p2 || p3 || p4));
    if p1 || p2 || p3 || p4 {
        let a = nth(s, i)->0;
        let b = nth(s, i + 1)->0;
        assert(nth(s, i) == Some(a) && nth(s, i + 1) == Some(b) && is_ss(a, b));
    }
    // (F2)
    assert forall|x: nat, y: nat| is_ss(x, y) implies
        (memn(i + 1, m(s, f, cons(Item::R(Re::ILit(two(x, y))), L::Nil), i)) <==> nth(s, i) == Some(223nat)) by {
        m_ss(s, i, f, x, y);
        let l0 = cons(two(83nat, 83nat), cons(two(83nat, 115nat), cons(two(115nat, 83nat), cons(two(115nat, 115nat), L::Nil))));
        let r = drop2(x, y, l0);
        let q0 = prefix_at(s, i, two(x, y));
        let q1 = prefix_at(s, i, a0);
        assert(len(two(x, y)) == 2) by { reveal_with_fuel(len, 3); }
        assert(ss_items(x, y) == cons(a0, r));
        assert(seg_ends(s, i, cons(a0, r)) == app(pick(q1, i + 1), seg_ends(s, i, r)));
        assert(seg_ends(s, i, alts_ss(x, y)) == app(pick(q0, i + 2), seg_ends(s, i, cons(a0, r))));
        memn_app(i + 1, pick(q0, i + 2), seg_ends(s, i, cons(a0, r)));
        memn_app(i + 1, pick(q1, i + 1), seg_ends(s, i, r));
        assert forall|w: L<nat>| mem_w(w, l0) implies len(w) == 2 by {
            reveal_with_fuel(mem_w, 5);
            reveal_with_fuel(len, 3);
        }
        drop2_ends(s, i, l0, x, y, i + 1);
        prefix1(s, i, 223);
    }
}

// Stretch (decision 6, LEMMAS.md "Stretch"): the one-level fold statement
// for every literal w.  e is an end of [R (ILit w)] at i iff s[i..e) is a
// concatenation of one alternative per segment of unravel w.  Proved for
// any list of segments (the induction is on the segments and their
// alternatives, not on w), at every fuel above the number of
// alternatives plus 2 (7 for [0xDF], the bound of lemma F).  Rocq's
// inductive fold_rel is a recursive spec fn with an existential.
pub open spec fn fold_rel(s: L<nat>, i: nat, sg: L<L<L<nat>>>, e: nat) -> bool decreases sg {
    match sg {
        L::Nil => e == i,
        L::Cons(alts, t) => exists|u: L<nat>| #[trigger] mem_w(u, alts) && prefix_at(s, i, u) && fold_rel(s, i + len(u), *t, e),
    }
}

pub open spec fn cost(sg: L<L<L<nat>>>) -> nat decreases sg {
    match sg { L::Nil => 1, L::Cons(alts, t) => len(alts) + cost(*t) }
}

pub proof fn cost_pos(sg: L<L<L<nat>>>) ensures 1 <= cost(sg) decreases sg {
    if let L::Cons(_, t) = sg { cost_pos(*t); }
}

pub proof fn seg_alts(s: L<nat>, alts: L<L<nat>>, t: L<L<L<nat>>>, f: nat, i: nat, e: nat)
    requires len(alts) + cost(t) <= f,
             forall|f2: nat, i2: nat| cost(t) <= f2 ==>
                 (#[trigger] memn(e, m(s, f2, segs(t, L::Nil), i2)) <==> fold_rel(s, i2, t, e)),
    ensures memn(e, m(s, f, cons(Item::Seg(alts), segs(t, L::Nil)), i)) <==>
            (exists|u: L<nat>| #[trigger] mem_w(u, alts) && prefix_at(s, i, u) && fold_rel(s, i + len(u), t, e)),
    decreases alts
{
    let k = segs(t, L::Nil);
    cost_pos(t);
    match alts {
        L::Nil => {},
        L::Cons(u, rest) => {
            let f1 = (f - 1) as nat;
            seg_alts(s, *rest, t, f1, i, e);
            let first = if prefix_at(s, i, u) { m(s, f1, k, i + len(u)) } else { L::Nil };
            memn_app(e, first, m(s, f1, cons(Item::Seg(*rest), k), i));
            assert(memn(e, m(s, f1, k, i + len(u))) <==> fold_rel(s, i + len(u), t, e));
            if exists|u2: L<nat>| #[trigger] mem_w(u2, alts) && prefix_at(s, i, u2) && fold_rel(s, i + len(u2), t, e) {
                let u2 = choose|u2: L<nat>| #[trigger] mem_w(u2, alts) && prefix_at(s, i, u2) && fold_rel(s, i + len(u2), t, e);
                if u2 != u { assert(mem_w(u2, *rest)); }
            }
            if memn(e, m(s, f1, cons(Item::Seg(*rest), k), i)) {
                let u2 = choose|u2: L<nat>| #[trigger] mem_w(u2, *rest) && prefix_at(s, i, u2) && fold_rel(s, i + len(u2), t, e);
                assert(mem_w(u2, alts));
            }
            if prefix_at(s, i, u) && fold_rel(s, i + len(u), t, e) { assert(mem_w(u, alts)); }
        }
    }
}

pub proof fn segs_m(s: L<nat>, sg: L<L<L<nat>>>, f: nat, i: nat, e: nat)
    requires cost(sg) <= f,
    ensures memn(e, m(s, f, segs(sg, L::Nil), i)) <==> fold_rel(s, i, sg, e),
    decreases sg
{
    match sg {
        L::Nil => { reveal_with_fuel(memn, 2); },
        L::Cons(alts, t) => {
            assert forall|f2: nat, i2: nat| cost(*t) <= f2 implies
                (#[trigger] memn(e, m(s, f2, segs(*t, L::Nil), i2)) <==> fold_rel(s, i2, *t, e)) by {
                segs_m(s, *t, f2, i2, e);
            }
            seg_alts(s, alts, *t, f, i, e);
        }
    }
}

pub proof fn fold_lit(s: L<nat>, w: L<nat>, i: nat, e: nat, f: nat)
    requires cost(unravel(w)) <= f,
    ensures memn(e, m(s, f + 1, cons(Item::R(Re::ILit(w)), L::Nil), i)) <==> fold_rel(s, i, unravel(w), e),
{
    assert(m(s, f + 1, cons(Item::R(Re::ILit(w)), L::Nil), i) == m(s, f, segs(unravel(w), L::Nil), i));
    segs_m(s, unravel(w), f, i, e);
}

pub proof fn cost_df() ensures cost(unravel(cons(223, L::Nil))) == 6 {
    assert(cost(unravel(cons(223, L::Nil))) == 6) by (compute_only);
}

} // verus!
