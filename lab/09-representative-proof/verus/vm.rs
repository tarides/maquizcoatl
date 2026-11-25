// Experiment #9, Verus: the backtracking VM (FRAGMENT.md 5), transcribed
// from fstar/Vm.fst, after match_at (upstream/src/regexec.c:3068) on the
// fragment's opcodes, with an explicit backtrack stack bottomed by the
// OP_FINISH sentinel (regexec.c:3074, 3277).  Captures are upstream's
// mem_start_stk / mem_end_stk pair; the stack pop is STACK_POP at
// STACK_POP_LEVEL_MEM_START (regexec.c:2295-2337).  Terminates by fuel
// only: one unit per instruction executed.
//
// The spec fns (`step`, `run`, `vm`) define the VM; the exec VM below
// (`evm`: a loop over a `Vec` stack and a `Vec` of captures) is proved
// to return exactly `vm`'s result.  Stack top and the latest capture
// write are the last elements.
use vstd::prelude::*;
use crate::syntax::*;

verus! {

pub type Cap = (Option<nat>, Option<nat>);

// group k -> (start, end); absent = (None, None) (INVALID_STACK_INDEX)
pub type MCaps = Seq<(nat, Cap)>;

pub open spec fn mget(k: nat, m: MCaps) -> Cap
    decreases m.len(),
{
    if m.len() == 0 {
        (None, None)
    } else if m.last().0 == k {
        m.last().1
    } else {
        mget(k, m.drop_last())
    }
}

pub open spec fn mset(k: nat, v: Cap, m: MCaps) -> MCaps { m.push((k, v)) }

// backtrack stack entries (upstream StackType)
pub enum Entry {
    EFinish,                // bottom STK_ALT -> OP_FINISH
    EAlt(nat, nat),         // STK_ALT, from OP_PUSH: pc, pos
    EMemStart(nat, Cap),    // STK_MEM_START: group, previous capture
    EEmptyStart(nat, nat),  // STK_EMPTY_CHECK_START: id, pos
}

pub struct State {
    pub pc: nat,
    pub pos: nat,
    pub m: MCaps,
    pub stk: Seq<Entry>,
}

// STACK_POP: pop to the first alternative, restoring the captures of
// every STK_MEM_START on the way; None when it reaches the sentinel
// (OP_FINISH: no more alternatives)
pub open spec fn pop(stk: Seq<Entry>, m: MCaps) -> Option<State>
    decreases stk.len(),
{
    if stk.len() == 0 {
        None
    } else {
        let t = stk.drop_last();
        match stk.last() {
            Entry::EFinish => None,
            Entry::EAlt(pc, pos) => Some(State { pc, pos, m, stk: t }),
            Entry::EMemStart(k, prev) => pop(t, mset(k, prev, m)),
            Entry::EEmptyStart(_, _) => pop(t, m),
        }
    }
}

// EMPTY_CHECK_START_SEARCH (regexec.c:2409-2419): the start position
// of the innermost open iteration with this id
pub open spec fn empty_start(id: nat, stk: Seq<Entry>) -> Option<nat>
    decreases stk.len(),
{
    if stk.len() == 0 {
        None
    } else {
        match stk.last() {
            Entry::EEmptyStart(id2, p) => if id == id2 { Some(p) } else { empty_start(id, stk.drop_last()) },
            _ => empty_start(id, stk.drop_last()),
        }
    }
}

pub enum Outcome {
    Next(State),
    Halt(Option<(nat, MCaps)>),   // OP_END: Some; OP_FINISH: None
}

pub open spec fn fail(stk: Seq<Entry>, m: MCaps) -> Outcome {
    match pop(stk, m) {
        Some(st) => Outcome::Next(st),
        None => Outcome::Halt(None),
    }
}

pub open spec fn nth(code: Seq<Instr>, pc: nat) -> Option<Instr> {
    if pc < code.len() { Some(code[pc as int]) } else { None }
}

pub open spec fn step(code: Seq<Instr>, s: Seq<u8>, st: State) -> Outcome {
    let (pc, pos, m, stk) = (st.pc, st.pos, st.m, st.stk);
    match nth(code, pc) {
        None => fail(stk, m),                               // outside the code: as OP_FAIL
        Some(i) => match i {
            Instr::IStr(l) =>                               // regexec.c:3412-3480
                if is_prefix_at(l, s, pos) { Outcome::Next(State { pc: pc + 1, pos: pos + l.len(), m, stk }) }
                else { fail(stk, m) },
            Instr::IPush(a) =>                              // :4310-4314
                Outcome::Next(State { pc: pc + 1, pos, m, stk: stk.push(Entry::EAlt(a, pos)) }),
            Instr::IJump(a) => Outcome::Next(State { pc: a, pos, m, stk }),   // :4305-4308
            Instr::IFail => fail(stk, m),                   // :4668-4679
            Instr::IMemStart(k) =>                          // :4009-4013
                Outcome::Next(State { pc: pc + 1, pos, m: mset(k, (Some(pos), mget(k, m).1), m), stk }),
            Instr::IMemStartPush(k) =>                      // :4003-4007, :2072-2082
                Outcome::Next(State { pc: pc + 1, pos, m: mset(k, (Some(pos), None), m),
                                      stk: stk.push(Entry::EMemStart(k, mget(k, m))) }),
            Instr::IMemEnd(k) =>                            // :4021-4025
                Outcome::Next(State { pc: pc + 1, pos, m: mset(k, (mget(k, m).0, Some(pos)), m), stk }),
            Instr::IEmptyStart(id) =>                       // :4221-4225
                Outcome::Next(State { pc: pc + 1, pos, m, stk: stk.push(Entry::EEmptyStart(id, pos)) }),
            Instr::IEmptyEnd(id) =>                         // :4227-4257
                // empty iteration: skip the next instruction (the loop's JUMP)
                match empty_start(id, stk) {
                    Some(p0) => if p0 == pos { Outcome::Next(State { pc: pc + 2, pos, m, stk }) }
                                else { Outcome::Next(State { pc: pc + 1, pos, m, stk }) },
                    None => Outcome::Next(State { pc: pc + 1, pos, m, stk }),
                },
            Instr::IEnd => Outcome::Halt(Some((pos, m))),   // :3285-3357
        },
    }
}

pub open spec fn run(fuel: nat, code: Seq<Instr>, s: Seq<u8>, st: State) -> Option<Option<(nat, MCaps)>>
    decreases fuel,
{
    if fuel == 0 {
        None
    } else {
        match step(code, s, st) {
            Outcome::Next(st2) => run((fuel - 1) as nat, code, s, st2),
            Outcome::Halt(r) => Some(r),
        }
    }
}

// region of a match (regexec.c:3347-3357): a group is set when its end
// is valid; groups 1..n
pub open spec fn region(n: nat, m: MCaps) -> Seq<Span> {
    Seq::new(n, |i: int| match mget((i + 1) as nat, m) {
        (Some(a), Some(b)) => Some((a, b)),
        _ => None,
    })
}

pub open spec fn init(p: nat) -> State {
    State { pc: 0, pos: p, m: Seq::empty(), stk: seq![Entry::EFinish] }
}

// one match_at call at start position p on code of n groups
pub open spec fn vm(fuel: nat, code: Seq<Instr>, n: nat, s: Seq<u8>, p: nat) -> Res {
    match run(fuel, code, s, init(p)) {
        None => Res::OutOfFuel,
        Some(None) => Res::NoMatch,
        Some(Some((e, m))) => Res::Match(e, region(n, m)),
    }
}

pub open spec fn vm_at(fuel: nat, code: Seq<Instr>, n: nat, s: Seq<u8>) -> spec_fn(nat) -> Res {
    |p: nat| vm(fuel, code, n, s, p)
}

// ---- exec VM ----

pub type ECap = (Option<usize>, Option<usize>);

#[derive(Clone, Copy)]
pub enum EEntry {
    EFinish,
    EAlt(usize, usize),
    EMemStart(usize, ECap),
    EEmptyStart(usize, usize),
}

pub open spec fn onv(o: Option<usize>) -> Option<nat> {
    match o { Some(x) => Some(x as nat), None => None }
}

pub open spec fn cv(c: ECap) -> Cap { (onv(c.0), onv(c.1)) }

pub open spec fn mv(m: Seq<(usize, ECap)>) -> MCaps {
    m.map_values(|x: (usize, ECap)| (x.0 as nat, cv(x.1)))
}

pub open spec fn ev(e: EEntry) -> Entry {
    match e {
        EEntry::EFinish => Entry::EFinish,
        EEntry::EAlt(pc, pos) => Entry::EAlt(pc as nat, pos as nat),
        EEntry::EMemStart(k, c) => Entry::EMemStart(k as nat, cv(c)),
        EEntry::EEmptyStart(id, pos) => Entry::EEmptyStart(id as nat, pos as nat),
    }
}

pub open spec fn skv(v: Seq<EEntry>) -> Seq<Entry> { v.map_values(|e: EEntry| ev(e)) }

pub struct EState {
    pub pc: usize,
    pub pos: usize,
    pub m: Vec<(usize, ECap)>,
    pub stk: Vec<EEntry>,
}

pub open spec fn stv(st: EState) -> State {
    State { pc: st.pc as nat, pos: st.pos as nat, m: mv(st.m@), stk: skv(st.stk@) }
}

pub fn emget(k: usize, m: &Vec<(usize, ECap)>) -> (r: ECap)
    ensures cv(r) == mget(k as nat, mv(m@)),
{
    let mut i = m.len();
    assert(m@.subrange(0, i as int) =~= m@);
    while i > 0
        invariant i <= m.len(), mget(k as nat, mv(m@)) == mget(k as nat, mv(m@.subrange(0, i as int))),
        decreases i,
    {
        assert(mv(m@.subrange(0, i as int)).drop_last() =~= mv(m@.subrange(0, i - 1)));
        let (k2, v) = m[i - 1];
        if k2 == k {
            return v;
        }
        i = i - 1;
    }
    (None, None)
}

fn emset(k: usize, v: ECap, m: &mut Vec<(usize, ECap)>)
    ensures mv(final(m)@) == mset(k as nat, cv(v), mv(old(m)@)),
{
    let ghost m0 = mv(m@);
    m.push((k, v));
    assert(mv(m@) =~= m0.push((k as nat, cv(v))));
}

// STACK_POP on the state's stack and captures; false: the sentinel
// (or an empty stack) was reached
pub fn epop(st: &mut EState) -> (b: bool)
    ensures
        match pop(skv(old(st).stk@), mv(old(st).m@)) {
            Some(s2) => b && stv(*final(st)) == s2,
            None => !b,
        },
{
    let ghost goal = pop(skv(st.stk@), mv(st.m@));
    while st.stk.len() > 0
        invariant goal == pop(skv(st.stk@), mv(st.m@)), goal == pop(skv(old(st).stk@), mv(old(st).m@)),
        decreases st.stk.len(),
    {
        let ghost sk = skv(st.stk@);
        let e = st.stk[st.stk.len() - 1];
        st.stk.pop();
        assert(skv(st.stk@) =~= sk.drop_last());
        match e {
            EEntry::EFinish => { return false; }
            EEntry::EAlt(pc, pos) => {
                st.pc = pc;
                st.pos = pos;
                return true;
            }
            EEntry::EMemStart(k, prev) => { emset(k, prev, &mut st.m); }
            EEntry::EEmptyStart(_, _) => {}
        }
    }
    false
}

pub fn eempty_start(id: usize, stk: &Vec<EEntry>) -> (r: Option<usize>)
    ensures onv(r) == empty_start(id as nat, skv(stk@)),
{
    let mut i = stk.len();
    assert(stk@.subrange(0, i as int) =~= stk@);
    while i > 0
        invariant i <= stk.len(), empty_start(id as nat, skv(stk@)) == empty_start(id as nat, skv(stk@.subrange(0, i as int))),
        decreases i,
    {
        assert(skv(stk@.subrange(0, i as int)).drop_last() =~= skv(stk@.subrange(0, i - 1)));
        match stk[i - 1] {
            EEntry::EEmptyStart(id2, p) => { if id2 == id { return Some(p); } }
            _ => {}
        }
        i = i - 1;
    }
    None
}

// one step; None: the state was updated (Next); Some(None): no match;
// Some(Some(e)): OP_END at position e, captures in st.m
pub fn estep(code: &Vec<EInstr>, s: &Vec<u8>, st: &mut EState) -> (o: Option<Option<usize>>)
    requires code.len() < usize::MAX - 2,
    ensures
        match step(insv(code@), s@, stv(*old(st))) {
            Outcome::Next(s2) => o is None && stv(*final(st)) == s2,
            Outcome::Halt(None) => o == Some(None::<usize>),
            Outcome::Halt(Some((e, m))) => o == Some(Some(e as usize)) && mv(final(st).m@) == m
                && e == old(st).pos,
        },
{
    let pc = st.pc;
    let pos = st.pos;
    if pc >= code.len() {
        return if epop(st) { None } else { Some(None) };
    }
    assert(insv(code@)[pc as int] == iv(code@[pc as int]));
    match code[pc] {
        EInstr::IStr(l) => {
            if eis_prefix_at(l, s, pos) {
                let sl = s.len();
                assert(l@.len() == 0 || pos + l@.len() <= sl);
                st.pc = pc + 1;
                st.pos = pos + l.len();
                None
            } else if epop(st) { None } else { Some(None) }
        }
        EInstr::IPush(a) => {
            let ghost sk = skv(st.stk@);
            st.stk.push(EEntry::EAlt(a, pos));
            assert(skv(st.stk@) =~= sk.push(Entry::EAlt(a as nat, pos as nat)));
            st.pc = pc + 1;
            None
        }
        EInstr::IJump(a) => { st.pc = a; None }
        EInstr::IFail => { if epop(st) { None } else { Some(None) } }
        EInstr::IMemStart(k) => {
            let (_, e) = emget(k, &st.m);
            emset(k, (Some(pos), e), &mut st.m);
            st.pc = pc + 1;
            None
        }
        EInstr::IMemStartPush(k) => {
            let prev = emget(k, &st.m);
            let ghost sk = skv(st.stk@);
            st.stk.push(EEntry::EMemStart(k, prev));
            assert(skv(st.stk@) =~= sk.push(Entry::EMemStart(k as nat, cv(prev))));
            emset(k, (Some(pos), None), &mut st.m);
            st.pc = pc + 1;
            None
        }
        EInstr::IMemEnd(k) => {
            let (b, _) = emget(k, &st.m);
            emset(k, (b, Some(pos)), &mut st.m);
            st.pc = pc + 1;
            None
        }
        EInstr::IEmptyStart(id) => {
            let ghost sk = skv(st.stk@);
            st.stk.push(EEntry::EEmptyStart(id, pos));
            assert(skv(st.stk@) =~= sk.push(Entry::EEmptyStart(id as nat, pos as nat)));
            st.pc = pc + 1;
            None
        }
        EInstr::IEmptyEnd(id) => {
            match eempty_start(id, &st.stk) {
                Some(p0) => { if p0 == pos { st.pc = pc + 2; } else { st.pc = pc + 1; } }
                None => { st.pc = pc + 1; }
            }
            None
        }
        EInstr::IEnd => Some(Some(pos)),
    }
}

pub fn eregion(n: usize, m: &Vec<(usize, ECap)>) -> (r: Vec<Option<(usize, usize)>>)
    ensures r@.map_values(|o: Option<(usize, usize)>| spv(o)) == region(n as nat, mv(m@)),
{
    let mut r: Vec<Option<(usize, usize)>> = Vec::new();
    let mut i: usize = 0;
    while i < n
        invariant i <= n,
            r@.map_values(|o: Option<(usize, usize)>| spv(o)) =~= region(i as nat, mv(m@)),
        decreases n - i,
    {
        let x = match emget(i + 1, m) {
            (Some(a), Some(b)) => Some((a, b)),
            _ => None,
        };
        let ghost r0 = r@;
        r.push(x);
        assert(r@.map_values(|o: Option<(usize, usize)>| spv(o))
            =~= r0.map_values(|o: Option<(usize, usize)>| spv(o)).push(spv(x)));
        i = i + 1;
    }
    assert(region(n as nat, mv(m@)) =~= region(n as nat, mv(m@)));
    r
}

// one match_at call at start position p
pub fn evm(fuel: u64, code: &Vec<EInstr>, n: usize, s: &Vec<u8>, p: usize) -> (r: ERes)
    requires code.len() < usize::MAX - 2,
    ensures resv(r) == vm(fuel as nat, insv(code@), n as nat, s@, p as nat),
{
    let mut stk: Vec<EEntry> = Vec::new();
    stk.push(EEntry::EFinish);
    let mut st = EState { pc: 0, pos: p, m: Vec::new(), stk };
    assert(stv(st) == init(p as nat)) by {
        assert(skv(st.stk@) =~= seq![Entry::EFinish]);
        assert(mv(st.m@) =~= Seq::<(nat, Cap)>::empty());
    }
    let ghost goal = run(fuel as nat, insv(code@), s@, init(p as nat));
    let mut f = fuel;
    loop
        invariant code.len() < usize::MAX - 2, goal == run(f as nat, insv(code@), s@, stv(st)),
            goal == run(fuel as nat, insv(code@), s@, init(p as nat)),
        decreases f,
    {
        if f == 0 {
            return ERes::OutOfFuel;
        }
        match estep(code, s, &mut st) {
            None => { f = f - 1; }
            Some(None) => { return ERes::NoMatch; }
            Some(Some(e)) => { return ERes::Match(e, eregion(n, &st.m)); }
        }
    }
}

// the left-to-right search of the VM (syntax::search)
pub fn esearch_vm(fuel: u64, code: &Vec<EInstr>, n: usize, s: &Vec<u8>) -> (o: Option<(usize, ERes)>)
    requires s.len() < usize::MAX, code.len() < usize::MAX - 2,
    ensures sresv(o) == search(vm_at(fuel as nat, insv(code@), n as nat, s@), s@),
{
    let ghost m = vm_at(fuel as nat, insv(code@), n as nat, s@);
    let mut p: usize = 0;
    while p <= s.len()
        invariant p <= s.len() + 1, s.len() < usize::MAX, code.len() < usize::MAX - 2,
            m == vm_at(fuel as nat, insv(code@), n as nat, s@),
            search(m, s@) == search_from(m, p as nat, (s.len() + 1 - p) as nat),
        decreases s.len() + 1 - p,
    {
        let x = evm(fuel, code, n, s, p);
        assert(m(p as nat) == resv(x));
        match x {
            ERes::NoMatch => { p = p + 1; }
            _ => { return Some((p, x)); }
        }
    }
    None
}

} // verus!
