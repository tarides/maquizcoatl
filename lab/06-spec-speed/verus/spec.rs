// Experiment #6, Verus: executable semantics of experiment #9's subset of
// Oniguruma f95747b (concatenation, alternation, greedy star, capture
// groups, character classes; UTF-8; forward search), transcribed from
// stack G (lab/06-spec-speed/g/g.ml) as the same small-step machine as
// rocq/Spec.v: stack G's pending items plus an explicit list of
// backtracking points, one machine step per call of stack G's step.
//
// Exec code only (criterion 3: Verus spec fns are ghost, only exec code
// runs); Verus checks it for safety (bounds, arithmetic overflow,
// termination by the fuel), with no functional specification.  Rust
// shape: the pattern is an arena (`nodes`, with literal bytes and class
// ranges in side pools, children by index), the pending items are a
// Vec used as a stack (top last) that is cloned into each backtracking
// point, positions index the subject.  An index outside the arena is
// treated as Eps; gen.py only emits well-formed arenas.
use vstd::prelude::*;

verus! {

#[derive(Clone, Copy)]
pub enum Node {
    Eps,
    Lit(usize, usize),          // start, length in `bytes`
    Cls(bool, usize, usize),    // negated, start, length in `ranges`
    Cat(usize, usize),
    Alt(usize, usize),
    Star(usize),                // greedy
    Group(usize, usize),        // group number, body
}

pub struct Re {
    pub nodes: Vec<Node>,
    pub bytes: Vec<u8>,
    pub ranges: Vec<(u32, u32)>,
    pub root: usize,
    pub ncap: usize,
}

#[derive(Clone, Copy)]
pub enum Item {
    INode(usize),
    IClose(usize, usize),       // group, start position
    ILoop(usize, usize),        // the Star node, iteration start
}

pub struct Frame {
    pub items: Vec<Item>,
    pub pos: usize,
    pub caps: Vec<(usize, usize, usize)>,
}

pub enum Outcome {
    Matched(usize, Vec<(usize, usize, usize)>),
    Failed,
    Limit,
}

// UTF-8, as upstream/src/utf8.c (EncLen_UTF8, USE_RFC3629_RANGE)
pub fn enc_len(b: u8) -> (r: usize)
    ensures 1 <= r <= 4,
{
    if b < 194 { 1 } else if b < 224 { 2 } else if b < 240 { 3 } else if b < 245 { 4 } else { 1 }
}

fn node_at(re: &Re, i: usize) -> Node {
    if i < re.nodes.len() { re.nodes[i] } else { Node::Eps }
}

fn vec_clone_items(v: &Vec<Item>) -> (r: Vec<Item>) {
    let mut r: Vec<Item> = Vec::new();
    let mut i: usize = 0;
    while i < v.len()
        decreases v.len() - i,
    {
        r.push(v[i]);
        i = i + 1;
    }
    r
}

fn vec_clone_caps(v: &Vec<(usize, usize, usize)>) -> (r: Vec<(usize, usize, usize)>) {
    let mut r: Vec<(usize, usize, usize)> = Vec::new();
    let mut i: usize = 0;
    while i < v.len()
        decreases v.len() - i,
    {
        r.push(v[i]);
        i = i + 1;
    }
    r
}

// does the literal (start, len) occur at pos?  Returns the new position.
fn lit_at(re: &Re, s: &Vec<u8>, pos: usize, start: usize, len: usize) -> (r: Option<usize>) {
    if pos > s.len() || len > s.len() - pos {
        return None;
    }
    let mut j: usize = 0;
    while j < len
        invariant pos <= s.len(), len <= s.len() - pos,
        decreases len - j,
    {
        if start >= re.bytes.len() || j >= re.bytes.len() - start {
            return None;
        }
        if s[pos + j] != re.bytes[start + j] {
            return None;
        }
        j = j + 1;
    }
    Some(pos + len)
}

// code point and encoded length at pos; None past the end (DATA_ENSURE)
fn decode(s: &Vec<u8>, pos: usize) -> (r: Option<(u32, usize)>) {
    if pos >= s.len() {
        return None;
    }
    let b = s[pos];
    let l = enc_len(b);
    if l > s.len() - pos {
        return None;
    }
    if l == 1 {
        return Some((b as u32, 1));
    }
    let mask: u8 = if l == 2 { 31 } else if l == 3 { 15 } else { 7 };
    let mut v: u32 = (b & mask) as u32;
    let mut j: usize = 1;
    while j < l
        invariant l <= s.len() - pos, pos < s.len(), l <= 4,
        decreases l - j,
    {
        let d = s[pos + j];
        v = ((v & 0x3ffffff) << 6u32) | ((d & 63) as u32);
        j = j + 1;
    }
    Some((v, l))
}

fn in_ranges(re: &Re, c: u32, start: usize, len: usize) -> bool {
    let mut j: usize = 0;
    while j < len
        decreases len - j,
    {
        if start >= re.ranges.len() || j >= re.ranges.len() - start {
            return false;
        }
        let (lo, hi) = re.ranges[start + j];
        if lo <= c && c <= hi {
            return true;
        }
        j = j + 1;
    }
    false
}

fn set_cap(caps: &mut Vec<(usize, usize, usize)>, k: usize, s: usize, e: usize) {
    let mut i: usize = 0;
    while i < caps.len()
        decreases caps.len() - i,
    {
        if caps[i].0 == k {
            caps.set(i, (k, s, e));
            return;
        }
        i = i + 1;
    }
    caps.push((k, s, e));
}

// the machine from start, at most fuel steps
pub fn run(re: &Re, s: &Vec<u8>, start: usize, fuel: u64) -> Outcome {
    let mut items: Vec<Item> = Vec::new();
    items.push(Item::INode(re.root));
    let mut pos = start;
    let mut caps: Vec<(usize, usize, usize)> = Vec::new();
    let mut bt: Vec<Frame> = Vec::new();
    let mut fuel = fuel;
    loop
        decreases fuel,
    {
        if fuel == 0 {
            return Outcome::Limit;
        }
        fuel = fuel - 1;
        let mut fail = false;
        match items.pop() {
            None => { return Outcome::Matched(pos, caps); }
            Some(Item::INode(n)) => {
                match node_at(re, n) {
                    Node::Eps => {}
                    Node::Lit(st, len) => {
                        match lit_at(re, s, pos, st, len) {
                            Some(p) => { pos = p; }
                            None => { fail = true; }
                        }
                    }
                    Node::Cls(ng, st, len) => {
                        match decode(s, pos) {
                            Some((c, l)) => {
                                if in_ranges(re, c, st, len) == ng { fail = true; }
                                else if pos <= s.len() && l <= s.len() - pos { pos = pos + l; }
                                else { fail = true; }
                            }
                            None => { fail = true; }
                        }
                    }
                    Node::Cat(a, b) => { items.push(Item::INode(b)); items.push(Item::INode(a)); }
                    Node::Alt(a, b) => {
                        let mut k = vec_clone_items(&items);
                        k.push(Item::INode(b));
                        bt.push(Frame { items: k, pos, caps: vec_clone_caps(&caps) });
                        items.push(Item::INode(a));
                    }
                    Node::Star(a) => {
                        bt.push(Frame { items: vec_clone_items(&items), pos, caps: vec_clone_caps(&caps) });
                        items.push(Item::ILoop(n, pos));
                        items.push(Item::INode(a));
                    }
                    Node::Group(i, a) => { items.push(Item::IClose(i, pos)); items.push(Item::INode(a)); }
                }
            }
            Some(Item::ILoop(n, p0)) => {
                // an iteration that ends where it started leaves the loop
                if pos != p0 { items.push(Item::INode(n)); }
            }
            Some(Item::IClose(i, p0)) => { set_cap(&mut caps, i, p0, pos); }
        }
        if fail {
            match bt.pop() {
                None => { return Outcome::Failed; }
                Some(f) => { items = f.items; pos = f.pos; caps = f.caps; }
            }
        }
    }
}

pub enum SResult {
    Match(usize, usize, Vec<(usize, usize, usize)>),
    Mismatch,
    Limit,
}

// forward search: start positions 0..length, advanced by enc_len
pub fn search(re: &Re, s: &Vec<u8>, fuel: u64) -> SResult {
    let mut start: usize = 0;
    loop
        invariant start <= s.len(),
        decreases s.len() - start,
    {
        match run(re, s, start, fuel) {
            Outcome::Matched(e, caps) => { return SResult::Match(start, e, caps); }
            Outcome::Limit => { return SResult::Limit; }
            Outcome::Failed => {
                if start >= s.len() { return SResult::Mismatch; }
                let l = enc_len(s[start]);
                if l > s.len() - start { return SResult::Mismatch; }
                start = start + l;
            }
        }
    }
}

// verdict as numbers: [0] no match, [2] limit, 1, s, e, then per group
// [1, s, e] or [0] when unset
pub fn encode(ncap: usize, r: &SResult) -> Vec<u64> {
    let mut out: Vec<u64> = Vec::new();
    match r {
        SResult::Mismatch => { out.push(0); }
        SResult::Limit => { out.push(2); }
        SResult::Match(st, e, caps) => {
            out.push(1); out.push(*st as u64); out.push(*e as u64);
            let mut i: usize = 0;
            while i < ncap
                decreases ncap - i,
            {
                let k = i + 1;
                let mut found = false;
                let mut j: usize = 0;
                while j < caps.len()
                    decreases caps.len() - j,
                {
                    let (k2, x, y) = caps[j];
                    if k2 == k {
                        out.push(1); out.push(x as u64); out.push(y as u64);
                        found = true;
                        break;
                    }
                    j = j + 1;
                }
                if !found { out.push(0); }
                i = i + 1;
            }
        }
    }
    out
}

pub const FUEL0: u64 = 10_000_000;

pub fn run_case(fuel: u64, ncap: usize, re: &Re, s: &Vec<u8>) -> Vec<u64> {
    let r = search(re, s, fuel);
    encode(ncap, &r)
}

// a case: number of groups, pattern, subject bytes, expected verdict
pub struct Case {
    pub ncap: usize,
    pub re: Re,
    pub s: Vec<u8>,
    pub exp: Vec<u64>,
}

fn eq_vec(a: &Vec<u64>, b: &Vec<u64>) -> bool {
    if a.len() != b.len() { return false; }
    let mut i: usize = 0;
    while i < a.len()
        invariant a.len() == b.len(),
        decreases a.len() - i,
    {
        if a[i] != b[i] { return false; }
        i = i + 1;
    }
    true
}

pub fn count(fuel: u64, cs: &Vec<Case>) -> u64 {
    let mut n: u64 = 0;
    let mut i: usize = 0;
    while i < cs.len()
        invariant n <= i,
        decreases cs.len() - i,
    {
        let c = &cs[i];
        if eq_vec(&run_case(fuel, c.ncap, &c.re, &c.s), &c.exp) { n = n + 1; }
        i = i + 1;
    }
    n
}

// r passes; pass i uses FUEL0 + (i mod 1024) so that no pass can be shared
pub fn passes(r: u64, cs: &Vec<Case>) -> u64 {
    let mut acc: u64 = 0;
    let mut i: u64 = 0;
    while i < r
        decreases r - i,
    {
        let c = count(FUEL0 + (i % 1024), cs);
        acc = acc.wrapping_add(c);
        i = i + 1;
    }
    acc
}

} // verus!
