// Experiment #9, Verus: the reference semantics (FRAGMENT.md 4),
// transcribed from fstar/Sem.fst: a backtracking tree in Linden's style.
// `compute_tree` unfolds the pattern, under a list of pending actions
// (the continuation; its head is the last element of the Seq), into the
// tree of choices in priority order; the result is the tree's leftmost
// leaf that is a match.  The empty-iteration rule is DEV-008 on the
// fragment, i.e. upstream's plain check.  Fuel: one unit per
// `compute_tree` call, as in Rocq and F* (FRAGMENT.md 4, "Fuel, per
// tool").
//
// The spec fns are the semantics.  Verus does not run spec fns, so the
// exec fns below (`ecompute_tree`, `efirst_match`, `esem`, ...) mirror
// them on exec data and are proved to return exactly the spec fns'
// results (their `ensures`); the driver runs those.
use vstd::prelude::*;
use crate::syntax::*;

verus! {

// captures: group number -> span, last write last (F*: first)
pub type GMap = Seq<(nat, (nat, nat))>;

pub open spec fn gget(k: nat, g: GMap) -> Span
    decreases g.len(),
{
    if g.len() == 0 {
        None
    } else if g.last().0 == k {
        Some(g.last().1)
    } else {
        gget(k, g.drop_last())
    }
}

pub open spec fn gset(k: nat, v: (nat, nat), g: GMap) -> GMap { g.push((k, v)) }

// pending actions
pub enum Action {
    ARe(Regex),             // match r
    ACheck(nat, Regex),     // end of an iteration of Star r begun at p0
    AClose(nat, nat),       // close group k opened at p0
}

pub enum Tree {
    TMismatch,
    TMatch(nat, GMap),
    TChoice(Box<Tree>, Box<Tree>),  // the first has priority
}

pub open spec fn compute_tree(fuel: nat, s: Seq<u8>, acts: Seq<Action>, pos: nat, g: GMap) -> Option<Tree>
    decreases fuel,
{
    if fuel == 0 {
        None
    } else {
        let f = (fuel - 1) as nat;
        if acts.len() == 0 {
            Some(Tree::TMatch(pos, g))
        } else {
            let k = acts.drop_last();
            match acts.last() {
                Action::ARe(r) => match r {
                    Regex::Eps => compute_tree(f, s, k, pos, g),
                    Regex::Lit(l) =>
                        if is_prefix_at(l, s, pos) { compute_tree(f, s, k, pos + l.len(), g) }
                        else { Some(Tree::TMismatch) },
                    Regex::Cat(a, b) => compute_tree(f, s, k.push(Action::ARe(*b)).push(Action::ARe(*a)), pos, g),
                    Regex::Alt(a, b) =>
                        match (compute_tree(f, s, k.push(Action::ARe(*a)), pos, g),
                               compute_tree(f, s, k.push(Action::ARe(*b)), pos, g)) {
                            (Some(t1), Some(t2)) => Some(Tree::TChoice(Box::new(t1), Box::new(t2))),
                            _ => None,
                        },
                    // greedy: one more iteration first, then leave the loop
                    Regex::Star(a) =>
                        match (compute_tree(f, s, k.push(Action::ACheck(pos, *a)).push(Action::ARe(*a)), pos, g),
                               compute_tree(f, s, k, pos, g)) {
                            (Some(t1), Some(t2)) => Some(Tree::TChoice(Box::new(t1), Box::new(t2))),
                            _ => None,
                        },
                    Regex::Group(n, a) => compute_tree(f, s, k.push(Action::AClose(n, pos)).push(Action::ARe(*a)), pos, g),
                },
                // plain empty check: an empty iteration leaves the loop
                Action::ACheck(p0, a) =>
                    if pos == p0 { compute_tree(f, s, k, pos, g) }
                    else { compute_tree(f, s, k.push(Action::ARe(Regex::Star(Box::new(a)))), pos, g) },
                Action::AClose(n, p0) => compute_tree(f, s, k, pos, gset(n, (p0, pos), g)),
            }
        }
    }
}

// leftmost match leaf
pub open spec fn first_match(t: Tree) -> Option<(nat, GMap)>
    decreases t,
{
    match t {
        Tree::TMismatch => None,
        Tree::TMatch(e, g) => Some((e, g)),
        Tree::TChoice(t1, t2) => match first_match(*t1) {
            Some(x) => Some(x),
            None => first_match(*t2),
        },
    }
}

// spans of groups 1..n
pub open spec fn spans(n: nat, g: GMap) -> Seq<Span> {
    Seq::new(n, |i: int| gget((i + 1) as nat, g))
}

// the semantics of r on subject s at start position p
pub open spec fn sem(fuel: nat, r: Regex, s: Seq<u8>, p: nat) -> Res {
    match compute_tree(fuel, s, seq![Action::ARe(r)], p, Seq::empty()) {
        None => Res::OutOfFuel,
        Some(t) => match first_match(t) {
            None => Res::NoMatch,
            Some((e, g)) => Res::Match(e, spans(ncap(r), g)),
        },
    }
}

pub open spec fn sem_at(fuel: nat, r: Regex, s: Seq<u8>) -> spec_fn(nat) -> Res {
    |p: nat| sem(fuel, r, s, p)
}

// ---- exec mirror ----

pub type EGMap = Vec<(usize, (usize, usize))>;

pub open spec fn gv(g: Seq<(usize, (usize, usize))>) -> GMap {
    g.map_values(|x: (usize, (usize, usize))| (x.0 as nat, (x.1.0 as nat, x.1.1 as nat)))
}

// An exec action borrows its pattern; ACheck holds the Star node itself
// (its view is the Star's body), so that leaving the iteration can push
// the Star again without building a node.
#[derive(Clone, Copy)]
pub enum EAction<'a> {
    ARe(&'a ERegex),
    ACheck(usize, &'a ERegex),
    AClose(usize, usize),
}

pub open spec fn star_body(r: Regex) -> Regex {
    match r { Regex::Star(a) => *a, _ => Regex::Eps }
}

pub open spec fn av(a: EAction) -> Action {
    match a {
        EAction::ARe(r) => Action::ARe(rv(*r)),
        EAction::ACheck(p, r) => Action::ACheck(p as nat, star_body(rv(*r))),
        EAction::AClose(k, p) => Action::AClose(k as nat, p as nat),
    }
}

pub open spec fn actsv(v: Seq<EAction>) -> Seq<Action> { v.map_values(|a: EAction| av(a)) }

pub open spec fn acts_wf(v: Seq<EAction>) -> bool {
    forall|i: int| 0 <= i < v.len() ==> (#[trigger] v[i] matches EAction::ACheck(_, r) ==> *r is Star)
}

pub enum ETree {
    TMismatch,
    TMatch(usize, EGMap),
    TChoice(Box<ETree>, Box<ETree>),
}

pub open spec fn tv(t: ETree) -> Tree
    decreases t,
{
    match t {
        ETree::TMismatch => Tree::TMismatch,
        ETree::TMatch(e, g) => Tree::TMatch(e as nat, gv(g@)),
        ETree::TChoice(a, b) => Tree::TChoice(Box::new(tv(*a)), Box::new(tv(*b))),
    }
}

pub open spec fn otv(o: Option<ETree>) -> Option<Tree> {
    match o { Some(t) => Some(tv(t)), None => None }
}

pub fn copy_vec<T: Copy>(v: &Vec<T>) -> (r: Vec<T>)
    ensures r@ == v@,
{
    let mut r: Vec<T> = Vec::new();
    let mut i: usize = 0;
    while i < v.len()
        invariant i <= v.len(), r@ =~= v@.subrange(0, i as int),
        decreases v.len() - i,
    {
        r.push(v[i]);
        i = i + 1;
    }
    assert(r@ =~= v@);
    r
}

pub fn ecompute_tree<'a>(fuel: u64, s: &Vec<u8>, acts: &Vec<EAction<'a>>, pos: usize, g: &EGMap) -> (r: Option<ETree>)
    requires acts_wf(acts@),
    ensures otv(r) == compute_tree(fuel as nat, s@, actsv(acts@), pos as nat, gv(g@)),
    decreases fuel,
{
    if fuel == 0 {
        return None;
    }
    let f = fuel - 1;
    if acts.len() == 0 {
        return Some(ETree::TMatch(pos, copy_vec(g)));
    }
    let ghost av0 = actsv(acts@);
    let mut k = copy_vec(acts);
    let top = k[k.len() - 1];
    k.pop();
    assert(actsv(k@) =~= av0.drop_last());
    assert(av(top) == av0.last());
    match top {
        EAction::ARe(r) => match r {
            ERegex::Eps => ecompute_tree(f, s, &k, pos, g),
            ERegex::Lit(l) => {
                if eis_prefix_at(l, s, pos) {
                    let sl = s.len();
                    assert(l@.len() == 0 || pos + l@.len() <= sl);
                    ecompute_tree(f, s, &k, pos + l.len(), g)
                } else {
                    Some(ETree::TMismatch)
                }
            }
            ERegex::Cat(a, b) => {
                let ghost kv = actsv(k@);
                k.push(EAction::ARe(&**b));
                k.push(EAction::ARe(&**a));
                assert(actsv(k@) =~= kv.push(Action::ARe(rv(**b))).push(Action::ARe(rv(**a))));
                ecompute_tree(f, s, &k, pos, g)
            }
            ERegex::Alt(a, b) => {
                let ghost kv = actsv(k@);
                let mut ka = copy_vec(&k);
                ka.push(EAction::ARe(&**a));
                assert(actsv(ka@) =~= kv.push(Action::ARe(rv(**a))));
                let t1 = ecompute_tree(f, s, &ka, pos, g);
                k.push(EAction::ARe(&**b));
                assert(actsv(k@) =~= kv.push(Action::ARe(rv(**b))));
                let t2 = ecompute_tree(f, s, &k, pos, g);
                match (t1, t2) {
                    (Some(x), Some(y)) => Some(ETree::TChoice(Box::new(x), Box::new(y))),
                    _ => None,
                }
            }
            ERegex::Star(a) => {
                let ghost kv = actsv(k@);
                let mut ka = copy_vec(&k);
                ka.push(EAction::ACheck(pos, r));
                ka.push(EAction::ARe(&**a));
                assert(actsv(ka@) =~= kv.push(Action::ACheck(pos as nat, rv(**a))).push(Action::ARe(rv(**a))));
                let t1 = ecompute_tree(f, s, &ka, pos, g);
                let t2 = ecompute_tree(f, s, &k, pos, g);
                match (t1, t2) {
                    (Some(x), Some(y)) => Some(ETree::TChoice(Box::new(x), Box::new(y))),
                    _ => None,
                }
            }
            ERegex::Group(n, a) => {
                let ghost kv = actsv(k@);
                k.push(EAction::AClose(*n, pos));
                k.push(EAction::ARe(&**a));
                assert(actsv(k@) =~= kv.push(Action::AClose(*n as nat, pos as nat)).push(Action::ARe(rv(**a))));
                ecompute_tree(f, s, &k, pos, g)
            }
        },
        EAction::ACheck(p0, r) => {
            if pos == p0 {
                ecompute_tree(f, s, &k, pos, g)
            } else {
                let ghost kv = actsv(k@);
                k.push(EAction::ARe(r));
                assert(actsv(k@) =~= kv.push(Action::ARe(Regex::Star(Box::new(star_body(rv(*r)))))));
                ecompute_tree(f, s, &k, pos, g)
            }
        }
        EAction::AClose(n, p0) => {
            let mut g2 = copy_vec(g);
            g2.push((n, (p0, pos)));
            assert(gv(g2@) =~= gset(n as nat, (p0 as nat, pos as nat), gv(g@)));
            ecompute_tree(f, s, &k, pos, &g2)
        }
    }
}

pub open spec fn ofv(o: Option<(usize, EGMap)>) -> Option<(nat, GMap)> {
    match o { Some((e, g)) => Some((e as nat, gv(g@))), None => None }
}

pub fn efirst_match(t: &ETree) -> (r: Option<(usize, EGMap)>)
    ensures ofv(r) == first_match(tv(*t)),
    decreases t,
{
    match t {
        ETree::TMismatch => None,
        ETree::TMatch(e, g) => Some((*e, copy_vec(g))),
        ETree::TChoice(t1, t2) => match efirst_match(t1) {
            Some(x) => Some(x),
            None => efirst_match(t2),
        },
    }
}

pub fn egget(k: usize, g: &EGMap) -> (r: Option<(usize, usize)>)
    ensures spv(r) == gget(k as nat, gv(g@)),
{
    let mut i = g.len();
    assert(g@.subrange(0, i as int) =~= g@);
    while i > 0
        invariant i <= g.len(), gget(k as nat, gv(g@)) == gget(k as nat, gv(g@.subrange(0, i as int))),
        decreases i,
    {
        let ghost sub = gv(g@.subrange(0, i as int));
        assert(sub.drop_last() =~= gv(g@.subrange(0, i - 1)));
        let (k2, v) = g[i - 1];
        if k2 == k {
            return Some(v);
        }
        i = i - 1;
    }
    None
}

pub fn espans(n: usize, g: &EGMap) -> (r: Vec<Option<(usize, usize)>>)
    ensures r@.map_values(|o: Option<(usize, usize)>| spv(o)) == spans(n as nat, gv(g@)),
{
    let mut r: Vec<Option<(usize, usize)>> = Vec::new();
    let mut i: usize = 0;
    while i < n
        invariant i <= n,
            r@.map_values(|o: Option<(usize, usize)>| spv(o)) =~= Seq::new(i as nat, |j: int| gget((j + 1) as nat, gv(g@))),
        decreases n - i,
    {
        let x = egget(i + 1, g);
        let ghost r0 = r@;
        r.push(x);
        assert(r@.map_values(|o: Option<(usize, usize)>| spv(o))
            =~= r0.map_values(|o: Option<(usize, usize)>| spv(o)).push(spv(x)));
        i = i + 1;
    }
    r
}

pub fn esem(fuel: u64, r: &ERegex, s: &Vec<u8>, p: usize) -> (res: ERes)
    ensures resv(res) == sem(fuel as nat, rv(*r), s@, p as nat),
{
    let mut acts: Vec<EAction> = Vec::new();
    acts.push(EAction::ARe(r));
    assert(actsv(acts@) =~= seq![Action::ARe(rv(*r))]);
    let g: EGMap = Vec::new();
    assert(gv(g@) =~= Seq::<(nat, (nat, nat))>::empty());
    match ecompute_tree(fuel, s, &acts, p, &g) {
        None => ERes::OutOfFuel,
        Some(t) => match efirst_match(&t) {
            None => ERes::NoMatch,
            Some((e, g2)) => ERes::Match(e, espans(encap(r), &g2)),
        },
    }
}

// the left-to-right search of the semantics (syntax::search)
pub fn esearch_sem(fuel: u64, r: &ERegex, s: &Vec<u8>) -> (o: Option<(usize, ERes)>)
    requires s.len() < usize::MAX,
    ensures sresv(o) == search(sem_at(fuel as nat, rv(*r), s@), s@),
{
    let ghost m = sem_at(fuel as nat, rv(*r), s@);
    let mut p: usize = 0;
    while p <= s.len()
        invariant p <= s.len() + 1, s.len() < usize::MAX, m == sem_at(fuel as nat, rv(*r), s@),
            search(m, s@) == search_from(m, p as nat, (s.len() + 1 - p) as nat),
        decreases s.len() + 1 - p,
    {
        let x = esem(fuel, r, s, p);
        assert(m(p as nat) == resv(x));
        match x {
            ERes::NoMatch => { p = p + 1; }
            _ => { return Some((p, x)); }
        }
    }
    None
}

} // verus!
