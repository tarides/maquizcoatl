// Experiment #8 follow-up (issue #34): a model of the C desugaring of the
// absent operator and a state-threaded matcher for it; transcription of
// rocq/Desugar.v.  Design and citations: lab/08-discriminating-lemmas/LEMMAS.md,
// sections "The desugaring" and "The state-threaded matcher".  References
// are upstream/<path>:<line> at f95747b.
//
// The model's faithfulness to the C library is checked only on the case
// corpus (cases.rs: lab/08-hard-features/cases/absent.tsv and
// lab/08-discriminating-lemmas/cases/absent-restore.tsv).
//
// Rocq's dseq [x1; ...; xk] (fold_right DSeq DEps) is written out as the
// nested DSeq it unfolds to (ds2, ds4), so that each tree is the same term.
use vstd::prelude::*;
use crate::absent::*;

verus! {

// The desugared AST: experiment #8's absent-free core plus the nodes the
// C parser emits for the absent constructs (regparse.c:2995-3391).
pub enum DRe {
    DEps, DChr(nat), DAny, DAnyO,
    DSeq(Box<DRe>, Box<DRe>), DAlt(Box<DRe>, Box<DRe>), DStar(Box<DRe>),
    DAtomic(Box<DRe>),        // BAG_STOP_BACKTRACK
    DFail,                    // node_new_fail
    DSaveRR(nat),             // SAVE_RIGHT_RANGE gimmick
    DSaveS(nat),              // SAVE_S gimmick
    DUpdRRFromStack(nat),     // UPDATE_VAR_RIGHT_RANGE_FROM_STACK
    DUpdRRFromS(nat),         // UPDATE_VAR_RIGHT_RANGE_FROM_S_STACK
    DUpdSFromStack(nat),      // UPDATE_VAR_S_FROM_STACK
    DRRInit,                  // UPDATE_VAR_RIGHT_RANGE_INIT
}

pub open spec fn dsq(a: DRe, b: DRe) -> DRe { DRe::DSeq(Box::new(a), Box::new(b)) }
pub open spec fn dalt(a: DRe, b: DRe) -> DRe { DRe::DAlt(Box::new(a), Box::new(b)) }
pub open spec fn dstar(a: DRe) -> DRe { DRe::DStar(Box::new(a)) }
// dseq [a; b] and dseq [a; b; c; d]
pub open spec fn ds2(a: DRe, b: DRe) -> DRe { dsq(a, dsq(b, DRe::DEps)) }
pub open spec fn ds3(a: DRe, b: DRe, c: DRe) -> DRe { dsq(a, dsq(b, dsq(c, DRe::DEps))) }
pub open spec fn ds4(a: DRe, b: DRe, c: DRe, d: DRe) -> DRe { dsq(a, dsq(b, dsq(c, dsq(d, DRe::DEps)))) }

// Absent-free core, embedded unchanged.
pub open spec fn emb(r: Re) -> DRe decreases r {
    match r {
        Re::Eps => DRe::DEps, Re::Chr(c) => DRe::DChr(c), Re::Any => DRe::DAny, Re::AnyO => DRe::DAnyO,
        Re::Seq(a, b) => dsq(emb(*a), emb(*b)), Re::Alt(a, b) => dalt(emb(*a), emb(*b)),
        Re::Star(a) => dstar(emb(*a)),
        _ => DRe::DFail, // absent constructs inside an absent pattern: out of scope
    }
}

// The engine's attempt branch SaveS j; a; UpdRRFromS j; Fail.
pub open spec fn att(j: nat, a: DRe) -> DRe { ds4(DRe::DSaveS(j), a, DRe::DUpdRRFromS(j), DRe::DFail) }
// make_absent_engine (regparse.c:2995-3075), id = pre_save_right_id,
// j = the engine's own SAVE_S id.  The SUPER flag on the outer
// alternation (range cutter) is not modelled: it changes only which stack
// entries a cut voids, and no pattern in scope has an atomic group or a
// lookaround around an absent construct (LEMMAS.md, scope conditions).
pub open spec fn engine(id: nat, j: nat, a: DRe, step: DRe, poss: bool) -> DRe {
    let body = dstar(dalt(att(j, a), step));
    dalt(if poss { DRe::DAtomic(Box::new(body)) } else { body }, ds2(DRe::DUpdRRFromStack(id), DRe::DFail))
}

// make_absent_tail (regparse.c:3078-3124).
pub open spec fn tail(id1: nat, id3: nat) -> DRe {
    dsq(DRe::DSaveRR(id3), dalt(DRe::DUpdRRFromStack(id1), ds2(DRe::DUpdRRFromStack(id3), DRe::DFail)))
}

// is_simple_one_char_repeat (regparse.c:3184-3249) on the AST: a greedy
// repeat whose body is a one-character string; the AST has no classes,
// other quantifiers or possessive groups, so Star (Chr c) is its only
// simple case.
pub open spec fn simple_step(e: Re) -> Option<nat> {
    match e { Re::Star(b) => match *b { Re::Chr(c) => Some(c), _ => None }, _ => None }
}

// The simple path (regparse.c:3252-3296) and the general path
// (regparse.c:3347-3384); the stopper is the general path without the
// tail (regparse.c:3371-3373).
pub open spec fn simple_tree(n: nat, a: Re, step: DRe) -> DRe {
    ds3(DRe::DSaveRR(n), engine(n, n + 1, emb(a), step, false), DRe::DUpdRRFromStack(n))
}
pub open spec fn gen_head(n: nat, a: Re, rest: DRe) -> DRe {
    dsq(DRe::DSaveRR(n), dsq(DRe::DSaveS(n + 1), dsq(engine(n, n + 2, emb(a), DRe::DAnyO, true),
        dsq(DRe::DUpdSFromStack(n + 1), rest))))
}

// desugar r n = (tree, next free id).  Ids are allocated in the order the
// C allocates them (ID_ENTRY in node_new_save_gimmick, regparse.c:2785-2799);
// the model only needs them distinct per construct.
pub open spec fn desugar(r: Re, n: nat) -> (DRe, nat) decreases r {
    match r {
        Re::Eps => (DRe::DEps, n), Re::Chr(c) => (DRe::DChr(c), n), Re::Any => (DRe::DAny, n), Re::AnyO => (DRe::DAnyO, n),
        Re::Seq(a, b) => { let (da, n1) = desugar(*a, n); let (db, n2) = desugar(*b, n1); (dsq(da, db), n2) },
        Re::Alt(a, b) => { let (da, n1) = desugar(*a, n); let (db, n2) = desugar(*b, n1); (dalt(da, db), n2) },
        Re::Star(a) => { let (da, n1) = desugar(*a, n); (dstar(da), n1) },
        // (?~absent): simple path with \O* (regparse.c:3317-3328, 3252-3296)
        Re::AbsRep(a) => (simple_tree(n, *a, DRe::DAnyO), n + 2),
        Re::AbsExp(a, e) => match simple_step(*e) {
            // simple path, step = the repeated character (regparse.c:3331, 3252-3296)
            Some(c) => (simple_tree(n, *a, DRe::DChr(c)), n + 2),
            // general path (regparse.c:3347-3384): ids id1 = n, id2 = n+1,
            // engine's SAVE_S n+2, tail's SAVE_RIGHT_RANGE n+3
            None => (gen_head(n, *a, dsq(emb(*e), dsq(tail(n, n + 3), DRe::DEps))), n + 4),
        },
        // range cutter: the general path without the tail (regparse.c:3371-3373)
        Re::Stopper(a) => (gen_head(n, *a, DRe::DEps), n + 3),
        // make_range_clear (regparse.c:3127-3183); SUPER not modelled
        Re::RClear => (ds2(DRe::DSaveRR(n), dalt(DRe::DRRInit, ds2(DRe::DUpdRRFromStack(n), DRe::DFail))), n + 1),
    }
}

pub enum DItem { DR(DRe), DChk(nat, DRe) }

// The save store: STK_SAVE_VAL entries of the backtrack stack, newest
// first; STACK_GET_SAVE_VAL_TYPE_LAST_ID (regexec.c:2211-2230) takes the
// last entry of the id.
pub open spec fn lookup(id: nat, sv: L<(nat, nat)>) -> Option<nat> decreases sv {
    match sv { L::Nil => None, L::Cons(kv, t) => if kv.0 == id { Some(kv.1) } else { lookup(id, *t) } }
}

// A result: end position, register and save store at success.
pub type DRes = (nat, nat, L<(nat, nat)>);

// md f ks i rr sv = Some (results in priority order, register at final
// failure), or None (out of fuel, or a lookup of an id with no save).
// The register rr is right_range (regexec.c:3189): backtracking does not
// restore it, so the alternative tried next starts from the register the
// previous one failed with.  The save store sv lives on the backtrack
// stack: each alternative starts from the store of its choice point.
pub open spec fn md(s: L<nat>, f: nat, ks: L<DItem>, i: nat, rr: nat, sv: L<(nat, nat)>) -> Option<(L<DRes>, nat)>
    decreases f
{
    if f == 0 { None } else {
        let f1 = (f - 1) as nat;
        match ks {
            L::Nil => Some((cons((i, rr, sv), L::Nil), rr)),
            L::Cons(it, rest) => {
                let ks = *rest;
                match it {
                    DItem::DChk(i0, a) => if i == i0 { md(s, f1, ks, i, rr, sv) }
                                          else { md(s, f1, cons(DItem::DR(dstar(a)), ks), i, rr, sv) },
                    DItem::DR(d) => match d {
                        DRe::DEps => md(s, f1, ks, i, rr, sv),
                        DRe::DChr(c) => match at_(s, i, rr) {
                            Some(c2) => if c == c2 { md(s, f1, ks, i + 1, rr, sv) } else { Some((L::Nil, rr)) },
                            None => Some((L::Nil, rr)) },
                        DRe::DAny => match at_(s, i, rr) {
                            Some(c2) => if c2 == 10 { Some((L::Nil, rr)) } else { md(s, f1, ks, i + 1, rr, sv) },
                            None => Some((L::Nil, rr)) },
                        DRe::DAnyO => match at_(s, i, rr) { Some(_) => md(s, f1, ks, i + 1, rr, sv), None => Some((L::Nil, rr)) },
                        DRe::DSeq(a, b) => md(s, f1, cons(DItem::DR(*a), cons(DItem::DR(*b), ks)), i, rr, sv),
                        DRe::DAlt(a, b) => match md(s, f1, cons(DItem::DR(*a), ks), i, rr, sv) {
                            Some((r1, rr1)) => match md(s, f1, cons(DItem::DR(*b), ks), i, rr1, sv) {
                                Some((r2, rr2)) => Some((app(r1, r2), rr2)), None => None },
                            None => None },
                        DRe::DStar(a) => match md(s, f1, cons(DItem::DR(*a), cons(DItem::DChk(i, *a), ks)), i, rr, sv) {
                            Some((r1, rr1)) => match md(s, f1, ks, i, rr1, sv) {
                                Some((r2, rr2)) => Some((app(r1, r2), rr2)), None => None },
                            None => None },
                        // the body's first result, with its register and saves
                        // (STK_SAVE_VAL is not voided by the cut: regexec.c:1269,
                        // 1276, 2391); the body's other branches are dropped
                        DRe::DAtomic(a) => match md(s, f1, cons(DItem::DR(*a), L::Nil), i, rr, sv) {
                            Some((L::Cons(r, _), _)) => md(s, f1, ks, r.0, r.1, r.2),
                            Some((L::Nil, rr2)) => Some((L::Nil, rr2)),
                            None => None },
                        DRe::DFail => Some((L::Nil, rr)),
                        DRe::DSaveRR(id) => md(s, f1, ks, i, rr, cons((id, rr), sv)),
                        DRe::DSaveS(id) => md(s, f1, ks, i, rr, cons((id, i), sv)),
                        DRe::DUpdRRFromStack(id) => match lookup(id, sv) { Some(v) => md(s, f1, ks, i, v, sv), None => None },
                        DRe::DUpdRRFromS(id) => match lookup(id, sv) { Some(v) => md(s, f1, ks, i, v, sv), None => None },
                        DRe::DUpdSFromStack(id) => match lookup(id, sv) { Some(v) => md(s, f1, ks, v, rr, sv), None => None },
                        DRe::DRRInit => md(s, f1, ks, i, len(s), sv),
                    },
                }
            }
        }
    }
}

// Forward search on the desugared tree; the register starts at the
// subject end at each start (INIT_RIGHT_RANGE, regexec.c:2729, 3278).
pub open spec fn dsearch_from(s: L<nat>, f: nat, d: DRe, k: nat, st: nat) -> SRes decreases k {
    if k == 0 { SRes::NoMatch } else {
        match md(s, f, cons(DItem::DR(d), L::Nil), st, len(s), L::Nil) {
            Some((L::Cons(r, _), _)) => SRes::Match(st, r.0),
            Some((L::Nil, _)) => dsearch_from(s, f, d, (k - 1) as nat, st + 1),
            None => SRes::OutOfFuel,
        }
    }
}
pub open spec fn dsearch(f: nat, main: Re, s: L<nat>) -> SRes { dsearch_from(s, f, desugar(main, 0).0, len(s) + 1, 0) }

} // verus!
