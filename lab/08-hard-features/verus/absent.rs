// Experiment #8, Verus: the absent operator (non-nested).
// Semantics fixed in lab/08-hard-features/SEMANTICS.md, "Absent operator".
// The state carries the right range rr; every consuming step checks i < rr.
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
pub open spec fn mb(s: L<nat>, f: nat, ks: L<Item>, i: nat, rr: nat) -> bool decreases f {
    if f == 0 { false } else {
        let f1 = (f - 1) as nat;
        match ks {
            L::Nil => true,
            L::Cons(it, rest) => {
                let ks = *rest;
                match it {
                    Item::R(r) => match r {
                        Re::Eps => mb(s, f1, ks, i, rr),
                        Re::Chr(c) => match at_(s, i, rr) { Some(c2) => c == c2 && mb(s, f1, ks, i + 1, rr), None => false },
                        Re::Any => match at_(s, i, rr) { Some(c2) => c2 != 10 && mb(s, f1, ks, i + 1, rr), None => false },
                        Re::AnyO => match at_(s, i, rr) { Some(_) => mb(s, f1, ks, i + 1, rr), None => false },
                        Re::Seq(a, b) => mb(s, f1, cons(Item::R(*a), cons(Item::R(*b), ks)), i, rr),
                        Re::Alt(a, b) => mb(s, f1, cons(Item::R(*a), ks), i, rr) || mb(s, f1, cons(Item::R(*b), ks), i, rr),
                        Re::Star(a) => mb(s, f1, cons(Item::R(*a), cons(Item::Chk(i, *a), ks)), i, rr) || mb(s, f1, ks, i, rr),
                        _ => false, // absent constructors: out of scope here
                    },
                    Item::Chk(i0, a) => if i == i0 { mb(s, f1, ks, i, rr) }
                                        else { mb(s, f1, cons(Item::R(Re::Star(Box::new(a))), ks), i, rr) },
                    Item::SetRR(n) => mb(s, f1, ks, i, n),
                    Item::Ends(_) => false,
                }
            }
        }
    }
}

pub open spec fn fuel() -> nat { 1000 }
pub open spec fn occ(a: Re, s: L<nat>, p: nat, rr: nat) -> bool { mb(s, fuel(), cons(Item::R(a), L::Nil), p, rr) }

pub open spec fn scan(a: Re, s: L<nat>, rr: nat, k: nat, p: nat) -> nat decreases k {
    if k == 0 { p } else if occ(a, s, p, rr) { p } else { scan(a, s, rr, (k - 1) as nat, p + 1) }
}
pub open spec fn cut(a: Re, s: L<nat>, i: nat, rr: nat) -> nat {
    scan(a, s, rr, if rr >= i { (rr - i) as nat } else { 0 }, i)
}
pub open spec fn downs(n: nat, i: nat) -> L<nat> decreases n {
    if n == 0 { cons(i, L::Nil) } else { cons(i + n, downs((n - 1) as nat, i)) }
}
pub open spec fn rep_ends(a: Re, s: L<nat>, i: nat, rr: nat) -> L<nat> {
    let c = cut(a, s, i, rr);
    downs(if c >= i { (c - i) as nat } else { 0 }, i)
}

pub open spec fn m(s: L<nat>, f: nat, ks: L<Item>, i: nat, rr: nat) -> L<nat> decreases f {
    if f == 0 { L::Nil } else {
        let f1 = (f - 1) as nat;
        match ks {
            L::Nil => cons(i, L::Nil),
            L::Cons(it, rest) => {
                let ks = *rest;
                match it {
                    Item::R(r) => match r {
                        Re::Eps => m(s, f1, ks, i, rr),
                        Re::Chr(c) => match at_(s, i, rr) { Some(c2) => if c == c2 { m(s, f1, ks, i + 1, rr) } else { L::Nil }, None => L::Nil },
                        Re::Any => match at_(s, i, rr) { Some(c2) => if c2 == 10 { L::Nil } else { m(s, f1, ks, i + 1, rr) }, None => L::Nil },
                        Re::AnyO => match at_(s, i, rr) { Some(_) => m(s, f1, ks, i + 1, rr), None => L::Nil },
                        Re::Seq(a, b) => m(s, f1, cons(Item::R(*a), cons(Item::R(*b), ks)), i, rr),
                        Re::Alt(a, b) => app(m(s, f1, cons(Item::R(*a), ks), i, rr), m(s, f1, cons(Item::R(*b), ks), i, rr)),
                        Re::Star(a) => app(m(s, f1, cons(Item::R(*a), cons(Item::Chk(i, *a), ks)), i, rr), m(s, f1, ks, i, rr)),
                        Re::AbsRep(a) => m(s, f1, cons(Item::Ends(rep_ends(*a, s, i, rr)), ks), i, rr),
                        Re::AbsExp(a, e) => m(s, f1, cons(Item::R(*e), cons(Item::SetRR(rr), ks)), i, cut(*a, s, i, rr)),
                        Re::Stopper(a) => m(s, f1, ks, i, cut(*a, s, i, rr)),
                        Re::RClear => m(s, f1, ks, i, len(s)),
                    },
                    Item::Chk(i0, a) => if i == i0 { m(s, f1, ks, i, rr) }
                                        else { m(s, f1, cons(Item::R(Re::Star(Box::new(a))), ks), i, rr) },
                    Item::SetRR(n) => m(s, f1, ks, i, n),
                    Item::Ends(es) => match es {
                        L::Nil => L::Nil,
                        L::Cons(e, es2) => app(m(s, f1, ks, e, rr), m(s, f1, cons(Item::Ends(*es2), ks), i, rr)),
                    },
                }
            }
        }
    }
}

pub open spec fn search_from(s: L<nat>, main: Re, k: nat, st: nat) -> Option<(nat, nat)> decreases k {
    if k == 0 { None } else {
        match m(s, fuel(), cons(Item::R(main), L::Nil), st, len(s)) {
            L::Cons(e, _) => Some((st, e)),
            L::Nil => search_from(s, main, (k - 1) as nat, st + 1),
        }
    }
}
pub open spec fn search(main: Re, s: L<nat>) -> Option<(nat, nat)> { search_from(s, main, len(s) + 1, 0) }

// Main lemma (SEMANTICS.md, "Absent operator", lemma A).
pub proof fn scan_ge(a: Re, s: L<nat>, rr: nat, k: nat, p: nat)
    ensures p <= scan(a, s, rr, k, p),
    decreases k
{
    if k > 0 && !occ(a, s, p, rr) { scan_ge(a, s, rr, (k - 1) as nat, p + 1); }
}

pub proof fn scan_none(a: Re, s: L<nat>, rr: nat, k: nat, p: nat, q: nat)
    requires p <= q, q < scan(a, s, rr, k, p),
    ensures !occ(a, s, q, rr),
    decreases k
{
    if k > 0 && !occ(a, s, p, rr) && q != p { scan_none(a, s, rr, (k - 1) as nat, p + 1, q); }
}

pub proof fn downs_mem(n: nat, i: nat, e: nat)
    requires mem(e, downs(n, i)),
    ensures i <= e <= i + n,
    decreases n
{
    reveal_with_fuel(mem, 2); // help: [i] needs mem unfolded twice
    if n > 0 && e != i + n { downs_mem((n - 1) as nat, i, e); }
}

pub proof fn absent_not_inside(a: Re, s: L<nat>, i: nat, rr: nat, e: nat, p: nat)
    requires mem(e, rep_ends(a, s, i, rr)), i <= p, p < e,
    ensures !occ(a, s, p, rr),
{
    let k = if rr >= i { (rr - i) as nat } else { 0 };
    scan_ge(a, s, rr, k, i);
    let c = cut(a, s, i, rr);
    downs_mem(if c >= i { (c - i) as nat } else { 0 }, i, e);
    scan_none(a, s, rr, k, i, p);
}

// Test cases (cases/absent.tsv); a=97 b=98 c=99 x=120 y=121 z=122.
pub open spec fn sq(x: Re, y: Re) -> Re { Re::Seq(Box::new(x), Box::new(y)) }
pub open spec fn al(x: Re, y: Re) -> Re { Re::Alt(Box::new(x), Box::new(y)) }
pub open spec fn lit2(x: nat, y: nat) -> Re { sq(Re::Chr(x), Re::Chr(y)) }
pub open spec fn abc() -> Re { sq(Re::Chr(97), lit2(98, 99)) }
pub open spec fn lit5a() -> Re { sq(Re::Chr(97), sq(Re::Chr(97), sq(Re::Chr(97), lit2(97, 97)))) }
pub open spec fn ostar() -> Re { Re::Star(Box::new(Re::AnyO)) }
pub open spec fn dotstar() -> Re { Re::Star(Box::new(Re::Any)) }
pub open spec fn s_abc() -> L<nat> { cons(97, cons(98, cons(99, L::Nil))) }
pub open spec fn s_xabcx() -> L<nat> { cons(120, cons(97, cons(98, cons(99, cons(120, L::Nil))))) }
pub open spec fn s_xabz() -> L<nat> { cons(120, cons(97, cons(98, cons(122, L::Nil)))) }
pub open spec fn s_xxabcyy() -> L<nat> { cons(120, cons(120, cons(97, cons(98, cons(99, cons(121, cons(121, L::Nil))))))) }
pub open spec fn s_a10() -> L<nat> { cons(97, cons(97, cons(97, cons(97, cons(97, cons(97, cons(97, cons(97, cons(97, cons(97, L::Nil)))))))))) }

pub proof fn cases() {
    assert(search(Re::AbsRep(Box::new(lit2(97, 98))), s_abc()) == Some((0, 0))) by (compute_only); // ab01
    assert(search(Re::AbsRep(Box::new(abc())), s_abc()) == Some((0, 0))) by (compute_only); // ab02
    assert(search(Re::AbsRep(Box::new(al(abc(), lit2(97, 98)))), s_abc()) == Some((0, 0))) by (compute_only); // ab03
    assert(search(sq(lit5a(), Re::AbsRep(Box::new(Re::Eps))), s_a10()) == Some((0, 5))) by (compute_only); // ab04
    assert(search(Re::AbsExp(Box::new(abc()), Box::new(ostar())), s_abc()) == Some((0, 0))) by (compute_only); // ab05
    assert(search(Re::AbsRep(Box::new(abc())), s_xabcx()) == Some((0, 1))) by (compute_only); // ab06
    assert(search(Re::AbsExp(Box::new(abc()), Box::new(ostar())), s_xabcx()) == Some((0, 1))) by (compute_only); // ab07
    assert(search(sq(Re::AbsRep(Box::new(abc())), Re::Chr(122)), s_xabz()) == Some((0, 4))) by (compute_only); // ab08
    assert(search(sq(Re::AbsExp(Box::new(abc()), Box::new(ostar())), Re::Chr(122)), s_xabz()) == Some((0, 4))) by (compute_only); // ab09
    assert(search(sq(Re::Stopper(Box::new(abc())), dotstar()), s_xxabcyy()) == Some((0, 2))) by (compute_only); // ab10
    assert(search(sq(Re::Stopper(Box::new(abc())), sq(Re::RClear, dotstar())), s_xxabcyy()) == Some((0, 7))) by (compute_only); // ab11
}

} // verus!

fn main() {}
