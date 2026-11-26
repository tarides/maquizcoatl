// Experiment #8 follow-up (issue #34), lemma 2: absent desugaring
// equivalence; Verus transcription of rocq/AbsentProof.v.  Design:
// lab/08-discriminating-lemmas/LEMMAS.md, "Lemma 2" and "Lemma plan".  The
// direct semantics m (absent.rs) and the state-threaded matcher md on the
// C desugaring (desugar.rs) give the same complete lists of ends, each for
// some fuel, in both directions (decision 3), for AbsRep, AbsExp (simple
// and general path), the stopper and the range clear, with no absent
// construct inside an absent one.
//
// Differences of encoding from the Rocq proof (same statements):
// - Rocq's Forall2 over the ends of a scan is replaced by one fuel for all
//   the ends (fuel monotonicity) and the concatenation of the results at
//   that fuel (dcat, mcat); the per-end fuels are merged with choose and a
//   maximum over the range (dfuel, dmax, mfuel, mmax);
// - Rocq's step predicate and register function h (sections Scan) are a
//   DRe (DAnyO or DChr c, stp) and an Option<nat> (hf: constant or identity);
// - Rocq's inductive rel is a recursive spec fn that takes the ids of each
//   item as a list ns.
use vstd::prelude::*;
use crate::absent::*;
use crate::desugar::*;
use crate::absent_mono::*;

verus! {

// ---------------------------------------------------------------- //
// Scope

pub open spec fn core(r: Re) -> bool decreases r {
    match r {
        Re::Eps | Re::Chr(_) | Re::Any | Re::AnyO => true,
        Re::Seq(a, b) => core(*a) && core(*b),
        Re::Alt(a, b) => core(*a) && core(*b),
        Re::Star(a) => core(*a),
        _ => false,
    }
}

pub open spec fn in_scope(r: Re) -> bool decreases r {
    match r {
        Re::Eps | Re::Chr(_) | Re::Any | Re::AnyO | Re::RClear => true,
        Re::Seq(a, b) => in_scope(*a) && in_scope(*b),
        Re::Alt(a, b) => in_scope(*a) && in_scope(*b),
        Re::Star(a) => in_scope(*a),
        Re::AbsRep(a) => core(*a),
        Re::Stopper(a) => core(*a),
        Re::AbsExp(a, e) => core(*a) && core(*e),
    }
}

pub proof fn core_in_scope(r: Re)
    requires core(r),
    ensures in_scope(r),
    decreases r
{
    match r {
        Re::Seq(a, b) => { core_in_scope(*a); core_in_scope(*b); },
        Re::Alt(a, b) => { core_in_scope(*a); core_in_scope(*b); },
        Re::Star(a) => core_in_scope(*a),
        _ => {},
    }
}

pub proof fn core_desugar(r: Re, n: nat)
    requires core(r),
    ensures desugar(r, n) == (emb(r), n),
    decreases r
{
    match r {
        Re::Seq(a, b) => { core_desugar(*a, n); core_desugar(*b, n); },
        Re::Alt(a, b) => { core_desugar(*a, n); core_desugar(*b, n); },
        Re::Star(a) => core_desugar(*a, n),
        _ => {},
    }
}

pub open spec fn emb_item(it: Item) -> DItem {
    match it { Item::R(x) => DItem::DR(emb(x)), Item::Chk(i, x) => DItem::DChk(i, emb(x)), _ => DItem::DR(DRe::DFail) }
}
pub open spec fn core_item(it: Item) -> bool {
    match it { Item::R(x) => core(x), Item::Chk(_, x) => core(x), _ => false }
}
pub open spec fn core_items(ks: L<Item>) -> bool decreases ks {
    match ks { L::Nil => true, L::Cons(it, t) => core_item(it) && core_items(*t) }
}
// map emb_item ks ++ tl
pub open spec fn embs(ks: L<Item>, tl: L<DItem>) -> L<DItem> decreases ks {
    match ks { L::Nil => tl, L::Cons(it, t) => cons(emb_item(it), embs(*t, tl)) }
}

pub open spec fn rsz(r: Re) -> nat decreases r {
    match r {
        Re::Seq(a, b) => 1 + rsz(*a) + rsz(*b),
        Re::Alt(a, b) => 1 + rsz(*a) + rsz(*b),
        Re::Star(a) => 2 + rsz(*a),
        _ => 1,
    }
}

pub open spec fn ends(rs: L<DRes>) -> L<nat> decreases rs {
    match rs { L::Nil => L::Nil, L::Cons(r, t) => cons(r.0, ends(*t)) }
}

// The continuation of the absent pattern inside the engine:
// UpdRRFromS j; Fail (regparse.c:3013-3020).
pub open spec fn kk(j: nat, rest: L<DItem>) -> L<DItem> {
    cons(DItem::DR(dsq(DRe::DUpdRRFromS(j), dsq(DRe::DFail, DRe::DEps))), rest)
}

pub proof fn md_k(s: L<nat>, f: nat, j: nat, rest: L<DItem>, q: nat, rho: nat, sv: L<(nat, nat)>, p: nat)
    requires lookup(j, sv) == Some(p),
    ensures f >= 4 ==> md(s, f, kk(j, rest), q, rho, sv) == Some((L::<DRes>::Nil, p)),
            md(s, f, kk(j, rest), q, rho, sv) is Some ==> f >= 4,
{
    let r0 = dsq(DRe::DFail, DRe::DEps);
    let a1 = cons(DItem::DR(DRe::DUpdRRFromS(j)), cons(DItem::DR(r0), rest));
    let a2 = cons(DItem::DR(r0), rest);
    let a3 = cons(DItem::DR(DRe::DFail), cons(DItem::DR(DRe::DEps), rest));
    if f >= 1 {
        assert(md(s, f, kk(j, rest), q, rho, sv) == md(s, (f - 1) as nat, a1, q, rho, sv));
        if f >= 2 {
            assert(md(s, (f - 1) as nat, a1, q, rho, sv) == md(s, (f - 2) as nat, a2, q, p, sv));
            if f >= 3 {
                assert(md(s, (f - 2) as nat, a2, q, p, sv) == md(s, (f - 3) as nat, a3, q, p, sv));
                if f >= 4 { assert(md(s, (f - 3) as nat, a3, q, p, sv) == Some((L::<DRes>::Nil, p))); }
            }
        }
    }
}

// (a), core part: on an absent-free stack followed by K, md never writes
// the register before K, and K sets it to p: md ends with p if the stack
// has a result (mb true), with the starting register otherwise.
pub proof fn core_k(s: L<nat>, j: nat, p: nat, rest: L<DItem>, f: nat, ks: L<Item>, q: nat, rho: nat, sv: L<(nat, nat)>)
    requires core_items(ks), lookup(j, sv) == Some(p), md(s, f, embs(ks, kk(j, rest)), q, rho, sv) is Some,
    ensures mb(s, f, ks, q, rho) is Some,
            (md(s, f, embs(ks, kk(j, rest)), q, rho, sv)->0).0 == L::<DRes>::Nil,
            (md(s, f, embs(ks, kk(j, rest)), q, rho, sv)->0).1 == if mb(s, f, ks, q, rho)->0 { p } else { rho },
    decreases f
{
    let f1 = (f - 1) as nat;
    let tl = kk(j, rest);
    match ks {
        L::Nil => { md_k(s, f, j, rest, q, rho, sv, p); },
        L::Cons(it, t) => {
            let e = embs(*t, tl);
            match it {
                Item::R(y) => match y {
                    Re::Eps => core_k(s, j, p, rest, f1, *t, q, rho, sv),
                    Re::Chr(c) => if at_(s, q, rho) == Some(c) { core_k(s, j, p, rest, f1, *t, q + 1, rho, sv) },
                    Re::Any => if at_(s, q, rho) is Some && at_(s, q, rho) != Some(10nat) { core_k(s, j, p, rest, f1, *t, q + 1, rho, sv) },
                    Re::AnyO => if at_(s, q, rho) is Some { core_k(s, j, p, rest, f1, *t, q + 1, rho, sv) },
                    Re::Seq(a, b) => {
                        let k2 = cons(Item::R(*a), cons(Item::R(*b), *t));
                        assert(embs(k2, tl) == cons(DItem::DR(emb(*a)), cons(DItem::DR(emb(*b)), e))) by { reveal_with_fuel(embs, 3); }
                        assert(core_items(k2)) by { reveal_with_fuel(core_items, 3); }
                        core_k(s, j, p, rest, f1, k2, q, rho, sv);
                    },
                    Re::Alt(a, b) => {
                        let ka = cons(Item::R(*a), *t);
                        let kb = cons(Item::R(*b), *t);
                        assert(embs(ka, tl) == cons(DItem::DR(emb(*a)), e));
                        assert(embs(kb, tl) == cons(DItem::DR(emb(*b)), e));
                        core_k(s, j, p, rest, f1, ka, q, rho, sv);
                        let x1 = (md(s, f1, embs(ka, tl), q, rho, sv)->0).1;
                        core_k(s, j, p, rest, f1, kb, q, x1, sv);
                    },
                    Re::Star(a) => {
                        let ka = cons(Item::R(*a), cons(Item::Chk(q, *a), *t));
                        assert(embs(ka, tl) == cons(DItem::DR(emb(*a)), cons(DItem::DChk(q, emb(*a)), e))) by { reveal_with_fuel(embs, 3); }
                        assert(core_items(ka)) by { reveal_with_fuel(core_items, 3); }
                        core_k(s, j, p, rest, f1, ka, q, rho, sv);
                        let x1 = (md(s, f1, embs(ka, tl), q, rho, sv)->0).1;
                        core_k(s, j, p, rest, f1, *t, q, x1, sv);
                    },
                    _ => {},
                },
                Item::Chk(i0, y) => {
                    if q == i0 { core_k(s, j, p, rest, f1, *t, q, rho, sv); }
                    else {
                        let ka = cons(Item::R(Re::Star(Box::new(y))), *t);
                        assert(embs(ka, tl) == cons(DItem::DR(dstar(emb(y))), e));
                        core_k(s, j, p, rest, f1, ka, q, rho, sv);
                    }
                },
                _ => {},
            }
        }
    }
}

// Termination measure on absent-free stacks at a fixed position.
pub open spec fn wt(it: Item, q: nat) -> nat {
    match it { Item::R(x) => rsz(x), Item::Chk(i0, x) => if i0 == q { 1 } else { rsz(x) + 3 }, _ => 1 }
}
pub open spec fn mu(ks: L<Item>, q: nat) -> nat decreases ks {
    match ks { L::Nil => 0, L::Cons(it, t) => wt(it, q) + mu(*t, q) }
}
pub open spec fn gap(rho: nat, q: nat) -> nat { if rho >= q { (rho - q) as nat } else { 0 } }

pub proof fn rsz_pos(r: Re) ensures 1 <= rsz(r) { }

pub proof fn at_lt(s: L<nat>, i: nat, rr: nat)
    requires at_(s, i, rr) is Some,
    ensures i < rr,
{ }

// (b)/(c) support: md on an absent-free stack followed by K terminates,
// by induction on (rho - q, mu) lexicographically.
pub proof fn term_core(s: L<nat>, j: nat, p: nat, rest: L<DItem>, ks: L<Item>, q: nat, rho: nat, sv: L<(nat, nat)>) -> (f: nat)
    requires core_items(ks), lookup(j, sv) == Some(p), p <= q,
    ensures md(s, f, embs(ks, kk(j, rest)), q, rho, sv) is Some,
    decreases gap(rho, q), mu(ks, q)
{
    let tl = kk(j, rest);
    match ks {
        L::Nil => { md_k(s, 4, j, rest, q, rho, sv, p); 4 },
        L::Cons(it, t) => {
            let e = embs(*t, tl);
            match it {
                Item::R(y) => match y {
                    Re::Eps => { rsz_pos(y); 1 + term_core(s, j, p, rest, *t, q, rho, sv) },
                    Re::Chr(c) => if at_(s, q, rho) == Some(c) {
                        let f = term_core(s, j, p, rest, *t, q + 1, rho, sv);
                        f + 1
                    } else { 1 },
                    Re::Any => if at_(s, q, rho) is Some && at_(s, q, rho) != Some(10nat) {
                        let f = term_core(s, j, p, rest, *t, q + 1, rho, sv);
                        f + 1
                    } else { 1 },
                    Re::AnyO => if at_(s, q, rho) is Some {
                        let f = term_core(s, j, p, rest, *t, q + 1, rho, sv);
                        f + 1
                    } else { 1 },
                    Re::Seq(a, b) => {
                        let k2 = cons(Item::R(*a), cons(Item::R(*b), *t));
                        assert(embs(k2, tl) == cons(DItem::DR(emb(*a)), cons(DItem::DR(emb(*b)), e))) by { reveal_with_fuel(embs, 3); }
                        assert(core_items(k2)) by { reveal_with_fuel(core_items, 3); }
                        assert(mu(k2, q) < mu(ks, q)) by { reveal_with_fuel(mu, 3); }
                        1 + term_core(s, j, p, rest, k2, q, rho, sv)
                    },
                    Re::Alt(a, b) => {
                        let ka = cons(Item::R(*a), *t);
                        let kb = cons(Item::R(*b), *t);
                        assert(embs(ka, tl) == cons(DItem::DR(emb(*a)), e));
                        assert(embs(kb, tl) == cons(DItem::DR(emb(*b)), e));
                        assert(mu(ka, q) < mu(ks, q) && mu(kb, q) < mu(ks, q)) by { rsz_pos(*a); rsz_pos(*b); }
                        let f1 = term_core(s, j, p, rest, ka, q, rho, sv);
                        core_k(s, j, p, rest, f1, ka, q, rho, sv);
                        let x1 = (md(s, f1, embs(ka, tl), q, rho, sv)->0).1;
                        let f2 = term_core(s, j, p, rest, kb, q, x1, sv);
                        md_mono(s, f1, f1 + f2, embs(ka, tl), q, rho, sv);
                        md_mono(s, f2, f1 + f2, embs(kb, tl), q, x1, sv);
                        1 + f1 + f2
                    },
                    Re::Star(a) => {
                        let ka = cons(Item::R(*a), cons(Item::Chk(q, *a), *t));
                        assert(embs(ka, tl) == cons(DItem::DR(emb(*a)), cons(DItem::DChk(q, emb(*a)), e))) by { reveal_with_fuel(embs, 3); }
                        assert(core_items(ka)) by { reveal_with_fuel(core_items, 3); }
                        assert(mu(ka, q) < mu(ks, q) && mu(*t, q) < mu(ks, q)) by { rsz_pos(*a); reveal_with_fuel(mu, 3); }
                        let f1 = term_core(s, j, p, rest, ka, q, rho, sv);
                        core_k(s, j, p, rest, f1, ka, q, rho, sv);
                        let x1 = (md(s, f1, embs(ka, tl), q, rho, sv)->0).1;
                        let f2 = term_core(s, j, p, rest, *t, q, x1, sv);
                        md_mono(s, f1, f1 + f2, embs(ka, tl), q, rho, sv);
                        md_mono(s, f2, f1 + f2, e, q, x1, sv);
                        1 + f1 + f2
                    },
                    _ => 0,
                },
                Item::Chk(i0, y) => {
                    if q == i0 { 1 + term_core(s, j, p, rest, *t, q, rho, sv) }
                    else {
                        let ka = cons(Item::R(Re::Star(Box::new(y))), *t);
                        assert(embs(ka, tl) == cons(DItem::DR(dstar(emb(y))), e));
                        1 + term_core(s, j, p, rest, ka, q, rho, sv)
                    }
                },
                _ => 0,
            }
        }
    }
}

// mb terminates on absent-free stacks (some fuel gives a complete answer).
pub proof fn mb_term(s: L<nat>, ks: L<Item>, q: nat, rho: nat) -> (f: nat)
    requires core_items(ks),
    ensures mb(s, f, ks, q, rho) is Some,
{
    let sv = cons((0nat, 0nat), L::Nil);
    let f = term_core(s, 0, 0, L::Nil, ks, q, rho, sv);
    core_k(s, 0, 0, L::Nil, f, ks, q, rho, sv);
    f
}

// (c), one position of the engine's scan: the branch
// SaveS j; a; UpdRRFromS j; Fail at q leaves the register at q if a has a
// result at q (mb true), unchanged otherwise, and has no result.
pub proof fn att_unfold(s: L<nat>, f: nat, j: nat, a: Re, rest: L<DItem>, q: nat, rho: nat, sv: L<(nat, nat)>)
    requires f >= 3,
    ensures md(s, f, cons(DItem::DR(att(j, emb(a))), rest), q, rho, sv)
            == md(s, (f - 3) as nat, embs(cons(Item::R(a), L::Nil), kk(j, rest)), q, rho, cons((j, q), sv)),
{
    let k3 = dsq(DRe::DUpdRRFromS(j), dsq(DRe::DFail, DRe::DEps));
    let a1 = cons(DItem::DR(DRe::DSaveS(j)), cons(DItem::DR(dsq(emb(a), k3)), rest));
    let a2 = cons(DItem::DR(dsq(emb(a), k3)), rest);
    assert(md(s, f, cons(DItem::DR(att(j, emb(a))), rest), q, rho, sv) == md(s, (f - 1) as nat, a1, q, rho, sv));
    assert(md(s, (f - 1) as nat, a1, q, rho, sv) == md(s, (f - 2) as nat, a2, q, rho, cons((j, q), sv)));
    assert(embs(cons(Item::R(a), L::Nil), kk(j, rest)) == cons(DItem::DR(emb(a)), cons(DItem::DR(k3), rest))) by { reveal_with_fuel(embs, 2); }
}

pub proof fn attempt(s: L<nat>, j: nat, a: Re, q: nat, rho: nat, sv: L<(nat, nat)>, rest: L<DItem>) -> (res: (nat, bool))
    requires core(a),
    ensures mb(s, res.0, cons(Item::R(a), L::Nil), q, rho) == Some(res.1),
            md(s, res.0, cons(DItem::DR(att(j, emb(a))), rest), q, rho, sv) == Some((L::<DRes>::Nil, if res.1 { q } else { rho })),
{
    let ka = cons(Item::R(a), L::Nil);
    let sv1 = cons((j, q), sv);
    assert(core_items(ka)) by { reveal_with_fuel(core_items, 2); }
    let f = term_core(s, j, q, rest, ka, q, rho, sv1);
    core_k(s, j, q, rest, f, ka, q, rho, sv1);
    let b = mb(s, f, ka, q, rho)->0;
    mb_mono(s, f, f + 3, ka, q, rho);
    att_unfold(s, f + 3, j, a, rest, q, rho, sv);
    (f + 3, b)
}

pub proof fn attempt_inv(s: L<nat>, j: nat, a: Re, q: nat, rho: nat, sv: L<(nat, nat)>, rest: L<DItem>, f: nat)
    requires core(a), md(s, f, cons(DItem::DR(att(j, emb(a))), rest), q, rho, sv) is Some,
    ensures mb(s, f, cons(Item::R(a), L::Nil), q, rho) is Some,
            md(s, f, cons(DItem::DR(att(j, emb(a))), rest), q, rho, sv)
              == Some((L::<DRes>::Nil, if mb(s, f, cons(Item::R(a), L::Nil), q, rho)->0 { q } else { rho })),
{
    let ka = cons(Item::R(a), L::Nil);
    let sv1 = cons((j, q), sv);
    assert(core_items(ka)) by { reveal_with_fuel(core_items, 2); }
    if f < 3 {
        let k3 = dsq(DRe::DUpdRRFromS(j), dsq(DRe::DFail, DRe::DEps));
        let a1 = cons(DItem::DR(DRe::DSaveS(j)), cons(DItem::DR(dsq(emb(a), k3)), rest));
        let a2 = cons(DItem::DR(dsq(emb(a), k3)), rest);
        assert(md(s, f, cons(DItem::DR(att(j, emb(a))), rest), q, rho, sv) == md(s, (f - 1) as nat, a1, q, rho, sv));
        if f == 2 { assert(md(s, 1, a1, q, rho, sv) == md(s, 0, a2, q, rho, cons((j, q), sv))); }
        assert(false);
    }
    att_unfold(s, f, j, a, rest, q, rho, sv);
    core_k(s, j, q, rest, (f - 3) as nat, ka, q, rho, sv1);
    mb_mono(s, (f - 3) as nat, f, ka, q, rho);
}

// ---------------------------------------------------------------- //
// Lists

pub proof fn app_nil<A>(l: L<A>)
    ensures app(l, L::Nil) == l,
    decreases l
{
    if let L::Cons(_, t) = l { app_nil(*t); }
}

pub proof fn app_assoc<A>(a: L<A>, b: L<A>, c: L<A>)
    ensures app(app(a, b), c) == app(a, app(b, c)),
    decreases a
{
    if let L::Cons(_, t) = a { app_assoc(*t, b, c); }
}

pub proof fn downs_s(n: nat, q: nat)
    ensures downs(n + 1, q) == app(downs(n, q + 1), cons(q, L::Nil)),
    decreases n
{
    if n == 0 {
        assert(downs(1, q) == cons(q + 1, downs(0, q)));
        assert(downs(0, q + 1) == cons(q + 1, L::Nil));
        assert(app(cons(q + 1, L::<nat>::Nil), cons(q, L::Nil)) == cons(q + 1, app(L::<nat>::Nil, cons(q, L::Nil))));
    } else {
        downs_s((n - 1) as nat, q);
        assert(downs(n + 1, q) == cons(q + (n + 1), downs(n, q)));
        assert(downs(n, q + 1) == cons(q + 1 + n, downs((n - 1) as nat, q + 1)));
        assert(app(downs(n, q + 1), cons(q, L::Nil)) == cons(q + 1 + n, app(downs((n - 1) as nat, q + 1), cons(q, L::Nil))));
    }
}

pub proof fn ends_app(a: L<DRes>, b: L<DRes>)
    ensures ends(app(a, b)) == app(ends(a), ends(b)),
    decreases a
{
    if let L::Cons(_, t) = a { ends_app(*t, b); }
}

// ---------------------------------------------------------------- //
// (c)/(d): the engine's scan, for a general step st (DAnyO, or DChr c on
// the simple path), followed by a continuation uu whose final register is
// hh(hf, x) of the register x it is entered with (hf = Some(r): the
// constant r; hf = None: the identity).

pub open spec fn is_step(st: DRe) -> bool { st is DAnyO || st is DChr }
pub open spec fn stp(s: L<nat>, st: DRe, q: nat, x: nat) -> bool {
    match st { DRe::DAnyO => at_(s, q, x) is Some, DRe::DChr(c) => at_(s, q, x) == Some(c), _ => false }
}
pub open spec fn hh(hf: Option<nat>, x: nat) -> nat { match hf { Some(r) => r, None => x } }
pub open spec fn body(j: nat, a: Re, st: DRe) -> DRe { dalt(att(j, emb(a)), st) }
pub open spec fn reg(top: nat, xt: nat, y: nat, e: nat) -> nat { if e == top { xt } else { y } }
// The register the attempt leaves at the top of the scan.
pub open spec fn xtop(bt: bool, top: nat, rho: nat) -> nat { if bt { top } else { rho } }

// The results of the continuation at each end of the scan, concatenated.
pub open spec fn dcat(s: L<nat>, f: nat, uu: L<DItem>, sv: L<(nat, nat)>, top: nat, xt: nat, y: nat, es: L<nat>) -> L<DRes>
    decreases es
{
    match es {
        L::Nil => L::Nil,
        L::Cons(e, t) => app((md(s, f, uu, e, reg(top, xt, y, e), sv)->0).0, dcat(s, f, uu, sv, top, xt, y, *t)),
    }
}

pub proof fn step_eq(s: L<nat>, st: DRe, f: nat, q: nat, x: nat, rest: L<DItem>, sv: L<(nat, nat)>)
    requires is_step(st),
    ensures md(s, f + 1, cons(DItem::DR(st), rest), q, x, sv)
            == if stp(s, st, q, x) { md(s, f, rest, q + 1, x, sv) } else { Some((L::<DRes>::Nil, x)) },
{ }

pub proof fn dcat_mono(s: L<nat>, f1: nat, f2: nat, uu: L<DItem>, sv: L<(nat, nat)>, top: nat, xt: nat, y: nat, d: nat, q: nat)
    requires f1 <= f2, forall|e: nat| q <= e <= q + d ==> #[trigger] md(s, f1, uu, e, reg(top, xt, y, e), sv) is Some,
    ensures dcat(s, f1, uu, sv, top, xt, y, downs(d, q)) == dcat(s, f2, uu, sv, top, xt, y, downs(d, q)),
    decreases d
{
    md_mono(s, f1, f2, uu, q + d, reg(top, xt, y, q + d), sv);
    if d > 0 {
        dcat_mono(s, f1, f2, uu, sv, top, xt, y, (d - 1) as nat, q);
        assert(downs(d, q) == cons(q + d, downs((d - 1) as nat, q)));
    } else {
        assert(downs(0, q) == cons(q, L::Nil));
    }
    let l = downs(d, q);
    let e = q + d;
    assert(dcat(s, f1, uu, sv, top, xt, y, l) == app((md(s, f1, uu, e, reg(top, xt, y, e), sv)->0).0, dcat(s, f1, uu, sv, top, xt, y, *(l->1))));
    assert(dcat(s, f2, uu, sv, top, xt, y, l) == app((md(s, f2, uu, e, reg(top, xt, y, e), sv)->0).0, dcat(s, f2, uu, sv, top, xt, y, *(l->1))));
}

pub proof fn dcat_app(s: L<nat>, f: nat, uu: L<DItem>, sv: L<(nat, nat)>, top: nat, xt: nat, y: nat, a: L<nat>, b: L<nat>)
    ensures dcat(s, f, uu, sv, top, xt, y, app(a, b)) == app(dcat(s, f, uu, sv, top, xt, y, a), dcat(s, f, uu, sv, top, xt, y, b)),
    decreases a
{
    if let L::Cons(e, t) = a {
        dcat_app(s, f, uu, sv, top, xt, y, *t, b);
        app_assoc((md(s, f, uu, e, reg(top, xt, y, e), sv)->0).0, dcat(s, f, uu, sv, top, xt, y, *t), dcat(s, f, uu, sv, top, xt, y, b));
    }
}

// dcat over downs (d + 1) q: the ends above q, then q's results.
pub proof fn dcat_downs_s(s: L<nat>, f: nat, uu: L<DItem>, sv: L<(nat, nat)>, top: nat, xt: nat, y: nat, d: nat, q: nat)
    ensures dcat(s, f, uu, sv, top, xt, y, downs(d + 1, q))
            == app(dcat(s, f, uu, sv, top, xt, y, downs(d, q + 1)), (md(s, f, uu, q, reg(top, xt, y, q), sv)->0).0),
{
    downs_s(d, q);
    dcat_app(s, f, uu, sv, top, xt, y, downs(d, q + 1), cons(q, L::Nil));
    let rq = (md(s, f, uu, q, reg(top, xt, y, q), sv)->0).0;
    app_nil(rq);
    assert(dcat(s, f, uu, sv, top, xt, y, cons(q, L::Nil)) == app(rq, dcat(s, f, uu, sv, top, xt, y, L::Nil)));
}

pub proof fn scan_a(s: L<nat>, j: nat, a: Re, st: DRe, uu: L<DItem>, hf: Option<nat>, sv: L<(nat, nat)>, rho: nat,
                    d: nat, q: nat, top: nat, bt: bool, fa: nat, fb: nat, fu: nat) -> (f: nat)
    requires
        core(a), is_step(st), top == q + d,
        forall|p: nat| q <= p < top ==> #[trigger] mb(s, fa, cons(Item::R(a), L::Nil), p, rho) == Some(false) && stp(s, st, p, rho),
        mb(s, fb, cons(Item::R(a), L::Nil), top, rho) == Some(bt),
        !stp(s, st, top, xtop(bt, top, rho)),
        forall|e: nat| q <= e <= top ==> {
            &&& #[trigger] md(s, fu, uu, e, reg(top, xtop(bt, top, rho), hh(hf, xtop(bt, top, rho)), e), sv) is Some
            &&& (md(s, fu, uu, e, reg(top, xtop(bt, top, rho), hh(hf, xtop(bt, top, rho)), e), sv)->0).1 == hh(hf, xtop(bt, top, rho))
        },
    ensures ({
        let xt = xtop(bt, top, rho);
        md(s, f, cons(DItem::DR(dstar(body(j, a, st))), uu), q, rho, sv)
            == Some((dcat(s, fu, uu, sv, top, xt, hh(hf, xt), downs(d, q)), hh(hf, xt)))
    }),
    decreases d
{
    let xt = xtop(bt, top, rho);
    let y = hh(hf, xt);
    let bb = body(j, a, st);
    let k1 = cons(DItem::DChk(q, bb), uu);
    let ka = cons(Item::R(a), L::Nil);
    let (fat, b) = attempt(s, j, a, q, rho, sv, k1);
    if d == 0 {
        mb_det(s, fat, fb, ka, q, rho);
        assert(md(s, fu, uu, q, reg(top, xtop(bt, top, rho), hh(hf, xtop(bt, top, rho)), q), sv) is Some);
        let f = fat + fu + 3;
        md_mono(s, fat, (f - 2) as nat, cons(DItem::DR(att(j, emb(a))), k1), q, rho, sv);
        step_eq(s, st, (f - 3) as nat, q, xt, k1, sv);
        md_mono(s, fu, (f - 1) as nat, uu, q, xt, sv);
        assert(md(s, (f - 1) as nat, cons(DItem::DR(bb), k1), q, rho, sv) == Some((app(L::<DRes>::Nil, L::<DRes>::Nil), xt)));
        app_nil((md(s, fu, uu, q, xt, sv)->0).0);
        assert(downs(0, q) == cons(q, L::Nil));
        assert(dcat(s, fu, uu, sv, top, xt, y, cons(q, L::Nil)) == app((md(s, fu, uu, q, xt, sv)->0).0, dcat(s, fu, uu, sv, top, xt, y, L::Nil)));
        f
    } else {
        let f1 = scan_a(s, j, a, st, uu, hf, sv, rho, (d - 1) as nat, q + 1, top, bt, fa, fb, fu);
        mb_det(s, fat, fa, ka, q, rho);
        let f = f1 + fat + fu + 4;
        md_mono(s, fat, (f - 2) as nat, cons(DItem::DR(att(j, emb(a))), k1), q, rho, sv);
        step_eq(s, st, (f - 3) as nat, q, rho, k1, sv);
        md_mono(s, f1, (f - 4) as nat, cons(DItem::DR(dstar(bb)), uu), q + 1, rho, sv);
        assert(md(s, (f - 3) as nat, k1, q + 1, rho, sv) == md(s, (f - 4) as nat, cons(DItem::DR(dstar(bb)), uu), q + 1, rho, sv));
        let r1 = dcat(s, fu, uu, sv, top, xt, y, downs((d - 1) as nat, q + 1));
        assert(md(s, (f - 1) as nat, cons(DItem::DR(bb), k1), q, rho, sv) == Some((app(L::<DRes>::Nil, r1), y)));
        assert(md(s, fu, uu, q, reg(top, xtop(bt, top, rho), hh(hf, xtop(bt, top, rho)), q), sv) is Some);
        md_mono(s, fu, (f - 1) as nat, uu, q, y, sv);
        dcat_downs_s(s, fu, uu, sv, top, xt, y, (d - 1) as nat, q);
        assert(((d - 1) as nat) + 1 == d);
        assert(app(app(L::<DRes>::Nil, r1), (md(s, fu, uu, q, y, sv)->0).0) == app(r1, (md(s, fu, uu, q, y, sv)->0).0));
        f
    }
}

pub proof fn scan_b(s: L<nat>, j: nat, a: Re, st: DRe, uu: L<DItem>, hf: Option<nat>, sv: L<(nat, nat)>, rho: nat,
                    ff: nat, q: nat, r: L<DRes>, x: nat) -> (res: (nat, bool))
    requires
        core(a), is_step(st), q <= rho,
        md(s, ff, cons(DItem::DR(dstar(body(j, a, st))), uu), q, rho, sv) == Some((r, x)),
        forall|f: nat, e: nat, x0: nat| f <= ff && e <= rho && #[trigger] md(s, f, uu, e, x0, sv) is Some
            ==> (md(s, f, uu, e, x0, sv)->0).1 == hh(hf, x0),
    ensures
        q <= res.0,
        forall|p: nat| q <= p < res.0 ==> #[trigger] mb(s, ff, cons(Item::R(a), L::Nil), p, rho) == Some(false) && stp(s, st, p, rho),
        mb(s, ff, cons(Item::R(a), L::Nil), res.0, rho) == Some(res.1),
        !stp(s, st, res.0, xtop(res.1, res.0, rho)),
        forall|e: nat| q <= e <= res.0 ==> {
            &&& #[trigger] md(s, ff, uu, e, reg(res.0, xtop(res.1, res.0, rho), hh(hf, xtop(res.1, res.0, rho)), e), sv) is Some
            &&& (md(s, ff, uu, e, reg(res.0, xtop(res.1, res.0, rho), hh(hf, xtop(res.1, res.0, rho)), e), sv)->0).1 == hh(hf, xtop(res.1, res.0, rho))
        },
        r == dcat(s, ff, uu, sv, res.0, xtop(res.1, res.0, rho), hh(hf, xtop(res.1, res.0, rho)), downs((res.0 - q) as nat, q)),
        x == hh(hf, xtop(res.1, res.0, rho)),
    decreases ff
{
    let bb = body(j, a, st);
    let k1 = cons(DItem::DChk(q, bb), uu);
    let ka = cons(Item::R(a), L::Nil);
    let f1 = (ff - 1) as nat;
    let f2 = (ff - 2) as nat;
    let (r1, x1) = md(s, f1, cons(DItem::DR(bb), k1), q, rho, sv)->0;
    let (r2, x2) = md(s, f1, uu, q, x1, sv)->0;
    assert(ff >= 2);
    let (ra, xa) = md(s, f2, cons(DItem::DR(att(j, emb(a))), k1), q, rho, sv)->0;
    attempt_inv(s, j, a, q, rho, sv, k1, f2);
    let b = mb(s, f2, ka, q, rho)->0;
    let (rb, xb) = md(s, f2, cons(DItem::DR(st), k1), q, xa, sv)->0;
    assert(f2 >= 1);
    step_eq(s, st, (f2 - 1) as nat, q, xa, k1, sv);
    mb_mono(s, f2, ff, ka, q, rho);
    if stp(s, st, q, xa) {
        assert(!b);
        let f4 = (ff - 4) as nat;
        assert(md(s, (ff - 3) as nat, k1, q + 1, rho, sv) == md(s, f4, cons(DItem::DR(dstar(bb)), uu), q + 1, rho, sv));
        let (top, bt) = scan_b(s, j, a, st, uu, hf, sv, rho, f4, q + 1, rb, xb);
        let xt = xtop(bt, top, rho);
        let y = hh(hf, xt);
        mb_mono(s, f4, ff, ka, top, rho);
        assert forall|p: nat| q <= p < top implies #[trigger] mb(s, ff, ka, p, rho) == Some(false) && stp(s, st, p, rho) by {
            if p > q { mb_mono(s, f4, ff, ka, p, rho); }
        }
        assert forall|e: nat| q <= e <= top implies {
            &&& #[trigger] md(s, ff, uu, e, reg(top, xt, y, e), sv) is Some
            &&& (md(s, ff, uu, e, reg(top, xt, y, e), sv)->0).1 == y
        } by {
            if e > q { md_mono(s, f4, ff, uu, e, reg(top, xt, y, e), sv); }
            else { md_mono(s, f1, ff, uu, q, y, sv); }
        }
        dcat_mono(s, f4, ff, uu, sv, top, xt, y, (top - (q + 1)) as nat, q + 1);
        dcat_downs_s(s, ff, uu, sv, top, xt, y, (top - (q + 1)) as nat, q);
        assert(((top - (q + 1)) as nat) + 1 == (top - q) as nat);
        assert(x1 == y);
        md_mono(s, f1, ff, uu, q, y, sv);
        assert(reg(top, xt, y, q) == y);
        assert(r1 == app(L::<DRes>::Nil, rb));
        assert(r == app(r1, r2));
        (top, bt)
    } else {
        let xt = xtop(b, q, rho);
        let y = hh(hf, xt);
        md_mono(s, f1, ff, uu, q, xt, sv);
        assert(downs(0, q) == cons(q, L::Nil));
        app_nil(r2);
        assert(x1 == xt);
        assert(r1 == app(L::<DRes>::Nil, L::<DRes>::Nil));
        assert(dcat(s, ff, uu, sv, q, xt, y, cons(q, L::Nil)) == app((md(s, ff, uu, q, xt, sv)->0).0, dcat(s, ff, uu, sv, q, xt, y, L::Nil)));
        (q, b)
    }
}

// ---------------------------------------------------------------- //
// The direct side: cut, Ends and x* in experiment #8's m.

pub proof fn scan_spec(a: Re, s: L<nat>, g: nat, rr: nat, k: nat, q: nat, c: nat)
    requires scan(a, s, g, rr, k, q) == Some(c),
    ensures q <= c,
            forall|p: nat| q <= p < c ==> #[trigger] occ(a, s, g, p, rr) == Some(false),
            c == q + k || (c < q + k && occ(a, s, g, c, rr) == Some(true)),
    decreases k
{
    if k > 0 && occ(a, s, g, q, rr) == Some(false) {
        scan_spec(a, s, g, rr, (k - 1) as nat, q + 1, c);
        assert forall|p: nat| q <= p < c implies #[trigger] occ(a, s, g, p, rr) == Some(false) by {
            if p > q { assert(q + 1 <= p < c); }
        }
    }
}

pub proof fn scan_intro(a: Re, s: L<nat>, g: nat, rr: nat, k: nat, q: nat, c: nat)
    requires q <= c,
             forall|p: nat| q <= p < c ==> #[trigger] occ(a, s, g, p, rr) == Some(false),
             c == q + k || (c < q + k && occ(a, s, g, c, rr) == Some(true)),
    ensures scan(a, s, g, rr, k, q) == Some(c),
    decreases k
{
    if k > 0 && q != c {
        assert(occ(a, s, g, q, rr) == Some(false));
        scan_intro(a, s, g, rr, (k - 1) as nat, q + 1, c);
    }
}

pub proof fn nth_some(s: L<nat>, p: nat)
    requires p < len(s),
    ensures nth(s, p) is Some,
    decreases s
{
    if let L::Cons(_, t) = s { if p > 0 { nth_some(*t, (p - 1) as nat); } }
}

pub proof fn at_some(s: L<nat>, p: nat, rr: nat)
    requires p < rr, rr <= len(s),
    ensures at_(s, p, rr) is Some,
{
    nth_some(s, p);
}

// The cut seen from the direct side: the register value the engine leaves
// at the cut position is the cut itself.  Returns a fuel and the result of
// mb at the cut.
pub proof fn cut_top(s: L<nat>, g: nat, a: Re, i: nat, rr: nat, c: nat) -> (res: (nat, bool))
    requires core(a), i <= rr, cut(a, s, g, i, rr) == Some(c),
    ensures i <= c, c <= rr,
            forall|p: nat| i <= p < c ==> #[trigger] mb(s, g, cons(Item::R(a), L::Nil), p, rr) == Some(false),
            mb(s, res.0, cons(Item::R(a), L::Nil), c, rr) == Some(res.1),
            xtop(res.1, c, rr) == c,
{
    scan_spec(a, s, g, rr, (rr - i) as nat, i, c);
    assert forall|p: nat| i <= p < c implies #[trigger] mb(s, g, cons(Item::R(a), L::Nil), p, rr) == Some(false) by {
        assert(occ(a, s, g, p, rr) == Some(false));
    }
    if c == rr {
        let ka = cons(Item::R(a), L::Nil);
        assert(core_items(ka)) by { reveal_with_fuel(core_items, 2); }
        let f = mb_term(s, ka, c, rr);
        (f, mb(s, f, ka, c, rr)->0)
    } else {
        (g, true)
    }
}

pub proof fn cut_term(s: L<nat>, a: Re, i: nat, rr: nat) -> (g: nat)
    requires core(a),
    ensures cut(a, s, g, i, rr) is Some,
{
    scan_term(s, a, rr, (rr - i) as nat, i)
}

pub proof fn scan_term(s: L<nat>, a: Re, rr: nat, k: nat, q: nat) -> (g: nat)
    requires core(a),
    ensures scan(a, s, g, rr, k, q) is Some,
    decreases k
{
    if k == 0 { 0 } else {
        let ka = cons(Item::R(a), L::Nil);
        assert(core_items(ka)) by { reveal_with_fuel(core_items, 2); }
        let fq = mb_term(s, ka, q, rr);
        let g1 = scan_term(s, a, rr, (k - 1) as nat, q + 1);
        let gm = if fq <= g1 { g1 } else { fq };
        mb_mono(s, fq, gm, ka, q, rr);
        if mb(s, fq, ka, q, rr) == Some(false) { scan_mono(a, s, g1, gm, rr, (k - 1) as nat, q + 1); }
        gm
    }
}

// The results of m at each of es, concatenated.
pub open spec fn mcat(s: L<nat>, g: nat, f: nat, ks: L<Item>, rr: nat, es: L<nat>) -> L<nat> decreases es {
    match es { L::Nil => L::Nil, L::Cons(e, t) => app(m(s, g, f, ks, e, rr)->0, mcat(s, g, f, ks, rr, *t)) }
}

pub proof fn m_ends_a(s: L<nat>, g: nat, f: nat, es: L<nat>, ks: L<Item>, i: nat, rr: nat)
    requires m(s, g, f, cons(Item::Ends(es), ks), i, rr) is Some,
    ensures forall|e: nat| mem(e, es) ==> #[trigger] m(s, g, (f - 1) as nat, ks, e, rr) is Some,
            m(s, g, f, cons(Item::Ends(es), ks), i, rr) == Some(mcat(s, g, (f - 1) as nat, ks, rr, es)),
    decreases es
{
    let f1 = (f - 1) as nat;
    if let L::Cons(e, t) = es {
        m_ends_a(s, g, f1, *t, ks, i, rr);
        assert forall|e2: nat| mem(e2, *t) implies #[trigger] m(s, g, f1, ks, e2, rr) is Some by {
            m_mono(s, g, g, (f1 - 1) as nat, f1, ks, e2, rr);
        }
        mcat_mono(s, g, (f1 - 1) as nat, f1, ks, rr, *t);
    }
}

pub proof fn mcat_mono(s: L<nat>, g: nat, f1: nat, f2: nat, ks: L<Item>, rr: nat, es: L<nat>)
    requires f1 <= f2, forall|e: nat| mem(e, es) ==> #[trigger] m(s, g, f1, ks, e, rr) is Some,
    ensures mcat(s, g, f1, ks, rr, es) == mcat(s, g, f2, ks, rr, es),
    decreases es
{
    if let L::Cons(e, t) = es {
        assert(mem(e, es));
        m_mono(s, g, g, f1, f2, ks, e, rr);
        assert forall|e2: nat| mem(e2, *t) implies #[trigger] m(s, g, f1, ks, e2, rr) is Some by { assert(mem(e2, es)); }
        mcat_mono(s, g, f1, f2, ks, rr, *t);
    }
}

pub proof fn m_ends_b(s: L<nat>, g: nat, f: nat, es: L<nat>, ks: L<Item>, i: nat, rr: nat)
    requires forall|e: nat| mem(e, es) ==> #[trigger] m(s, g, f, ks, e, rr) is Some,
    ensures m(s, g, f + len(es) + 1, cons(Item::Ends(es), ks), i, rr) == Some(mcat(s, g, f, ks, rr, es)),
    decreases es
{
    if let L::Cons(e, t) = es {
        assert(mem(e, es));
        assert forall|e2: nat| mem(e2, *t) implies #[trigger] m(s, g, f, ks, e2, rr) is Some by { assert(mem(e2, es)); }
        m_ends_b(s, g, f, *t, ks, i, rr);
        m_mono(s, g, g, f, f + len(es), ks, e, rr);
    }
}

pub proof fn mem_downs(d: nat, q: nat, e: nat)
    ensures mem(e, downs(d, q)) <==> q <= e <= q + d,
    decreases d
{
    reveal_with_fuel(mem, 2);
    if d > 0 { mem_downs((d - 1) as nat, q, e); }
}

pub proof fn len_downs(d: nat, q: nat)
    ensures len(downs(d, q)) == d + 1,
    decreases d
{
    reveal_with_fuel(len, 2);
    if d > 0 { len_downs((d - 1) as nat, q); }
}

pub proof fn mcat_downs_s(s: L<nat>, g: nat, f: nat, ks: L<Item>, rr: nat, d: nat, q: nat)
    ensures mcat(s, g, f, ks, rr, downs(d + 1, q)) == app(mcat(s, g, f, ks, rr, downs(d, q + 1)), m(s, g, f, ks, q, rr)->0),
{
    downs_s(d, q);
    mcat_app(s, g, f, ks, rr, downs(d, q + 1), cons(q, L::Nil));
    app_nil(m(s, g, f, ks, q, rr)->0);
    assert(mcat(s, g, f, ks, rr, cons(q, L::Nil)) == app(m(s, g, f, ks, q, rr)->0, mcat(s, g, f, ks, rr, L::Nil)));
}

pub proof fn mcat_app(s: L<nat>, g: nat, f: nat, ks: L<Item>, rr: nat, a: L<nat>, b: L<nat>)
    ensures mcat(s, g, f, ks, rr, app(a, b)) == app(mcat(s, g, f, ks, rr, a), mcat(s, g, f, ks, rr, b)),
    decreases a
{
    if let L::Cons(e, t) = a {
        mcat_app(s, g, f, ks, rr, *t, b);
        app_assoc(m(s, g, f, ks, e, rr)->0, mcat(s, g, f, ks, rr, *t), mcat(s, g, f, ks, rr, b));
    }
}

// x* on the direct side (the simple path of AbsExp): the ends of the
// repetitions of ch from q under the register c, longest first.
pub proof fn mstar_a(s: L<nat>, ch: nat, g: nat, f: nat, k: L<Item>, q: nat, c: nat) -> (top: nat)
    requires m(s, g, f, cons(Item::R(Re::Star(Box::new(Re::Chr(ch)))), k), q, c) is Some,
    ensures q <= top,
            forall|p: nat| q <= p < top ==> #[trigger] at_(s, p, c) == Some(ch),
            at_(s, top, c) != Some(ch),
            forall|e: nat| q <= e <= top ==> #[trigger] m(s, g, f, k, e, c) is Some,
            m(s, g, f, cons(Item::R(Re::Star(Box::new(Re::Chr(ch)))), k), q, c) == Some(mcat(s, g, f, k, c, downs((top - q) as nat, q))),
    decreases f
{
    let x = Re::Star(Box::new(Re::Chr(ch)));
    let f1 = (f - 1) as nat;
    let f2 = (f - 2) as nat;
    let k1 = cons(Item::R(Re::Chr(ch)), cons(Item::Chk(q, Re::Chr(ch)), k));
    let l2 = m(s, g, f1, k, q, c)->0;
    m_mono(s, g, g, f1, f, k, q, c);
    if at_(s, q, c) == Some(ch) {
        let f3 = (f - 3) as nat;
        assert(m(s, g, f1, k1, q, c) == m(s, g, f2, cons(Item::Chk(q, Re::Chr(ch)), k), q + 1, c));
        assert(m(s, g, f2, cons(Item::Chk(q, Re::Chr(ch)), k), q + 1, c) == m(s, g, f3, cons(Item::R(x), k), q + 1, c));
        let top = mstar_a(s, ch, g, f3, k, q + 1, c);
        assert forall|e: nat| q <= e <= top implies #[trigger] m(s, g, f, k, e, c) is Some by {
            if e > q { m_mono(s, g, g, f3, f, k, e, c); }
        }
        assert forall|p: nat| q <= p < top implies #[trigger] at_(s, p, c) == Some(ch) by { if p > q { assert(q + 1 <= p); } }
        assert forall|e: nat| mem(e, downs((top - (q + 1)) as nat, q + 1)) implies #[trigger] m(s, g, f3, k, e, c) is Some by {
            mem_downs((top - (q + 1)) as nat, q + 1, e);
        }
        mcat_mono(s, g, f3, f, k, c, downs((top - (q + 1)) as nat, q + 1));
        mcat_downs_s(s, g, f, k, c, (top - (q + 1)) as nat, q);
        assert(((top - (q + 1)) as nat) + 1 == (top - q) as nat);
        top
    } else {
        assert(m(s, g, f1, k1, q, c) == Some(L::<nat>::Nil));
        assert(downs(0, q) == cons(q, L::Nil));
        app_nil(l2);
        assert(mcat(s, g, f, k, c, cons(q, L::Nil)) == app(m(s, g, f, k, q, c)->0, mcat(s, g, f, k, c, L::Nil)));
        q
    }
}

pub proof fn mstar_b(s: L<nat>, ch: nat, g: nat, f: nat, k: L<Item>, d: nat, q: nat, top: nat, c: nat)
    requires top == q + d,
             forall|p: nat| q <= p < top ==> #[trigger] at_(s, p, c) == Some(ch),
             at_(s, top, c) != Some(ch),
             forall|e: nat| q <= e <= top ==> #[trigger] m(s, g, f, k, e, c) is Some,
    ensures m(s, g, f + 2 + 3 * d, cons(Item::R(Re::Star(Box::new(Re::Chr(ch)))), k), q, c) == Some(mcat(s, g, f, k, c, downs(d, q))),
    decreases d
{
    let x = Re::Star(Box::new(Re::Chr(ch)));
    let ff = f + 2 + 3 * d;
    let f1 = (ff - 1) as nat;
    let k1 = cons(Item::R(Re::Chr(ch)), cons(Item::Chk(q, Re::Chr(ch)), k));
    assert(m(s, g, f, k, q, c) is Some);
    m_mono(s, g, g, f, f1, k, q, c);
    if d == 0 {
        assert(m(s, g, f1, k1, q, c) == Some(L::<nat>::Nil));
        assert(downs(0, q) == cons(q, L::Nil));
        app_nil(m(s, g, f, k, q, c)->0);
        assert(mcat(s, g, f, k, c, cons(q, L::Nil)) == app(m(s, g, f, k, q, c)->0, mcat(s, g, f, k, c, L::Nil)));
    } else {
        mstar_b(s, ch, g, f, k, (d - 1) as nat, q + 1, top, c);
        let fp = f + 2 + 3 * ((d - 1) as nat);
        assert(at_(s, q, c) == Some(ch));
        assert(m(s, g, f1, k1, q, c) == m(s, g, (ff - 2) as nat, cons(Item::Chk(q, Re::Chr(ch)), k), q + 1, c));
        assert(m(s, g, (ff - 2) as nat, cons(Item::Chk(q, Re::Chr(ch)), k), q + 1, c) == m(s, g, (ff - 3) as nat, cons(Item::R(x), k), q + 1, c));
        assert((ff - 3) as nat == fp);
        mcat_downs_s(s, g, f, k, c, (d - 1) as nat, q);
    }
}

pub proof fn ends_dcat(s: L<nat>, fu: nat, uu: L<DItem>, sv: L<(nat, nat)>, top: nat, xt: nat, y: nat,
                       g: nat, f: nat, ks: L<Item>, rr: nat, d: nat, q: nat)
    requires forall|e: nat| q <= e <= q + d ==>
        ends((#[trigger] md(s, fu, uu, e, reg(top, xt, y, e), sv)->0).0) == m(s, g, f, ks, e, rr)->0,
    ensures ends(dcat(s, fu, uu, sv, top, xt, y, downs(d, q))) == mcat(s, g, f, ks, rr, downs(d, q)),
    decreases d
{
    let e = q + d;
    assert(ends((md(s, fu, uu, e, reg(top, xt, y, e), sv)->0).0) == m(s, g, f, ks, e, rr)->0);
    ends_app((md(s, fu, uu, e, reg(top, xt, y, e), sv)->0).0, dcat(s, fu, uu, sv, top, xt, y, *(downs(d, q)->1)));
    if d > 0 {
        ends_dcat(s, fu, uu, sv, top, xt, y, g, f, ks, rr, (d - 1) as nat, q);
        assert(downs(d, q) == cons(q + d, downs((d - 1) as nat, q)));
    } else {
        assert(downs(d, q) == cons(q, L::Nil));
        assert(dcat(s, fu, uu, sv, top, xt, y, L::Nil) == L::<DRes>::Nil);
        assert(mcat(s, g, f, ks, rr, L::Nil) == L::<nat>::Nil);
        assert(ends(L::<DRes>::Nil) == L::<nat>::Nil);
    }
    let l = downs(d, q);
    assert(dcat(s, fu, uu, sv, top, xt, y, l) == app((md(s, fu, uu, e, reg(top, xt, y, e), sv)->0).0, dcat(s, fu, uu, sv, top, xt, y, *(l->1))));
    assert(mcat(s, g, f, ks, rr, l) == app(m(s, g, f, ks, e, rr)->0, mcat(s, g, f, ks, rr, *(l->1))));
}

// One fuel for md at every end of a range (choose, then a maximum).
pub open spec fn dterm(s: L<nat>, ks: L<DItem>, e: nat, x: nat, sv: L<(nat, nat)>) -> bool {
    exists|f: nat| #[trigger] md(s, f, ks, e, x, sv) is Some
}
pub open spec fn dfuel(s: L<nat>, ks: L<DItem>, e: nat, x: nat, sv: L<(nat, nat)>) -> nat {
    choose|f: nat| md(s, f, ks, e, x, sv) is Some
}
pub open spec fn dmax(s: L<nat>, ks: L<DItem>, x: nat, sv: L<(nat, nat)>, d: nat, q: nat) -> nat decreases d {
    let f0 = dfuel(s, ks, q + d, x, sv);
    if d == 0 { f0 } else { let f1 = dmax(s, ks, x, sv, (d - 1) as nat, q); if f0 <= f1 { f1 } else { f0 } }
}
pub proof fn dmax_ok(s: L<nat>, ks: L<DItem>, x: nat, sv: L<(nat, nat)>, d: nat, q: nat)
    requires forall|e: nat| q <= e <= q + d ==> #[trigger] dterm(s, ks, e, x, sv),
    ensures forall|e: nat| q <= e <= q + d ==> #[trigger] md(s, dmax(s, ks, x, sv, d, q), ks, e, x, sv) == md(s, dfuel(s, ks, e, x, sv), ks, e, x, sv)
            && md(s, dfuel(s, ks, e, x, sv), ks, e, x, sv) is Some,
    decreases d
{
    let fm = dmax(s, ks, x, sv, d, q);
    assert forall|e: nat| q <= e <= q + d implies #[trigger] md(s, fm, ks, e, x, sv) == md(s, dfuel(s, ks, e, x, sv), ks, e, x, sv)
            && md(s, dfuel(s, ks, e, x, sv), ks, e, x, sv) is Some by {
        assert(dterm(s, ks, e, x, sv));
        let fe = dfuel(s, ks, e, x, sv);
        if d > 0 && e < q + d {
            dmax_ok(s, ks, x, sv, (d - 1) as nat, q);
            md_mono(s, dmax(s, ks, x, sv, (d - 1) as nat, q), fm, ks, e, x, sv);
        } else {
            md_mono(s, fe, fm, ks, e, x, sv);
        }
    }
}

// The same for m, with both fuels.
pub open spec fn mterm(s: L<nat>, ks: L<Item>, e: nat, rr: nat) -> bool {
    exists|g: nat, f: nat| #[trigger] m(s, g, f, ks, e, rr) is Some
}
pub open spec fn mfuel(s: L<nat>, ks: L<Item>, e: nat, rr: nat) -> (nat, nat) {
    choose|gf: (nat, nat)| m(s, gf.0, gf.1, ks, e, rr) is Some
}
pub open spec fn nmax(a: nat, b: nat) -> nat { if a <= b { b } else { a } }
pub open spec fn mmax(s: L<nat>, ks: L<Item>, rr: nat, d: nat, q: nat) -> (nat, nat) decreases d {
    let p0 = mfuel(s, ks, q + d, rr);
    if d == 0 { p0 } else { let p1 = mmax(s, ks, rr, (d - 1) as nat, q); (nmax(p0.0, p1.0), nmax(p0.1, p1.1)) }
}
pub proof fn mmax_ok(s: L<nat>, ks: L<Item>, rr: nat, d: nat, q: nat)
    requires forall|e: nat| q <= e <= q + d ==> #[trigger] mterm(s, ks, e, rr),
    ensures forall|e: nat| q <= e <= q + d ==>
            #[trigger] m(s, mmax(s, ks, rr, d, q).0, mmax(s, ks, rr, d, q).1, ks, e, rr) == m(s, mfuel(s, ks, e, rr).0, mfuel(s, ks, e, rr).1, ks, e, rr)
            && m(s, mfuel(s, ks, e, rr).0, mfuel(s, ks, e, rr).1, ks, e, rr) is Some,
    decreases d
{
    let pm = mmax(s, ks, rr, d, q);
    assert forall|e: nat| q <= e <= q + d implies
            #[trigger] m(s, pm.0, pm.1, ks, e, rr) == m(s, mfuel(s, ks, e, rr).0, mfuel(s, ks, e, rr).1, ks, e, rr)
            && m(s, mfuel(s, ks, e, rr).0, mfuel(s, ks, e, rr).1, ks, e, rr) is Some by {
        assert(mterm(s, ks, e, rr));
        let (g0, f0) = choose|g: nat, f: nat| m(s, g, f, ks, e, rr) is Some;
        assert(m(s, (g0, f0).0, (g0, f0).1, ks, e, rr) is Some);
        let pe = mfuel(s, ks, e, rr);
        if d > 0 && e < q + d {
            mmax_ok(s, ks, rr, (d - 1) as nat, q);
            let p1 = mmax(s, ks, rr, (d - 1) as nat, q);
            m_mono(s, p1.0, pm.0, p1.1, pm.1, ks, e, rr);
        } else {
            m_mono(s, pe.0, pm.0, pe.1, pm.1, ks, e, rr);
        }
    }
}

// ---------------------------------------------------------------- //
// Lemma 2: the stack relation and the per-construct equations of md

pub open spec fn noset(ks: L<Item>) -> bool decreases ks {
    match ks {
        L::Nil => true,
        L::Cons(it, t) => match it { Item::SetRR(_) => false, Item::Ends(_) => false, _ => noset(*t) },
    }
}

// A direct item stack and a desugared one (Rocq's inductive rel); ns
// holds the ids of each item: desugar's first id for R and Chk, the two
// ids of the tail for SetRR.  An absent construct is only followed by a
// stack with no SetRR (no absent construct inside an absent one); a SetRR
// (the end of AbsExp's exp) is only preceded by absent-free items, and its
// tail looks up the register saved at the construct's start.
pub open spec fn rel(s: L<nat>, sv: L<(nat, nat)>, rho: nat, ks: L<Item>, ns: L<(nat, nat)>, dks: L<DItem>) -> bool
    decreases ks
{
    match ks {
        L::Nil => ns is Nil && dks is Nil,
        L::Cons(it, kt) => match ns {
            L::Cons(n, nt) => match dks {
                L::Cons(di, dt) => match it {
                    Item::R(x) => di == DItem::DR(desugar(x, n.0).0) && in_scope(x) && (core(x) || noset(*kt))
                                  && rel(s, sv, rho, *kt, *nt, *dt),
                    Item::Chk(i, x) => di == DItem::DChk(i, desugar(x, n.0).0) && in_scope(x) && (core(x) || noset(*kt))
                                  && rel(s, sv, rho, *kt, *nt, *dt),
                    Item::SetRR(k) => di == DItem::DR(dsq(tail(n.0, n.1), DRe::DEps)) && noset(*kt)
                                  && rel(s, sv, rho, *kt, *nt, *dt)
                                  && lookup(n.0, sv) == Some(k) && n.1 != n.0 && rho <= k && k <= len(s),
                    Item::Ends(_) => false,
                },
                L::Nil => false,
            },
            L::Nil => false,
        },
    }
}

pub proof fn rel_free(s: L<nat>, sv: L<(nat, nat)>, rho: nat, ks: L<Item>, ns: L<(nat, nat)>, dks: L<DItem>, sv2: L<(nat, nat)>, rho2: nat)
    requires rel(s, sv, rho, ks, ns, dks), noset(ks),
    ensures rel(s, sv2, rho2, ks, ns, dks),
    decreases ks
{
    if let L::Cons(_, kt) = ks { rel_free(s, sv, rho, *kt, *(ns->1), *(dks->1), sv2, rho2); }
}

pub open spec fn ur(n: nat, dks: L<DItem>) -> L<DItem> { cons(DItem::DR(dsq(DRe::DUpdRRFromStack(n), DRe::DEps)), dks) }
pub open spec fn rst(n: nat) -> DRe { ds2(DRe::DUpdRRFromStack(n), DRe::DFail) }
pub open spec fn sv1(n: nat, i: nat, rr: nat, sv: L<(nat, nat)>) -> L<(nat, nat)> { cons((n + 1, i), cons((n, rr), sv)) }

pub proof fn lookup_sv1(n: nat, i: nat, rr: nat, sv: L<(nat, nat)>)
    ensures lookup(n, sv1(n, i, rr, sv)) == Some(rr), lookup(n + 1, sv1(n, i, rr, sv)) == Some(i),
{
    reveal_with_fuel(lookup, 2);
}

pub proof fn md_rst(s: L<nat>, f: nat, n: nat, k: L<DItem>, i: nat, x: nat, sv: L<(nat, nat)>, y: nat)
    requires lookup(n, sv) == Some(y),
    ensures f >= 4 ==> md(s, f, cons(DItem::DR(rst(n)), k), i, x, sv) == Some((L::<DRes>::Nil, y)),
            md(s, f, cons(DItem::DR(rst(n)), k), i, x, sv) is Some ==> md(s, f, cons(DItem::DR(rst(n)), k), i, x, sv) == Some((L::<DRes>::Nil, y)),
{
    let r0 = dsq(DRe::DFail, DRe::DEps);
    let a1 = cons(DItem::DR(DRe::DUpdRRFromStack(n)), cons(DItem::DR(r0), k));
    let a2 = cons(DItem::DR(r0), k);
    let a3 = cons(DItem::DR(DRe::DFail), cons(DItem::DR(DRe::DEps), k));
    if f >= 1 {
        assert(md(s, f, cons(DItem::DR(rst(n)), k), i, x, sv) == md(s, (f - 1) as nat, a1, i, x, sv));
        if f >= 2 {
            assert(md(s, (f - 1) as nat, a1, i, x, sv) == md(s, (f - 2) as nat, a2, i, y, sv));
            if f >= 3 {
                assert(md(s, (f - 2) as nat, a2, i, y, sv) == md(s, (f - 3) as nat, a3, i, y, sv));
            }
        }
    }
}

pub proof fn md_ur(s: L<nat>, f: nat, n: nat, dks: L<DItem>, e: nat, x: nat, sv: L<(nat, nat)>, y: nat)
    requires lookup(n, sv) == Some(y),
    ensures md(s, f + 3, ur(n, dks), e, x, sv) == md(s, f, dks, e, y, sv),
            md(s, f, ur(n, dks), e, x, sv) is Some ==> f >= 3,
{
    let a1 = cons(DItem::DR(DRe::DUpdRRFromStack(n)), cons(DItem::DR(DRe::DEps), dks));
    assert(md(s, f + 3, ur(n, dks), e, x, sv) == md(s, f + 2, a1, e, x, sv));
    assert(md(s, f + 2, a1, e, x, sv) == md(s, f + 1, cons(DItem::DR(DRe::DEps), dks), e, y, sv));
    if f >= 1 {
        assert(md(s, f, ur(n, dks), e, x, sv) == md(s, (f - 1) as nat, a1, e, x, sv));
        if f >= 2 { assert(md(s, (f - 1) as nat, a1, e, x, sv) == md(s, (f - 2) as nat, cons(DItem::DR(DRe::DEps), dks), e, y, sv)); }
    }
}

pub proof fn simple_unfold(s: L<nat>, f: nat, n: nat, a: Re, st: DRe, dks: L<DItem>, i: nat, rr: nat, sv: L<(nat, nat)>)
    requires f >= 4,
    ensures md(s, f, cons(DItem::DR(simple_tree(n, a, st)), dks), i, rr, sv) ==
        match md(s, (f - 4) as nat, cons(DItem::DR(dstar(body(n + 1, a, st))), ur(n, dks)), i, rr, cons((n, rr), sv)) {
            Some((r1, x1)) => match md(s, (f - 4) as nat, cons(DItem::DR(rst(n)), ur(n, dks)), i, x1, cons((n, rr), sv)) {
                Some((r2, x2)) => Some((app(r1, r2), x2)), None => None },
            None => None },
{
    let sv2 = cons((n, rr), sv);
    let eng = engine(n, n + 1, emb(a), st, false);
    let t1 = dsq(eng, dsq(DRe::DUpdRRFromStack(n), DRe::DEps));
    assert(eng == dalt(dstar(body(n + 1, a, st)), rst(n)));
    assert(md(s, f, cons(DItem::DR(simple_tree(n, a, st)), dks), i, rr, sv)
        == md(s, (f - 1) as nat, cons(DItem::DR(DRe::DSaveRR(n)), cons(DItem::DR(t1), dks)), i, rr, sv));
    assert(md(s, (f - 1) as nat, cons(DItem::DR(DRe::DSaveRR(n)), cons(DItem::DR(t1), dks)), i, rr, sv)
        == md(s, (f - 2) as nat, cons(DItem::DR(t1), dks), i, rr, sv2));
    assert(md(s, (f - 2) as nat, cons(DItem::DR(t1), dks), i, rr, sv2)
        == md(s, (f - 3) as nat, cons(DItem::DR(eng), ur(n, dks)), i, rr, sv2));
}

pub proof fn simple_intro(s: L<nat>, fs: nat, n: nat, a: Re, st: DRe, dks: L<DItem>, i: nat, rr: nat, sv: L<(nat, nat)>, rs: L<DRes>)
    requires md(s, fs, cons(DItem::DR(dstar(body(n + 1, a, st))), ur(n, dks)), i, rr, cons((n, rr), sv)) == Some((rs, rr)),
    ensures md(s, fs + 8, cons(DItem::DR(simple_tree(n, a, st)), dks), i, rr, sv) == Some((rs, rr)),
{
    let sv2 = cons((n, rr), sv);
    simple_unfold(s, fs + 8, n, a, st, dks, i, rr, sv);
    md_mono(s, fs, fs + 4, cons(DItem::DR(dstar(body(n + 1, a, st))), ur(n, dks)), i, rr, sv2);
    md_rst(s, fs + 4, n, ur(n, dks), i, rr, sv2, rr);
    app_nil(rs);
}

pub proof fn gen_unfold(s: L<nat>, f: nat, n: nat, a: Re, rest: DRe, dks: L<DItem>, i: nat, rr: nat, sv: L<(nat, nat)>)
    requires f >= 6,
    ensures ({
        let s1 = sv1(n, i, rr, sv);
        let k2 = cons(DItem::DR(dsq(DRe::DUpdSFromStack(n + 1), rest)), dks);
        md(s, f, cons(DItem::DR(gen_head(n, a, rest)), dks), i, rr, sv) ==
        match md(s, (f - 6) as nat, cons(DItem::DR(DRe::DAtomic(Box::new(dstar(body(n + 2, a, DRe::DAnyO))))), k2), i, rr, s1) {
            Some((r1, x1)) => match md(s, (f - 6) as nat, cons(DItem::DR(rst(n)), k2), i, x1, s1) {
                Some((r2, x2)) => Some((app(r1, r2), x2)), None => None },
            None => None }
    }),
{
    let s1 = sv1(n, i, rr, sv);
    let sv2 = cons((n, rr), sv);
    let k2 = cons(DItem::DR(dsq(DRe::DUpdSFromStack(n + 1), rest)), dks);
    let eng = engine(n, n + 2, emb(a), DRe::DAnyO, true);
    assert(eng == dalt(DRe::DAtomic(Box::new(dstar(body(n + 2, a, DRe::DAnyO)))), rst(n)));
    let t3 = dsq(eng, dsq(DRe::DUpdSFromStack(n + 1), rest));
    let t2 = dsq(DRe::DSaveS(n + 1), t3);
    assert(md(s, f, cons(DItem::DR(gen_head(n, a, rest)), dks), i, rr, sv)
        == md(s, (f - 1) as nat, cons(DItem::DR(DRe::DSaveRR(n)), cons(DItem::DR(t2), dks)), i, rr, sv));
    assert(md(s, (f - 1) as nat, cons(DItem::DR(DRe::DSaveRR(n)), cons(DItem::DR(t2), dks)), i, rr, sv)
        == md(s, (f - 2) as nat, cons(DItem::DR(t2), dks), i, rr, sv2));
    assert(md(s, (f - 2) as nat, cons(DItem::DR(t2), dks), i, rr, sv2)
        == md(s, (f - 3) as nat, cons(DItem::DR(DRe::DSaveS(n + 1)), cons(DItem::DR(t3), dks)), i, rr, sv2));
    assert(md(s, (f - 3) as nat, cons(DItem::DR(DRe::DSaveS(n + 1)), cons(DItem::DR(t3), dks)), i, rr, sv2)
        == md(s, (f - 4) as nat, cons(DItem::DR(t3), dks), i, rr, s1));
    assert(md(s, (f - 4) as nat, cons(DItem::DR(t3), dks), i, rr, s1)
        == md(s, (f - 5) as nat, cons(DItem::DR(eng), k2), i, rr, s1));
}

pub proof fn md_u2(s: L<nat>, f: nat, n: nat, rest: DRe, dks: L<DItem>, e: nat, x: nat, sv: L<(nat, nat)>, i: nat)
    requires lookup(n + 1, sv) == Some(i),
    ensures md(s, f + 2, cons(DItem::DR(dsq(DRe::DUpdSFromStack(n + 1), rest)), dks), e, x, sv) == md(s, f, cons(DItem::DR(rest), dks), i, x, sv),
            md(s, f, cons(DItem::DR(dsq(DRe::DUpdSFromStack(n + 1), rest)), dks), e, x, sv) is Some ==> f >= 2,
{
    let a1 = cons(DItem::DR(DRe::DUpdSFromStack(n + 1)), cons(DItem::DR(rest), dks));
    assert(md(s, f + 2, cons(DItem::DR(dsq(DRe::DUpdSFromStack(n + 1), rest)), dks), e, x, sv) == md(s, f + 1, a1, e, x, sv));
    if f >= 1 { assert(md(s, f, cons(DItem::DR(dsq(DRe::DUpdSFromStack(n + 1), rest)), dks), e, x, sv) == md(s, (f - 1) as nat, a1, e, x, sv)); }
}

pub proof fn gen_intro(s: L<nat>, fs: nat, fk: nat, n: nat, a: Re, rest: DRe, dks: L<DItem>, i: nat, rr: nat, sv: L<(nat, nat)>,
                       t: L<DRes>, y: nat, rs: L<DRes>, c: nat)
    requires
        md(s, fs, cons(DItem::DR(dstar(body(n + 2, a, DRe::DAnyO))), L::Nil), i, rr, sv1(n, i, rr, sv)) == Some((cons((c, c, sv1(n, i, rr, sv)), t), y)),
        md(s, fk, cons(DItem::DR(rest), dks), i, c, sv1(n, i, rr, sv)) == Some((rs, c)),
    ensures md(s, fs + fk + 12, cons(DItem::DR(gen_head(n, a, rest)), dks), i, rr, sv) == Some((rs, rr)),
{
    let f = fs + fk + 12;
    let s1 = sv1(n, i, rr, sv);
    let k2 = cons(DItem::DR(dsq(DRe::DUpdSFromStack(n + 1), rest)), dks);
    gen_unfold(s, f, n, a, rest, dks, i, rr, sv);
    lookup_sv1(n, i, rr, sv);
    md_mono(s, fs, (f - 7) as nat, cons(DItem::DR(dstar(body(n + 2, a, DRe::DAnyO))), L::Nil), i, rr, s1);
    md_u2(s, (f - 9) as nat, n, rest, dks, c, c, s1, i);
    md_mono(s, fk, (f - 9) as nat, cons(DItem::DR(rest), dks), i, c, s1);
    assert(md(s, (f - 6) as nat, cons(DItem::DR(DRe::DAtomic(Box::new(dstar(body(n + 2, a, DRe::DAnyO))))), k2), i, rr, s1)
        == md(s, (f - 7) as nat, k2, c, c, s1));
    lookup_sv1(n, i, rr, sv);
    md_rst(s, (f - 6) as nat, n, k2, i, c, s1, rr);
    app_nil(rs);
}

pub proof fn rclear_unfold(s: L<nat>, f: nat, n: nat, dks: L<DItem>, i: nat, rr: nat, sv: L<(nat, nat)>)
    requires f >= 4,
    ensures ({
        let sv2 = cons((n, rr), sv);
        let k2 = cons(DItem::DR(DRe::DEps), dks);
        md(s, f, cons(DItem::DR(desugar(Re::RClear, n).0), dks), i, rr, sv) ==
        match md(s, (f - 4) as nat, cons(DItem::DR(DRe::DRRInit), k2), i, rr, sv2) {
            Some((r1, x1)) => match md(s, (f - 4) as nat, cons(DItem::DR(rst(n)), k2), i, x1, sv2) {
                Some((r2, x2)) => Some((app(r1, r2), x2)), None => None },
            None => None }
    }),
{
    let sv2 = cons((n, rr), sv);
    let al = dalt(DRe::DRRInit, rst(n));
    let t1 = dsq(al, DRe::DEps);
    assert(desugar(Re::RClear, n).0 == dsq(DRe::DSaveRR(n), t1));
    assert(md(s, f, cons(DItem::DR(desugar(Re::RClear, n).0), dks), i, rr, sv)
        == md(s, (f - 1) as nat, cons(DItem::DR(DRe::DSaveRR(n)), cons(DItem::DR(t1), dks)), i, rr, sv));
    assert(md(s, (f - 1) as nat, cons(DItem::DR(DRe::DSaveRR(n)), cons(DItem::DR(t1), dks)), i, rr, sv)
        == md(s, (f - 2) as nat, cons(DItem::DR(t1), dks), i, rr, sv2));
    assert(md(s, (f - 2) as nat, cons(DItem::DR(t1), dks), i, rr, sv2)
        == md(s, (f - 3) as nat, cons(DItem::DR(al), cons(DItem::DR(DRe::DEps), dks)), i, rr, sv2));
}

pub proof fn rrinit_eq(s: L<nat>, f: nat, dks: L<DItem>, i: nat, x: nat, sv: L<(nat, nat)>)
    ensures md(s, f + 2, cons(DItem::DR(DRe::DRRInit), cons(DItem::DR(DRe::DEps), dks)), i, x, sv) == md(s, f, dks, i, len(s), sv),
            md(s, f, cons(DItem::DR(DRe::DRRInit), cons(DItem::DR(DRe::DEps), dks)), i, x, sv) is Some ==> f >= 2,
{
    assert(md(s, f + 2, cons(DItem::DR(DRe::DRRInit), cons(DItem::DR(DRe::DEps), dks)), i, x, sv)
        == md(s, f + 1, cons(DItem::DR(DRe::DEps), dks), i, len(s), sv));
    if f >= 1 {
        assert(md(s, f, cons(DItem::DR(DRe::DRRInit), cons(DItem::DR(DRe::DEps), dks)), i, x, sv)
            == md(s, (f - 1) as nat, cons(DItem::DR(DRe::DEps), dks), i, len(s), sv));
    }
}

pub proof fn rclear_intro(s: L<nat>, fe: nat, n: nat, dks: L<DItem>, i: nat, rr: nat, sv: L<(nat, nat)>, rs: L<DRes>, y: nat)
    requires md(s, fe, dks, i, len(s), cons((n, rr), sv)) == Some((rs, y)),
    ensures md(s, fe + 10, cons(DItem::DR(desugar(Re::RClear, n).0), dks), i, rr, sv) == Some((rs, rr)),
{
    let sv2 = cons((n, rr), sv);
    rclear_unfold(s, fe + 10, n, dks, i, rr, sv);
    rrinit_eq(s, fe + 4, dks, i, rr, sv2);
    md_mono(s, fe, fe + 4, dks, i, len(s), sv2);
    md_rst(s, fe + 6, n, cons(DItem::DR(DRe::DEps), dks), i, y, sv2, rr);
    app_nil(rs);
}

pub proof fn tail_unfold(s: L<nat>, f: nat, n: nat, n3: nat, dks: L<DItem>, i: nat, rr: nat, sv: L<(nat, nat)>)
    requires f >= 4,
    ensures ({
        let sv3 = cons((n3, rr), sv);
        let k2 = cons(DItem::DR(DRe::DEps), dks);
        md(s, f, cons(DItem::DR(dsq(tail(n, n3), DRe::DEps)), dks), i, rr, sv) ==
        match md(s, (f - 4) as nat, cons(DItem::DR(DRe::DUpdRRFromStack(n)), k2), i, rr, sv3) {
            Some((r1, x1)) => match md(s, (f - 4) as nat, cons(DItem::DR(rst(n3)), k2), i, x1, sv3) {
                Some((r2, x2)) => Some((app(r1, r2), x2)), None => None },
            None => None }
    }),
{
    let sv3 = cons((n3, rr), sv);
    let k2 = cons(DItem::DR(DRe::DEps), dks);
    let al = dalt(DRe::DUpdRRFromStack(n), rst(n3));
    assert(md(s, f, cons(DItem::DR(dsq(tail(n, n3), DRe::DEps)), dks), i, rr, sv)
        == md(s, (f - 1) as nat, cons(DItem::DR(tail(n, n3)), k2), i, rr, sv));
    assert(md(s, (f - 1) as nat, cons(DItem::DR(tail(n, n3)), k2), i, rr, sv)
        == md(s, (f - 2) as nat, cons(DItem::DR(DRe::DSaveRR(n3)), cons(DItem::DR(al), k2)), i, rr, sv));
    assert(md(s, (f - 2) as nat, cons(DItem::DR(DRe::DSaveRR(n3)), cons(DItem::DR(al), k2)), i, rr, sv)
        == md(s, (f - 3) as nat, cons(DItem::DR(al), k2), i, rr, sv3));
}

pub proof fn upd_eps_eq(s: L<nat>, f: nat, n: nat, dks: L<DItem>, i: nat, x: nat, sv: L<(nat, nat)>, y: nat)
    requires lookup(n, sv) == Some(y),
    ensures md(s, f + 2, cons(DItem::DR(DRe::DUpdRRFromStack(n)), cons(DItem::DR(DRe::DEps), dks)), i, x, sv) == md(s, f, dks, i, y, sv),
            md(s, f, cons(DItem::DR(DRe::DUpdRRFromStack(n)), cons(DItem::DR(DRe::DEps), dks)), i, x, sv) is Some ==> f >= 2,
{
    assert(md(s, f + 2, cons(DItem::DR(DRe::DUpdRRFromStack(n)), cons(DItem::DR(DRe::DEps), dks)), i, x, sv)
        == md(s, f + 1, cons(DItem::DR(DRe::DEps), dks), i, y, sv));
    if f >= 1 {
        assert(md(s, f, cons(DItem::DR(DRe::DUpdRRFromStack(n)), cons(DItem::DR(DRe::DEps), dks)), i, x, sv)
            == md(s, (f - 1) as nat, cons(DItem::DR(DRe::DEps), dks), i, y, sv));
    }
}

pub proof fn tail_intro(s: L<nat>, fe: nat, n: nat, n3: nat, dks: L<DItem>, i: nat, rr: nat, sv: L<(nat, nat)>, k: nat, rs: L<DRes>, y: nat)
    requires lookup(n, sv) == Some(k), n3 != n, md(s, fe, dks, i, k, cons((n3, rr), sv)) == Some((rs, y)),
    ensures md(s, fe + 10, cons(DItem::DR(dsq(tail(n, n3), DRe::DEps)), dks), i, rr, sv) == Some((rs, rr)),
{
    let sv3 = cons((n3, rr), sv);
    tail_unfold(s, fe + 10, n, n3, dks, i, rr, sv);
    assert(lookup(n, sv3) == Some(k));
    upd_eps_eq(s, fe + 4, n, dks, i, rr, sv3, k);
    md_mono(s, fe, fe + 4, dks, i, k, sv3);
    md_rst(s, fe + 6, n3, cons(DItem::DR(DRe::DEps), dks), i, y, sv3, rr);
    app_nil(rs);
}

// ---------------------------------------------------------------- //
// (g), direction (2a)

// The simple path, once the scan's facts and the per-end results of the
// continuation are known (AbsRep with step DAnyO, AbsExp a (Star (Chr c))
// with step DChr c): md on the simple tree gives the per-end results,
// concatenated, and ends with the starting register.
pub proof fn simple_finish(s: L<nat>, n: nat, a: Re, st: DRe, dks: L<DItem>, i: nat, rr: nat, sv: L<(nat, nat)>,
                           top: nat, bt: bool, g: nat, fb: nat, kd: L<Item>, cd: nat, fm: nat) -> (res: (nat, L<DRes>))
    requires
        core(a), is_step(st), i <= top,
        forall|p: nat| i <= p < top ==> #[trigger] mb(s, g, cons(Item::R(a), L::Nil), p, rr) == Some(false) && stp(s, st, p, rr),
        mb(s, fb, cons(Item::R(a), L::Nil), top, rr) == Some(bt),
        !stp(s, st, top, xtop(bt, top, rr)),
        forall|e: nat| i <= e <= top ==> {
            &&& #[trigger] dterm(s, dks, e, rr, cons((n, rr), sv))
            &&& (md(s, dfuel(s, dks, e, rr, cons((n, rr), sv)), dks, e, rr, cons((n, rr), sv))->0).1 == rr
            &&& ends((md(s, dfuel(s, dks, e, rr, cons((n, rr), sv)), dks, e, rr, cons((n, rr), sv))->0).0) == m(s, g, fm, kd, e, cd)->0
        },
    ensures md(s, res.0, cons(DItem::DR(simple_tree(n, a, st)), dks), i, rr, sv) == Some((res.1, rr)),
            ends(res.1) == mcat(s, g, fm, kd, cd, downs((top - i) as nat, i)),
{
    let sv2 = cons((n, rr), sv);
    let d = (top - i) as nat;
    let fd = dmax(s, dks, rr, sv2, d, i);
    dmax_ok(s, dks, rr, sv2, d, i);
    let fu = fd + 3;
    let uu = ur(n, dks);
    let xt = xtop(bt, top, rr);
    assert(lookup(n, sv2) == Some(rr));
    assert forall|e: nat| i <= e <= top implies {
        &&& #[trigger] md(s, fu, uu, e, reg(top, xtop(bt, top, rr), hh(Some(rr), xtop(bt, top, rr)), e), sv2) is Some
        &&& (md(s, fu, uu, e, reg(top, xtop(bt, top, rr), hh(Some(rr), xtop(bt, top, rr)), e), sv2)->0).1 == hh(Some(rr), xtop(bt, top, rr))
        &&& ends((md(s, fu, uu, e, reg(top, xtop(bt, top, rr), hh(Some(rr), xtop(bt, top, rr)), e), sv2)->0).0) == m(s, g, fm, kd, e, cd)->0
    } by {
        assert(dterm(s, dks, e, rr, sv2));
        md_ur(s, fd, n, dks, e, reg(top, xt, rr, e), sv2, rr);
        assert(md(s, fd, dks, e, rr, sv2) == md(s, dfuel(s, dks, e, rr, sv2), dks, e, rr, sv2));
    }
    let fs = scan_a(s, n + 1, a, st, uu, Some(rr), sv2, rr, d, i, top, bt, g, fb, fu);
    let rs = dcat(s, fu, uu, sv2, top, xt, rr, downs(d, i));
    simple_intro(s, fs, n, a, st, dks, i, rr, sv, rs);
    ends_dcat(s, fu, uu, sv2, top, xt, rr, g, fm, kd, cd, d, i);
    (fs + 8, rs)
}

pub proof fn downs_hd(d: nat, q: nat)
    ensures downs(d, q) is Cons, downs(d, q)->0 == q + d,
{ }

// The general path (AbsExp a e with e not x*, the stopper), once the
// continuation rest is known to give rs at the cut c with register c.
pub proof fn gen_finish(s: L<nat>, n: nat, a: Re, rest: DRe, dks: L<DItem>, i: nat, rr: nat, sv: L<(nat, nat)>,
                        c: nat, bt: bool, g: nat, fb: nat, fk: nat, rs: L<DRes>, len_s: nat) -> (f: nat)
    requires
        core(a), i <= c, c <= rr, rr <= len_s, len_s == len(s),
        forall|p: nat| i <= p < c ==> #[trigger] mb(s, g, cons(Item::R(a), L::Nil), p, rr) == Some(false),
        mb(s, fb, cons(Item::R(a), L::Nil), c, rr) == Some(bt), xtop(bt, c, rr) == c,
        md(s, fk, cons(DItem::DR(rest), dks), i, c, sv1(n, i, rr, sv)) == Some((rs, c)),
    ensures md(s, f, cons(DItem::DR(gen_head(n, a, rest)), dks), i, rr, sv) == Some((rs, rr)),
{
    let s1 = sv1(n, i, rr, sv);
    let d = (c - i) as nat;
    assert forall|p: nat| i <= p < c implies #[trigger] mb(s, g, cons(Item::R(a), L::Nil), p, rr) == Some(false) && stp(s, DRe::DAnyO, p, rr) by {
        at_some(s, p, rr);
    }
    assert forall|e: nat| i <= e <= c implies {
        &&& #[trigger] md(s, 1, L::<DItem>::Nil, e, reg(c, xtop(bt, c, rr), hh(None, xtop(bt, c, rr)), e), s1) is Some
        &&& (md(s, 1, L::<DItem>::Nil, e, reg(c, xtop(bt, c, rr), hh(None, xtop(bt, c, rr)), e), s1)->0).1 == hh(None, xtop(bt, c, rr))
    } by { }
    let fs = scan_a(s, n + 2, a, DRe::DAnyO, L::Nil, None, s1, rr, d, i, c, bt, g, fb, 1);
    downs_hd(d, i);
    let dl = downs(d, i);
    let tl = dcat(s, 1, L::Nil, s1, c, c, c, *(dl->1));
    assert(md(s, 1, L::<DItem>::Nil, c, c, s1) == Some((cons((c, c, s1), L::<DRes>::Nil), c)));
    assert(dcat(s, 1, L::Nil, s1, c, c, c, dl) == app(cons((c, c, s1), L::<DRes>::Nil), tl));
    assert(app(cons((c, c, s1), L::<DRes>::Nil), tl) == cons((c, c, s1), app(L::<DRes>::Nil, tl)));
    gen_intro(s, fs, fk, n, a, rest, dks, i, rr, sv, tl, c, rs, c);
    fs + fk + 12
}

pub proof fn sim_a(s: L<nat>, g: nat, f: nat, ks: L<Item>, i: nat, rr: nat, l: L<nat>, dks: L<DItem>, ns: L<(nat, nat)>, sv: L<(nat, nat)>)
    -> (res: (nat, L<DRes>))
    requires m(s, g, f, ks, i, rr) == Some(l), rel(s, sv, rr, ks, ns, dks), i <= rr, rr <= len(s),
    ensures md(s, res.0, dks, i, rr, sv) == Some((res.1, rr)), ends(res.1) == l,
    decreases f, 1nat
{
    let f1 = (f - 1) as nat;
    match ks {
        L::Nil => { reveal_with_fuel(ends, 2); (1, cons((i, rr, sv), L::Nil)) },
        L::Cons(it, kt) => {
            let k2 = *kt;
            let n = ns->0;
            let n2 = *(ns->1);
            let d2 = *(dks->1);
            match it {
                Item::R(x) => {
                    match x {
                        Re::Eps => { let (fe, rs) = sim_a(s, g, f1, k2, i, rr, l, d2, n2, sv); (fe + 1, rs) },
                        Re::Chr(c) => if at_(s, i, rr) == Some(c) {
                            let (fe, rs) = sim_a(s, g, f1, k2, i + 1, rr, l, d2, n2, sv); (fe + 1, rs)
                        } else { (1, L::Nil) },
                        Re::Any => if at_(s, i, rr) is Some && at_(s, i, rr) != Some(10nat) {
                            let (fe, rs) = sim_a(s, g, f1, k2, i + 1, rr, l, d2, n2, sv); (fe + 1, rs)
                        } else { (1, L::Nil) },
                        Re::AnyO => if at_(s, i, rr) is Some {
                            let (fe, rs) = sim_a(s, g, f1, k2, i + 1, rr, l, d2, n2, sv); (fe + 1, rs)
                        } else { (1, L::Nil) },
                        Re::Seq(a, b) => {
                            let na = desugar(*a, n.0);
                            let kk2 = cons(Item::R(*a), cons(Item::R(*b), k2));
                            let nn2 = cons((n.0, 0nat), cons((na.1, 0nat), n2));
                            let dd2 = cons(DItem::DR(na.0), cons(DItem::DR(desugar(*b, na.1).0), d2));
                            assert(rel(s, sv, rr, kk2, nn2, dd2)) by { reveal_with_fuel(rel, 3); reveal_with_fuel(noset, 2); }
                            let (fe, rs) = sim_a(s, g, f1, kk2, i, rr, l, dd2, nn2, sv);
                            (fe + 1, rs)
                        },
                        Re::Alt(a, b) => {
                            let na = desugar(*a, n.0);
                            let ka = cons(Item::R(*a), k2);
                            let kb = cons(Item::R(*b), k2);
                            let da = cons(DItem::DR(na.0), d2);
                            let db = cons(DItem::DR(desugar(*b, na.1).0), d2);
                            let la = m(s, g, f1, ka, i, rr)->0;
                            let lb = m(s, g, f1, kb, i, rr)->0;
                            let (fa, ra) = sim_a(s, g, f1, ka, i, rr, la, da, cons((n.0, 0nat), n2), sv);
                            let (fb, rb) = sim_a(s, g, f1, kb, i, rr, lb, db, cons((na.1, 0nat), n2), sv);
                            md_mono(s, fa, fa + fb, da, i, rr, sv);
                            md_mono(s, fb, fa + fb, db, i, rr, sv);
                            ends_app(ra, rb);
                            (fa + fb + 1, app(ra, rb))
                        },
                        Re::Star(a) => {
                            let na = desugar(*a, n.0);
                            let ka = cons(Item::R(*a), cons(Item::Chk(i, *a), k2));
                            let da = cons(DItem::DR(na.0), cons(DItem::DChk(i, na.0), d2));
                            let na2 = cons((n.0, 0nat), cons((n.0, 0nat), n2));
                            assert(rel(s, sv, rr, ka, na2, da)) by { reveal_with_fuel(rel, 3); reveal_with_fuel(noset, 2); }
                            let la = m(s, g, f1, ka, i, rr)->0;
                            let lb = m(s, g, f1, k2, i, rr)->0;
                            let (fa, ra) = sim_a(s, g, f1, ka, i, rr, la, da, na2, sv);
                            let (fb, rb) = sim_a(s, g, f1, k2, i, rr, lb, d2, n2, sv);
                            md_mono(s, fa, fa + fb, da, i, rr, sv);
                            md_mono(s, fb, fa + fb, d2, i, rr, sv);
                            ends_app(ra, rb);
                            (fa + fb + 1, app(ra, rb))
                        },
                        Re::AbsRep(a) => sim_a_rep(s, g, f, *a, k2, i, rr, l, d2, n.0, n2, sv),
                        Re::AbsExp(a, e) => match simple_step(*e) {
                            Some(ch) => sim_a_xs(s, g, f, *a, ch, k2, i, rr, l, d2, n.0, n2, sv),
                            None => sim_a_gen(s, g, f, *a, *e, k2, i, rr, l, d2, n.0, n2, sv),
                        },
                        Re::Stopper(a) => sim_a_stop(s, g, f, *a, k2, i, rr, l, d2, n.0, n2, sv),
                        Re::RClear => {
                            rel_free(s, sv, rr, k2, n2, d2, cons((n.0, rr), sv), len(s));
                            let (fe, rs) = sim_a(s, g, f1, k2, i, len(s), l, d2, n2, cons((n.0, rr), sv));
                            rclear_intro(s, fe, n.0, d2, i, rr, sv, rs, len(s));
                            (fe + 10, rs)
                        },
                    }
                },
                Item::Chk(i0, x) => {
                    if i == i0 {
                        let (fe, rs) = sim_a(s, g, f1, k2, i, rr, l, d2, n2, sv); (fe + 1, rs)
                    } else {
                        let ka = cons(Item::R(Re::Star(Box::new(x))), k2);
                        let da = cons(DItem::DR(dstar(desugar(x, n.0).0)), d2);
                        assert(desugar(Re::Star(Box::new(x)), n.0).0 == dstar(desugar(x, n.0).0));
                        let (fe, rs) = sim_a(s, g, f1, ka, i, rr, l, da, ns, sv); (fe + 1, rs)
                    }
                },
                Item::SetRR(k) => {
                    rel_free(s, sv, rr, k2, n2, d2, cons((n.1, rr), sv), k);
                    let (fe, rs) = sim_a(s, g, f1, k2, i, k, l, d2, n2, cons((n.1, rr), sv));
                    tail_intro(s, fe, n.0, n.1, d2, i, rr, sv, k, rs, k);
                    (fe + 10, rs)
                },
                Item::Ends(_) => { (0, L::Nil) },
            }
        }
    }
}

// AbsRep a: the simple path with step \O.
pub proof fn sim_a_rep(s: L<nat>, g: nat, f: nat, a: Re, k2: L<Item>, i: nat, rr: nat, l: L<nat>, d2: L<DItem>, n: nat,
                       n2: L<(nat, nat)>, sv: L<(nat, nat)>) -> (res: (nat, L<DRes>))
    requires core(a), noset(k2), rel(s, sv, rr, k2, n2, d2), i <= rr, rr <= len(s),
             m(s, g, f, cons(Item::R(Re::AbsRep(Box::new(a))), k2), i, rr) == Some(l),
    ensures md(s, res.0, cons(DItem::DR(simple_tree(n, a, DRe::DAnyO)), d2), i, rr, sv) == Some((res.1, rr)), ends(res.1) == l,
    decreases f, 0nat
{
    let f1 = (f - 1) as nat;
    let f2 = (f - 2) as nat;
    let c = cut(a, s, g, i, rr)->0;
    let (fb, bt) = cut_top(s, g, a, i, rr, c);
    let es = downs((c - i) as nat, i);
    m_ends_a(s, g, f1, es, k2, i, rr);
    let sv2 = cons((n, rr), sv);
    rel_free(s, sv, rr, k2, n2, d2, sv2, rr);
    assert forall|e: nat| i <= e <= c implies {
        &&& #[trigger] dterm(s, d2, e, rr, sv2)
        &&& (md(s, dfuel(s, d2, e, rr, sv2), d2, e, rr, sv2)->0).1 == rr
        &&& ends((md(s, dfuel(s, d2, e, rr, sv2), d2, e, rr, sv2)->0).0) == m(s, g, f2, k2, e, rr)->0
    } by {
        mem_downs((c - i) as nat, i, e);
        let (fe, rse) = sim_a(s, g, f2, k2, e, rr, m(s, g, f2, k2, e, rr)->0, d2, n2, sv2);
        assert(md(s, fe, d2, e, rr, sv2) is Some);
        md_det(s, fe, dfuel(s, d2, e, rr, sv2), d2, e, rr, sv2);
    }
    assert forall|p: nat| i <= p < c implies #[trigger] mb(s, g, cons(Item::R(a), L::Nil), p, rr) == Some(false) && stp(s, DRe::DAnyO, p, rr) by {
        at_some(s, p, rr);
    }
    simple_finish(s, n, a, DRe::DAnyO, d2, i, rr, sv, c, bt, g, fb, k2, rr, f2)
}

// AbsExp a (Star (Chr ch)): the simple path with step ch.
pub proof fn sim_a_xs(s: L<nat>, g: nat, f: nat, a: Re, ch: nat, k2: L<Item>, i: nat, rr: nat, l: L<nat>, d2: L<DItem>, n: nat,
                      n2: L<(nat, nat)>, sv: L<(nat, nat)>) -> (res: (nat, L<DRes>))
    requires core(a), noset(k2), rel(s, sv, rr, k2, n2, d2), i <= rr, rr <= len(s),
             m(s, g, f, cons(Item::R(Re::AbsExp(Box::new(a), Box::new(Re::Star(Box::new(Re::Chr(ch)))))), k2), i, rr) == Some(l),
    ensures md(s, res.0, cons(DItem::DR(simple_tree(n, a, DRe::DChr(ch))), d2), i, rr, sv) == Some((res.1, rr)), ends(res.1) == l,
    decreases f, 0nat
{
    let f1 = (f - 1) as nat;
    let f2 = (f - 2) as nat;
    let c = cut(a, s, g, i, rr)->0;
    let (fb0, bt0) = cut_top(s, g, a, i, rr, c);
    let kd = cons(Item::SetRR(rr), k2);
    let top = mstar_a(s, ch, g, f1, kd, i, c);
    if top > c { assert(at_(s, c, c) == Some(ch)); }
    let sv2 = cons((n, rr), sv);
    rel_free(s, sv, rr, k2, n2, d2, sv2, rr);
    assert forall|e: nat| i <= e <= top implies {
        &&& #[trigger] dterm(s, d2, e, rr, sv2)
        &&& (md(s, dfuel(s, d2, e, rr, sv2), d2, e, rr, sv2)->0).1 == rr
        &&& ends((md(s, dfuel(s, d2, e, rr, sv2), d2, e, rr, sv2)->0).0) == m(s, g, f1, kd, e, c)->0
    } by {
        assert(m(s, g, f1, kd, e, c) is Some);
        assert(m(s, g, f1, kd, e, c) == m(s, g, f2, k2, e, rr));
        let (fe, rse) = sim_a(s, g, f2, k2, e, rr, m(s, g, f2, k2, e, rr)->0, d2, n2, sv2);
        assert(md(s, fe, d2, e, rr, sv2) is Some);
        md_det(s, fe, dfuel(s, d2, e, rr, sv2), d2, e, rr, sv2);
    }
    assert forall|p: nat| i <= p < top implies #[trigger] mb(s, g, cons(Item::R(a), L::Nil), p, rr) == Some(false) && stp(s, DRe::DChr(ch), p, rr) by {
        assert(at_(s, p, c) == Some(ch));
    }
    if top == c {
        simple_finish(s, n, a, DRe::DChr(ch), d2, i, rr, sv, top, bt0, g, fb0, kd, c, f1)
    } else {
        assert(mb(s, g, cons(Item::R(a), L::Nil), top, rr) == Some(false));
        simple_finish(s, n, a, DRe::DChr(ch), d2, i, rr, sv, top, false, g, g, kd, c, f1)
    }
}

// AbsExp a e, e not x*: the general path.
pub proof fn sim_a_gen(s: L<nat>, g: nat, f: nat, a: Re, e: Re, k2: L<Item>, i: nat, rr: nat, l: L<nat>, d2: L<DItem>, n: nat,
                       n2: L<(nat, nat)>, sv: L<(nat, nat)>) -> (res: (nat, L<DRes>))
    requires core(a), core(e), simple_step(e) is None, noset(k2), rel(s, sv, rr, k2, n2, d2), i <= rr, rr <= len(s),
             m(s, g, f, cons(Item::R(Re::AbsExp(Box::new(a), Box::new(e))), k2), i, rr) == Some(l),
    ensures md(s, res.0, cons(DItem::DR(desugar(Re::AbsExp(Box::new(a), Box::new(e)), n).0), d2), i, rr, sv) == Some((res.1, rr)),
            ends(res.1) == l,
    decreases f, 0nat
{
    let f1 = (f - 1) as nat;
    let c = cut(a, s, g, i, rr)->0;
    let (fb0, bt0) = cut_top(s, g, a, i, rr, c);
    let s1 = sv1(n, i, rr, sv);
    lookup_sv1(n, i, rr, sv);
    core_desugar(e, 0);
    core_in_scope(e);
    let tl = dsq(tail(n, n + 3), DRe::DEps);
    let kk2 = cons(Item::R(e), cons(Item::SetRR(rr), k2));
    let nn2 = cons((0nat, 0nat), cons((n, n + 3), n2));
    let dd2 = cons(DItem::DR(emb(e)), cons(DItem::DR(tl), d2));
    rel_free(s, sv, rr, k2, n2, d2, s1, c);
    assert(rel(s, s1, c, kk2, nn2, dd2)) by { reveal_with_fuel(rel, 3); }
    let (fe, rs) = sim_a(s, g, f1, kk2, i, c, l, dd2, nn2, s1);
    let rest = dsq(emb(e), tl);
    assert(md(s, fe + 1, cons(DItem::DR(rest), d2), i, c, s1) == md(s, fe, dd2, i, c, s1));
    let fg = gen_finish(s, n, a, rest, d2, i, rr, sv, c, bt0, g, fb0, fe + 1, rs, len(s));
    (fg, rs)
}

// Stopper a: the general path without the tail.
pub proof fn sim_a_stop(s: L<nat>, g: nat, f: nat, a: Re, k2: L<Item>, i: nat, rr: nat, l: L<nat>, d2: L<DItem>, n: nat,
                        n2: L<(nat, nat)>, sv: L<(nat, nat)>) -> (res: (nat, L<DRes>))
    requires core(a), noset(k2), rel(s, sv, rr, k2, n2, d2), i <= rr, rr <= len(s),
             m(s, g, f, cons(Item::R(Re::Stopper(Box::new(a))), k2), i, rr) == Some(l),
    ensures md(s, res.0, cons(DItem::DR(gen_head(n, a, DRe::DEps)), d2), i, rr, sv) == Some((res.1, rr)), ends(res.1) == l,
    decreases f, 0nat
{
    let f1 = (f - 1) as nat;
    let c = cut(a, s, g, i, rr)->0;
    let (fb0, bt0) = cut_top(s, g, a, i, rr, c);
    let s1 = sv1(n, i, rr, sv);
    rel_free(s, sv, rr, k2, n2, d2, s1, c);
    let (fe, rs) = sim_a(s, g, f1, k2, i, c, l, d2, n2, s1);
    assert(md(s, fe + 1, cons(DItem::DR(DRe::DEps), d2), i, c, s1) == md(s, fe, d2, i, c, s1));
    let fg = gen_finish(s, n, a, DRe::DEps, d2, i, rr, sv, c, bt0, g, fb0, fe + 1, rs, len(s));
    (fg, rs)
}

// ---------------------------------------------------------------- //
// Direction (2b): inversion lemmas

pub proof fn simple_inv(s: L<nat>, ff: nat, n: nat, a: Re, st: DRe, dks: L<DItem>, i: nat, rr: nat, sv: L<(nat, nat)>)
    requires md(s, ff, cons(DItem::DR(simple_tree(n, a, st)), dks), i, rr, sv) is Some,
    ensures ff >= 4,
            md(s, (ff - 4) as nat, cons(DItem::DR(dstar(body(n + 1, a, st))), ur(n, dks)), i, rr, cons((n, rr), sv)) is Some,
            (md(s, ff, cons(DItem::DR(simple_tree(n, a, st)), dks), i, rr, sv)->0).0
                == (md(s, (ff - 4) as nat, cons(DItem::DR(dstar(body(n + 1, a, st))), ur(n, dks)), i, rr, cons((n, rr), sv))->0).0,
            (md(s, ff, cons(DItem::DR(simple_tree(n, a, st)), dks), i, rr, sv)->0).1 == rr,
{
    let sv2 = cons((n, rr), sv);
    if ff < 4 {
        let eng = engine(n, n + 1, emb(a), st, false);
        let t1 = dsq(eng, dsq(DRe::DUpdRRFromStack(n), DRe::DEps));
        assert(md(s, ff, cons(DItem::DR(simple_tree(n, a, st)), dks), i, rr, sv)
            == md(s, (ff - 1) as nat, cons(DItem::DR(DRe::DSaveRR(n)), cons(DItem::DR(t1), dks)), i, rr, sv));
        if ff >= 2 {
            assert(md(s, (ff - 1) as nat, cons(DItem::DR(DRe::DSaveRR(n)), cons(DItem::DR(t1), dks)), i, rr, sv)
                == md(s, (ff - 2) as nat, cons(DItem::DR(t1), dks), i, rr, sv2));
            if ff >= 3 {
                assert(md(s, (ff - 2) as nat, cons(DItem::DR(t1), dks), i, rr, sv2)
                    == md(s, (ff - 3) as nat, cons(DItem::DR(eng), ur(n, dks)), i, rr, sv2));
            }
        }
        assert(false);
    }
    simple_unfold(s, ff, n, a, st, dks, i, rr, sv);
    let (r1, x1) = md(s, (ff - 4) as nat, cons(DItem::DR(dstar(body(n + 1, a, st))), ur(n, dks)), i, rr, sv2)->0;
    md_rst(s, (ff - 4) as nat, n, ur(n, dks), i, x1, sv2, rr);
    app_nil(r1);
}

pub proof fn gen_inv(s: L<nat>, ff: nat, n: nat, a: Re, rest: DRe, dks: L<DItem>, i: nat, rr: nat, sv: L<(nat, nat)>)
    requires md(s, ff, cons(DItem::DR(gen_head(n, a, rest)), dks), i, rr, sv) is Some,
    ensures ({
        let s1 = sv1(n, i, rr, sv);
        let k2 = cons(DItem::DR(dsq(DRe::DUpdSFromStack(n + 1), rest)), dks);
        let ra = (md(s, (ff - 7) as nat, cons(DItem::DR(dstar(body(n + 2, a, DRe::DAnyO))), L::Nil), i, rr, s1)->0).0;
        let rs = (md(s, ff, cons(DItem::DR(gen_head(n, a, rest)), dks), i, rr, sv)->0).0;
        &&& ff >= 7
        &&& (md(s, ff, cons(DItem::DR(gen_head(n, a, rest)), dks), i, rr, sv)->0).1 == rr
        &&& md(s, (ff - 7) as nat, cons(DItem::DR(dstar(body(n + 2, a, DRe::DAnyO))), L::Nil), i, rr, s1) is Some
        &&& match ra {
            L::Cons(r, _) => md(s, (ff - 7) as nat, k2, r.0, r.1, r.2) is Some && rs == (md(s, (ff - 7) as nat, k2, r.0, r.1, r.2)->0).0,
            L::Nil => rs == L::<DRes>::Nil,
        }
    }),
{
    let s1 = sv1(n, i, rr, sv);
    let sv2 = cons((n, rr), sv);
    let k2 = cons(DItem::DR(dsq(DRe::DUpdSFromStack(n + 1), rest)), dks);
    if ff < 7 {
        let eng = engine(n, n + 2, emb(a), DRe::DAnyO, true);
        let t3 = dsq(eng, dsq(DRe::DUpdSFromStack(n + 1), rest));
        let t2 = dsq(DRe::DSaveS(n + 1), t3);
        assert(md(s, ff, cons(DItem::DR(gen_head(n, a, rest)), dks), i, rr, sv)
            == md(s, (ff - 1) as nat, cons(DItem::DR(DRe::DSaveRR(n)), cons(DItem::DR(t2), dks)), i, rr, sv));
        if ff >= 2 {
            assert(md(s, (ff - 1) as nat, cons(DItem::DR(DRe::DSaveRR(n)), cons(DItem::DR(t2), dks)), i, rr, sv)
                == md(s, (ff - 2) as nat, cons(DItem::DR(t2), dks), i, rr, sv2));
            if ff >= 3 {
                assert(md(s, (ff - 2) as nat, cons(DItem::DR(t2), dks), i, rr, sv2)
                    == md(s, (ff - 3) as nat, cons(DItem::DR(DRe::DSaveS(n + 1)), cons(DItem::DR(t3), dks)), i, rr, sv2));
                if ff >= 4 {
                    assert(md(s, (ff - 3) as nat, cons(DItem::DR(DRe::DSaveS(n + 1)), cons(DItem::DR(t3), dks)), i, rr, sv2)
                        == md(s, (ff - 4) as nat, cons(DItem::DR(t3), dks), i, rr, s1));
                    if ff >= 5 {
                        assert(md(s, (ff - 4) as nat, cons(DItem::DR(t3), dks), i, rr, s1)
                            == md(s, (ff - 5) as nat, cons(DItem::DR(eng), k2), i, rr, s1));
                        if ff == 6 {
                            gen_unfold(s, ff, n, a, rest, dks, i, rr, sv);
                        }
                    }
                }
            }
        }
        assert(false);
    }
    gen_unfold(s, ff, n, a, rest, dks, i, rr, sv);
    lookup_sv1(n, i, rr, sv);
    let x1 = (md(s, (ff - 6) as nat, cons(DItem::DR(DRe::DAtomic(Box::new(dstar(body(n + 2, a, DRe::DAnyO))))), k2), i, rr, s1)->0).1;
    let r1 = (md(s, (ff - 6) as nat, cons(DItem::DR(DRe::DAtomic(Box::new(dstar(body(n + 2, a, DRe::DAnyO))))), k2), i, rr, s1)->0).0;
    md_rst(s, (ff - 6) as nat, n, k2, i, x1, s1, rr);
    app_nil(r1);
}

pub proof fn rclear_inv(s: L<nat>, ff: nat, n: nat, dks: L<DItem>, i: nat, rr: nat, sv: L<(nat, nat)>)
    requires md(s, ff, cons(DItem::DR(desugar(Re::RClear, n).0), dks), i, rr, sv) is Some,
    ensures ff >= 6,
            (md(s, ff, cons(DItem::DR(desugar(Re::RClear, n).0), dks), i, rr, sv)->0).1 == rr,
            md(s, (ff - 6) as nat, dks, i, len(s), cons((n, rr), sv)) is Some,
            (md(s, ff, cons(DItem::DR(desugar(Re::RClear, n).0), dks), i, rr, sv)->0).0 == (md(s, (ff - 6) as nat, dks, i, len(s), cons((n, rr), sv))->0).0,
{
    let sv2 = cons((n, rr), sv);
    let k2 = cons(DItem::DR(DRe::DEps), dks);
    if ff < 4 {
        let al = dalt(DRe::DRRInit, rst(n));
        let t1 = dsq(al, DRe::DEps);
        assert(desugar(Re::RClear, n).0 == dsq(DRe::DSaveRR(n), t1));
        assert(md(s, ff, cons(DItem::DR(desugar(Re::RClear, n).0), dks), i, rr, sv)
            == md(s, (ff - 1) as nat, cons(DItem::DR(DRe::DSaveRR(n)), cons(DItem::DR(t1), dks)), i, rr, sv));
        if ff >= 2 {
            assert(md(s, (ff - 1) as nat, cons(DItem::DR(DRe::DSaveRR(n)), cons(DItem::DR(t1), dks)), i, rr, sv)
                == md(s, (ff - 2) as nat, cons(DItem::DR(t1), dks), i, rr, sv2));
            if ff >= 3 {
                assert(md(s, (ff - 2) as nat, cons(DItem::DR(t1), dks), i, rr, sv2)
                    == md(s, (ff - 3) as nat, cons(DItem::DR(al), k2), i, rr, sv2));
            }
        }
        assert(false);
    }
    rclear_unfold(s, ff, n, dks, i, rr, sv);
    rrinit_eq(s, (ff - 4) as nat, dks, i, rr, sv2);
    rrinit_eq(s, (ff - 6) as nat, dks, i, rr, sv2);
    let (r1, x1) = md(s, (ff - 4) as nat, cons(DItem::DR(DRe::DRRInit), k2), i, rr, sv2)->0;
    md_rst(s, (ff - 4) as nat, n, k2, i, x1, sv2, rr);
    app_nil(r1);
}

pub proof fn tail_inv(s: L<nat>, ff: nat, n: nat, n3: nat, dks: L<DItem>, i: nat, rr: nat, sv: L<(nat, nat)>, k: nat)
    requires lookup(n, sv) == Some(k), n3 != n, md(s, ff, cons(DItem::DR(dsq(tail(n, n3), DRe::DEps)), dks), i, rr, sv) is Some,
    ensures ff >= 6,
            (md(s, ff, cons(DItem::DR(dsq(tail(n, n3), DRe::DEps)), dks), i, rr, sv)->0).1 == rr,
            md(s, (ff - 6) as nat, dks, i, k, cons((n3, rr), sv)) is Some,
            (md(s, ff, cons(DItem::DR(dsq(tail(n, n3), DRe::DEps)), dks), i, rr, sv)->0).0 == (md(s, (ff - 6) as nat, dks, i, k, cons((n3, rr), sv))->0).0,
{
    let sv3 = cons((n3, rr), sv);
    let k2 = cons(DItem::DR(DRe::DEps), dks);
    assert(lookup(n, sv3) == Some(k));
    if ff < 4 {
        let al = dalt(DRe::DUpdRRFromStack(n), rst(n3));
        assert(md(s, ff, cons(DItem::DR(dsq(tail(n, n3), DRe::DEps)), dks), i, rr, sv)
            == md(s, (ff - 1) as nat, cons(DItem::DR(tail(n, n3)), k2), i, rr, sv));
        if ff >= 2 {
            assert(md(s, (ff - 1) as nat, cons(DItem::DR(tail(n, n3)), k2), i, rr, sv)
                == md(s, (ff - 2) as nat, cons(DItem::DR(DRe::DSaveRR(n3)), cons(DItem::DR(al), k2)), i, rr, sv));
            if ff >= 3 {
                assert(md(s, (ff - 2) as nat, cons(DItem::DR(DRe::DSaveRR(n3)), cons(DItem::DR(al), k2)), i, rr, sv)
                    == md(s, (ff - 3) as nat, cons(DItem::DR(al), k2), i, rr, sv3));
            }
        }
        assert(false);
    }
    tail_unfold(s, ff, n, n3, dks, i, rr, sv);
    upd_eps_eq(s, (ff - 4) as nat, n, dks, i, rr, sv3, k);
    upd_eps_eq(s, (ff - 6) as nat, n, dks, i, rr, sv3, k);
    let (r1, x1) = md(s, (ff - 4) as nat, cons(DItem::DR(DRe::DUpdRRFromStack(n)), k2), i, rr, sv3)->0;
    md_rst(s, (ff - 4) as nat, n3, k2, i, x1, sv3, rr);
    app_nil(r1);
}

// The cut seen from the desugared side (DAnyO step): the scan stops at
// the cut, and the register it leaves there is the cut.
pub proof fn cut_from_scan(s: L<nat>, g: nat, a: Re, i: nat, rr: nat, top: nat, bt: bool)
    requires i <= rr, rr <= len(s), i <= top,
             forall|p: nat| i <= p < top ==> #[trigger] mb(s, g, cons(Item::R(a), L::Nil), p, rr) == Some(false) && stp(s, DRe::DAnyO, p, rr),
             mb(s, g, cons(Item::R(a), L::Nil), top, rr) == Some(bt),
             !stp(s, DRe::DAnyO, top, xtop(bt, top, rr)),
    ensures cut(a, s, g, i, rr) == Some(top), xtop(bt, top, rr) == top, top <= rr,
{
    if top > i { assert(mb(s, g, cons(Item::R(a), L::Nil), (top - 1) as nat, rr) == Some(false)); }
    if !bt && top < rr { at_some(s, top, rr); }
    assert forall|p: nat| i <= p < top implies #[trigger] occ(a, s, g, p, rr) == Some(false) by {
        assert(mb(s, g, cons(Item::R(a), L::Nil), p, rr) == Some(false));
    }
    scan_intro(a, s, g, rr, (rr - i) as nat, i, top);
}

// The same for the simple path (DChr ch step): the scan may stop before
// the cut, at the first position that is not ch.
pub proof fn simple_top(s: L<nat>, g: nat, a: Re, i: nat, rr: nat, top: nat, bt: bool, c: nat, ch: nat)
    requires i <= rr, i <= top,
             forall|p: nat| i <= p < top ==> #[trigger] mb(s, g, cons(Item::R(a), L::Nil), p, rr) == Some(false) && stp(s, DRe::DChr(ch), p, rr),
             mb(s, g, cons(Item::R(a), L::Nil), top, rr) == Some(bt),
             !stp(s, DRe::DChr(ch), top, xtop(bt, top, rr)),
             cut(a, s, g, i, rr) == Some(c),
    ensures top <= c, c <= rr,
            forall|p: nat| i <= p < top ==> #[trigger] at_(s, p, c) == Some(ch),
            at_(s, top, c) != Some(ch),
{
    scan_spec(a, s, g, rr, (rr - i) as nat, i, c);
    if top > c {
        assert(mb(s, g, cons(Item::R(a), L::Nil), c, rr) == Some(false) && stp(s, DRe::DChr(ch), c, rr));
        assert(occ(a, s, g, c, rr) == Some(false));
    }
    assert forall|p: nat| i <= p < top implies #[trigger] at_(s, p, c) == Some(ch) by {
        assert(mb(s, g, cons(Item::R(a), L::Nil), p, rr) == Some(false) && stp(s, DRe::DChr(ch), p, rr));
    }
    if top < c {
        assert(occ(a, s, g, top, rr) == Some(false));
    }
}

// ---------------------------------------------------------------- //
// (g), direction (2b)

pub proof fn sim_b(s: L<nat>, ff: nat, dks: L<DItem>, i: nat, rr: nat, sv: L<(nat, nat)>, rs: L<DRes>, x: nat,
                   ks: L<Item>, ns: L<(nat, nat)>) -> (gf: (nat, nat))
    requires md(s, ff, dks, i, rr, sv) == Some((rs, x)), rel(s, sv, rr, ks, ns, dks), i <= rr, rr <= len(s),
    ensures x == rr, m(s, gf.0, gf.1, ks, i, rr) == Some(ends(rs)),
    decreases ff, 1nat
{
    let f1 = (ff - 1) as nat;
    match ks {
        L::Nil => { reveal_with_fuel(ends, 2); (0, 1) },
        L::Cons(it, kt) => {
            let k2 = *kt;
            let n = ns->0;
            let n2 = *(ns->1);
            let d2 = *(dks->1);
            match it {
                Item::R(x0) => {
                    match x0 {
                        Re::Eps => { let (g, f) = sim_b(s, f1, d2, i, rr, sv, rs, x, k2, n2); (g, f + 1) },
                        Re::Chr(c) => if at_(s, i, rr) == Some(c) {
                            let (g, f) = sim_b(s, f1, d2, i + 1, rr, sv, rs, x, k2, n2); (g, f + 1)
                        } else { (0, 1) },
                        Re::Any => if at_(s, i, rr) is Some && at_(s, i, rr) != Some(10nat) {
                            let (g, f) = sim_b(s, f1, d2, i + 1, rr, sv, rs, x, k2, n2); (g, f + 1)
                        } else { (0, 1) },
                        Re::AnyO => if at_(s, i, rr) is Some {
                            let (g, f) = sim_b(s, f1, d2, i + 1, rr, sv, rs, x, k2, n2); (g, f + 1)
                        } else { (0, 1) },
                        Re::Seq(a, b) => {
                            let na = desugar(*a, n.0);
                            let kk2 = cons(Item::R(*a), cons(Item::R(*b), k2));
                            let nn2 = cons((n.0, 0nat), cons((na.1, 0nat), n2));
                            let dd2 = cons(DItem::DR(na.0), cons(DItem::DR(desugar(*b, na.1).0), d2));
                            assert(rel(s, sv, rr, kk2, nn2, dd2)) by { reveal_with_fuel(rel, 3); reveal_with_fuel(noset, 2); }
                            let (g, f) = sim_b(s, f1, dd2, i, rr, sv, rs, x, kk2, nn2);
                            (g, f + 1)
                        },
                        Re::Alt(a, b) => sim_b_alt(s, ff, *a, *b, k2, i, rr, rs, x, d2, n.0, n2, sv),
                        Re::Star(a) => sim_b_star(s, ff, *a, k2, i, rr, rs, x, d2, n.0, n2, sv),
                        Re::AbsRep(a) => sim_b_rep(s, ff, *a, k2, i, rr, rs, x, d2, n.0, n2, sv),
                        Re::AbsExp(a, e) => match simple_step(*e) {
                            Some(ch) => sim_b_xs(s, ff, *a, ch, k2, i, rr, rs, x, d2, n.0, n2, sv),
                            None => {
                                core_desugar(*e, 0);
                                sim_b_gen(s, ff, *a, *e, k2, i, rr, rs, x, d2, n.0, n2, sv)
                            },
                        },
                        Re::Stopper(a) => sim_b_stop(s, ff, *a, k2, i, rr, rs, x, d2, n.0, n2, sv),
                        Re::RClear => {
                            rclear_inv(s, ff, n.0, d2, i, rr, sv);
                            let sv2 = cons((n.0, rr), sv);
                            rel_free(s, sv, rr, k2, n2, d2, sv2, len(s));
                            let y = (md(s, (ff - 6) as nat, d2, i, len(s), sv2)->0).1;
                            let (g, f) = sim_b(s, (ff - 6) as nat, d2, i, len(s), sv2, rs, y, k2, n2);
                            (g, f + 1)
                        },
                    }
                },
                Item::Chk(i0, x0) => {
                    if i == i0 {
                        let (g, f) = sim_b(s, f1, d2, i, rr, sv, rs, x, k2, n2); (g, f + 1)
                    } else {
                        let ka = cons(Item::R(Re::Star(Box::new(x0))), k2);
                        let da = cons(DItem::DR(dstar(desugar(x0, n.0).0)), d2);
                        assert(desugar(Re::Star(Box::new(x0)), n.0).0 == dstar(desugar(x0, n.0).0));
                        let (g, f) = sim_b(s, f1, da, i, rr, sv, rs, x, ka, ns); (g, f + 1)
                    }
                },
                Item::SetRR(k) => {
                    tail_inv(s, ff, n.0, n.1, d2, i, rr, sv, k);
                    let sv3 = cons((n.1, rr), sv);
                    rel_free(s, sv, rr, k2, n2, d2, sv3, k);
                    let y = (md(s, (ff - 6) as nat, d2, i, k, sv3)->0).1;
                    let (g, f) = sim_b(s, (ff - 6) as nat, d2, i, k, sv3, rs, y, k2, n2);
                    (g, f + 1)
                },
                Item::Ends(_) => { (0, 0) },
            }
        }
    }
}

pub proof fn sim_b_alt(s: L<nat>, ff: nat, a: Re, b: Re, k2: L<Item>, i: nat, rr: nat, rs: L<DRes>, x: nat, d2: L<DItem>, n: nat,
                       n2: L<(nat, nat)>, sv: L<(nat, nat)>) -> (gf: (nat, nat))
    requires in_scope(a), in_scope(b), (core(a) && core(b)) || noset(k2), rel(s, sv, rr, k2, n2, d2), i <= rr, rr <= len(s),
             md(s, ff, cons(DItem::DR(dalt(desugar(a, n).0, desugar(b, desugar(a, n).1).0)), d2), i, rr, sv) == Some((rs, x)),
    ensures x == rr, m(s, gf.0, gf.1, cons(Item::R(Re::Alt(Box::new(a), Box::new(b))), k2), i, rr) == Some(ends(rs)),
    decreases ff, 0nat
{
    let f1 = (ff - 1) as nat;
    let na = desugar(a, n);
    let ka = cons(Item::R(a), k2);
    let kb = cons(Item::R(b), k2);
    let da = cons(DItem::DR(na.0), d2);
    let db = cons(DItem::DR(desugar(b, na.1).0), d2);
    let (r1, x1) = md(s, f1, da, i, rr, sv)->0;
    let (r2, x2) = md(s, f1, db, i, x1, sv)->0;
    let (g1, h1) = sim_b(s, f1, da, i, rr, sv, r1, x1, ka, cons((n, 0nat), n2));
    let (g2, h2) = sim_b(s, f1, db, i, rr, sv, r2, x2, kb, cons((na.1, 0nat), n2));
    let gm = nmax(g1, g2);
    let hm = nmax(h1, h2);
    m_mono(s, g1, gm, h1, hm, ka, i, rr);
    m_mono(s, g2, gm, h2, hm, kb, i, rr);
    ends_app(r1, r2);
    (gm, hm + 1)
}

pub proof fn sim_b_star(s: L<nat>, ff: nat, a: Re, k2: L<Item>, i: nat, rr: nat, rs: L<DRes>, x: nat, d2: L<DItem>, n: nat,
                        n2: L<(nat, nat)>, sv: L<(nat, nat)>) -> (gf: (nat, nat))
    requires in_scope(a), core(a) || noset(k2), rel(s, sv, rr, k2, n2, d2), i <= rr, rr <= len(s),
             md(s, ff, cons(DItem::DR(dstar(desugar(a, n).0)), d2), i, rr, sv) == Some((rs, x)),
    ensures x == rr, m(s, gf.0, gf.1, cons(Item::R(Re::Star(Box::new(a))), k2), i, rr) == Some(ends(rs)),
    decreases ff, 0nat
{
    let f1 = (ff - 1) as nat;
    let na = desugar(a, n);
    let ka = cons(Item::R(a), cons(Item::Chk(i, a), k2));
    let da = cons(DItem::DR(na.0), cons(DItem::DChk(i, na.0), d2));
    let na2 = cons((n, 0nat), cons((n, 0nat), n2));
    assert(rel(s, sv, rr, ka, na2, da)) by { reveal_with_fuel(rel, 3); reveal_with_fuel(noset, 2); }
    let (r1, x1) = md(s, f1, da, i, rr, sv)->0;
    let (r2, x2) = md(s, f1, d2, i, x1, sv)->0;
    let (g1, h1) = sim_b(s, f1, da, i, rr, sv, r1, x1, ka, na2);
    let (g2, h2) = sim_b(s, f1, d2, i, rr, sv, r2, x2, k2, n2);
    let gm = nmax(g1, g2);
    let hm = nmax(h1, h2);
    m_mono(s, g1, gm, h1, hm, ka, i, rr);
    m_mono(s, g2, gm, h2, hm, k2, i, rr);
    ends_app(r1, r2);
    (gm, hm + 1)
}

// The per-end facts of the simple path, from the desugared side: each end
// e of the scan gives a complete m on the stack after the construct.
pub proof fn simple_ends_b(s: L<nat>, fp: nat, n: nat, k2: L<Item>, n2: L<(nat, nat)>, d2: L<DItem>, sv: L<(nat, nat)>,
                           rr: nat, top: nat, xt: nat, i: nat)
    requires rel(s, cons((n, rr), sv), rr, k2, n2, d2), top <= rr, rr <= len(s), i <= top,
             forall|e: nat| i <= e <= top ==> {
                &&& #[trigger] md(s, fp, ur(n, d2), e, reg(top, xt, rr, e), cons((n, rr), sv)) is Some
                &&& (md(s, fp, ur(n, d2), e, reg(top, xt, rr, e), cons((n, rr), sv))->0).1 == rr
             },
    ensures forall|e: nat| i <= e <= top ==> {
                &&& #[trigger] m(s, mmax(s, k2, rr, (top - i) as nat, i).0, mmax(s, k2, rr, (top - i) as nat, i).1, k2, e, rr) is Some
                &&& ends((md(s, fp, ur(n, d2), e, reg(top, xt, rr, e), cons((n, rr), sv))->0).0)
                    == m(s, mmax(s, k2, rr, (top - i) as nat, i).0, mmax(s, k2, rr, (top - i) as nat, i).1, k2, e, rr)->0
            },
    decreases fp, 0nat
{
    let sv2 = cons((n, rr), sv);
    let d = (top - i) as nat;
    assert(lookup(n, sv2) == Some(rr));
    assert forall|e: nat| i <= e <= i + d implies #[trigger] mterm(s, k2, e, rr)
        && ends((md(s, fp, ur(n, d2), e, reg(top, xt, rr, e), sv2)->0).0) == m(s, mfuel(s, k2, e, rr).0, mfuel(s, k2, e, rr).1, k2, e, rr)->0 by {
        assert(md(s, fp, ur(n, d2), e, reg(top, xt, rr, e), sv2) is Some);
        md_ur(s, fp, n, d2, e, reg(top, xt, rr, e), sv2, rr);
        md_ur(s, (fp - 3) as nat, n, d2, e, reg(top, xt, rr, e), sv2, rr);
        let (rse, ye) = md(s, (fp - 3) as nat, d2, e, rr, sv2)->0;
        let (ge, he) = sim_b(s, (fp - 3) as nat, d2, e, rr, sv2, rse, ye, k2, n2);
        assert(m(s, ge, he, k2, e, rr) is Some);
        m_det(s, ge, mfuel(s, k2, e, rr).0, he, mfuel(s, k2, e, rr).1, k2, e, rr);
    }
    mmax_ok(s, k2, rr, d, i);
    let pm = mmax(s, k2, rr, d, i);
    assert forall|e: nat| i <= e <= top implies {
                &&& #[trigger] m(s, pm.0, pm.1, k2, e, rr) is Some
                &&& ends((md(s, fp, ur(n, d2), e, reg(top, xt, rr, e), sv2)->0).0) == m(s, pm.0, pm.1, k2, e, rr)->0
    } by {
        assert(mterm(s, k2, e, rr));
        assert(m(s, pm.0, pm.1, k2, e, rr) == m(s, mfuel(s, k2, e, rr).0, mfuel(s, k2, e, rr).1, k2, e, rr));
    }
}

// AbsRep a, direction (2b).
pub proof fn sim_b_rep(s: L<nat>, ff: nat, a: Re, k2: L<Item>, i: nat, rr: nat, rs: L<DRes>, x: nat, d2: L<DItem>, n: nat,
                       n2: L<(nat, nat)>, sv: L<(nat, nat)>) -> (gf: (nat, nat))
    requires core(a), noset(k2), rel(s, sv, rr, k2, n2, d2), i <= rr, rr <= len(s),
             md(s, ff, cons(DItem::DR(simple_tree(n, a, DRe::DAnyO)), d2), i, rr, sv) == Some((rs, x)),
    ensures x == rr, m(s, gf.0, gf.1, cons(Item::R(Re::AbsRep(Box::new(a))), k2), i, rr) == Some(ends(rs)),
    decreases ff, 0nat
{
    let sv2 = cons((n, rr), sv);
    let uu = ur(n, d2);
    simple_inv(s, ff, n, a, DRe::DAnyO, d2, i, rr, sv);
    let fp = (ff - 4) as nat;
    let x1 = (md(s, fp, cons(DItem::DR(dstar(body(n + 1, a, DRe::DAnyO))), uu), i, rr, sv2)->0).1;
    rel_free(s, sv, rr, k2, n2, d2, sv2, rr);
    assert(lookup(n, sv2) == Some(rr));
    assert forall|f: nat, e: nat, x0: nat| f <= fp && e <= rr && #[trigger] md(s, f, uu, e, x0, sv2) is Some
        implies (md(s, f, uu, e, x0, sv2)->0).1 == hh(Some(rr), x0) by {
        md_ur(s, f, n, d2, e, x0, sv2, rr);
        md_ur(s, (f - 3) as nat, n, d2, e, x0, sv2, rr);
        let (rse, ye) = md(s, (f - 3) as nat, d2, e, rr, sv2)->0;
        sim_b(s, (f - 3) as nat, d2, e, rr, sv2, rse, ye, k2, n2);
    }
    let (top, bt) = scan_b(s, n + 1, a, DRe::DAnyO, uu, Some(rr), sv2, rr, fp, i, rs, x1);
    cut_from_scan(s, fp, a, i, rr, top, bt);
    let xt = xtop(bt, top, rr);
    let d = (top - i) as nat;
    simple_ends_b(s, fp, n, k2, n2, d2, sv, rr, top, xt, i);
    let (gm, hm) = mmax(s, k2, rr, d, i);
    ends_dcat(s, fp, uu, sv2, top, xt, rr, gm, hm, k2, rr, d, i);
    let es = downs(d, i);
    assert forall|e: nat| mem(e, es) implies #[trigger] m(s, gm, hm, k2, e, rr) is Some by { mem_downs(d, i, e); }
    m_ends_b(s, gm, hm, es, k2, i, rr);
    let g2 = nmax(gm, fp);
    cut_mono(a, s, fp, g2, i, rr);
    len_downs(d, i);
    m_mono(s, gm, g2, hm + len(es) + 1, hm + len(es) + 1, cons(Item::Ends(es), k2), i, rr);
    (g2, hm + len(es) + 2)
}

// AbsExp a (Star (Chr ch)), direction (2b).
pub proof fn sim_b_xs(s: L<nat>, ff: nat, a: Re, ch: nat, k2: L<Item>, i: nat, rr: nat, rs: L<DRes>, x: nat, d2: L<DItem>, n: nat,
                      n2: L<(nat, nat)>, sv: L<(nat, nat)>) -> (gf: (nat, nat))
    requires core(a), noset(k2), rel(s, sv, rr, k2, n2, d2), i <= rr, rr <= len(s),
             md(s, ff, cons(DItem::DR(simple_tree(n, a, DRe::DChr(ch))), d2), i, rr, sv) == Some((rs, x)),
    ensures x == rr,
            m(s, gf.0, gf.1, cons(Item::R(Re::AbsExp(Box::new(a), Box::new(Re::Star(Box::new(Re::Chr(ch)))))), k2), i, rr) == Some(ends(rs)),
    decreases ff, 0nat
{
    let sv2 = cons((n, rr), sv);
    let uu = ur(n, d2);
    let st = DRe::DChr(ch);
    simple_inv(s, ff, n, a, st, d2, i, rr, sv);
    let fp = (ff - 4) as nat;
    let x1 = (md(s, fp, cons(DItem::DR(dstar(body(n + 1, a, st))), uu), i, rr, sv2)->0).1;
    rel_free(s, sv, rr, k2, n2, d2, sv2, rr);
    assert(lookup(n, sv2) == Some(rr));
    assert forall|f: nat, e: nat, x0: nat| f <= fp && e <= rr && #[trigger] md(s, f, uu, e, x0, sv2) is Some
        implies (md(s, f, uu, e, x0, sv2)->0).1 == hh(Some(rr), x0) by {
        md_ur(s, f, n, d2, e, x0, sv2, rr);
        md_ur(s, (f - 3) as nat, n, d2, e, x0, sv2, rr);
        let (rse, ye) = md(s, (f - 3) as nat, d2, e, rr, sv2)->0;
        sim_b(s, (f - 3) as nat, d2, e, rr, sv2, rse, ye, k2, n2);
    }
    let (top, bt) = scan_b(s, n + 1, a, st, uu, Some(rr), sv2, rr, fp, i, rs, x1);
    let xt = xtop(bt, top, rr);
    let d = (top - i) as nat;
    let g0 = cut_term(s, a, i, rr);
    let g1 = nmax(g0, fp);
    cut_mono(a, s, g0, g1, i, rr);
    let c = cut(a, s, g1, i, rr)->0;
    let ka = cons(Item::R(a), L::Nil);
    assert forall|p: nat| i <= p < top implies #[trigger] mb(s, g1, ka, p, rr) == Some(false) && stp(s, st, p, rr) by {
        assert(mb(s, fp, ka, p, rr) == Some(false));
        mb_mono(s, fp, g1, ka, p, rr);
    }
    mb_mono(s, fp, g1, ka, top, rr);
    simple_top(s, g1, a, i, rr, top, bt, c, ch);
    simple_ends_b(s, fp, n, k2, n2, d2, sv, rr, top, xt, i);
    let (gm, hm) = mmax(s, k2, rr, d, i);
    let kd = cons(Item::SetRR(rr), k2);
    assert forall|e: nat| i <= e <= top implies {
        &&& #[trigger] m(s, gm, hm + 1, kd, e, c) is Some
        &&& ends((md(s, fp, uu, e, reg(top, xt, rr, e), sv2)->0).0) == m(s, gm, hm + 1, kd, e, c)->0
    } by {
        assert(m(s, gm, hm, k2, e, rr) is Some);
        assert(m(s, gm, hm + 1, kd, e, c) == m(s, gm, hm, k2, e, rr));
    }
    ends_dcat(s, fp, uu, sv2, top, xt, rr, gm, hm + 1, kd, c, d, i);
    mstar_b(s, ch, gm, hm + 1, kd, d, i, top, c);
    let g2 = nmax(gm, g1);
    let fs = hm + 1 + 2 + 3 * d;
    let xs = Re::Star(Box::new(Re::Chr(ch)));
    m_mono(s, gm, g2, fs, fs, cons(Item::R(xs), kd), i, c);
    cut_mono(a, s, g1, g2, i, rr);
    (g2, fs + 1)
}

// The general path, direction (2b): the atomic scan, then the
// continuation rest from the start i with the cut as the register.
pub proof fn gen_b(s: L<nat>, ff: nat, n: nat, a: Re, rest: DRe, d2: L<DItem>, i: nat, rr: nat, sv: L<(nat, nat)>, rs: L<DRes>, x: nat)
    -> (res: (nat, nat))
    requires core(a), i <= rr, rr <= len(s),
             md(s, ff, cons(DItem::DR(gen_head(n, a, rest)), d2), i, rr, sv) == Some((rs, x)),
    ensures ({
        let (c, fk) = res;
        &&& x == rr && i <= c && c <= rr && fk < ff
        &&& cut(a, s, ff, i, rr) == Some(c)
        &&& md(s, fk, cons(DItem::DR(rest), d2), i, c, sv1(n, i, rr, sv)) is Some
        &&& (md(s, fk, cons(DItem::DR(rest), d2), i, c, sv1(n, i, rr, sv))->0).0 == rs
    }),
{
    let s1 = sv1(n, i, rr, sv);
    let k2 = cons(DItem::DR(dsq(DRe::DUpdSFromStack(n + 1), rest)), d2);
    gen_inv(s, ff, n, a, rest, d2, i, rr, sv);
    let fp = (ff - 7) as nat;
    let (ra, xa) = md(s, fp, cons(DItem::DR(dstar(body(n + 2, a, DRe::DAnyO))), L::Nil), i, rr, s1)->0;
    let (top, bt) = scan_b(s, n + 2, a, DRe::DAnyO, L::Nil, None, s1, rr, fp, i, ra, xa);
    cut_from_scan(s, fp, a, i, rr, top, bt);
    let d = (top - i) as nat;
    downs_hd(d, i);
    let dl = downs(d, i);
    let tl = dcat(s, fp, L::Nil, s1, top, top, top, *(dl->1));
    assert(md(s, fp, L::<DItem>::Nil, top, top, s1) == Some((cons((top, top, s1), L::<DRes>::Nil), top)));
    assert(ra == app(cons((top, top, s1), L::<DRes>::Nil), tl));
    assert(app(cons((top, top, s1), L::<DRes>::Nil), tl) == cons((top, top, s1), app(L::<DRes>::Nil, tl)));
    lookup_sv1(n, i, rr, sv);
    md_u2(s, fp, n, rest, d2, top, top, s1, i);
    md_u2(s, (fp - 2) as nat, n, rest, d2, top, top, s1, i);
    mb_mono(s, fp, ff, cons(Item::R(a), L::Nil), top, rr);
    assert forall|p: nat| i <= p < top implies #[trigger] occ(a, s, ff, p, rr) == Some(false) by {
        assert(mb(s, fp, cons(Item::R(a), L::Nil), p, rr) == Some(false));
        mb_mono(s, fp, ff, cons(Item::R(a), L::Nil), p, rr);
    }
    cut_mono(a, s, fp, ff, i, rr);
    (top, (fp - 2) as nat)
}

// AbsExp a e, e not x*, direction (2b).
pub proof fn sim_b_gen(s: L<nat>, ff: nat, a: Re, e: Re, k2: L<Item>, i: nat, rr: nat, rs: L<DRes>, x: nat, d2: L<DItem>, n: nat,
                       n2: L<(nat, nat)>, sv: L<(nat, nat)>) -> (gf: (nat, nat))
    requires core(a), core(e), simple_step(e) is None, noset(k2), rel(s, sv, rr, k2, n2, d2), i <= rr, rr <= len(s),
             desugar(e, 0) == (emb(e), 0nat),
             md(s, ff, cons(DItem::DR(desugar(Re::AbsExp(Box::new(a), Box::new(e)), n).0), d2), i, rr, sv) == Some((rs, x)),
    ensures x == rr, m(s, gf.0, gf.1, cons(Item::R(Re::AbsExp(Box::new(a), Box::new(e))), k2), i, rr) == Some(ends(rs)),
    decreases ff, 0nat
{
    let tl = dsq(tail(n, n + 3), DRe::DEps);
    let rest = dsq(emb(e), tl);
    let (c, fk) = gen_b(s, ff, n, a, rest, d2, i, rr, sv, rs, x);
    let s1 = sv1(n, i, rr, sv);
    lookup_sv1(n, i, rr, sv);
    core_in_scope(e);
    let kk2 = cons(Item::R(e), cons(Item::SetRR(rr), k2));
    let nn2 = cons((0nat, 0nat), cons((n, n + 3), n2));
    let dd2 = cons(DItem::DR(emb(e)), cons(DItem::DR(tl), d2));
    rel_free(s, sv, rr, k2, n2, d2, s1, c);
    assert(rel(s, s1, c, kk2, nn2, dd2)) by { reveal_with_fuel(rel, 3); }
    assert(md(s, fk, cons(DItem::DR(rest), d2), i, c, s1) == md(s, (fk - 1) as nat, dd2, i, c, s1));
    let y = (md(s, (fk - 1) as nat, dd2, i, c, s1)->0).1;
    let (g1, h1) = sim_b(s, (fk - 1) as nat, dd2, i, c, s1, rs, y, kk2, nn2);
    let g2 = nmax(g1, ff);
    cut_mono(a, s, ff, g2, i, rr);
    m_mono(s, g1, g2, h1, h1, kk2, i, c);
    (g2, h1 + 1)
}

// Stopper a, direction (2b).
pub proof fn sim_b_stop(s: L<nat>, ff: nat, a: Re, k2: L<Item>, i: nat, rr: nat, rs: L<DRes>, x: nat, d2: L<DItem>, n: nat,
                        n2: L<(nat, nat)>, sv: L<(nat, nat)>) -> (gf: (nat, nat))
    requires core(a), noset(k2), rel(s, sv, rr, k2, n2, d2), i <= rr, rr <= len(s),
             md(s, ff, cons(DItem::DR(gen_head(n, a, DRe::DEps)), d2), i, rr, sv) == Some((rs, x)),
    ensures x == rr, m(s, gf.0, gf.1, cons(Item::R(Re::Stopper(Box::new(a))), k2), i, rr) == Some(ends(rs)),
    decreases ff, 0nat
{
    let (c, fk) = gen_b(s, ff, n, a, DRe::DEps, d2, i, rr, sv, rs, x);
    let s1 = sv1(n, i, rr, sv);
    rel_free(s, sv, rr, k2, n2, d2, s1, c);
    assert(md(s, fk, cons(DItem::DR(DRe::DEps), d2), i, c, s1) == md(s, (fk - 1) as nat, d2, i, c, s1));
    let y = (md(s, (fk - 1) as nat, d2, i, c, s1)->0).1;
    let (g1, h1) = sim_b(s, (fk - 1) as nat, d2, i, c, s1, rs, y, k2, n2);
    let g2 = nmax(g1, ff);
    cut_mono(a, s, ff, g2, i, rr);
    m_mono(s, g1, g2, h1, h1, k2, i, c);
    (g2, h1 + 1)
}

// Main lemma (LEMMAS.md, lemma 2): for every pattern r built from the
// core, AbsRep, AbsExp (simple and general path), the stopper and the
// range clear, with no absent construct inside an absent one, every
// subject s, position i and register rr with i <= rr <= len(s):
// (2a) every complete list of ends of the direct matcher (some fuels g, f)
//      is the list of ends of md on the desugared tree for some fuel, and
//      md ends with the register it started with;
// (2b) every complete result of md is a complete list of the direct
//      matcher for some fuels g, f.
pub proof fn absent_desugar_eq(s: L<nat>, r: Re, i: nat, rr: nat)
    requires in_scope(r), i <= rr, rr <= len(s),
    ensures
        forall|g: nat, f: nat| #[trigger] m(s, g, f, cons(Item::R(r), L::Nil), i, rr) is Some ==>
            exists|f2: nat, rs: L<DRes>| md(s, f2, cons(DItem::DR(desugar(r, 0).0), L::Nil), i, rr, L::Nil) == Some((rs, rr))
                && ends(rs) == m(s, g, f, cons(Item::R(r), L::Nil), i, rr)->0,
        forall|f2: nat| #[trigger] md(s, f2, cons(DItem::DR(desugar(r, 0).0), L::Nil), i, rr, L::Nil) is Some ==>
            (md(s, f2, cons(DItem::DR(desugar(r, 0).0), L::Nil), i, rr, L::Nil)->0).1 == rr
            && exists|g: nat, f: nat| m(s, g, f, cons(Item::R(r), L::Nil), i, rr)
                == Some(ends((md(s, f2, cons(DItem::DR(desugar(r, 0).0), L::Nil), i, rr, L::Nil)->0).0)),
{
    let ks = cons(Item::R(r), L::Nil);
    let ns = cons((0nat, 0nat), L::Nil);
    let dks = cons(DItem::DR(desugar(r, 0).0), L::Nil);
    assert(rel(s, L::Nil, rr, ks, ns, dks)) by { reveal_with_fuel(rel, 2); reveal_with_fuel(noset, 1); }
    assert forall|g: nat, f: nat| #[trigger] m(s, g, f, ks, i, rr) is Some implies
        exists|f2: nat, rs: L<DRes>| md(s, f2, dks, i, rr, L::Nil) == Some((rs, rr)) && ends(rs) == m(s, g, f, ks, i, rr)->0 by {
        let (f2, rs) = sim_a(s, g, f, ks, i, rr, m(s, g, f, ks, i, rr)->0, dks, ns, L::Nil);
    }
    assert forall|f2: nat| #[trigger] md(s, f2, dks, i, rr, L::Nil) is Some implies
        (md(s, f2, dks, i, rr, L::Nil)->0).1 == rr
        && exists|g: nat, f: nat| m(s, g, f, ks, i, rr) == Some(ends((md(s, f2, dks, i, rr, L::Nil)->0).0)) by {
        let (rs, x) = md(s, f2, dks, i, rr, L::Nil)->0;
        let (g, f) = sim_b(s, f2, dks, i, rr, L::Nil, rs, x, ks, ns);
    }
}

} // verus!
