// Experiment #8 follow-up (issue #34), lemma plan (b): fuel monotonicity
// and determinism of mb, scan/cut, m (in both fuels f and g) and md,
// after experiment #9's ct_mono/ct_det
// (lab/09-representative-proof/verus/proof_sem.rs); transcription of
// rocq/AbsentMono.v.  Design: lab/08-discriminating-lemmas/LEMMAS.md,
// "Lemma plan".
use vstd::prelude::*;
use crate::absent::*;
use crate::desugar::*;

verus! {

pub proof fn mb_mono(s: L<nat>, f: nat, f2: nat, ks: L<Item>, i: nat, rr: nat)
    requires mb(s, f, ks, i, rr) is Some, f <= f2,
    ensures mb(s, f2, ks, i, rr) == mb(s, f, ks, i, rr),
    decreases f
{
    let f1 = (f - 1) as nat;
    let g1 = (f2 - 1) as nat;
    if let L::Cons(it, rest) = ks {
        let k = *rest;
        match it {
            Item::R(r) => match r {
                Re::Eps => mb_mono(s, f1, g1, k, i, rr),
                Re::Chr(c) => if at_(s, i, rr) == Some(c) { mb_mono(s, f1, g1, k, i + 1, rr) },
                Re::Any => if at_(s, i, rr) is Some && at_(s, i, rr) != Some(10nat) { mb_mono(s, f1, g1, k, i + 1, rr) },
                Re::AnyO => if at_(s, i, rr) is Some { mb_mono(s, f1, g1, k, i + 1, rr) },
                Re::Seq(a, b) => mb_mono(s, f1, g1, cons(Item::R(*a), cons(Item::R(*b), k)), i, rr),
                Re::Alt(a, b) => {
                    mb_mono(s, f1, g1, cons(Item::R(*a), k), i, rr);
                    if mb(s, f1, cons(Item::R(*a), k), i, rr) == Some(false) { mb_mono(s, f1, g1, cons(Item::R(*b), k), i, rr); }
                },
                Re::Star(a) => {
                    mb_mono(s, f1, g1, cons(Item::R(*a), cons(Item::Chk(i, *a), k)), i, rr);
                    if mb(s, f1, cons(Item::R(*a), cons(Item::Chk(i, *a), k)), i, rr) == Some(false) { mb_mono(s, f1, g1, k, i, rr); }
                },
                _ => {},
            },
            Item::Chk(i0, a) => if i == i0 { mb_mono(s, f1, g1, k, i, rr) }
                                else { mb_mono(s, f1, g1, cons(Item::R(Re::Star(Box::new(a))), k), i, rr) },
            Item::SetRR(n) => mb_mono(s, f1, g1, k, i, n),
            Item::Ends(_) => {},
        }
    }
}

pub proof fn mb_det(s: L<nat>, f: nat, f2: nat, ks: L<Item>, i: nat, rr: nat)
    requires mb(s, f, ks, i, rr) is Some, mb(s, f2, ks, i, rr) is Some,
    ensures mb(s, f, ks, i, rr) == mb(s, f2, ks, i, rr),
{
    if f <= f2 { mb_mono(s, f, f2, ks, i, rr) } else { mb_mono(s, f2, f, ks, i, rr) }
}

pub proof fn scan_mono(a: Re, s: L<nat>, g: nat, g2: nat, rr: nat, k: nat, p: nat)
    requires scan(a, s, g, rr, k, p) is Some, g <= g2,
    ensures scan(a, s, g2, rr, k, p) == scan(a, s, g, rr, k, p),
    decreases k
{
    if k > 0 {
        mb_mono(s, g, g2, cons(Item::R(a), L::Nil), p, rr);
        if occ(a, s, g, p, rr) == Some(false) { scan_mono(a, s, g, g2, rr, (k - 1) as nat, p + 1); }
    }
}

pub proof fn cut_mono(a: Re, s: L<nat>, g: nat, g2: nat, i: nat, rr: nat)
    requires cut(a, s, g, i, rr) is Some, g <= g2,
    ensures cut(a, s, g2, i, rr) == cut(a, s, g, i, rr),
{
    scan_mono(a, s, g, g2, rr, if rr >= i { (rr - i) as nat } else { 0 }, i);
}

pub proof fn m_mono(s: L<nat>, g: nat, g2: nat, f: nat, f2: nat, ks: L<Item>, i: nat, rr: nat)
    requires m(s, g, f, ks, i, rr) is Some, f <= f2, g <= g2,
    ensures m(s, g2, f2, ks, i, rr) == m(s, g, f, ks, i, rr),
    decreases f
{
    let f1 = (f - 1) as nat;
    let h1 = (f2 - 1) as nat;
    if let L::Cons(it, rest) = ks {
        let k = *rest;
        match it {
            Item::R(r) => match r {
                Re::Eps => m_mono(s, g, g2, f1, h1, k, i, rr),
                Re::Chr(c) => if at_(s, i, rr) == Some(c) { m_mono(s, g, g2, f1, h1, k, i + 1, rr) },
                Re::Any => if at_(s, i, rr) is Some && at_(s, i, rr) != Some(10nat) { m_mono(s, g, g2, f1, h1, k, i + 1, rr) },
                Re::AnyO => if at_(s, i, rr) is Some { m_mono(s, g, g2, f1, h1, k, i + 1, rr) },
                Re::Seq(a, b) => m_mono(s, g, g2, f1, h1, cons(Item::R(*a), cons(Item::R(*b), k)), i, rr),
                Re::Alt(a, b) => {
                    m_mono(s, g, g2, f1, h1, cons(Item::R(*a), k), i, rr);
                    m_mono(s, g, g2, f1, h1, cons(Item::R(*b), k), i, rr);
                },
                Re::Star(a) => {
                    m_mono(s, g, g2, f1, h1, cons(Item::R(*a), cons(Item::Chk(i, *a), k)), i, rr);
                    m_mono(s, g, g2, f1, h1, k, i, rr);
                },
                Re::AbsRep(a) => {
                    cut_mono(*a, s, g, g2, i, rr);
                    m_mono(s, g, g2, f1, h1, cons(Item::Ends(rep_ends(*a, s, g, i, rr)->0), k), i, rr);
                },
                Re::AbsExp(a, e) => {
                    cut_mono(*a, s, g, g2, i, rr);
                    m_mono(s, g, g2, f1, h1, cons(Item::R(*e), cons(Item::SetRR(rr), k)), i, cut(*a, s, g, i, rr)->0);
                },
                Re::Stopper(a) => {
                    cut_mono(*a, s, g, g2, i, rr);
                    m_mono(s, g, g2, f1, h1, k, i, cut(*a, s, g, i, rr)->0);
                },
                Re::RClear => m_mono(s, g, g2, f1, h1, k, i, len(s)),
            },
            Item::Chk(i0, a) => if i == i0 { m_mono(s, g, g2, f1, h1, k, i, rr) }
                                else { m_mono(s, g, g2, f1, h1, cons(Item::R(Re::Star(Box::new(a))), k), i, rr) },
            Item::SetRR(n) => m_mono(s, g, g2, f1, h1, k, i, n),
            Item::Ends(es) => if let L::Cons(e, es2) = es {
                m_mono(s, g, g2, f1, h1, k, e, rr);
                m_mono(s, g, g2, f1, h1, cons(Item::Ends(*es2), k), i, rr);
            },
        }
    }
}

pub proof fn m_det(s: L<nat>, g: nat, g2: nat, f: nat, f2: nat, ks: L<Item>, i: nat, rr: nat)
    requires m(s, g, f, ks, i, rr) is Some, m(s, g2, f2, ks, i, rr) is Some,
    ensures m(s, g, f, ks, i, rr) == m(s, g2, f2, ks, i, rr),
{
    let gm = if g <= g2 { g2 } else { g };
    let fm = if f <= f2 { f2 } else { f };
    m_mono(s, g, gm, f, fm, ks, i, rr);
    m_mono(s, g2, gm, f2, fm, ks, i, rr);
}

pub proof fn md_mono(s: L<nat>, f: nat, f2: nat, ks: L<DItem>, i: nat, rr: nat, sv: L<(nat, nat)>)
    requires md(s, f, ks, i, rr, sv) is Some, f <= f2,
    ensures md(s, f2, ks, i, rr, sv) == md(s, f, ks, i, rr, sv),
    decreases f
{
    let f1 = (f - 1) as nat;
    let h1 = (f2 - 1) as nat;
    if let L::Cons(it, rest) = ks {
        let k = *rest;
        match it {
            DItem::DChk(i0, a) => if i == i0 { md_mono(s, f1, h1, k, i, rr, sv) }
                                  else { md_mono(s, f1, h1, cons(DItem::DR(dstar(a)), k), i, rr, sv) },
            DItem::DR(d) => match d {
                DRe::DEps => md_mono(s, f1, h1, k, i, rr, sv),
                DRe::DChr(c) => if at_(s, i, rr) == Some(c) { md_mono(s, f1, h1, k, i + 1, rr, sv) },
                DRe::DAny => if at_(s, i, rr) is Some && at_(s, i, rr) != Some(10nat) { md_mono(s, f1, h1, k, i + 1, rr, sv) },
                DRe::DAnyO => if at_(s, i, rr) is Some { md_mono(s, f1, h1, k, i + 1, rr, sv) },
                DRe::DSeq(a, b) => md_mono(s, f1, h1, cons(DItem::DR(*a), cons(DItem::DR(*b), k)), i, rr, sv),
                DRe::DAlt(a, b) => {
                    md_mono(s, f1, h1, cons(DItem::DR(*a), k), i, rr, sv);
                    let x1 = (md(s, f1, cons(DItem::DR(*a), k), i, rr, sv)->0).1;
                    md_mono(s, f1, h1, cons(DItem::DR(*b), k), i, x1, sv);
                },
                DRe::DStar(a) => {
                    md_mono(s, f1, h1, cons(DItem::DR(*a), cons(DItem::DChk(i, *a), k)), i, rr, sv);
                    let x1 = (md(s, f1, cons(DItem::DR(*a), cons(DItem::DChk(i, *a), k)), i, rr, sv)->0).1;
                    md_mono(s, f1, h1, k, i, x1, sv);
                },
                DRe::DAtomic(a) => {
                    md_mono(s, f1, h1, cons(DItem::DR(*a), L::Nil), i, rr, sv);
                    if let L::Cons(r, _) = (md(s, f1, cons(DItem::DR(*a), L::Nil), i, rr, sv)->0).0 {
                        md_mono(s, f1, h1, k, r.0, r.1, r.2);
                    }
                },
                DRe::DFail => {},
                DRe::DSaveRR(id) => md_mono(s, f1, h1, k, i, rr, cons((id, rr), sv)),
                DRe::DSaveS(id) => md_mono(s, f1, h1, k, i, rr, cons((id, i), sv)),
                DRe::DUpdRRFromStack(id) => if let Some(v) = lookup(id, sv) { md_mono(s, f1, h1, k, i, v, sv) },
                DRe::DUpdRRFromS(id) => if let Some(v) = lookup(id, sv) { md_mono(s, f1, h1, k, i, v, sv) },
                DRe::DUpdSFromStack(id) => if let Some(v) = lookup(id, sv) { md_mono(s, f1, h1, k, v, rr, sv) },
                DRe::DRRInit => md_mono(s, f1, h1, k, i, len(s), sv),
            },
        }
    }
}

pub proof fn md_det(s: L<nat>, f: nat, f2: nat, ks: L<DItem>, i: nat, rr: nat, sv: L<(nat, nat)>)
    requires md(s, f, ks, i, rr, sv) is Some, md(s, f2, ks, i, rr, sv) is Some,
    ensures md(s, f, ks, i, rr, sv) == md(s, f2, ks, i, rr, sv),
{
    if f <= f2 { md_mono(s, f, f2, ks, i, rr, sv) } else { md_mono(s, f2, f, ks, i, rr, sv) }
}

} // verus!
