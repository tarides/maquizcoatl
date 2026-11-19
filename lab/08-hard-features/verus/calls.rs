// Experiment #8, Verus: subexpression calls with the nest limit.
// Semantics fixed in lab/08-hard-features/SEMANTICS.md, section "Calls":
// spec fns for the semantics, proof fns for the lemmas. Own list type L
// (rather than vstd Seq) so that `by (compute_only)` can run the cases.
use vstd::prelude::*;

verus! {

pub enum Re { Eps, Chr(nat), Any, Seq(Box<Re>, Box<Re>), Alt(Box<Re>, Box<Re>), Star(Box<Re>), Call(nat), Bos, Eos }
pub enum Item { R(Re), Ret, Chk(nat, Re) }
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

// m(lim, defs, s, f, ks, i, d, mx): results (end, max depth) of the pending
// items ks at position i, nest depth d (live call frames), running maximum mx.
pub open spec fn m(lim: nat, defs: L<Re>, s: L<nat>, f: nat, ks: L<Item>, i: nat, d: nat, mx: nat) -> L<(nat, nat)>
    decreases f
{
    if f == 0 { L::Nil } else {
        let f1 = (f - 1) as nat;
        match ks {
            L::Nil => cons((i, mx), L::Nil),
            L::Cons(it, rest) => {
                let ks = *rest;
                match it {
                    Item::R(r) => match r {
                        Re::Eps => m(lim, defs, s, f1, ks, i, d, mx),
                        Re::Chr(c) => match nth(s, i) {
                            Some(c2) => if c == c2 { m(lim, defs, s, f1, ks, i + 1, d, mx) } else { L::Nil },
                            None => L::Nil,
                        },
                        Re::Any => match nth(s, i) {
                            Some(c2) => if c2 == 10 { L::Nil } else { m(lim, defs, s, f1, ks, i + 1, d, mx) },
                            None => L::Nil,
                        },
                        Re::Seq(a, b) => m(lim, defs, s, f1, cons(Item::R(*a), cons(Item::R(*b), ks)), i, d, mx),
                        Re::Alt(a, b) => app(m(lim, defs, s, f1, cons(Item::R(*a), ks), i, d, mx),
                                             m(lim, defs, s, f1, cons(Item::R(*b), ks), i, d, mx)),
                        Re::Star(a) => app(m(lim, defs, s, f1, cons(Item::R(*a), cons(Item::Chk(i, *a), ks)), i, d, mx),
                                           m(lim, defs, s, f1, ks, i, d, mx)),
                        Re::Call(n) => if lim <= d { L::Nil } else {
                            match nth(defs, n) {
                                Some(b) => m(lim, defs, s, f1, cons(Item::R(b), cons(Item::Ret, ks)), i, d + 1,
                                             if mx >= d + 1 { mx } else { d + 1 }),
                                None => L::Nil,
                            }
                        },
                        Re::Bos => if i == 0 { m(lim, defs, s, f1, ks, i, d, mx) } else { L::Nil },
                        Re::Eos => if i == len(s) { m(lim, defs, s, f1, ks, i, d, mx) } else { L::Nil },
                    },
                    Item::Ret => m(lim, defs, s, f1, ks, i, if d == 0 { 0 } else { (d - 1) as nat }, mx),
                    Item::Chk(i0, a) => if i == i0 { m(lim, defs, s, f1, ks, i, d, mx) }
                                        else { m(lim, defs, s, f1, cons(Item::R(Re::Star(Box::new(a))), ks), i, d, mx) },
                }
            }
        }
    }
}

pub open spec fn search_from(lim: nat, defs: L<Re>, s: L<nat>, f: nat, main: Re, k: nat, st: nat) -> Option<(nat, nat)>
    decreases k
{
    if k == 0 { None } else {
        match m(lim, defs, s, f, cons(Item::R(main), L::Nil), st, 0, 0) {
            L::Cons(p, _) => Some((st, p.0)),
            L::Nil => search_from(lim, defs, s, f, main, (k - 1) as nat, st + 1),
        }
    }
}

pub open spec fn default_limit() -> nat { 20 }
pub open spec fn fuel() -> nat { 1000 }
pub open spec fn search(lim: nat, defs: L<Re>, main: Re, s: L<nat>) -> Option<(nat, nat)> {
    search_from(lim, defs, s, fuel(), main, len(s) + 1, 0)
}

pub proof fn lemma_app_mem<A>(x: A, a: L<A>, b: L<A>)
    ensures mem(x, app(a, b)) == (mem(x, a) || mem(x, b))
    decreases a
{
    match a { L::Nil => {}, L::Cons(_, t) => lemma_app_mem(x, *t, b) }
}

// Main lemma (SEMANTICS.md, "Calls", lemma C).
pub proof fn depth_bound(lim: nat, defs: L<Re>, s: L<nat>, f: nat, ks: L<Item>, i: nat, d: nat, mx: nat, p: (nat, nat))
    requires d <= lim, mx <= lim, mem(p, m(lim, defs, s, f, ks, i, d, mx)),
    ensures p.1 <= lim,
    decreases f
{
    if f == 0 {} else {
        let f1 = (f - 1) as nat;
        match ks {
            L::Nil => {
                // help: the single result needs mem unfolded twice
                reveal_with_fuel(mem, 2);
            },
            L::Cons(it, rest) => {
                let ks = *rest;
                match it {
                    Item::R(r) => match r {
                        Re::Eps => depth_bound(lim, defs, s, f1, ks, i, d, mx, p),
                        Re::Chr(c) => match nth(s, i) {
                            Some(c2) => if c == c2 { depth_bound(lim, defs, s, f1, ks, i + 1, d, mx, p) },
                            None => {},
                        },
                        Re::Any => match nth(s, i) {
                            Some(c2) => if c2 != 10 { depth_bound(lim, defs, s, f1, ks, i + 1, d, mx, p) },
                            None => {},
                        },
                        Re::Seq(a, b) => depth_bound(lim, defs, s, f1, cons(Item::R(*a), cons(Item::R(*b), ks)), i, d, mx, p),
                        Re::Alt(a, b) => {
                            let l1 = m(lim, defs, s, f1, cons(Item::R(*a), ks), i, d, mx);
                            let l2 = m(lim, defs, s, f1, cons(Item::R(*b), ks), i, d, mx);
                            lemma_app_mem(p, l1, l2);
                            if mem(p, l1) { depth_bound(lim, defs, s, f1, cons(Item::R(*a), ks), i, d, mx, p); }
                            else { depth_bound(lim, defs, s, f1, cons(Item::R(*b), ks), i, d, mx, p); }
                        },
                        Re::Star(a) => {
                            let k1 = cons(Item::R(*a), cons(Item::Chk(i, *a), ks));
                            let l1 = m(lim, defs, s, f1, k1, i, d, mx);
                            let l2 = m(lim, defs, s, f1, ks, i, d, mx);
                            lemma_app_mem(p, l1, l2);
                            if mem(p, l1) { depth_bound(lim, defs, s, f1, k1, i, d, mx, p); }
                            else { depth_bound(lim, defs, s, f1, ks, i, d, mx, p); }
                        },
                        Re::Call(n) => if lim > d {
                            match nth(defs, n) {
                                Some(b) => depth_bound(lim, defs, s, f1, cons(Item::R(b), cons(Item::Ret, ks)), i, d + 1,
                                                       if mx >= d + 1 { mx } else { d + 1 }, p),
                                None => {},
                            }
                        },
                        Re::Bos => if i == 0 { depth_bound(lim, defs, s, f1, ks, i, d, mx, p) },
                        Re::Eos => if i == len(s) { depth_bound(lim, defs, s, f1, ks, i, d, mx, p) },
                    },
                    Item::Ret => depth_bound(lim, defs, s, f1, ks, i, if d == 0 { 0 } else { (d - 1) as nat }, mx, p),
                    Item::Chk(i0, a) => if i == i0 { depth_bound(lim, defs, s, f1, ks, i, d, mx, p) }
                                        else { depth_bound(lim, defs, s, f1, cons(Item::R(Re::Star(Box::new(a))), ks), i, d, mx, p) },
                }
            }
        }
    }
}

// Test cases (cases/calls.tsv, nest.tsv); a=97 b=98 (=40 )=41.
pub open spec fn ra() -> Re { Re::Chr(97) }
pub open spec fn rb() -> Re { Re::Chr(98) }
pub open spec fn sq(x: Re, y: Re) -> Re { Re::Seq(Box::new(x), Box::new(y)) }
pub open spec fn al(x: Re, y: Re) -> Re { Re::Alt(Box::new(x), Box::new(y)) }
pub open spec fn d1() -> L<Re> { cons(ra(), L::Nil) }
pub open spec fn m1() -> Re { sq(Re::Call(0), Re::Call(0)) }
pub open spec fn d2() -> L<Re> { cons(sq(ra(), rb()), L::Nil) }
pub open spec fn d3() -> L<Re> { cons(al(sq(ra(), Re::Call(0)), Re::Eps), L::Nil) }
pub open spec fn m3() -> Re { sq(Re::Bos, sq(Re::Call(0), Re::Eos)) }
pub open spec fn d4() -> L<Re> { cons(al(ra(), sq(Re::Chr(40), sq(Re::Call(0), Re::Chr(41)))), L::Nil) }
pub open spec fn d5() -> L<Re> { cons(al(sq(ra(), Re::Call(0)), rb()), L::Nil) }
pub open spec fn s_aa() -> L<nat> { cons(97, cons(97, L::Nil)) }
pub open spec fn s_abab() -> L<nat> { cons(97, cons(98, cons(97, cons(98, L::Nil)))) }
pub open spec fn s_aaaa() -> L<nat> { cons(97, cons(97, cons(97, cons(97, L::Nil)))) }
pub open spec fn s_aaab() -> L<nat> { cons(97, cons(97, cons(97, cons(98, L::Nil)))) }
pub open spec fn s_s4() -> L<nat> { cons(40, cons(40, cons(40, cons(40, cons(40, cons(40, cons(97, cons(41, cons(41, cons(41, cons(41, cons(41, cons(41, L::Nil))))))))))))) }
pub open spec fn s_s6() -> L<nat> { cons(40, cons(40, cons(40, cons(40, cons(40, cons(40, cons(40, cons(40, cons(40, cons(40, cons(40, cons(40, cons(40, cons(40, cons(40, cons(40, cons(40, cons(40, cons(40, cons(40, cons(40, cons(40, cons(40, cons(40, cons(97, cons(41, cons(41, cons(41, cons(41, cons(41, cons(41, cons(41, cons(41, cons(41, cons(41, cons(41, cons(41, cons(41, cons(41, cons(41, cons(41, cons(41, cons(41, cons(41, cons(41, cons(41, cons(41, cons(41, cons(41, L::Nil))))))))))))))))))))))))))))))))))))))))))))))))) }

pub proof fn cases() {
    assert(search(default_limit(), d1(), m1(), s_aa()) == Some((0, 2))) by (compute_only); // ca01
    assert(search(default_limit(), d2(), m1(), s_abab()) == Some((0, 4))) by (compute_only); // ca02
    assert(search(default_limit(), d3(), m3(), s_aaaa()) == Some((0, 4))) by (compute_only); // ca03
    assert(search(default_limit(), d4(), Re::Call(0), s_s4()) == Some((0, 13))) by (compute_only); // ca04
    assert(search(default_limit(), d5(), m3(), s_aaab()) == Some((0, 4))) by (compute_only); // ca05
    assert(search(2, d5(), m3(), s_aaab()) == None) by (compute_only); // nc01
    assert(search(20, d5(), m3(), s_aaab()) == Some((0, 4))) by (compute_only); // nc02
    assert(search(2, d4(), Re::Call(0), s_s4()) == Some((5, 8))) by (compute_only); // nc03
    assert(search(0, d1(), m1(), s_aa()) == None) by (compute_only); // nc04
    assert(search(3, d5(), m3(), s_aaab()) == None) by (compute_only); // ns01_3
    assert(search(4, d5(), m3(), s_aaab()) == Some((0, 4))) by (compute_only); // ns01_4
    assert(search(1, d4(), Re::Call(0), s_s4()) == Some((6, 7))) by (compute_only); // ns02_1
    assert(search(6, d4(), Re::Call(0), s_s4()) == Some((1, 12))) by (compute_only); // ns02_6
    assert(search(default_limit(), d4(), Re::Call(0), s_s6()) == Some((5, 44))) by (compute_only); // ca06
    assert(search(7, d4(), Re::Call(0), s_s4()) == Some((0, 13))) by (compute_only); // ns02_7
}

} // verus!

fn main() {}
