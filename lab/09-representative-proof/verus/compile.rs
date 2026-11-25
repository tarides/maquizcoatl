// Experiment #9, Verus: the compiler (FRAGMENT.md 3), transcribed from
// fstar/Compile.fst, after upstream's compile_tree
// (upstream/src/regcomp.c:2575-2598, alternation),
// compile_bag_memory_node (:1699-1776), compile_quantifier_node
// (:1399-1515, infinite greedy branch, lower = 0, no peephole) and
// compile_quant_body_with_empty_check (:958-1000).
//
// Spec fns, then exec mirrors proved to return the spec fns' results.
// The exec mirrors compute addresses in usize: they return None (or
// false) on overflow, which the driver reports; on success the result
// is the spec's.
use vstd::prelude::*;
use crate::syntax::*;

verus! {

pub open spec fn min(a: nat, b: nat) -> nat { if a <= b { a } else { b } }

// minimal length of a match (upstream node_min_byte_len,
// regcomp.c:5681-5689: the body needs the empty check when it is 0)
pub open spec fn minlen(r: Regex) -> nat
    decreases r,
{
    match r {
        Regex::Eps => 0,
        Regex::Lit(l) => l.len(),
        Regex::Cat(a, b) => minlen(*a) + minlen(*b),
        Regex::Alt(a, b) => min(minlen(*a), minlen(*b)),
        Regex::Star(_) => 0,
        Regex::Group(_, a) => minlen(*a),
    }
}

pub open spec fn nullable(r: Regex) -> bool { minlen(r) == 0 }

// compiled length (upstream compile_length_tree)
pub open spec fn clen(r: Regex) -> nat
    decreases r,
{
    match r {
        Regex::Eps => 0,
        Regex::Lit(l) => if l.len() == 0 { 0 } else { 1 },
        Regex::Cat(a, b) => clen(*a) + clen(*b),
        Regex::Alt(a, b) => clen(*a) + clen(*b) + 2,
        Regex::Star(a) => {
            let n = clen(*a);
            if n == 0 { 0 }                                // regcomp.c:1407, tlen == 0
            else { n + 2 + (if nullable(*a) { 2nat } else { 0nat }) }
        }
        Regex::Group(_, a) => clen(*a) + 2,
    }
}

// number of empty-check ids the code of r uses (upstream
// reg->num_empty_check, incremented in pre-order, regcomp.c:971-974)
pub open spec fn nchecks(r: Regex) -> nat
    decreases r,
{
    match r {
        Regex::Eps => 0,
        Regex::Lit(_) => 0,
        Regex::Cat(a, b) => nchecks(*a) + nchecks(*b),
        Regex::Alt(a, b) => nchecks(*a) + nchecks(*b),
        Regex::Star(a) =>
            if clen(*a) == 0 { 0 }
            else { (if nullable(*a) { 1nat } else { 0nat }) + nchecks(*a) },
        Regex::Group(_, a) => nchecks(*a),
    }
}

// code of r placed at address pc, first free empty-check id eid;
// `push`: r is inside an alternation or a star, so its groups use
// OP_MEM_START_PUSH (upstream IN_ALT | IN_VAR_REPEAT, regcomp.c:5819-5821,
// push_mem_start = backtrack_mem, :7540)
pub open spec fn comp(r: Regex, pc: nat, eid: nat, push: bool) -> Seq<Instr>
    decreases r,
{
    match r {
        Regex::Eps => Seq::empty(),
        Regex::Lit(l) => if l.len() == 0 { Seq::empty() } else { seq![Instr::IStr(l)] },
        Regex::Cat(a, b) => comp(*a, pc, eid, push) + comp(*b, pc + clen(*a), eid + nchecks(*a), push),
        // PUSH L1; a; JUMP end; L1: b; end:  (n-ary upstream layout
        // when alternations nest to the right, as the parser builds them)
        Regex::Alt(a, b) =>
            seq![Instr::IPush(pc + clen(*a) + 2)]
                + (comp(*a, pc + 1, eid, true)
                   + (seq![Instr::IJump(pc + clen(*a) + clen(*b) + 2)]
                      + comp(*b, pc + clen(*a) + 2, eid + nchecks(*a), true))),
        Regex::Star(a) => {
            let n = clen(*a);
            if n == 0 {
                Seq::empty()
            } else if nullable(*a) {
                // L: PUSH out; EMPTY_CHECK_START id; a; EMPTY_CHECK_END id; JUMP L; out:
                seq![Instr::IPush(pc + n + 4), Instr::IEmptyStart(eid)]
                    + (comp(*a, pc + 2, eid + 1, true) + seq![Instr::IEmptyEnd(eid), Instr::IJump(pc)])
            } else {
                // L: PUSH out; a; JUMP L; out:
                seq![Instr::IPush(pc + n + 2)] + (comp(*a, pc + 1, eid, true) + seq![Instr::IJump(pc)])
            }
        }
        Regex::Group(k, a) =>
            seq![if push { Instr::IMemStartPush(k) } else { Instr::IMemStart(k) }]
                + (comp(*a, pc + 1, eid, push) + seq![Instr::IMemEnd(k)]),
    }
}

pub open spec fn compile(r: Regex) -> Seq<Instr> { comp(r, 0, 0, false) + seq![Instr::IEnd] }

// ---- exec mirror ----

fn add(a: usize, b: usize) -> (o: Option<usize>)
    ensures o matches Some(c) ==> c == a + b,
{
    if a <= usize::MAX - b { Some(a + b) } else { None }
}

pub fn enullable(r: &ERegex) -> (b: bool)
    ensures b == nullable(rv(*r)),
    decreases r,
{
    match r {
        ERegex::Eps => true,
        ERegex::Lit(l) => l.len() == 0,
        ERegex::Cat(a, b) => enullable(a) && enullable(b),
        ERegex::Alt(a, b) => enullable(a) || enullable(b),
        ERegex::Star(_) => true,
        ERegex::Group(_, a) => enullable(a),
    }
}

pub fn eclen(r: &ERegex) -> (o: Option<usize>)
    ensures o matches Some(n) ==> n == clen(rv(*r)),
    decreases r,
{
    match r {
        ERegex::Eps => Some(0),
        ERegex::Lit(l) => if l.len() == 0 { Some(0) } else { Some(1) },
        ERegex::Cat(a, b) => match (eclen(a), eclen(b)) {
            (Some(x), Some(y)) => add(x, y),
            _ => None,
        },
        ERegex::Alt(a, b) => match (eclen(a), eclen(b)) {
            (Some(x), Some(y)) => match add(x, y) { Some(z) => add(z, 2), None => None },
            _ => None,
        },
        ERegex::Star(a) => match eclen(a) {
            Some(n) => if n == 0 { Some(0) } else { add(n, if enullable(a) { 4 } else { 2 }) },
            None => None,
        },
        ERegex::Group(_, a) => match eclen(a) { Some(n) => add(n, 2), None => None },
    }
}

pub fn enchecks(r: &ERegex) -> (o: Option<usize>)
    ensures o matches Some(n) ==> n == nchecks(rv(*r)),
    decreases r,
{
    match r {
        ERegex::Eps => Some(0),
        ERegex::Lit(_) => Some(0),
        ERegex::Cat(a, b) | ERegex::Alt(a, b) => match (enchecks(a), enchecks(b)) {
            (Some(x), Some(y)) => add(x, y),
            _ => None,
        },
        ERegex::Star(a) => match (eclen(a), enchecks(a)) {
            (Some(n), Some(c)) => if n == 0 { Some(0) } else { add(if enullable(a) { 1 } else { 0 }, c) },
            _ => None,
        },
        ERegex::Group(_, a) => enchecks(a),
    }
}

// appends the code of r to `out`; false on address overflow.  One
// helper per compound construct (each re-matches r), to keep each
// function's verification condition small.
pub fn ecomp<'a>(r: &'a ERegex, pc: usize, eid: usize, push: bool, out: &mut Vec<EInstr<'a>>) -> (ok: bool)
    ensures ok ==> insv(final(out)@) == insv(old(out)@) + comp(rv(*r), pc as nat, eid as nat, push),
    decreases r, 1nat,
{
    let ghost o0 = insv(out@);
    match r {
        ERegex::Eps => {
            assert(insv(out@) =~= o0 + Seq::<Instr>::empty());
            true
        }
        ERegex::Lit(l) => {
            if l.len() == 0 {
                assert(insv(out@) =~= o0 + Seq::<Instr>::empty());
            } else {
                out.push(EInstr::IStr(l));
                assert(insv(out@) =~= o0 + seq![Instr::IStr(l@)]);
            }
            true
        }
        ERegex::Cat(_, _) => ecomp_cat(r, pc, eid, push, out),
        ERegex::Alt(_, _) => ecomp_alt(r, pc, eid, push, out),
        ERegex::Star(_) => ecomp_star(r, pc, eid, push, out),
        ERegex::Group(_, _) => ecomp_group(r, pc, eid, push, out),
    }
}

fn ecomp_cat<'a>(r: &'a ERegex, pc: usize, eid: usize, push: bool, out: &mut Vec<EInstr<'a>>) -> (ok: bool)
    ensures ok ==> insv(final(out)@) == insv(old(out)@) + comp(rv(*r), pc as nat, eid as nat, push),
    decreases r, 0nat,
{
    let ghost o0 = insv(out@);
    match r {
        ERegex::Cat(a, b) => {
            let ca = match eclen(a) { Some(x) => x, None => { return false; } };
            let na = match enchecks(a) { Some(x) => x, None => { return false; } };
            let pb = match add(pc, ca) { Some(x) => x, None => { return false; } };
            let eb = match add(eid, na) { Some(x) => x, None => { return false; } };
            if !ecomp(a, pc, eid, push, out) { return false; }
            let ghost o1 = insv(out@);
            if !ecomp(b, pb, eb, push, out) { return false; }
            assert(insv(out@) =~= o0 + comp(rv(*r), pc as nat, eid as nat, push));
            true
        }
        _ => false,
    }
}

fn ecomp_alt<'a>(r: &'a ERegex, pc: usize, eid: usize, push: bool, out: &mut Vec<EInstr<'a>>) -> (ok: bool)
    ensures ok ==> insv(final(out)@) == insv(old(out)@) + comp(rv(*r), pc as nat, eid as nat, push),
    decreases r, 0nat,
{
    let ghost o0 = insv(out@);
    match r {
        ERegex::Alt(a, b) => {
            let ca = match eclen(a) { Some(x) => x, None => { return false; } };
            let cb = match eclen(b) { Some(x) => x, None => { return false; } };
            let na = match enchecks(a) { Some(x) => x, None => { return false; } };
            let t1 = match add(pc, ca) { Some(x) => match add(x, 2) { Some(y) => y, None => { return false; } }, None => { return false; } };
            let t2 = match add(t1, cb) { Some(x) => x, None => { return false; } };
            let pa = match add(pc, 1) { Some(x) => x, None => { return false; } };
            let eb = match add(eid, na) { Some(x) => x, None => { return false; } };
            out.push(EInstr::IPush(t1));
            let ghost o1 = insv(out@);
            assert(o1 =~= o0 + seq![Instr::IPush(t1 as nat)]);
            if !ecomp(a, pa, eid, true, out) { return false; }
            let ghost o2 = insv(out@);
            out.push(EInstr::IJump(t2));
            let ghost o3 = insv(out@);
            assert(o3 =~= o2 + seq![Instr::IJump(t2 as nat)]);
            if !ecomp(b, t1, eb, true, out) { return false; }
            assert(insv(out@) =~= o0 + comp(rv(*r), pc as nat, eid as nat, push));
            true
        }
        _ => false,
    }
}

fn ecomp_star<'a>(r: &'a ERegex, pc: usize, eid: usize, push: bool, out: &mut Vec<EInstr<'a>>) -> (ok: bool)
    ensures ok ==> insv(final(out)@) == insv(old(out)@) + comp(rv(*r), pc as nat, eid as nat, push),
    decreases r, 0nat,
{
    let ghost o0 = insv(out@);
    match r {
        ERegex::Star(a) => {
            let n = match eclen(a) { Some(x) => x, None => { return false; } };
            if n == 0 {
                assert(insv(out@) =~= o0 + Seq::<Instr>::empty());
                return true;
            }
            if enullable(a) {
                let t = match add(pc, n) { Some(x) => match add(x, 4) { Some(y) => y, None => { return false; } }, None => { return false; } };
                let pa = match add(pc, 2) { Some(x) => x, None => { return false; } };
                let ea = match add(eid, 1) { Some(x) => x, None => { return false; } };
                out.push(EInstr::IPush(t));
                out.push(EInstr::IEmptyStart(eid));
                let ghost o1 = insv(out@);
                assert(o1 =~= o0 + seq![Instr::IPush(t as nat), Instr::IEmptyStart(eid as nat)]);
                if !ecomp(a, pa, ea, true, out) { return false; }
                let ghost o2 = insv(out@);
                out.push(EInstr::IEmptyEnd(eid));
                out.push(EInstr::IJump(pc));
                assert(insv(out@) =~= o2 + seq![Instr::IEmptyEnd(eid as nat), Instr::IJump(pc as nat)]);
                assert(insv(out@) =~= o0 + comp(rv(*r), pc as nat, eid as nat, push));
            } else {
                let t = match add(pc, n) { Some(x) => match add(x, 2) { Some(y) => y, None => { return false; } }, None => { return false; } };
                let pa = match add(pc, 1) { Some(x) => x, None => { return false; } };
                out.push(EInstr::IPush(t));
                let ghost o1 = insv(out@);
                assert(o1 =~= o0 + seq![Instr::IPush(t as nat)]);
                if !ecomp(a, pa, eid, true, out) { return false; }
                let ghost o2 = insv(out@);
                out.push(EInstr::IJump(pc));
                assert(insv(out@) =~= o2 + seq![Instr::IJump(pc as nat)]);
                assert(insv(out@) =~= o0 + comp(rv(*r), pc as nat, eid as nat, push));
            }
            true
        }
        _ => false,
    }
}

fn ecomp_group<'a>(r: &'a ERegex, pc: usize, eid: usize, push: bool, out: &mut Vec<EInstr<'a>>) -> (ok: bool)
    ensures ok ==> insv(final(out)@) == insv(old(out)@) + comp(rv(*r), pc as nat, eid as nat, push),
    decreases r, 0nat,
{
    let ghost o0 = insv(out@);
    match r {
        ERegex::Group(k, a) => {
            let pa = match add(pc, 1) { Some(x) => x, None => { return false; } };
            out.push(if push { EInstr::IMemStartPush(*k) } else { EInstr::IMemStart(*k) });
            let ghost o1 = insv(out@);
            assert(o1 =~= o0 + seq![if push { Instr::IMemStartPush(*k as nat) } else { Instr::IMemStart(*k as nat) }]);
            if !ecomp(a, pa, eid, push, out) { return false; }
            let ghost o2 = insv(out@);
            out.push(EInstr::IMemEnd(*k));
            assert(insv(out@) =~= o2 + seq![Instr::IMemEnd(*k as nat)]);
            assert(insv(out@) =~= o0 + comp(rv(*r), pc as nat, eid as nat, push));
            true
        }
        _ => false,
    }
}

pub fn ecompile<'a>(r: &'a ERegex) -> (o: Option<Vec<EInstr<'a>>>)
    ensures o matches Some(c) ==> insv(c@) == compile(rv(*r)),
{
    let mut out: Vec<EInstr<'a>> = Vec::new();
    assert(insv(out@) =~= Seq::<Instr>::empty());
    if !ecomp(r, 0, 0, false, &mut out) {
        return None;
    }
    let ghost o1 = insv(out@);
    out.push(EInstr::IEnd);
    assert(insv(out@) =~= o1 + seq![Instr::IEnd]);
    Some(out)
}

} // verus!
