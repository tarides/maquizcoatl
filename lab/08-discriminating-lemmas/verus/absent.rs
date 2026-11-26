// Experiment #8, Verus: the absent operator (non-nested).
// Semantics fixed in lab/08-hard-features/SEMANTICS.md, "Absent operator".
// The state carries the right range rr; every consuming step checks i < rr.
//
// Experiment #8 follow-up (issue #34), changes to experiment #8's file
// (lab/08-hard-features/verus/absent.rs), the same as rocq/Absent.v's and
// recorded in lab/08-discriminating-lemmas/LEMMAS.md, section "Changes to
// experiment #8's definitions":
// C1 mb returns Option<bool> (None: out of fuel), so that occ's fuel
//    exhaustion is observable;
// C2 occ takes its fuel g as a parameter (was the constant fuel());
// C3 scan, cut and rep_ends return options and propagate None;
// C4 m returns Option<L<nat>> (None: out of fuel, or an occ out of fuel)
//    and takes g;
// C5 search takes both fuels and returns a three-way result; experiment
//    #8's case checks ab01-ab11 moved to cases.rs (and the file's
//    fn main() {} dropped: it is a module of the crate lib.rs);
// C6 lemma A (absent_not_inside) restated for the option cut.
// The equations are otherwise experiment #8's (rocq/Absent.v's).
use vstd::prelude::*;

verus! {

pub enum Re { Eps, Chr(nat), Any, AnyO, Seq(Box<Re>, Box<Re>), Alt(Box<Re>, Box<Re>), Star(Box<Re>),
              AbsRep(Box<Re>), AbsExp(Box<Re>, Box<Re>), Stopper(Box<Re>), RClear }
pub enum L<A> { Nil, Cons(A, Box<L<A>>) }
pub enum Item { R(Re), Chk(nat, Re), SetRR(nat), Ends(L<nat>) }

pub open spec fn cons<A>(x: A, t: L<A>) -> L<A> { L::Cons(x, Box::new(t)) }
pub open spec fn len<A>(l: L<A>) -> nat decreases l {
    match l { L::Nil => 0, L::Cons(_, t) => 1 + len(*t) }
}
pub open spec fn nth<A>(l: L<A>, n: nat) -> Option<A> decreases l {
    match l { L::Nil => None, L::Cons(x, t) => if n == 0 { Some(x) } else { nth(*t, (n - 1) as nat) } }
}
pub open spec fn app<A>(a: L<A>, b: L<A>) -> L<A> decreases a {
    match a { L::Nil => b, L::Cons(x, t) => L::Cons(x, Box::new(app(*t, b))) }
}
pub open spec fn mem<A>(x: A, l: L<A>) -> bool decreases l {
    match l { L::Nil => false, L::Cons(y, t) => y == x || mem(x, *t) }
}
pub open spec fn at_(s: L<nat>, i: nat, rr: nat) -> Option<nat> { if i < rr { nth(s, i) } else { None } }

// Base matcher, absent-free patterns: does ks have a result at i?
// None: out of fuel (C1); Alt and Star: a true left branch decides.
pub open spec fn mb(s: L<nat>, f: nat, ks: L<Item>, i: nat, rr: nat) -> Option<bool> decreases f {
    if f == 0 { None } else {
        let f1 = (f - 1) as nat;
        match ks {
            L::Nil => Some(true),
            L::Cons(it, rest) => {
                let ks = *rest;
                match it {
                    Item::R(r) => match r {
                        Re::Eps => mb(s, f1, ks, i, rr),
                        Re::Chr(c) => match at_(s, i, rr) { Some(c2) => if c == c2 { mb(s, f1, ks, i + 1, rr) } else { Some(false) }, None => Some(false) },
                        Re::Any => match at_(s, i, rr) { Some(c2) => if c2 == 10 { Some(false) } else { mb(s, f1, ks, i + 1, rr) }, None => Some(false) },
                        Re::AnyO => match at_(s, i, rr) { Some(_) => mb(s, f1, ks, i + 1, rr), None => Some(false) },
                        Re::Seq(a, b) => mb(s, f1, cons(Item::R(*a), cons(Item::R(*b), ks)), i, rr),
                        Re::Alt(a, b) => match mb(s, f1, cons(Item::R(*a), ks), i, rr) {
                            Some(true) => Some(true),
                            Some(false) => mb(s, f1, cons(Item::R(*b), ks), i, rr),
                            None => None,
                        },
                        Re::Star(a) => match mb(s, f1, cons(Item::R(*a), cons(Item::Chk(i, *a), ks)), i, rr) {
                            Some(true) => Some(true),
                            Some(false) => mb(s, f1, ks, i, rr),
                            None => None,
                        },
                        _ => Some(false), // absent constructors: out of scope here
                    },
                    Item::Chk(i0, a) => if i == i0 { mb(s, f1, ks, i, rr) }
                                        else { mb(s, f1, cons(Item::R(Re::Star(Box::new(a))), ks), i, rr) },
                    Item::SetRR(n) => mb(s, f1, ks, i, n),
                    Item::Ends(_) => Some(false),
                }
            }
        }
    }
}

// occ's fuel g is a parameter (C2).
pub open spec fn occ(a: Re, s: L<nat>, g: nat, p: nat, rr: nat) -> Option<bool> { mb(s, g, cons(Item::R(a), L::Nil), p, rr) }

pub open spec fn scan(a: Re, s: L<nat>, g: nat, rr: nat, k: nat, p: nat) -> Option<nat> decreases k {
    if k == 0 { Some(p) } else {
        match occ(a, s, g, p, rr) {
            Some(true) => Some(p),
            Some(false) => scan(a, s, g, rr, (k - 1) as nat, p + 1),
            None => None,
        }
    }
}
pub open spec fn cut(a: Re, s: L<nat>, g: nat, i: nat, rr: nat) -> Option<nat> {
    scan(a, s, g, rr, if rr >= i { (rr - i) as nat } else { 0 }, i)
}
pub open spec fn downs(n: nat, i: nat) -> L<nat> decreases n {
    if n == 0 { cons(i, L::Nil) } else { cons(i + n, downs((n - 1) as nat, i)) }
}
pub open spec fn rep_ends(a: Re, s: L<nat>, g: nat, i: nat, rr: nat) -> Option<L<nat>> {
    match cut(a, s, g, i, rr) {
        Some(c) => Some(downs(if c >= i { (c - i) as nat } else { 0 }, i)),
        None => None,
    }
}

// Option append: both sides complete (C4).
pub open spec fn oapp(x: Option<L<nat>>, y: Option<L<nat>>) -> Option<L<nat>> {
    match (x, y) { (Some(l1), Some(l2)) => Some(app(l1, l2)), _ => None }
}

pub open spec fn m(s: L<nat>, g: nat, f: nat, ks: L<Item>, i: nat, rr: nat) -> Option<L<nat>> decreases f {
    if f == 0 { None } else {
        let f1 = (f - 1) as nat;
        match ks {
            L::Nil => Some(cons(i, L::Nil)),
            L::Cons(it, rest) => {
                let ks = *rest;
                match it {
                    Item::R(r) => match r {
                        Re::Eps => m(s, g, f1, ks, i, rr),
                        Re::Chr(c) => match at_(s, i, rr) { Some(c2) => if c == c2 { m(s, g, f1, ks, i + 1, rr) } else { Some(L::Nil) }, None => Some(L::Nil) },
                        Re::Any => match at_(s, i, rr) { Some(c2) => if c2 == 10 { Some(L::Nil) } else { m(s, g, f1, ks, i + 1, rr) }, None => Some(L::Nil) },
                        Re::AnyO => match at_(s, i, rr) { Some(_) => m(s, g, f1, ks, i + 1, rr), None => Some(L::Nil) },
                        Re::Seq(a, b) => m(s, g, f1, cons(Item::R(*a), cons(Item::R(*b), ks)), i, rr),
                        Re::Alt(a, b) => oapp(m(s, g, f1, cons(Item::R(*a), ks), i, rr), m(s, g, f1, cons(Item::R(*b), ks), i, rr)),
                        Re::Star(a) => oapp(m(s, g, f1, cons(Item::R(*a), cons(Item::Chk(i, *a), ks)), i, rr), m(s, g, f1, ks, i, rr)),
                        Re::AbsRep(a) => match rep_ends(*a, s, g, i, rr) {
                            Some(es) => m(s, g, f1, cons(Item::Ends(es), ks), i, rr),
                            None => None,
                        },
                        Re::AbsExp(a, e) => match cut(*a, s, g, i, rr) {
                            Some(c) => m(s, g, f1, cons(Item::R(*e), cons(Item::SetRR(rr), ks)), i, c),
                            None => None,
                        },
                        Re::Stopper(a) => match cut(*a, s, g, i, rr) {
                            Some(c) => m(s, g, f1, ks, i, c),
                            None => None,
                        },
                        Re::RClear => m(s, g, f1, ks, i, len(s)),
                    },
                    Item::Chk(i0, a) => if i == i0 { m(s, g, f1, ks, i, rr) }
                                        else { m(s, g, f1, cons(Item::R(Re::Star(Box::new(a))), ks), i, rr) },
                    Item::SetRR(n) => m(s, g, f1, ks, i, n),
                    Item::Ends(es) => match es {
                        L::Nil => Some(L::Nil),
                        L::Cons(e, es2) => oapp(m(s, g, f1, ks, e, rr), m(s, g, f1, cons(Item::Ends(*es2), ks), i, rr)),
                    },
                }
            }
        }
    }
}

// Search result (C5): the first start with a result, no match, or out of
// fuel at some start.
pub enum SRes { Match(nat, nat), NoMatch, OutOfFuel }

pub open spec fn search_from(s: L<nat>, g: nat, f: nat, main: Re, k: nat, st: nat) -> SRes decreases k {
    if k == 0 { SRes::NoMatch } else {
        match m(s, g, f, cons(Item::R(main), L::Nil), st, len(s)) {
            Some(L::Cons(e, _)) => SRes::Match(st, e),
            Some(L::Nil) => search_from(s, g, f, main, (k - 1) as nat, st + 1),
            None => SRes::OutOfFuel,
        }
    }
}
pub open spec fn search(g: nat, f: nat, main: Re, s: L<nat>) -> SRes { search_from(s, g, f, main, len(s) + 1, 0) }

// Main lemma (SEMANTICS.md, "Absent operator", lemma A), for the option
// cut (C6).
pub proof fn scan_ge(a: Re, s: L<nat>, g: nat, rr: nat, k: nat, p: nat, c: nat)
    requires scan(a, s, g, rr, k, p) == Some(c),
    ensures p <= c,
    decreases k
{
    if k > 0 && occ(a, s, g, p, rr) == Some(false) { scan_ge(a, s, g, rr, (k - 1) as nat, p + 1, c); }
}

pub proof fn scan_none(a: Re, s: L<nat>, g: nat, rr: nat, k: nat, p: nat, q: nat, c: nat)
    requires scan(a, s, g, rr, k, p) == Some(c), p <= q, q < c,
    ensures occ(a, s, g, q, rr) == Some(false),
    decreases k
{
    if k > 0 && occ(a, s, g, p, rr) == Some(false) && q != p { scan_none(a, s, g, rr, (k - 1) as nat, p + 1, q, c); }
}

pub proof fn downs_mem(n: nat, i: nat, e: nat)
    requires mem(e, downs(n, i)),
    ensures i <= e <= i + n,
    decreases n
{
    reveal_with_fuel(mem, 2); // help: [i] needs mem unfolded twice
    if n > 0 && e != i + n { downs_mem((n - 1) as nat, i, e); }
}

pub proof fn absent_not_inside(a: Re, s: L<nat>, g: nat, i: nat, rr: nat, es: L<nat>, e: nat, p: nat)
    requires rep_ends(a, s, g, i, rr) == Some(es), mem(e, es), i <= p, p < e,
    ensures occ(a, s, g, p, rr) == Some(false),
{
    let k = if rr >= i { (rr - i) as nat } else { 0 };
    let c = cut(a, s, g, i, rr)->0;
    scan_ge(a, s, g, rr, k, i, c);
    downs_mem(if c >= i { (c - i) as nat } else { 0 }, i, e);
    scan_none(a, s, g, rr, k, i, p, c);
}

} // verus!
