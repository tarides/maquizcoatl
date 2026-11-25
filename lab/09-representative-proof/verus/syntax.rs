// Experiment #9, Verus: the fragment's abstract syntax, bytecode and
// results (lab/09-representative-proof/FRAGMENT.md, sections 1, 2, 6),
// transcribed from fstar/Syntax.fst.  Two layers, as Verus needs them:
// spec types (positions, group numbers and pcs are `nat`, byte strings
// are `Seq<u8>`), over which the semantics, the compiler, the VM and the
// theorem are spec fns; and exec types (`usize`, `Vec`, `Box`) for the
// exec code, each with a view to its spec type.  F*'s lists are Seqs
// here; a list used as a stack or a list of pending actions has its
// head at the end of the Seq (push = cons).
use vstd::prelude::*;

verus! {

// FRAGMENT.md 1: patterns.  `Lit` is a string of ASCII bytes (one per
// character in the case files); `Star` is greedy; `Group k` is a plain
// capture group numbered k >= 1 by the parser.
pub enum Regex {
    Eps,
    Lit(Seq<u8>),
    Cat(Box<Regex>, Box<Regex>),
    Alt(Box<Regex>, Box<Regex>),
    Star(Box<Regex>),
    Group(nat, Box<Regex>),
}

// FRAGMENT.md 2: bytecode, after upstream/src/regint.h:496-597.  Jump
// and push targets are absolute instruction indices.  OP_FINISH is not
// an instruction here: it is the sentinel at the bottom of the VM's
// backtrack stack (vm::Entry::EFinish).
pub enum Instr {
    IStr(Seq<u8>),        // OP_STR_1 .. OP_STR_N, collapsed
    IPush(nat),           // OP_PUSH
    IJump(nat),           // OP_JUMP
    IFail,                // OP_FAIL (never emitted for the fragment)
    IMemStart(nat),       // OP_MEM_START
    IMemStartPush(nat),   // OP_MEM_START_PUSH
    IMemEnd(nat),         // OP_MEM_END
    IEmptyStart(nat),     // OP_EMPTY_CHECK_START
    IEmptyEnd(nat),       // OP_EMPTY_CHECK_END
    IEnd,                 // OP_END
}

// A group's span, None when unset (upstream ONIG_REGION_NOTPOS).
pub type Span = Option<(nat, nat)>;

// FRAGMENT.md 6: the result of one match attempt at a start position:
// the match end and the spans of groups 1..ncap.
pub enum Res {
    Match(nat, Seq<Span>),
    NoMatch,
    OutOfFuel,
}

pub open spec fn max(a: nat, b: nat) -> nat { if a >= b { a } else { b } }

// Highest group number of a pattern (groups are numbered 1..ncap).
pub open spec fn ncap(r: Regex) -> nat
    decreases r,
{
    match r {
        Regex::Eps => 0,
        Regex::Lit(_) => 0,
        Regex::Cat(a, b) => max(ncap(*a), ncap(*b)),
        Regex::Alt(a, b) => max(ncap(*a), ncap(*b)),
        Regex::Star(a) => ncap(*a),
        Regex::Group(k, a) => max(k, ncap(*a)),
    }
}

// `l` is a prefix of s[pos..] (upstream DATA_ENSURE plus the byte
// compare of OP_STR_N, upstream/src/regexec.c:3472-3480); F*'s
// `is_prefix l (skipn pos s)`.
pub open spec fn is_prefix_at(l: Seq<u8>, s: Seq<u8>, pos: nat) -> bool {
    l.len() == 0 || (pos + l.len() <= s.len() && s.subrange(pos as int, (pos + l.len()) as int) =~= l)
}

// Left-to-right search over start positions p, p+1, ..., p+n-1, as
// search_in_range without the optimiser: the first start position
// whose attempt does not return NoMatch (a match, or out of fuel).
pub open spec fn search_from(m: spec_fn(nat) -> Res, p: nat, n: nat) -> Option<(nat, Res)>
    decreases n,
{
    if n == 0 {
        None
    } else {
        match m(p) {
            Res::NoMatch => search_from(m, p + 1, (n - 1) as nat),
            r => Some((p, r)),
        }
    }
}

pub open spec fn search(m: spec_fn(nat) -> Res, s: Seq<u8>) -> Option<(nat, Res)> {
    search_from(m, 0, s.len() + 1)
}

// ---- exec types and their views ----

pub enum ERegex {
    Eps,
    Lit(Vec<u8>),
    Cat(Box<ERegex>, Box<ERegex>),
    Alt(Box<ERegex>, Box<ERegex>),
    Star(Box<ERegex>),
    Group(usize, Box<ERegex>),
}

pub open spec fn rv(r: ERegex) -> Regex
    decreases r,
{
    match r {
        ERegex::Eps => Regex::Eps,
        ERegex::Lit(l) => Regex::Lit(l@),
        ERegex::Cat(a, b) => Regex::Cat(Box::new(rv(*a)), Box::new(rv(*b))),
        ERegex::Alt(a, b) => Regex::Alt(Box::new(rv(*a)), Box::new(rv(*b))),
        ERegex::Star(a) => Regex::Star(Box::new(rv(*a))),
        ERegex::Group(k, a) => Regex::Group(k as nat, Box::new(rv(*a))),
    }
}

// An exec instruction borrows its literal from the pattern it was
// compiled from.
#[derive(Clone, Copy)]
pub enum EInstr<'a> {
    IStr(&'a Vec<u8>),
    IPush(usize),
    IJump(usize),
    IFail,
    IMemStart(usize),
    IMemStartPush(usize),
    IMemEnd(usize),
    IEmptyStart(usize),
    IEmptyEnd(usize),
    IEnd,
}

pub open spec fn iv(i: EInstr) -> Instr {
    match i {
        EInstr::IStr(l) => Instr::IStr(l@),
        EInstr::IPush(a) => Instr::IPush(a as nat),
        EInstr::IJump(a) => Instr::IJump(a as nat),
        EInstr::IFail => Instr::IFail,
        EInstr::IMemStart(k) => Instr::IMemStart(k as nat),
        EInstr::IMemStartPush(k) => Instr::IMemStartPush(k as nat),
        EInstr::IMemEnd(k) => Instr::IMemEnd(k as nat),
        EInstr::IEmptyStart(i) => Instr::IEmptyStart(i as nat),
        EInstr::IEmptyEnd(i) => Instr::IEmptyEnd(i as nat),
        EInstr::IEnd => Instr::IEnd,
    }
}

pub open spec fn insv(ins: Seq<EInstr>) -> Seq<Instr> {
    ins.map_values(|i: EInstr| iv(i))
}

pub open spec fn spv(o: Option<(usize, usize)>) -> Span {
    match o { Some((a, b)) => Some((a as nat, b as nat)), None => None }
}

pub enum ERes {
    Match(usize, Vec<Option<(usize, usize)>>),
    NoMatch,
    OutOfFuel,
}

pub open spec fn resv(r: ERes) -> Res {
    match r {
        ERes::Match(e, caps) => Res::Match(e as nat, caps@.map_values(|o: Option<(usize, usize)>| spv(o))),
        ERes::NoMatch => Res::NoMatch,
        ERes::OutOfFuel => Res::OutOfFuel,
    }
}

pub open spec fn sresv(o: Option<(usize, ERes)>) -> Option<(nat, Res)> {
    match o { Some((p, r)) => Some((p as nat, resv(r))), None => None }
}

// Highest group number, exec.
pub fn encap(r: &ERegex) -> (n: usize)
    ensures n as nat == ncap(rv(*r)),
    decreases r,
{
    match r {
        ERegex::Eps => 0,
        ERegex::Lit(_) => 0,
        ERegex::Cat(a, b) | ERegex::Alt(a, b) => {
            let x = encap(a);
            let y = encap(b);
            if x >= y { x } else { y }
        }
        ERegex::Star(a) => encap(a),
        ERegex::Group(k, a) => {
            let y = encap(a);
            if *k >= y { *k } else { y }
        }
    }
}

// is_prefix_at, exec
pub fn eis_prefix_at(l: &Vec<u8>, s: &Vec<u8>, pos: usize) -> (b: bool)
    ensures b == is_prefix_at(l@, s@, pos as nat),
{
    let n = l.len();
    if n == 0 {
        return true;
    }
    if pos > s.len() || n > s.len() - pos {
        return false;
    }
    let mut j: usize = 0;
    while j < n
        invariant
            n == l.len(), pos + n <= s.len(), j <= n,
            forall|i: int| 0 <= i < j ==> s@[pos + i] == l@[i],
        decreases n - j,
    {
        if s[pos + j] != l[j] {
            assert(s@.subrange(pos as int, pos + n)[j as int] != l@[j as int]);
            return false;
        }
        j = j + 1;
    }
    assert(s@.subrange(pos as int, pos + n) =~= l@);
    true
}

} // verus!
