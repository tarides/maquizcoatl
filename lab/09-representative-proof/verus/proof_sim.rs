// Experiment #9, Verus M2, lemmas (b) and (c): the VM simulates the
// backtracking tree (FRAGMENT.md 8), after fstar/ProofSim.fst and
// rocq/ProofSim.v (same invariants, Verus proof).  `Rep` is a derivation
// of "the code at pc implements the pending actions": `ARe r` by `comp
// r`, `AClose n` by OP_MEM_END, `ACheck p0 a` by the end of a star's
// iteration (its OP_EMPTY_CHECK_END, whose OP_EMPTY_CHECK_START entry
// holds p0, or, for a body that cannot match the empty string, the
// loop's OP_JUMP); OP_JUMPs may come in between.  Rocq and F* make it an
// inductive relation; here it is a datatype (the derivation) checked by
// the spec fn `rep`, with the indices it determines (pc, pending actions,
// the empty-check ids `hp` the pending checks need on the stack, the
// non-push groups `hx` still to be entered) computed from it.  `sim` is
// proved by induction on the fuel of `compute_tree`, then on the
// derivation; its Star and ACheck cases are lemma (c).  As in F*, `sim`
// and its case functions return their witnesses (number of VM steps,
// final captures) instead of stating existentials.  Group numbers are
// handled as sets (`gsr`, `gs`, `topg`), and `gd_of` links them to the
// statement's `groups(r).no_duplicates()`.
use vstd::prelude::*;
use crate::syntax::*;
use crate::sem::*;
use crate::compile::*;
use crate::vm::*;
use crate::statement::*;
use crate::proof_a::*;
use crate::proof_sem::*;

verus! {

broadcast use group_lists;

// ---- group numbers ----

pub open spec fn disj(a: Set<nat>, b: Set<nat>) -> bool {
    forall|x: nat| #[trigger] a.contains(x) ==> !b.contains(x)
}

pub open spec fn gsr(r: Regex) -> Set<nat>
    decreases r,
{
    match r {
        Regex::Eps => Set::empty(),
        Regex::Lit(_) => Set::empty(),
        Regex::Cat(a, b) => gsr(*a).union(gsr(*b)),
        Regex::Alt(a, b) => gsr(*a).union(gsr(*b)),
        Regex::Star(a) => gsr(*a),
        Regex::Group(k, a) => gsr(*a).insert(k),
    }
}

// distinct group numbers, on sets
pub open spec fn gd(r: Regex) -> bool
    decreases r,
{
    match r {
        Regex::Eps => true,
        Regex::Lit(_) => true,
        Regex::Cat(a, b) => gd(*a) && gd(*b) && disj(gsr(*a), gsr(*b)),
        Regex::Alt(a, b) => gd(*a) && gd(*b) && disj(gsr(*a), gsr(*b)),
        Regex::Star(a) => gd(*a),
        Regex::Group(k, a) => gd(*a) && !gsr(*a).contains(k),
    }
}

pub proof fn lemma_contains_add(a: Seq<nat>, b: Seq<nat>, x: nat)
    ensures (a + b).contains(x) == (a.contains(x) || b.contains(x)),
{
    if a.contains(x) {
        let i = choose|i: int| 0 <= i < a.len() && a[i] == x;
        assert((a + b)[i] == x);
    }
    if b.contains(x) {
        let j = choose|j: int| 0 <= j < b.len() && b[j] == x;
        assert((a + b)[a.len() + j] == x);
    }
    if (a + b).contains(x) {
        let i = choose|i: int| 0 <= i < (a + b).len() && (a + b)[i] == x;
        if i < a.len() {
            assert(a[i] == x);
        } else {
            assert(b[i - a.len()] == x);
        }
    }
}

pub proof fn gsr_groups(r: Regex)
    ensures forall|x: nat| #[trigger] gsr(r).contains(x) == groups(r).contains(x),
    decreases r,
{
    match r {
        Regex::Eps => {
            assert(groups(r) =~= Seq::<nat>::empty());
        }
        Regex::Lit(_) => {
            assert(groups(r) =~= Seq::<nat>::empty());
        }
        Regex::Cat(a, b) => {
            gsr_groups(*a);
            gsr_groups(*b);
            assert(gsr(r) == gsr(*a).union(gsr(*b)));
            assert(groups(r) == groups(*a) + groups(*b));
            assert forall|x: nat| #[trigger] gsr(r).contains(x) == groups(r).contains(x) by {
                lemma_contains_add(groups(*a), groups(*b), x);
            }
        }
        Regex::Alt(a, b) => {
            gsr_groups(*a);
            gsr_groups(*b);
            assert(gsr(r) == gsr(*a).union(gsr(*b)));
            assert(groups(r) == groups(*a) + groups(*b));
            assert forall|x: nat| #[trigger] gsr(r).contains(x) == groups(r).contains(x) by {
                lemma_contains_add(groups(*a), groups(*b), x);
            }
        }
        Regex::Star(a) => {
            gsr_groups(*a);
            assert(gsr(r) == gsr(*a) && groups(r) == groups(*a));
        }
        Regex::Group(k, a) => {
            gsr_groups(*a);
            assert(gsr(r) == gsr(*a).insert(k));
            assert(groups(r) == seq![k] + groups(*a));
            assert forall|x: nat| #[trigger] gsr(r).contains(x) == groups(r).contains(x) by {
                lemma_contains_add(seq![k], groups(*a), x);
                assert(seq![k][0] == k);
            }
        }
    }
}

pub proof fn disj_sub(a: Set<nat>, b: Set<nat>, c: Set<nat>)
    requires disj(b, c), forall|x: nat| a.contains(x) ==> #[trigger] b.contains(x),
    ensures disj(a, c),
{
    assert forall|x: nat| #[trigger] a.contains(x) implies !c.contains(x) by {
        assert(b.contains(x));
    }
}

pub proof fn disj_union(a: Set<nat>, b: Set<nat>, c: Set<nat>)
    requires disj(a, b), disj(a, c),
    ensures disj(a, b.union(c)),
{
}

pub proof fn nodup_add(a: Seq<nat>, b: Seq<nat>)
    requires (a + b).no_duplicates(),
    ensures a.no_duplicates(), b.no_duplicates(), forall|x: nat| a.contains(x) ==> !b.contains(x),
{
    assert forall|i: int, j: int| 0 <= i < a.len() && 0 <= j < a.len() && i != j implies a[i] != a[j] by {
        assert((a + b)[i] == a[i] && (a + b)[j] == a[j]);
    }
    assert forall|i: int, j: int| 0 <= i < b.len() && 0 <= j < b.len() && i != j implies b[i] != b[j] by {
        assert((a + b)[a.len() + i] == b[i] && (a + b)[a.len() + j] == b[j]);
    }
    assert forall|x: nat| a.contains(x) implies !b.contains(x) by {
        if b.contains(x) {
            let i = choose|i: int| 0 <= i < a.len() && a[i] == x;
            let j = choose|j: int| 0 <= j < b.len() && b[j] == x;
            assert((a + b)[i] == x && (a + b)[a.len() + j] == x);
        }
    }
}

pub proof fn gd_of(r: Regex)
    requires groups(r).no_duplicates(),
    ensures gd(r),
    decreases r,
{
    match r {
        Regex::Eps => {}
        Regex::Lit(_) => {}
        Regex::Cat(a, b) => {
            nodup_add(groups(*a), groups(*b));
            gd_of(*a);
            gd_of(*b);
            gsr_groups(*a);
            gsr_groups(*b);
        }
        Regex::Alt(a, b) => {
            nodup_add(groups(*a), groups(*b));
            gd_of(*a);
            gd_of(*b);
            gsr_groups(*a);
            gsr_groups(*b);
        }
        Regex::Star(a) => gd_of(*a),
        Regex::Group(k, a) => {
            nodup_add(seq![k], groups(*a));
            assert(seq![k][0] == k);
            assert(seq![k].contains(k));
            gd_of(*a);
            gsr_groups(*a);
        }
    }
}

// ---- captures ----

// the capture a VM slot reports (vm::region)
pub open spec fn capv(v: Cap) -> Span {
    match v {
        (Some(a), Some(b)) => Some((a, b)),
        _ => None,
    }
}

// the groups opened on the current path and not yet closed
pub open spec fn cls(acts: Seq<Action>) -> Seq<(nat, nat)>
    decreases acts.len(),
{
    if acts.len() == 0 {
        Seq::empty()
    } else {
        match acts.last() {
            Action::AClose(n, p) => cls(acts.drop_last()).push((n, p)),
            _ => cls(acts.drop_last()),
        }
    }
}

pub open spec fn cget(k: nat, c: Seq<(nat, nat)>) -> Option<nat>
    decreases c.len(),
{
    if c.len() == 0 {
        None
    } else if c.last().0 == k {
        Some(c.last().1)
    } else {
        cget(k, c.drop_last())
    }
}

pub broadcast proof fn lemma_cget_push(k: nat, c: Seq<(nat, nat)>, n: nat, p: nat)
    ensures #[trigger] cget(k, c.push((n, p))) == (if k == n { Some(p) } else { cget(k, c) }),
{
}

// the captures relation at group k: groups in x are free; an open group
// has its start; every other group has the semantics' span
pub open spec fn capsrel_at(m: MCaps, g: GMap, c: Seq<(nat, nat)>, x: Set<nat>, k: nat) -> bool {
    !x.contains(k) ==> match cget(k, c) {
        Some(p) => mget(k, m).0 == Some(p),
        None => capv(mget(k, m)) == gget(k, g),
    }
}

#[verifier::opaque]
pub open spec fn capsrel(m: MCaps, g: GMap, c: Seq<(nat, nat)>, x: Set<nat>) -> bool {
    forall|k: nat| #[trigger] capsrel_at(m, g, c, x, k)
}

// what a failed attempt may leave changed in the captures
pub open spec fn meq_at(c: Seq<(nat, nat)>, x: Set<nat>, m1: MCaps, m: MCaps, k: nat) -> bool {
    mget(k, m1) == mget(k, m) || x.contains(k) || (cget(k, c) is Some && mget(k, m1).0 == mget(k, m).0)
}

#[verifier::opaque]
pub open spec fn meq(c: Seq<(nat, nat)>, x: Set<nat>, m1: MCaps, m: MCaps) -> bool {
    forall|k: nat| #[trigger] meq_at(c, x, m1, m, k)
}

// the VM's captures report the semantics' spans
pub open spec fn capeq(m: MCaps, g: GMap) -> bool {
    forall|k: nat| #![trigger mget(k, m)] capv(mget(k, m)) == gget(k, g)
}

// group numbers on the pending path; none repeats
pub open spec fn gs(acts: Seq<Action>) -> Set<nat>
    decreases acts.len(),
{
    if acts.len() == 0 {
        Set::empty()
    } else {
        match acts.last() {
            Action::ARe(r) => gsr(r).union(gs(acts.drop_last())),
            Action::AClose(n, _) => gs(acts.drop_last()).insert(n),
            Action::ACheck(_, _) => gs(acts.drop_last()),
        }
    }
}

pub open spec fn uniq(acts: Seq<Action>) -> bool
    decreases acts.len(),
{
    if acts.len() == 0 {
        true
    } else {
        let k = acts.drop_last();
        match acts.last() {
            Action::ARe(r) => gd(r) && disj(gsr(r), gs(k)) && uniq(k),
            Action::ACheck(_, a) => gd(a) && disj(gsr(a), gs(k)) && uniq(k),
            Action::AClose(n, _) => !gs(k).contains(n) && uniq(k),
        }
    }
}

// the non-push groups of a pattern entered on every path
pub open spec fn topg(r: Regex) -> Set<nat>
    decreases r,
{
    match r {
        Regex::Cat(a, b) => topg(*a).union(topg(*b)),
        Regex::Group(n, a) => topg(*a).insert(n),
        _ => Set::empty(),
    }
}

pub open spec fn npg(r: Regex, push: bool) -> Set<nat> {
    if push { Set::empty() } else { topg(r) }
}

pub open spec fn fresh(eid: nat, n: nat, p: Set<nat>) -> bool {
    forall|i: nat| #[trigger] p.contains(i) ==> (i < eid || eid + n <= i)
}

pub proof fn cls_none(n: nat, k: Seq<Action>)
    requires !gs(k).contains(n),
    ensures cget(n, cls(k)) == None::<nat>,
    decreases k.len(),
{
    broadcast use lemma_cget_push;
    if k.len() != 0 {
        cls_none(n, k.drop_last());
    }
}

pub proof fn meq_refl(c: Seq<(nat, nat)>, x: Set<nat>, m: MCaps)
    ensures meq(c, x, m, m),
{
    reveal(meq);
    assert forall|k: nat| #[trigger] meq_at(c, x, m, m, k) by {}
}

pub proof fn meq_trans(c: Seq<(nat, nat)>, x: Set<nat>, m2: MCaps, m1: MCaps, m: MCaps)
    requires meq(c, x, m2, m1), meq(c, x, m1, m),
    ensures meq(c, x, m2, m),
{
    reveal(meq);
    assert forall|k: nat| #[trigger] meq_at(c, x, m2, m, k) by {
        assert(meq_at(c, x, m2, m1, k) && meq_at(c, x, m1, m, k));
    }
}

pub proof fn capsrel_meq(m: MCaps, g: GMap, c: Seq<(nat, nat)>, x: Set<nat>, m1: MCaps)
    requires capsrel(m, g, c, x), meq(c, x, m1, m),
    ensures capsrel(m1, g, c, x),
{
    reveal(capsrel);
    reveal(meq);
    assert forall|k: nat| #[trigger] capsrel_at(m1, g, c, x, k) by {
        assert(capsrel_at(m, g, c, x, k) && meq_at(c, x, m1, m, k));
    }
}

pub proof fn capsrel_open(m: MCaps, g: GMap, c: Seq<(nat, nat)>, x: Set<nat>, x2: Set<nat>, n: nat, pos: nat, v: Cap)
    requires
        capsrel(m, g, c, x), cget(n, c) == None::<nat>, v.0 == Some(pos),
        forall|k: nat| k != n && !x2.contains(k) ==> !(#[trigger] x.contains(k)),
    ensures capsrel(mset(n, v, m), g, c.push((n, pos)), x2),
{
    broadcast use lemma_cget_push;
    reveal(capsrel);
    assert forall|k: nat| #[trigger] capsrel_at(mset(n, v, m), g, c.push((n, pos)), x2, k) by {
        assert(capsrel_at(m, g, c, x, k));
        if k != n && !x2.contains(k) {
            assert(!x.contains(k));
        }
    }
}

// failure through OP_MEM_START_PUSH: the popped entry restores group n
pub proof fn meq_push(c: Seq<(nat, nat)>, x: Set<nat>, m1: MCaps, m: MCaps, n: nat, pos: nat)
    requires meq(c.push((n, pos)), x, m1, mset(n, (Some(pos), None), m)),
    ensures meq(c, x, mset(n, mget(n, m), m1), m),
{
    broadcast use lemma_cget_push;
    reveal(meq);
    assert forall|k: nat| #[trigger] meq_at(c, x, mset(n, mget(n, m), m1), m, k) by {
        assert(meq_at(c.push((n, pos)), x, m1, mset(n, (Some(pos), None), m), k));
    }
}

// failure through OP_MEM_START: group n is free again
pub proof fn meq_nopush(c: Seq<(nat, nat)>, x: Set<nat>, m1: MCaps, m: MCaps, n: nat, pos: nat, v: Cap)
    requires meq(c.push((n, pos)), x, m1, mset(n, v, m)),
    ensures meq(c, x.insert(n), m1, m),
{
    broadcast use lemma_cget_push;
    reveal(meq);
    assert forall|k: nat| #[trigger] meq_at(c, x.insert(n), m1, m, k) by {
        assert(meq_at(c.push((n, pos)), x, m1, mset(n, v, m), k));
    }
}

pub proof fn capsrel_close(m: MCaps, g: GMap, c: Seq<(nat, nat)>, x: Set<nat>, n: nat, p0: nat, pos: nat)
    requires capsrel(m, g, c.push((n, p0)), x), cget(n, c) == None::<nat>,
    ensures capsrel(mset(n, (mget(n, m).0, Some(pos)), m), gset(n, (p0, pos), g), c, x),
{
    broadcast use lemma_cget_push;
    reveal(capsrel);
    assert forall|k: nat| #[trigger] capsrel_at(mset(n, (mget(n, m).0, Some(pos)), m), gset(n, (p0, pos), g), c, x, k) by {
        assert(capsrel_at(m, g, c.push((n, p0)), x, k));
    }
}

pub proof fn meq_close(c: Seq<(nat, nat)>, x: Set<nat>, m1: MCaps, m: MCaps, n: nat, p0: nat, pos: nat)
    requires meq(c, x, m1, mset(n, (mget(n, m).0, Some(pos)), m)),
    ensures meq(c.push((n, p0)), x, m1, m),
{
    broadcast use lemma_cget_push;
    reveal(meq);
    assert forall|k: nat| #[trigger] meq_at(c.push((n, p0)), x, m1, m, k) by {
        assert(meq_at(c, x, m1, mset(n, (mget(n, m).0, Some(pos)), m), k));
    }
}

pub proof fn capsrel_end(m: MCaps, g: GMap)
    requires capsrel(m, g, Seq::empty(), Set::empty()),
    ensures capeq(m, g),
{
    reveal(capsrel);
    assert forall|k: nat| #![trigger mget(k, m)] capv(mget(k, m)) == gget(k, g) by {
        assert(capsrel_at(m, g, Seq::empty(), Set::empty(), k));
    }
}

pub proof fn capsrel_init(x: Set<nat>)
    ensures capsrel(Seq::empty(), Seq::empty(), Seq::empty(), x),
{
    reveal(capsrel);
    assert forall|k: nat| #[trigger] capsrel_at(Seq::empty(), Seq::empty(), Seq::empty(), x, k) by {
        assert(mget(k, Seq::<(nat, Cap)>::empty()) == (None::<nat>, None::<nat>));
        assert(gget(k, Seq::<(nat, (nat, nat))>::empty()) == None::<(nat, nat)>);
        assert(cget(k, Seq::<(nat, nat)>::empty()) == None::<nat>);
    }
}

// ---- VM runs of exactly n steps ----

pub open spec fn stt(pc: nat, pos: nat, m: MCaps, stk: Seq<Entry>) -> State {
    State { pc, pos, m, stk }
}

pub open spec fn exe(code: Seq<Instr>, s: Seq<u8>, n: nat, st: State) -> Outcome
    decreases n,
{
    if n == 0 {
        Outcome::Next(st)
    } else {
        match step(code, s, st) {
            Outcome::Next(st2) => exe(code, s, (n - 1) as nat, st2),
            Outcome::Halt(r) => Outcome::Halt(r),
        }
    }
}

pub proof fn exe_next(code: Seq<Instr>, s: Seq<u8>, n: nat, st: State, st2: State)
    requires step(code, s, st) == Outcome::Next(st2),
    ensures exe(code, s, n + 1, st) == exe(code, s, n, st2),
{
}

pub proof fn exe_fail1(code: Seq<Instr>, s: Seq<u8>, st: State, stk: Seq<Entry>, m: MCaps)
    requires step(code, s, st) == fail(stk, m),
    ensures exe(code, s, 1, st) == fail(stk, m),
{
    match step(code, s, st) {
        Outcome::Next(st2) => assert(exe(code, s, 0, st2) == Outcome::Next(st2)),
        Outcome::Halt(_) => {}
    }
}

pub proof fn exe_add(code: Seq<Instr>, s: Seq<u8>, a: nat, b: nat, st: State)
    ensures exe(code, s, a + b, st) == (match exe(code, s, a, st) {
        Outcome::Next(st2) => exe(code, s, b, st2),
        Outcome::Halt(r) => Outcome::Halt(r),
    }),
    decreases a,
{
    if a != 0 {
        match step(code, s, st) {
            Outcome::Next(st2) => {
                exe_add(code, s, (a - 1) as nat, b, st2);
                assert((a + b - 1) as nat == (a - 1) as nat + b);
            }
            Outcome::Halt(_) => {}
        }
    }
}

// ---- the representation of pending actions by code ----

pub enum Rep {
    // pc, target, rest (at the target)
    RJump(nat, nat, Box<Rep>),
    // pc
    REnd(nat),
    // pc, r, eid, push, the position the rest is checked at, rest (at pc + clen r)
    RRe(nat, Regex, nat, bool, nat, Box<Rep>),
    // pc, group, start, rest (at pc + 1)
    RClose(nat, nat, nat, Box<Rep>),
    // loop address l, body a, eid, push, p0, the position the rest is checked at, rest (after the loop)
    RChkNull(nat, Regex, nat, bool, nat, nat, Box<Rep>),
    RChkNN(nat, Regex, nat, bool, nat, nat, Box<Rep>),
}

pub open spec fn hpc(h: Rep) -> nat {
    match h {
        Rep::RJump(pc, _, _) => pc,
        Rep::REnd(pc) => pc,
        Rep::RRe(pc, _, _, _, _, _) => pc,
        Rep::RClose(pc, _, _, _) => pc,
        Rep::RChkNull(l, a, _, _, _, _, _) => l + 2 + clen(a),
        Rep::RChkNN(l, a, _, _, _, _, _) => l + 1 + clen(a),
    }
}

pub open spec fn hacts(h: Rep) -> Seq<Action>
    decreases h,
{
    match h {
        Rep::RJump(_, _, h2) => hacts(*h2),
        Rep::REnd(_) => Seq::empty(),
        Rep::RRe(_, r, _, _, _, h2) => hacts(*h2).push(Action::ARe(r)),
        Rep::RClose(_, n, p0, h2) => hacts(*h2).push(Action::AClose(n, p0)),
        Rep::RChkNull(_, a, _, _, p0, _, h2) => hacts(*h2).push(Action::ACheck(p0, a)),
        Rep::RChkNN(_, a, _, _, p0, _, h2) => hacts(*h2).push(Action::ACheck(p0, a)),
    }
}

// the empty-check ids the pending checks need on the stack
pub open spec fn hp(h: Rep) -> Set<nat>
    decreases h,
{
    match h {
        Rep::RJump(_, _, h2) => hp(*h2),
        Rep::REnd(_) => Set::empty(),
        Rep::RRe(_, _, _, _, _, h2) => hp(*h2),
        Rep::RClose(_, _, _, h2) => hp(*h2),
        Rep::RChkNull(_, _, eid, _, _, _, h2) => hp(*h2).insert(eid),
        Rep::RChkNN(_, _, _, _, _, _, h2) => hp(*h2),
    }
}

// the non-push groups still to be entered
pub open spec fn hx(h: Rep) -> Set<nat>
    decreases h,
{
    match h {
        Rep::RJump(_, _, h2) => hx(*h2),
        Rep::REnd(_) => Set::empty(),
        Rep::RRe(_, r, _, push, _, h2) => npg(r, push).union(hx(*h2)),
        Rep::RClose(_, _, _, h2) => hx(*h2),
        Rep::RChkNull(_, _, _, _, _, _, h2) => hx(*h2),
        Rep::RChkNN(_, _, _, _, _, _, h2) => hx(*h2),
    }
}

pub open spec fn rep(code: Seq<Instr>, h: Rep, pos: nat, stk: Seq<Entry>) -> bool
    decreases h,
{
    match h {
        Rep::RJump(pc, tg, h2) =>
            nth(code, pc) == Some(Instr::IJump(tg)) && hpc(*h2) == tg && rep(code, *h2, pos, stk),
        Rep::REnd(pc) => nth(code, pc) == Some(Instr::IEnd),
        Rep::RRe(pc, r, eid, push, pos2, h2) =>
            code_at(code, pc, comp(r, pc, eid, push)) && fresh(eid, nchecks(r), hp(*h2))
            && hpc(*h2) == pc + clen(r) && pos2 <= pos + minlen(r) && rep(code, *h2, pos2, stk),
        Rep::RClose(pc, n, _, h2) =>
            nth(code, pc) == Some(Instr::IMemEnd(n)) && hpc(*h2) == pc + 1 && rep(code, *h2, pos, stk),
        Rep::RChkNull(l, a, eid, push, p0, pos2, h2) =>
            code_at(code, l, comp(Regex::Star(Box::new(a)), l, eid, push)) && clen(a) != 0 && nullable(a)
            && fresh(eid, nchecks(Regex::Star(Box::new(a))), hp(*h2)) && empty_start(eid, stk) == Some(p0)
            && p0 <= pos && hpc(*h2) == l + clen(Regex::Star(Box::new(a))) && pos2 <= p0
            && rep(code, *h2, pos2, stk),
        Rep::RChkNN(l, a, eid, push, p0, pos2, h2) =>
            code_at(code, l, comp(Regex::Star(Box::new(a)), l, eid, push)) && clen(a) != 0 && !nullable(a)
            && fresh(eid, nchecks(Regex::Star(Box::new(a))), hp(*h2)) && p0 + minlen(a) <= pos
            && hpc(*h2) == l + clen(Regex::Star(Box::new(a))) && pos2 <= p0
            && rep(code, *h2, pos2, stk),
    }
}

pub open spec fn same_checks(p: Set<nat>, stk2: Seq<Entry>, stk: Seq<Entry>) -> bool {
    forall|i: nat| #[trigger] p.contains(i) ==> empty_start(i, stk2) == empty_start(i, stk)
}

pub proof fn rep_mono(code: Seq<Instr>, h: Rep, pos: nat, stk: Seq<Entry>, pos3: nat, stk3: Seq<Entry>)
    requires rep(code, h, pos, stk), pos <= pos3, same_checks(hp(h), stk3, stk),
    ensures rep(code, h, pos3, stk3),
    decreases h,
{
    match h {
        Rep::RJump(_, _, h2) => rep_mono(code, *h2, pos, stk, pos3, stk3),
        Rep::REnd(_) => {}
        Rep::RRe(_, _, _, _, pos2, h2) => rep_mono(code, *h2, pos2, stk, pos2, stk3),
        Rep::RClose(_, _, _, h2) => rep_mono(code, *h2, pos, stk, pos3, stk3),
        Rep::RChkNull(_, _, eid, _, _, pos2, h2) => {
            assert(hp(h).contains(eid));
            assert forall|i: nat| #[trigger] hp(*h2).contains(i) implies empty_start(i, stk3) == empty_start(i, stk) by {
                assert(hp(h).contains(i));
            }
            rep_mono(code, *h2, pos2, stk, pos2, stk3);
        }
        Rep::RChkNN(_, _, _, _, _, pos2, h2) => rep_mono(code, *h2, pos2, stk, pos2, stk3),
    }
}

// ---- the simulation result ----

// o = (number of VM steps, final captures)
pub open spec fn simres(code: Seq<Instr>, s: Seq<u8>, c: Seq<(nat, nat)>, x: Set<nat>, pc: nat, pos: nat,
                        m: MCaps, stk: Seq<Entry>, t: Tree, o: (nat, MCaps)) -> bool {
    match first_match(t) {
        Some((e, g2)) => exe(code, s, o.0, stt(pc, pos, m, stk)) == Outcome::Halt(Some((e, o.1))) && capeq(o.1, g2),
        None => meq(c, x, o.1, m) && exe(code, s, o.0, stt(pc, pos, m, stk)) == fail(stk, o.1),
    }
}

pub open spec fn sim_pre(code: Seq<Instr>, s: Seq<u8>, f: nat, h: Rep, pos: nat, g: GMap, t: Tree,
                         stk: Seq<Entry>, m: MCaps) -> bool {
    compute_tree(f, s, hacts(h), pos, g) == Some(t) && capsrel(m, g, cls(hacts(h)), hx(h))
    && uniq(hacts(h)) && rep(code, h, pos, stk)
}

pub open spec fn sim_post(code: Seq<Instr>, s: Seq<u8>, h: Rep, pos: nat, t: Tree, stk: Seq<Entry>,
                          m: MCaps, o: (nat, MCaps)) -> bool {
    simres(code, s, cls(hacts(h)), hx(h), hpc(h), pos, m, stk, t, o)
}

// a choice point: OP_PUSH (and j - 1 more steps), the first branch,
// then on its failure the second
pub proof fn choice(code: Seq<Instr>, s: Seq<u8>, c: Seq<(nat, nat)>, x: Set<nat>, pc: nat, pos: nat,
                    m: MCaps, stk: Seq<Entry>, stk1: Seq<Entry>, pca: nat, pcb: nat, t1: Tree, t2: Tree,
                    j: nat, oa: (nat, MCaps), ob: (nat, MCaps)) -> (o: (nat, MCaps))
    requires
        exe(code, s, j, stt(pc, pos, m, stk)) == Outcome::Next(stt(pca, pos, m, stk1)),
        fail(stk1, oa.1) == Outcome::Next(stt(pcb, pos, oa.1, stk)),
        simres(code, s, c, x, pca, pos, m, stk1, t1, oa),
        first_match(t1) is None ==> simres(code, s, c, x, pcb, pos, oa.1, stk, t2, ob),
    ensures simres(code, s, c, x, pc, pos, m, stk, Tree::TChoice(Box::new(t1), Box::new(t2)), o),
{
    exe_add(code, s, j, oa.0, stt(pc, pos, m, stk));
    if first_match(t1) is Some {
        (j + oa.0, oa.1)
    } else {
        exe_add(code, s, j + oa.0, ob.0, stt(pc, pos, m, stk));
        if first_match(t2) is None {
            meq_trans(c, x, ob.1, oa.1, m);
        }
        (j + oa.0 + ob.0, ob.1)
    }
}

// ---- the cases of sim ----

pub proof fn case_end(code: Seq<Instr>, s: Seq<u8>, f: nat, h: Rep, pos: nat, g: GMap, t: Tree,
                      stk: Seq<Entry>, m: MCaps, pc: nat) -> (o: (nat, MCaps))
    requires sim_pre(code, s, f, h, pos, g, t, stk, m), h == Rep::REnd(pc),
    ensures sim_post(code, s, h, pos, t, stk, m, o),
{
    assert(hacts(h) == Seq::<Action>::empty());
    assert(t == Tree::TMatch(pos, g));
    capsrel_end(m, g);
    assert(exe(code, s, 0, stt(pc, pos, m, stk)) == Outcome::Next(stt(pc, pos, m, stk)));
    (1, m)
}

pub proof fn case_close(code: Seq<Instr>, s: Seq<u8>, f: nat, h: Rep, pos: nat, g: GMap, t: Tree,
                        stk: Seq<Entry>, m: MCaps, pc: nat, n: nat, p0: nat, h2: Rep) -> (o: (nat, MCaps))
    requires sim_pre(code, s, f, h, pos, g, t, stk, m), h == Rep::RClose(pc, n, p0, Box::new(h2)),
    ensures sim_post(code, s, h, pos, t, stk, m, o),
    decreases f, h, 0nat,
{
    let k = hacts(h2);
    let x = hx(h2);
    let f1 = (f - 1) as nat;
    let g2 = gset(n, (p0, pos), g);
    let m2 = mset(n, (mget(n, m).0, Some(pos)), m);
    assert(hacts(h) == k.push(Action::AClose(n, p0)));
    assert(cls(hacts(h)) == cls(k).push((n, p0)));
    assert(compute_tree(f1, s, k, pos, g2) == Some(t));
    cls_none(n, k);
    capsrel_close(m, g, cls(k), x, n, p0, pos);
    let o = sim(code, s, f1, h2, pos, g2, t, stk, m2);
    exe_next(code, s, o.0, stt(pc, pos, m, stk), stt(pc + 1, pos, m2, stk));
    if first_match(t) is None {
        meq_close(cls(k), x, o.1, m, n, p0, pos);
    }
    (o.0 + 1, o.1)
}

pub proof fn case_chk_null(code: Seq<Instr>, s: Seq<u8>, f: nat, h: Rep, pos: nat, g: GMap, t: Tree,
                           stk: Seq<Entry>, m: MCaps, l: nat, a: Regex, eid: nat, push: bool, p0: nat,
                           pos2: nat, h2: Rep) -> (o: (nat, MCaps))
    requires
        sim_pre(code, s, f, h, pos, g, t, stk, m),
        h == Rep::RChkNull(l, a, eid, push, p0, pos2, Box::new(h2)),
    ensures sim_post(code, s, h, pos, t, stk, m, o),
    decreases f, h, 0nat,
{
    let k = hacts(h2);
    let x = hx(h2);
    let f1 = (f - 1) as nat;
    let pc = l + 2 + clen(a);
    let sa = Regex::Star(Box::new(a));
    assert(hacts(h) == k.push(Action::ACheck(p0, a)));
    code_star_null(code, a, l, eid, push);
    if pos == p0 {
        assert(compute_tree(f1, s, k, pos, g) == Some(t));
        rep_mono(code, h2, pos2, stk, pos, stk);
        let o = sim(code, s, f1, h2, pos, g, t, stk, m);
        exe_next(code, s, o.0, stt(pc, pos, m, stk), stt(pc + 2, pos, m, stk));
        (o.0 + 1, o.1)
    } else {
        let hr = Rep::RRe(l, sa, eid, push, pos2, Box::new(h2));
        assert(hacts(hr) == k.push(Action::ARe(sa)));
        assert(compute_tree(f1, s, hacts(hr), pos, g) == Some(t));
        assert(hx(hr) =~= x);
        assert(rep(code, hr, pos, stk));
        assert(uniq(hacts(hr)));
        let o = sim(code, s, f1, hr, pos, g, t, stk, m);
        exe_next(code, s, o.0, stt(pc + 1, pos, m, stk), stt(l, pos, m, stk));
        exe_next(code, s, o.0 + 1, stt(pc, pos, m, stk), stt(pc + 1, pos, m, stk));
        (o.0 + 1 + 1, o.1)
    }
}

pub proof fn case_chk_nn(code: Seq<Instr>, s: Seq<u8>, f: nat, h: Rep, pos: nat, g: GMap, t: Tree,
                         stk: Seq<Entry>, m: MCaps, l: nat, a: Regex, eid: nat, push: bool, p0: nat,
                         pos2: nat, h2: Rep) -> (o: (nat, MCaps))
    requires
        sim_pre(code, s, f, h, pos, g, t, stk, m),
        h == Rep::RChkNN(l, a, eid, push, p0, pos2, Box::new(h2)),
    ensures sim_post(code, s, h, pos, t, stk, m, o),
    decreases f, h, 0nat,
{
    let k = hacts(h2);
    let x = hx(h2);
    let f1 = (f - 1) as nat;
    let pc = l + 1 + clen(a);
    let sa = Regex::Star(Box::new(a));
    assert(hacts(h) == k.push(Action::ACheck(p0, a)));
    code_star_nn(code, a, l, eid, push);
    assert(pos != p0);
    let hr = Rep::RRe(l, sa, eid, push, pos2, Box::new(h2));
    assert(hacts(hr) == k.push(Action::ARe(sa)));
    assert(compute_tree(f1, s, hacts(hr), pos, g) == Some(t));
    assert(hx(hr) =~= x);
    assert(rep(code, hr, pos, stk));
    assert(uniq(hacts(hr)));
    let o = sim(code, s, f1, hr, pos, g, t, stk, m);
    exe_next(code, s, o.0, stt(pc, pos, m, stk), stt(l, pos, m, stk));
    (o.0 + 1, o.1)
}

pub proof fn case_empty(code: Seq<Instr>, s: Seq<u8>, f: nat, h: Rep, pos: nat, g: GMap, t: Tree,
                        stk: Seq<Entry>, m: MCaps, pc: nat, r: Regex, eid: nat, push: bool, pos2: nat,
                        h2: Rep) -> (o: (nat, MCaps))
    requires
        sim_pre(code, s, f, h, pos, g, t, stk, m),
        h == Rep::RRe(pc, r, eid, push, pos2, Box::new(h2)),
        r == Regex::Eps || (r is Lit && r->Lit_0.len() == 0),
    ensures sim_post(code, s, h, pos, t, stk, m, o),
    decreases f, h, 0nat,
{
    let k = hacts(h2);
    let f1 = (f - 1) as nat;
    assert(hacts(h) == k.push(Action::ARe(r)));
    assert(compute_tree(f1, s, k, pos, g) == Some(t));
    assert(hx(h) =~= hx(h2));
    rep_mono(code, h2, pos2, stk, pos, stk);
    sim(code, s, f1, h2, pos, g, t, stk, m)
}

pub proof fn case_lit(code: Seq<Instr>, s: Seq<u8>, f: nat, h: Rep, pos: nat, g: GMap, t: Tree,
                      stk: Seq<Entry>, m: MCaps, pc: nat, l: Seq<u8>, eid: nat, push: bool, pos2: nat,
                      h2: Rep) -> (o: (nat, MCaps))
    requires
        sim_pre(code, s, f, h, pos, g, t, stk, m),
        h == Rep::RRe(pc, Regex::Lit(l), eid, push, pos2, Box::new(h2)),
        l.len() != 0,
    ensures sim_post(code, s, h, pos, t, stk, m, o),
    decreases f, h, 0nat,
{
    let k = hacts(h2);
    let f1 = (f - 1) as nat;
    assert(hacts(h) == k.push(Action::ARe(Regex::Lit(l))));
    assert(hx(h) =~= hx(h2));
    code_lit(code, l, pc, eid, push);
    if is_prefix_at(l, s, pos) {
        assert(compute_tree(f1, s, k, pos + l.len(), g) == Some(t));
        rep_mono(code, h2, pos2, stk, pos + l.len(), stk);
        let o = sim(code, s, f1, h2, pos + l.len(), g, t, stk, m);
        exe_next(code, s, o.0, stt(pc, pos, m, stk), stt(pc + 1, pos + l.len(), m, stk));
        (o.0 + 1, o.1)
    } else {
        assert(t == Tree::TMismatch);
        exe_fail1(code, s, stt(pc, pos, m, stk), stk, m);
        meq_refl(cls(k), hx(h2), m);
        (1, m)
    }
}

pub proof fn case_cat(code: Seq<Instr>, s: Seq<u8>, f: nat, h: Rep, pos: nat, g: GMap, t: Tree,
                      stk: Seq<Entry>, m: MCaps, pc: nat, a: Regex, b: Regex, eid: nat, push: bool,
                      pos2: nat, h2: Rep) -> (o: (nat, MCaps))
    requires
        sim_pre(code, s, f, h, pos, g, t, stk, m),
        h == Rep::RRe(pc, Regex::Cat(Box::new(a), Box::new(b)), eid, push, pos2, Box::new(h2)),
    ensures sim_post(code, s, h, pos, t, stk, m, o),
    decreases f, h, 0nat,
{
    let k = hacts(h2);
    let f1 = (f - 1) as nat;
    let r = Regex::Cat(Box::new(a), Box::new(b));
    assert(hacts(h) == k.push(Action::ARe(r)));
    code_cat(code, a, b, pc, eid, push);
    let hb = Rep::RRe(pc + clen(a), b, eid + nchecks(a), push, pos2, Box::new(h2));
    assert(rep(code, hb, pos + minlen(a), stk));
    let ha = Rep::RRe(pc, a, eid, push, pos + minlen(a), Box::new(hb));
    assert(hp(hb) == hp(h2));
    assert(rep(code, ha, pos, stk));
    let kb = k.push(Action::ARe(b));
    assert(hacts(hb) == kb);
    assert(hacts(ha) == kb.push(Action::ARe(a)));
    assert(compute_tree(f1, s, hacts(ha), pos, g) == Some(t));
    assert(hx(hb) == npg(b, push).union(hx(h2)));
    assert(hx(ha) == npg(a, push).union(hx(hb)));
    assert(hx(h) == npg(r, push).union(hx(h2)));
    assert(npg(r, push) =~= npg(a, push).union(npg(b, push)));
    assert(hx(ha) =~= hx(h));
    assert(cls(kb) == cls(k));
    assert(cls(hacts(ha)) == cls(k));
    assert(gs(kb) == gsr(b).union(gs(k)));
    assert(uniq(k.push(Action::ARe(r))));
    assert(gsr(r) == gsr(a).union(gsr(b)));
    disj_sub(gsr(a), gsr(r), gs(k));
    disj_sub(gsr(b), gsr(r), gs(k));
    disj_union(gsr(a), gsr(b), gs(k));
    assert(uniq(kb));
    assert(uniq(hacts(ha)));
    sim(code, s, f1, ha, pos, g, t, stk, m)
}

pub proof fn case_alt(code: Seq<Instr>, s: Seq<u8>, f: nat, h: Rep, pos: nat, g: GMap, t: Tree,
                      stk: Seq<Entry>, m: MCaps, pc: nat, a: Regex, b: Regex, eid: nat, push: bool,
                      pos2: nat, h2: Rep) -> (o: (nat, MCaps))
    requires
        sim_pre(code, s, f, h, pos, g, t, stk, m),
        h == Rep::RRe(pc, Regex::Alt(Box::new(a), Box::new(b)), eid, push, pos2, Box::new(h2)),
    ensures sim_post(code, s, h, pos, t, stk, m, o),
    decreases f, h, 0nat,
{
    let k = hacts(h2);
    let x0 = hx(h2);
    let f1 = (f - 1) as nat;
    let r = Regex::Alt(Box::new(a), Box::new(b));
    assert(hacts(h) == k.push(Action::ARe(r)));
    assert(hx(h) =~= x0);
    code_alt(code, a, b, pc, eid, push);
    let ka = k.push(Action::ARe(a));
    let kb = k.push(Action::ARe(b));
    let t1 = compute_tree(f1, s, ka, pos, g)->Some_0;
    let t2 = compute_tree(f1, s, kb, pos, g)->Some_0;
    assert(t == Tree::TChoice(Box::new(t1), Box::new(t2)));
    let pcb = pc + clen(a) + 2;
    let stk1 = stk.push(Entry::EAlt(pcb, pos));
    assert(same_checks(hp(h2), stk1, stk));
    rep_mono(code, h2, pos2, stk, pos2, stk1);
    let hj = Rep::RJump(pc + 1 + clen(a), hpc(h2), Box::new(h2));
    assert(rep(code, hj, pos2, stk1));
    let ha = Rep::RRe(pc + 1, a, eid, true, pos2, Box::new(hj));
    assert(rep(code, ha, pos, stk1));
    let hb = Rep::RRe(pcb, b, eid + nchecks(a), true, pos2, Box::new(h2));
    assert(rep(code, hb, pos, stk));
    assert(hacts(hj) == k);
    assert(hx(hj) == x0);
    assert(hacts(ha) == ka);
    assert(hacts(hb) == kb);
    assert(hx(ha) =~= x0);
    assert(hx(hb) =~= x0);
    assert(uniq(k.push(Action::ARe(r))));
    assert(gsr(r) == gsr(a).union(gsr(b)));
    disj_sub(gsr(a), gsr(r), gs(k));
    disj_sub(gsr(b), gsr(r), gs(k));
    assert(uniq(ka));
    assert(uniq(kb));
    let oa = sim(code, s, f1, ha, pos, g, t1, stk1, m);
    assert(exe(code, s, 0, stt(pc + 1, pos, m, stk1)) == Outcome::Next(stt(pc + 1, pos, m, stk1)));
    exe_next(code, s, 0, stt(pc, pos, m, stk), stt(pc + 1, pos, m, stk1));
    let ob = if first_match(t1) is None {
        capsrel_meq(m, g, cls(k), x0, oa.1);
        sim(code, s, f1, hb, pos, g, t2, stk, oa.1)
    } else {
        oa
    };
    choice(code, s, cls(k), x0, pc, pos, m, stk, stk1, pc + 1, pcb, t1, t2, 1, oa, ob)
}

pub proof fn case_star0(code: Seq<Instr>, s: Seq<u8>, f: nat, h: Rep, pos: nat, g: GMap, t: Tree,
                        stk: Seq<Entry>, m: MCaps, pc: nat, a: Regex, eid: nat, push: bool,
                        pos2: nat, h2: Rep) -> (o: (nat, MCaps))
    requires
        sim_pre(code, s, f, h, pos, g, t, stk, m),
        h == Rep::RRe(pc, Regex::Star(Box::new(a)), eid, push, pos2, Box::new(h2)),
        clen(a) == 0,
    ensures sim_post(code, s, h, pos, t, stk, m, o),
    decreases f, h, 0nat,
{
    let k = hacts(h2);
    let f1 = (f - 1) as nat;
    let r = Regex::Star(Box::new(a));
    assert(hacts(h) == k.push(Action::ARe(r)));
    assert(hx(h) =~= hx(h2));
    let kc = k.push(Action::ACheck(pos, a));
    let t1 = compute_tree(f1, s, kc.push(Action::ARe(a)), pos, g)->Some_0;
    let t2 = compute_tree(f1, s, k, pos, g)->Some_0;
    assert(t == Tree::TChoice(Box::new(t1), Box::new(t2)));
    clen0_fm(s, a, f1, kc, pos, g);
    let f2 = (f1 - 1) as nat;
    assert(compute_tree(f1, s, kc, pos, g) == compute_tree(f2, s, k, pos, g));
    ct_det(s, f2, f1, k, pos, g);
    assert(first_match(t) == first_match(t2));
    rep_mono(code, h2, pos2, stk, pos, stk);
    sim(code, s, f1, h2, pos, g, t2, stk, m)
}

pub proof fn case_star_null(code: Seq<Instr>, s: Seq<u8>, f: nat, h: Rep, pos: nat, g: GMap, t: Tree,
                            stk: Seq<Entry>, m: MCaps, pc: nat, a: Regex, eid: nat, push: bool,
                            pos2: nat, h2: Rep) -> (o: (nat, MCaps))
    requires
        sim_pre(code, s, f, h, pos, g, t, stk, m),
        h == Rep::RRe(pc, Regex::Star(Box::new(a)), eid, push, pos2, Box::new(h2)),
        clen(a) != 0, nullable(a),
    ensures sim_post(code, s, h, pos, t, stk, m, o),
    decreases f, h, 0nat,
{
    let k = hacts(h2);
    let x0 = hx(h2);
    let p = hp(h2);
    let f1 = (f - 1) as nat;
    let r = Regex::Star(Box::new(a));
    assert(hacts(h) == k.push(Action::ARe(r)));
    assert(hx(h) =~= x0);
    code_star_null(code, a, pc, eid, push);
    let kc = k.push(Action::ACheck(pos, a));
    let ka = kc.push(Action::ARe(a));
    let t1 = compute_tree(f1, s, ka, pos, g)->Some_0;
    let t2 = compute_tree(f1, s, k, pos, g)->Some_0;
    assert(t == Tree::TChoice(Box::new(t1), Box::new(t2)));
    let pcb = pc + clen(a) + 4;
    let stk1 = stk.push(Entry::EAlt(pcb, pos));
    let stk2 = stk1.push(Entry::EEmptyStart(eid, pos));
    assert(empty_start(eid, stk2) == Some(pos));
    assert forall|i: nat| #[trigger] p.contains(i) implies empty_start(i, stk2) == empty_start(i, stk) by {
        assert(i != eid);
        assert(empty_start(i, stk2) == empty_start(i, stk1));
    }
    rep_mono(code, h2, pos2, stk, pos2, stk2);
    let hchk = Rep::RChkNull(pc, a, eid, push, pos, pos2, Box::new(h2));
    assert(rep(code, hchk, pos, stk2));
    let ha = Rep::RRe(pc + 2, a, eid + 1, true, pos, Box::new(hchk));
    assert(hp(hchk) == p.insert(eid));
    assert(rep(code, ha, pos, stk2));
    assert(hacts(hchk) == kc);
    assert(hacts(ha) == ka);
    assert(hx(hchk) == x0);
    assert(hx(ha) =~= x0);
    assert(uniq(kc));
    assert(uniq(ka));
    assert(cls(kc) == cls(k));
    assert(cls(ka) == cls(k));
    let oa = sim(code, s, f1, ha, pos, g, t1, stk2, m);
    assert(exe(code, s, 0, stt(pc + 2, pos, m, stk2)) == Outcome::Next(stt(pc + 2, pos, m, stk2)));
    exe_next(code, s, 0, stt(pc + 1, pos, m, stk1), stt(pc + 2, pos, m, stk2));
    exe_next(code, s, 1, stt(pc, pos, m, stk), stt(pc + 1, pos, m, stk1));
    assert(pop(stk2, oa.1) == pop(stk1, oa.1));
    let ob = if first_match(t1) is None {
        capsrel_meq(m, g, cls(k), x0, oa.1);
        rep_mono(code, h2, pos2, stk, pos, stk);
        sim(code, s, f1, h2, pos, g, t2, stk, oa.1)
    } else {
        oa
    };
    choice(code, s, cls(k), x0, pc, pos, m, stk, stk2, pc + 2, pcb, t1, t2, 2, oa, ob)
}

pub proof fn case_star_nn(code: Seq<Instr>, s: Seq<u8>, f: nat, h: Rep, pos: nat, g: GMap, t: Tree,
                          stk: Seq<Entry>, m: MCaps, pc: nat, a: Regex, eid: nat, push: bool,
                          pos2: nat, h2: Rep) -> (o: (nat, MCaps))
    requires
        sim_pre(code, s, f, h, pos, g, t, stk, m),
        h == Rep::RRe(pc, Regex::Star(Box::new(a)), eid, push, pos2, Box::new(h2)),
        clen(a) != 0, !nullable(a),
    ensures sim_post(code, s, h, pos, t, stk, m, o),
    decreases f, h, 0nat,
{
    let k = hacts(h2);
    let x0 = hx(h2);
    let f1 = (f - 1) as nat;
    let r = Regex::Star(Box::new(a));
    assert(hacts(h) == k.push(Action::ARe(r)));
    assert(hx(h) =~= x0);
    code_star_nn(code, a, pc, eid, push);
    let kc = k.push(Action::ACheck(pos, a));
    let ka = kc.push(Action::ARe(a));
    let t1 = compute_tree(f1, s, ka, pos, g)->Some_0;
    let t2 = compute_tree(f1, s, k, pos, g)->Some_0;
    assert(t == Tree::TChoice(Box::new(t1), Box::new(t2)));
    let pcb = pc + clen(a) + 2;
    let stk1 = stk.push(Entry::EAlt(pcb, pos));
    assert(same_checks(hp(h2), stk1, stk));
    rep_mono(code, h2, pos2, stk, pos2, stk1);
    let hchk = Rep::RChkNN(pc, a, eid, push, pos, pos2, Box::new(h2));
    assert(rep(code, hchk, pos + minlen(a), stk1));
    let ha = Rep::RRe(pc + 1, a, eid, true, pos + minlen(a), Box::new(hchk));
    assert(rep(code, ha, pos, stk1));
    assert(hacts(hchk) == kc);
    assert(hacts(ha) == ka);
    assert(hx(hchk) == x0);
    assert(hx(ha) =~= x0);
    assert(uniq(kc));
    assert(uniq(ka));
    assert(cls(kc) == cls(k));
    assert(cls(ka) == cls(k));
    let oa = sim(code, s, f1, ha, pos, g, t1, stk1, m);
    assert(exe(code, s, 0, stt(pc + 1, pos, m, stk1)) == Outcome::Next(stt(pc + 1, pos, m, stk1)));
    exe_next(code, s, 0, stt(pc, pos, m, stk), stt(pc + 1, pos, m, stk1));
    let ob = if first_match(t1) is None {
        capsrel_meq(m, g, cls(k), x0, oa.1);
        rep_mono(code, h2, pos2, stk, pos, stk);
        sim(code, s, f1, h2, pos, g, t2, stk, oa.1)
    } else {
        oa
    };
    choice(code, s, cls(k), x0, pc, pos, m, stk, stk1, pc + 1, pcb, t1, t2, 1, oa, ob)
}

pub proof fn case_group(code: Seq<Instr>, s: Seq<u8>, f: nat, h: Rep, pos: nat, g: GMap, t: Tree,
                        stk: Seq<Entry>, m: MCaps, pc: nat, n: nat, a: Regex, eid: nat, push: bool,
                        pos2: nat, h2: Rep) -> (o: (nat, MCaps))
    requires
        sim_pre(code, s, f, h, pos, g, t, stk, m),
        h == Rep::RRe(pc, Regex::Group(n, Box::new(a)), eid, push, pos2, Box::new(h2)),
    ensures sim_post(code, s, h, pos, t, stk, m, o),
    decreases f, h, 0nat,
{
    let k = hacts(h2);
    let x0 = hx(h2);
    let f1 = (f - 1) as nat;
    let r = Regex::Group(n, Box::new(a));
    assert(hacts(h) == k.push(Action::ARe(r)));
    code_group(code, n, a, pc, eid, push);
    let kc = k.push(Action::AClose(n, pos));
    let acts2 = kc.push(Action::ARe(a));
    assert(compute_tree(f1, s, acts2, pos, g) == Some(t));
    assert(gs(kc) == gs(k).insert(n));
    assert(uniq(k.push(Action::ARe(r))));
    assert(gsr(r) == gsr(a).insert(n));
    assert(gsr(r).contains(n));
    assert(!gs(k).contains(n));
    assert forall|x: nat| #[trigger] gsr(a).contains(x) implies !gs(kc).contains(x) by {
        assert(gsr(r).contains(x));
    }
    cls_none(n, k);
    assert(uniq(kc));
    assert(uniq(acts2));
    assert(cls(kc) == cls(k).push((n, pos)));
    assert(cls(acts2) == cls(k).push((n, pos)));
    if push {
        let stk2 = stk.push(Entry::EMemStart(n, mget(n, m)));
        let m2 = mset(n, (Some(pos), None), m);
        assert(same_checks(hp(h2), stk2, stk));
        rep_mono(code, h2, pos2, stk, pos + minlen(a), stk2);
        let hc = Rep::RClose(pc + 1 + clen(a), n, pos, Box::new(h2));
        assert(rep(code, hc, pos + minlen(a), stk2));
        let hm = Rep::RRe(pc + 1, a, eid, push, pos + minlen(a), Box::new(hc));
        assert(rep(code, hm, pos, stk2));
        assert(hacts(hc) == kc);
        assert(hacts(hm) == acts2);
        assert(hx(hc) == x0);
        assert(hx(hm) =~= x0);
        assert(hx(h) =~= x0);
        capsrel_open(m, g, cls(k), x0, x0, n, pos, (Some(pos), None));
        let o = sim(code, s, f1, hm, pos, g, t, stk2, m2);
        exe_next(code, s, o.0, stt(pc, pos, m, stk), stt(pc + 1, pos, m2, stk2));
        if first_match(t) is Some {
            (o.0 + 1, o.1)
        } else {
            meq_push(cls(k), x0, o.1, m, n, pos);
            (o.0 + 1, mset(n, mget(n, m), o.1))
        }
    } else {
        let x1 = topg(a).union(x0);
        let v = (Some(pos), mget(n, m).1);
        let m2 = mset(n, v, m);
        rep_mono(code, h2, pos2, stk, pos + minlen(a), stk);
        let hc = Rep::RClose(pc + 1 + clen(a), n, pos, Box::new(h2));
        assert(rep(code, hc, pos + minlen(a), stk));
        let hm = Rep::RRe(pc + 1, a, eid, push, pos + minlen(a), Box::new(hc));
        assert(rep(code, hm, pos, stk));
        assert(hacts(hc) == kc);
        assert(hacts(hm) == acts2);
        assert(hx(hc) == x0);
        assert(hx(hm) =~= x1);
        assert(hx(h) =~= x1.insert(n));
        capsrel_open(m, g, cls(k), x1.insert(n), x1, n, pos, v);
        let o = sim(code, s, f1, hm, pos, g, t, stk, m2);
        exe_next(code, s, o.0, stt(pc, pos, m, stk), stt(pc + 1, pos, m2, stk));
        if first_match(t) is None {
            meq_nopush(cls(k), x1, o.1, m, n, pos, v);
        }
        (o.0 + 1, o.1)
    }
}

// ---- lemmas (b) and (c) ----

pub proof fn sim(code: Seq<Instr>, s: Seq<u8>, f: nat, h: Rep, pos: nat, g: GMap, t: Tree,
                 stk: Seq<Entry>, m: MCaps) -> (o: (nat, MCaps))
    requires sim_pre(code, s, f, h, pos, g, t, stk, m),
    ensures sim_post(code, s, h, pos, t, stk, m, o),
    decreases f, h, 1nat,
{
    match h {
        Rep::RJump(pc, tg, h2) => {
            let o = sim(code, s, f, *h2, pos, g, t, stk, m);
            exe_next(code, s, o.0, stt(pc, pos, m, stk), stt(tg, pos, m, stk));
            (o.0 + 1, o.1)
        }
        Rep::REnd(pc) => case_end(code, s, f, h, pos, g, t, stk, m, pc),
        Rep::RRe(pc, r, eid, push, pos2, h2) => match r {
            Regex::Eps => case_empty(code, s, f, h, pos, g, t, stk, m, pc, r, eid, push, pos2, *h2),
            Regex::Lit(l) => {
                if l.len() == 0 {
                    case_empty(code, s, f, h, pos, g, t, stk, m, pc, r, eid, push, pos2, *h2)
                } else {
                    case_lit(code, s, f, h, pos, g, t, stk, m, pc, l, eid, push, pos2, *h2)
                }
            }
            Regex::Cat(a, b) => case_cat(code, s, f, h, pos, g, t, stk, m, pc, *a, *b, eid, push, pos2, *h2),
            Regex::Alt(a, b) => case_alt(code, s, f, h, pos, g, t, stk, m, pc, *a, *b, eid, push, pos2, *h2),
            Regex::Star(a) => {
                if clen(*a) == 0 {
                    case_star0(code, s, f, h, pos, g, t, stk, m, pc, *a, eid, push, pos2, *h2)
                } else if nullable(*a) {
                    case_star_null(code, s, f, h, pos, g, t, stk, m, pc, *a, eid, push, pos2, *h2)
                } else {
                    case_star_nn(code, s, f, h, pos, g, t, stk, m, pc, *a, eid, push, pos2, *h2)
                }
            }
            Regex::Group(n, a) => case_group(code, s, f, h, pos, g, t, stk, m, pc, n, *a, eid, push, pos2, *h2),
        },
        Rep::RClose(pc, n, p0, h2) => case_close(code, s, f, h, pos, g, t, stk, m, pc, n, p0, *h2),
        Rep::RChkNull(l, a, eid, push, p0, pos2, h2) =>
            case_chk_null(code, s, f, h, pos, g, t, stk, m, l, a, eid, push, p0, pos2, *h2),
        Rep::RChkNN(l, a, eid, push, p0, pos2, h2) =>
            case_chk_nn(code, s, f, h, pos, g, t, stk, m, l, a, eid, push, p0, pos2, *h2),
    }
}

} // verus!
