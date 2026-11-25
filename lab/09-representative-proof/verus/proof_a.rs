// Experiment #9, Verus M2, lemma (a): compiler invariants (FRAGMENT.md 8),
// after fstar/ProofA.fst and rocq/ProofA.v (same statements, Verus proof).
// Also the Seq facts the other proof modules use: a list's head is the
// last element of the Seq, so `cons` is `push` and `tail` is `drop_last`
// (lemma_push_last), and the capture maps are looked up from the end
// (lemma_mget_mset, lemma_gget_gset).  `code_at code pc l` says that `l`
// sits in `code` at address `pc`; the layout lemmas give the instructions
// of each construct at their addresses, as the simulation (proof_sim.rs)
// reads them.
use vstd::prelude::*;
use crate::syntax::*;
use crate::sem::*;
use crate::compile::*;
use crate::vm::*;

verus! {

// ---- Seq as a list with its head at the end ----

pub broadcast proof fn lemma_push_last<A>(k: Seq<A>, x: A)
    ensures
        #[trigger] k.push(x).drop_last() == k,
        k.push(x).last() == x,
{
    assert(k.push(x).drop_last() =~= k);
}

pub broadcast proof fn lemma_mget_mset(k: nat, n: nat, v: Cap, m: MCaps)
    ensures #[trigger] mget(k, mset(n, v, m)) == (if k == n { v } else { mget(k, m) }),
{
    broadcast use lemma_push_last;
}

pub broadcast proof fn lemma_gget_gset(k: nat, n: nat, v: (nat, nat), g: GMap)
    ensures #[trigger] gget(k, gset(n, v, g)) == (if k == n { Some(v) } else { gget(k, g) }),
{
    broadcast use lemma_push_last;
}

pub broadcast group group_lists {
    lemma_push_last,
    lemma_mget_mset,
    lemma_gget_gset,
}

// ---- code length ----

pub proof fn length_comp(r: Regex, pc: nat, eid: nat, push: bool)
    ensures comp(r, pc, eid, push).len() == clen(r),
    decreases r,
{
    match r {
        Regex::Eps => {}
        Regex::Lit(_) => {}
        Regex::Cat(a, b) => {
            length_comp(*a, pc, eid, push);
            length_comp(*b, pc + clen(*a), eid + nchecks(*a), push);
        }
        Regex::Alt(a, b) => {
            length_comp(*a, pc + 1, eid, true);
            length_comp(*b, pc + clen(*a) + 2, eid + nchecks(*a), true);
        }
        Regex::Star(a) => {
            if clen(*a) != 0 {
                if nullable(*a) {
                    length_comp(*a, pc + 2, eid + 1, true);
                } else {
                    length_comp(*a, pc + 1, eid, true);
                }
            }
        }
        Regex::Group(_, a) => {
            length_comp(*a, pc + 1, eid, push);
        }
    }
}

// ---- l sits in code at address pc ----

pub open spec fn code_at(code: Seq<Instr>, pc: nat, l: Seq<Instr>) -> bool {
    pc + l.len() <= code.len() && forall|i: int| 0 <= i < l.len() ==> code[pc + i] == #[trigger] l[i]
}

pub proof fn code_at_app(code: Seq<Instr>, pc: nat, l1: Seq<Instr>, l2: Seq<Instr>)
    requires code_at(code, pc, l1 + l2),
    ensures code_at(code, pc, l1), code_at(code, pc + l1.len(), l2),
{
    assert forall|i: int| 0 <= i < l1.len() implies code[pc + i] == #[trigger] l1[i] by {
        assert((l1 + l2)[i] == l1[i]);
    }
    assert forall|i: int| 0 <= i < l2.len() implies code[pc + l1.len() + i] == #[trigger] l2[i] by {
        assert((l1 + l2)[l1.len() + i] == l2[i]);
    }
}

pub proof fn code_at_one(code: Seq<Instr>, pc: nat, x: Instr)
    requires code_at(code, pc, seq![x]),
    ensures nth(code, pc) == Some(x),
{
    assert(seq![x][0] == x);
}

// ---- layouts ----

pub proof fn code_lit(code: Seq<Instr>, l: Seq<u8>, pc: nat, eid: nat, push: bool)
    requires l.len() != 0, code_at(code, pc, comp(Regex::Lit(l), pc, eid, push)),
    ensures nth(code, pc) == Some(Instr::IStr(l)),
{
    code_at_one(code, pc, Instr::IStr(l));
}

pub proof fn code_cat(code: Seq<Instr>, a: Regex, b: Regex, pc: nat, eid: nat, push: bool)
    requires code_at(code, pc, comp(Regex::Cat(Box::new(a), Box::new(b)), pc, eid, push)),
    ensures
        code_at(code, pc, comp(a, pc, eid, push)),
        code_at(code, pc + clen(a), comp(b, pc + clen(a), eid + nchecks(a), push)),
{
    length_comp(a, pc, eid, push);
    code_at_app(code, pc, comp(a, pc, eid, push), comp(b, pc + clen(a), eid + nchecks(a), push));
}

pub proof fn code_alt(code: Seq<Instr>, a: Regex, b: Regex, pc: nat, eid: nat, push: bool)
    requires code_at(code, pc, comp(Regex::Alt(Box::new(a), Box::new(b)), pc, eid, push)),
    ensures
        nth(code, pc) == Some(Instr::IPush(pc + clen(a) + 2)),
        code_at(code, pc + 1, comp(a, pc + 1, eid, true)),
        nth(code, pc + 1 + clen(a)) == Some(Instr::IJump(pc + clen(a) + clen(b) + 2)),
        code_at(code, pc + clen(a) + 2, comp(b, pc + clen(a) + 2, eid + nchecks(a), true)),
{
    let ca = comp(a, pc + 1, eid, true);
    let cb = comp(b, pc + clen(a) + 2, eid + nchecks(a), true);
    let j = seq![Instr::IJump(pc + clen(a) + clen(b) + 2)];
    length_comp(a, pc + 1, eid, true);
    code_at_app(code, pc, seq![Instr::IPush(pc + clen(a) + 2)], ca + (j + cb));
    code_at_one(code, pc, Instr::IPush(pc + clen(a) + 2));
    code_at_app(code, pc + 1, ca, j + cb);
    code_at_app(code, pc + 1 + clen(a), j, cb);
    code_at_one(code, pc + 1 + clen(a), Instr::IJump(pc + clen(a) + clen(b) + 2));
}

pub proof fn code_group(code: Seq<Instr>, n: nat, a: Regex, pc: nat, eid: nat, push: bool)
    requires code_at(code, pc, comp(Regex::Group(n, Box::new(a)), pc, eid, push)),
    ensures
        nth(code, pc) == Some(if push { Instr::IMemStartPush(n) } else { Instr::IMemStart(n) }),
        code_at(code, pc + 1, comp(a, pc + 1, eid, push)),
        nth(code, pc + 1 + clen(a)) == Some(Instr::IMemEnd(n)),
{
    let i0 = if push { Instr::IMemStartPush(n) } else { Instr::IMemStart(n) };
    let ca = comp(a, pc + 1, eid, push);
    length_comp(a, pc + 1, eid, push);
    code_at_app(code, pc, seq![i0], ca + seq![Instr::IMemEnd(n)]);
    code_at_one(code, pc, i0);
    code_at_app(code, pc + 1, ca, seq![Instr::IMemEnd(n)]);
    code_at_one(code, pc + 1 + clen(a), Instr::IMemEnd(n));
}

pub proof fn code_star_null(code: Seq<Instr>, a: Regex, l: nat, eid: nat, push: bool)
    requires
        clen(a) != 0, nullable(a),
        code_at(code, l, comp(Regex::Star(Box::new(a)), l, eid, push)),
    ensures
        nth(code, l) == Some(Instr::IPush(l + clen(a) + 4)),
        nth(code, l + 1) == Some(Instr::IEmptyStart(eid)),
        code_at(code, l + 2, comp(a, l + 2, eid + 1, true)),
        nth(code, l + 2 + clen(a)) == Some(Instr::IEmptyEnd(eid)),
        nth(code, l + 3 + clen(a)) == Some(Instr::IJump(l)),
        clen(Regex::Star(Box::new(a))) == clen(a) + 4,
        nchecks(Regex::Star(Box::new(a))) == nchecks(a) + 1,
{
    let ca = comp(a, l + 2, eid + 1, true);
    let h = seq![Instr::IPush(l + clen(a) + 4), Instr::IEmptyStart(eid)];
    let e = seq![Instr::IEmptyEnd(eid), Instr::IJump(l)];
    length_comp(a, l + 2, eid + 1, true);
    code_at_app(code, l, h, ca + e);
    assert(h[0] == Instr::IPush(l + clen(a) + 4) && h[1] == Instr::IEmptyStart(eid));
    code_at_app(code, l + 2, ca, e);
    assert(e[0] == Instr::IEmptyEnd(eid) && e[1] == Instr::IJump(l));
}

pub proof fn code_star_nn(code: Seq<Instr>, a: Regex, l: nat, eid: nat, push: bool)
    requires
        clen(a) != 0, !nullable(a),
        code_at(code, l, comp(Regex::Star(Box::new(a)), l, eid, push)),
    ensures
        nth(code, l) == Some(Instr::IPush(l + clen(a) + 2)),
        code_at(code, l + 1, comp(a, l + 1, eid, true)),
        nth(code, l + 1 + clen(a)) == Some(Instr::IJump(l)),
        clen(Regex::Star(Box::new(a))) == clen(a) + 2,
        nchecks(Regex::Star(Box::new(a))) == nchecks(a),
{
    let ca = comp(a, l + 1, eid, true);
    length_comp(a, l + 1, eid, true);
    code_at_app(code, l, seq![Instr::IPush(l + clen(a) + 2)], ca + seq![Instr::IJump(l)]);
    code_at_one(code, l, Instr::IPush(l + clen(a) + 2));
    code_at_app(code, l + 1, ca, seq![Instr::IJump(l)]);
    code_at_one(code, l + 1 + clen(a), Instr::IJump(l));
}

// the whole program: the pattern's code at 0, then OP_END
pub proof fn code_compile(r: Regex)
    ensures
        code_at(compile(r), 0, comp(r, 0, 0, false)),
        nth(compile(r), clen(r)) == Some(Instr::IEnd),
{
    let c = comp(r, 0, 0, false);
    length_comp(r, 0, 0, false);
    assert forall|i: int| 0 <= i < c.len() implies compile(r)[0 + i] == #[trigger] c[i] by {
        assert((c + seq![Instr::IEnd])[i] == c[i]);
    }
    assert((c + seq![Instr::IEnd])[c.len() as int] == Instr::IEnd);
}

} // verus!
