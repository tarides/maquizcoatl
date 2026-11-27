// Experiment #8 follow-up (issue #34): agreement of the C library, the
// direct semantics m (absent.rs) and the desugared model md (desugar.rs) on
// the absent corpus, by assert(...) by (compute_only) at explicit fuels
// (Verus's interpreter, no fallback to Z3; no constant fuel in any lemma
// of the proofs; these fuels appear only here).  Transcription of
// rocq/Cases.v.
// Cases: lab/08-hard-features/cases/absent.tsv (ab01-ab11) and
// lab/08-discriminating-lemmas/cases/absent-restore.tsv (ab12-ab29).
// The expected value of each check is the C result, identical on the
// Debug and ASan/UBSan builds (lab/results/2026-11-26-exp-08-lemmas-cases.md).
// Patterns and subjects are in the two TSV files, by case id.
// Byte values: a=97 b=98 c=99 d=100 q=113 x=120 y=121 z=122.
use vstd::prelude::*;
use crate::absent::*;
use crate::desugar::*;

verus! {

pub open spec fn sq(x: Re, y: Re) -> Re { Re::Seq(Box::new(x), Box::new(y)) }
pub open spec fn al(x: Re, y: Re) -> Re { Re::Alt(Box::new(x), Box::new(y)) }
pub open spec fn star(x: Re) -> Re { Re::Star(Box::new(x)) }
pub open spec fn chr(c: nat) -> Re { Re::Chr(c) }
pub open spec fn abr(x: Re) -> Re { Re::AbsRep(Box::new(x)) }
pub open spec fn abx(x: Re, e: Re) -> Re { Re::AbsExp(Box::new(x), Box::new(e)) }
pub open spec fn stp(x: Re) -> Re { Re::Stopper(Box::new(x)) }
pub open spec fn lit(l: L<nat>) -> Re decreases l {
    match l {
        L::Nil => Re::Eps,
        L::Cons(c, cs) => match *cs { L::Nil => Re::Chr(c), _ => sq(Re::Chr(c), lit(*cs)) },
    }
}
pub open spec fn abc() -> Re { lit(cons(97, cons(98, cons(99, L::Nil)))) }
pub open spec fn ostar() -> Re { star(Re::AnyO) }
pub open spec fn dotstar() -> Re { star(Re::Any) }

// Fuels: fuel_g for occ's inner matcher, fuel_f for m and md (Rocq: G, F).
pub open spec fn fuel_g() -> nat { 1000 }
pub open spec fn fuel_f() -> nat { 1000 }

// The whole priority-ordered list of ends at one start, both matchers
// (C reports only the first match; lemma 2 is about the lists).
pub open spec fn dends(rs: L<DRes>) -> L<nat> decreases rs {
    match rs { L::Nil => L::Nil, L::Cons(r, t) => cons(r.0, dends(*t)) }
}
pub open spec fn ends_m(p: Re, s: L<nat>, st: nat) -> Option<L<nat>> {
    m(s, fuel_g(), fuel_f(), cons(Item::R(p), L::Nil), st, len(s))
}
pub open spec fn ends_md(p: Re, s: L<nat>, st: nat) -> Option<L<nat>> {
    match md(s, fuel_f(), cons(DItem::DR(desugar(p, 0).0), L::Nil), st, len(s), L::Nil) {
        Some((rs, _)) => Some(dends(rs)),
        None => None,
    }
}
pub open spec fn lists_from(p: Re, s: L<nat>, k: nat, st: nat) -> bool decreases k {
    if k == 0 { true } else {
        match (ends_m(p, s, st), ends_md(p, s, st)) {
            (Some(l1), Some(l2)) => if l1 == l2 { lists_from(p, s, (k - 1) as nat, st + 1) } else { false },
            _ => false,
        }
    }
}
pub open spec fn lists_agree(p: Re, s: L<nat>) -> bool { lists_from(p, s, len(s) + 1, 0) }

// One case: C's result r agrees with m and with md on the desugared tree,
// and m and md give the same complete list of ends at every start.
pub open spec fn agree(p: Re, s: L<nat>, r: SRes) -> bool {
    search(fuel_g(), fuel_f(), p, s) == r && dsearch(fuel_f(), p, s) == r && lists_agree(p, s)
}

// ab01, C: M 0-0
pub proof fn ab01() {
    assert(agree(abr(lit(cons(97, cons(98, L::Nil)))),
                 cons(97, cons(98, cons(99, L::Nil))), SRes::Match(0, 0))) by (compute_only);
}

// ab02, C: M 0-0
pub proof fn ab02() {
    assert(agree(abr(abc()),
                 cons(97, cons(98, cons(99, L::Nil))), SRes::Match(0, 0))) by (compute_only);
}

// ab03, C: M 0-0
pub proof fn ab03() {
    assert(agree(abr(al(abc(), lit(cons(97, cons(98, L::Nil))))),
                 cons(97, cons(98, cons(99, L::Nil))), SRes::Match(0, 0))) by (compute_only);
}

// ab04, C: M 0-5
pub proof fn ab04() {
    assert(agree(sq(lit(cons(97, cons(97, cons(97, cons(97, cons(97, L::Nil)))))), abr(Re::Eps)),
                 cons(97, cons(97, cons(97, cons(97, cons(97, cons(97, cons(97, cons(97, cons(97, cons(97, L::Nil)))))))))), SRes::Match(0, 5))) by (compute_only);
}

// ab05, C: M 0-0
pub proof fn ab05() {
    assert(agree(abx(abc(), ostar()),
                 cons(97, cons(98, cons(99, L::Nil))), SRes::Match(0, 0))) by (compute_only);
}

// ab06, C: M 0-1
pub proof fn ab06() {
    assert(agree(abr(abc()),
                 cons(120, cons(97, cons(98, cons(99, cons(120, L::Nil))))), SRes::Match(0, 1))) by (compute_only);
}

// ab07, C: M 0-1
pub proof fn ab07() {
    assert(agree(abx(abc(), ostar()),
                 cons(120, cons(97, cons(98, cons(99, cons(120, L::Nil))))), SRes::Match(0, 1))) by (compute_only);
}

// ab08, C: M 0-4
pub proof fn ab08() {
    assert(agree(sq(abr(abc()), chr(122)),
                 cons(120, cons(97, cons(98, cons(122, L::Nil)))), SRes::Match(0, 4))) by (compute_only);
}

// ab09, C: M 0-4
pub proof fn ab09() {
    assert(agree(sq(abx(abc(), ostar()), chr(122)),
                 cons(120, cons(97, cons(98, cons(122, L::Nil)))), SRes::Match(0, 4))) by (compute_only);
}

// ab10, C: M 0-2
pub proof fn ab10() {
    assert(agree(sq(stp(abc()), dotstar()),
                 cons(120, cons(120, cons(97, cons(98, cons(99, cons(121, cons(121, L::Nil))))))), SRes::Match(0, 2))) by (compute_only);
}

// ab11, C: M 0-7
pub proof fn ab11() {
    assert(agree(sq(stp(abc()), sq(Re::RClear, dotstar())),
                 cons(120, cons(120, cons(97, cons(98, cons(99, cons(121, cons(121, L::Nil))))))), SRes::Match(0, 7))) by (compute_only);
}

// ab12, C: M 0-6
pub proof fn ab12() {
    assert(agree(al(sq(abr(abc()), chr(122)), dotstar()),
                 cons(120, cons(97, cons(98, cons(99, cons(121, cons(121, L::Nil)))))), SRes::Match(0, 6))) by (compute_only);
}

// ab13, C: M 0-6
pub proof fn ab13() {
    assert(agree(al(sq(abx(abc(), ostar()), chr(122)), dotstar()),
                 cons(120, cons(97, cons(98, cons(99, cons(121, cons(121, L::Nil)))))), SRes::Match(0, 6))) by (compute_only);
}

// ab14, C: M 0-6
pub proof fn ab14() {
    assert(agree(al(sq(stp(abc()), chr(122)), dotstar()),
                 cons(120, cons(97, cons(98, cons(99, cons(121, cons(121, L::Nil)))))), SRes::Match(0, 6))) by (compute_only);
}

// ab15, C: M 0-5
pub proof fn ab15() {
    assert(agree(al(sq(stp(abc()), sq(ostar(), chr(122))), ostar()),
                 cons(120, cons(97, cons(98, cons(99, cons(122, L::Nil))))), SRes::Match(0, 5))) by (compute_only);
}

// ab16, C: M 0-5
pub proof fn ab16() {
    assert(agree(sq(abr(abc()), ostar()),
                 cons(120, cons(97, cons(98, cons(99, cons(121, L::Nil))))), SRes::Match(0, 5))) by (compute_only);
}

// ab17, C: M 0-4
pub proof fn ab17() {
    assert(agree(sq(abx(abc(), star(chr(120))), chr(97)),
                 cons(120, cons(120, cons(120, cons(97, cons(98, cons(99, cons(121, L::Nil))))))), SRes::Match(0, 4))) by (compute_only);
}

// ab18, C: M 0-6
pub proof fn ab18() {
    assert(agree(al(sq(abx(abc(), star(chr(120))), chr(122)), ostar()),
                 cons(120, cons(120, cons(97, cons(98, cons(99, cons(122, L::Nil)))))), SRes::Match(0, 6))) by (compute_only);
}

// ab19, C: M 6-7
pub proof fn ab19() {
    assert(agree(sq(abx(abc(), star(chr(120))), chr(121)),
                 cons(120, cons(120, cons(120, cons(97, cons(98, cons(99, cons(121, L::Nil))))))), SRes::Match(6, 7))) by (compute_only);
}

// ab20, C: M 2-7
pub proof fn ab20() {
    assert(agree(sq(abx(abc(), al(chr(120), sq(Re::AnyO, sq(Re::AnyO, sq(Re::AnyO, Re::AnyO))))), chr(113)),
                 cons(120, cons(97, cons(98, cons(99, cons(113, cons(113, cons(113, L::Nil))))))), SRes::Match(2, 7))) by (compute_only);
}

// ab21, C: M 0-4
pub proof fn ab21() {
    assert(agree(sq(abx(abc(), star(al(lit(cons(120, cons(120, L::Nil))), chr(120)))), lit(cons(120, cons(97, L::Nil)))),
                 cons(120, cons(120, cons(120, cons(97, cons(98, cons(99, L::Nil)))))), SRes::Match(0, 4))) by (compute_only);
}

// ab22, C: M 0-7
pub proof fn ab22() {
    assert(agree(sq(abx(abc(), star(al(chr(120), chr(121)))), ostar()),
                 cons(120, cons(121, cons(97, cons(98, cons(99, cons(120, cons(121, L::Nil))))))), SRes::Match(0, 7))) by (compute_only);
}

// ab23, C: M 0-2
pub proof fn ab23() {
    assert(agree(sq(stp(abc()), al(sq(Re::RClear, sq(ostar(), chr(122))), ostar())),
                 cons(120, cons(120, cons(97, cons(98, cons(99, cons(121, cons(121, L::Nil))))))), SRes::Match(0, 2))) by (compute_only);
}

// ab24, C: M 0-0
pub proof fn ab24() {
    assert(agree(abx(al(chr(97), Re::Eps), star(al(chr(120), chr(121)))),
                 cons(120, cons(121, cons(97, L::Nil))), SRes::Match(0, 0))) by (compute_only);
}

// ab25, C: M 0-1
pub proof fn ab25() {
    assert(agree(sq(abx(Re::Eps, ostar()), chr(122)),
                 cons(122, L::Nil), SRes::Match(0, 1))) by (compute_only);
}

// ab26, C: M 1-2
pub proof fn ab26() {
    assert(agree(sq(abr(Re::Eps), chr(122)),
                 cons(120, cons(122, L::Nil)), SRes::Match(1, 2))) by (compute_only);
}

// ab27, C: M 0-7
pub proof fn ab27() {
    assert(agree(sq(abx(lit(cons(97, cons(98, L::Nil))), ostar()), sq(abx(lit(cons(99, cons(100, L::Nil))), ostar()), chr(122))),
                 cons(120, cons(120, cons(99, cons(100, cons(97, cons(98, cons(122, L::Nil))))))), SRes::Match(0, 7))) by (compute_only);
}

// ab28, C: M 0-4
pub proof fn ab28() {
    assert(agree(star(sq(abr(lit(cons(97, cons(98, L::Nil)))), chr(99))),
                 cons(120, cons(99, cons(120, cons(99, cons(97, cons(98, cons(99, L::Nil))))))), SRes::Match(0, 4))) by (compute_only);
}

// ab29, C: M 0-6
pub proof fn ab29() {
    assert(agree(sq(star(sq(stp(lit(cons(97, cons(98, L::Nil)))), chr(99))), ostar()),
                 cons(120, cons(99, cons(97, cons(98, cons(99, cons(99, L::Nil)))))), SRes::Match(0, 6))) by (compute_only);
}

} // verus!
