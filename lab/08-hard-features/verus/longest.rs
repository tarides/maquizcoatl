// Experiment #8, Verus: ONIG_OPTION_FIND_LONGEST (forward search).
// Semantics fixed in lab/08-hard-features/SEMANTICS.md, "FIND_LONGEST".
use vstd::prelude::*;

verus! {

pub enum Re { Eps, Chr(nat), Word, Seq(Box<Re>, Box<Re>), Alt(Box<Re>, Box<Re>), Star(Box<Re>) }
pub enum Item { R(Re), Chk(nat, Re) }
pub enum L<A> { Nil, Cons(A, Box<L<A>>) }

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

// \w on ASCII: [0-9A-Za-z_]
pub open spec fn is_word(c: nat) -> bool {
    (48 <= c && c <= 57) || (65 <= c && c <= 90) || (97 <= c && c <= 122) || c == 95
}

pub open spec fn m(s: L<nat>, f: nat, ks: L<Item>, i: nat) -> L<nat> decreases f {
    if f == 0 { L::Nil } else {
        let f1 = (f - 1) as nat;
        match ks {
            L::Nil => cons(i, L::Nil),
            L::Cons(it, rest) => {
                let ks = *rest;
                match it {
                    Item::R(r) => match r {
                        Re::Eps => m(s, f1, ks, i),
                        Re::Chr(c) => match nth(s, i) { Some(c2) => if c == c2 { m(s, f1, ks, i + 1) } else { L::Nil }, None => L::Nil },
                        Re::Word => match nth(s, i) { Some(c2) => if is_word(c2) { m(s, f1, ks, i + 1) } else { L::Nil }, None => L::Nil },
                        Re::Seq(a, b) => m(s, f1, cons(Item::R(*a), cons(Item::R(*b), ks)), i),
                        Re::Alt(a, b) => app(m(s, f1, cons(Item::R(*a), ks), i), m(s, f1, cons(Item::R(*b), ks), i)),
                        Re::Star(a) => app(m(s, f1, cons(Item::R(*a), cons(Item::Chk(i, *a), ks)), i), m(s, f1, ks, i)),
                    },
                    Item::Chk(i0, a) => if i == i0 { m(s, f1, ks, i) }
                                        else { m(s, f1, cons(Item::R(Re::Star(Box::new(a))), ks), i) },
                }
            }
        }
    }
}

pub open spec fn fuel() -> nat { 1000 }
pub open spec fn res(s: L<nat>, main: Re, st: nat) -> L<nat> { m(s, fuel(), cons(Item::R(main), L::Nil), st) }

// First-match search.
pub open spec fn search_from(s: L<nat>, main: Re, k: nat, st: nat) -> Option<(nat, nat)> decreases k {
    if k == 0 { None } else {
        match res(s, main, st) {
            L::Cons(e, _) => Some((st, e)),
            L::Nil => search_from(s, main, (k - 1) as nat, st + 1),
        }
    }
}
pub open spec fn search(main: Re, s: L<nat>) -> Option<(nat, nat)> { search_from(s, main, len(s) + 1, 0) }

pub open spec fn better(st: nat, e: nat, b: Option<(nat, nat)>) -> bool {
    match b { None => true, Some(p) => p.1 - p.0 < e - st }
}
pub open spec fn pick(st: nat, b: Option<(nat, nat)>, l: L<nat>) -> Option<(nat, nat)> decreases l {
    match l { L::Nil => b, L::Cons(e, es) => pick(st, if better(st, e, b) { Some((st, e)) } else { b }, *es) }
}
// FIND_LONGEST: every start, every result, the first of maximal length.
pub open spec fn longest_from(s: L<nat>, main: Re, b: Option<(nat, nat)>, k: nat, st: nat) -> Option<(nat, nat)> decreases k {
    if k == 0 { b } else { longest_from(s, main, pick(st, b, res(s, main, st)), (k - 1) as nat, st + 1) }
}
pub open spec fn longest(main: Re, s: L<nat>) -> Option<(nat, nat)> { longest_from(s, main, None, len(s) + 1, 0) }

pub open spec fn ge(b: Option<(nat, nat)>, n: int) -> bool {
    match b { None => false, Some(p) => n <= p.1 - p.0 }
}

// Main lemma (SEMANTICS.md, "FIND_LONGEST", lemma L).
pub proof fn pick_mono(st: nat, l: L<nat>, b: Option<(nat, nat)>, n: int)
    requires ge(b, n),
    ensures ge(pick(st, b, l), n),
    decreases l
{
    match l { L::Nil => {}, L::Cons(e, es) => pick_mono(st, *es, if better(st, e, b) { Some((st, e)) } else { b }, n) }
}

pub proof fn pick_mem(st: nat, l: L<nat>, b: Option<(nat, nat)>, e: nat)
    requires mem(e, l),
    ensures ge(pick(st, b, l), e - st),
    decreases l
{
    match l {
        L::Nil => {},
        L::Cons(e2, es) => {
            let b2 = if better(st, e2, b) { Some((st, e2)) } else { b };
            if e == e2 { pick_mono(st, *es, b2, e - st); } else { pick_mem(st, *es, b2, e); }
        }
    }
}

pub proof fn longest_mono(s: L<nat>, main: Re, k: nat, st: nat, b: Option<(nat, nat)>, n: int)
    requires ge(b, n),
    ensures ge(longest_from(s, main, b, k, st), n),
    decreases k
{
    if k > 0 {
        pick_mono(st, res(s, main, st), b, n);
        longest_mono(s, main, (k - 1) as nat, st + 1, pick(st, b, res(s, main, st)), n);
    }
}

pub proof fn longest_ge_first(s: L<nat>, main: Re, k: nat, st: nat, b: Option<(nat, nat)>, s1: nat, e1: nat)
    requires search_from(s, main, k, st) == Some((s1, e1)),
    ensures ge(longest_from(s, main, b, k, st), e1 - s1),
    decreases k
{
    if k > 0 {
        match res(s, main, st) {
            L::Cons(e, _) => {
                pick_mem(st, res(s, main, st), b, e);
                longest_mono(s, main, (k - 1) as nat, st + 1, pick(st, b, res(s, main, st)), e - st);
            },
            L::Nil => longest_ge_first(s, main, (k - 1) as nat, st + 1, pick(st, b, res(s, main, st)), s1, e1),
        }
    }
}

pub proof fn longest_no_shorter(main: Re, s: L<nat>, s1: nat, e1: nat)
    requires search(main, s) == Some((s1, e1)),
    ensures longest(main, s) matches Some(p) && e1 - s1 <= p.1 - p.0,
{
    longest_ge_first(s, main, len(s) + 1, 0, None, s1, e1);
}

// Test cases (cases/find-longest.tsv).
pub open spec fn sq(x: Re, y: Re) -> Re { Re::Seq(Box::new(x), Box::new(y)) }
pub open spec fn al(x: Re, y: Re) -> Re { Re::Alt(Box::new(x), Box::new(y)) }
pub open spec fn w1() -> Re { sq(Re::Word, Re::Star(Box::new(Re::Word))) }
pub open spec fn bcd() -> Re { sq(Re::Chr(98), sq(Re::Chr(99), Re::Chr(100))) }
pub open spec fn ab() -> Re { sq(Re::Chr(97), Re::Chr(98)) }
pub open spec fn s_s1() -> L<nat> { cons(97, cons(98, cons(99, cons(32, cons(100, cons(101, cons(102, cons(103, cons(32, cons(104, cons(105, cons(106, L::Nil)))))))))))) }
pub open spec fn s_s2() -> L<nat> { cons(97, cons(98, cons(32, cons(99, cons(100, cons(32, cons(101, cons(102, L::Nil)))))))) }
pub open spec fn s_s3() -> L<nat> { cons(97, cons(98, cons(99, cons(100, L::Nil)))) }
pub open spec fn s_s4() -> L<nat> { cons(97, cons(98, L::Nil)) }

pub proof fn cases() {
    assert(longest(w1(), s_s1()) == Some((4, 8))) by (compute_only); // fl01
    assert(longest(w1(), s_s2()) == Some((0, 2))) by (compute_only); // fl02
    assert(longest(al(Re::Chr(97), bcd()), s_s3()) == Some((1, 4))) by (compute_only); // fl03
    assert(longest(al(Re::Chr(97), ab()), s_s4()) == Some((0, 2))) by (compute_only); // fl04
    assert(search(al(Re::Chr(97), bcd()), s_s3()) == Some((0, 1))) by (compute_only); // fl05
    assert(search(al(Re::Chr(97), ab()), s_s4()) == Some((0, 1))) by (compute_only); // fl06
}

} // verus!

fn main() {}
