// Experiment #8, Verus: ISO-8859-1 multi-character case folding.
// Semantics fixed in lab/08-hard-features/SEMANTICS.md, "ISO-8859-1 folding".
use vstd::prelude::*;

verus! {

pub enum L<A> { Nil, Cons(A, Box<L<A>>) }
pub enum Re { Eps, Chr(nat), Seq(Box<Re>, Box<Re>), Alt(Box<Re>, Box<Re>), ILit(L<nat>) }
pub enum Item { R(Re), Seg(L<L<nat>>) }

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
pub open spec fn one1(x: nat) -> L<L<nat>> { cons(cons(x, L::Nil), L::Nil) }
pub open spec fn two(x: nat, y: nat) -> L<nat> { cons(x, cons(y, L::Nil)) }

// One-byte fold items of get_case_fold_codes_by_str (iso8859_1.c:116-215),
// for a position that does not start a two-byte ss spelling.
pub open spec fn one(c: nat) -> L<L<nat>> {
    if 65 <= c && c <= 90 { one1(c + 32) }
    else if 97 <= c && c <= 122 { one1((c - 32) as nat) }
    else if 192 <= c && c <= 207 { one1(c + 32) }
    else if c == 223 { cons(two(115, 115), cons(two(83, 83), cons(two(115, 83), cons(two(83, 115), L::Nil)))) }
    else if 208 <= c && c <= 222 && c != 215 { one1(c + 32) }
    else if 224 <= c && c <= 239 { one1((c - 32) as nat) }
    else if 240 <= c && c <= 254 && c != 247 { one1((c - 32) as nat) }
    else { L::Nil }
}
pub open spec fn is_s(c: nat) -> bool { c == 115 || c == 83 }

// Items of a two-byte ss spelling: 0xDF, then the other three spellings.
pub open spec fn drop2(c: nat, d: nat, l: L<L<nat>>) -> L<L<nat>> decreases l {
    match l {
        L::Nil => L::Nil,
        L::Cons(w, t) => if w == two(c, d) { drop2(c, d, *t) } else { L::Cons(w, Box::new(drop2(c, d, *t))) },
    }
}
pub open spec fn ss_items(c: nat, d: nat) -> L<L<nat>> {
    cons(cons(223, L::Nil), drop2(c, d, cons(two(83, 83), cons(two(83, 115), cons(two(115, 83), cons(two(115, 115), L::Nil))))))
}

// unravel_case_fold_string: one segment per pattern position, each the
// list of alternatives, original bytes first.
pub open spec fn unr(prev: Option<nat>, w: L<nat>) -> L<L<L<nat>>> decreases w {
    match w {
        L::Nil => match prev { None => L::Nil, Some(c) => cons(cons(cons(c, L::Nil), one(c)), L::Nil) },
        L::Cons(d, rest) => match prev {
            None => unr(Some(d), *rest),
            Some(c) => if is_s(c) && is_s(d) { cons(cons(two(c, d), ss_items(c, d)), unr(None, *rest)) }
                       else { cons(cons(cons(c, L::Nil), one(c)), unr(Some(d), *rest)) },
        },
    }
}
pub open spec fn unravel(w: L<nat>) -> L<L<L<nat>>> { unr(None, w) }

pub open spec fn segs(l: L<L<L<nat>>>, ks: L<Item>) -> L<Item> decreases l {
    match l { L::Nil => ks, L::Cons(x, t) => cons(Item::Seg(x), segs(*t, ks)) }
}

pub open spec fn prefix_at(s: L<nat>, i: nat, w: L<nat>) -> bool decreases w {
    match w {
        L::Nil => true,
        L::Cons(c, t) => match nth(s, i) { Some(c2) => c == c2 && prefix_at(s, i + 1, *t), None => false },
    }
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
                        Re::Seq(a, b) => m(s, f1, cons(Item::R(*a), cons(Item::R(*b), ks)), i),
                        Re::Alt(a, b) => app(m(s, f1, cons(Item::R(*a), ks), i), m(s, f1, cons(Item::R(*b), ks), i)),
                        Re::ILit(w) => m(s, f1, segs(unravel(w), ks), i),
                    },
                    Item::Seg(alts) => match alts {
                        L::Nil => L::Nil,
                        L::Cons(w, ws) => app(if prefix_at(s, i, w) { m(s, f1, ks, i + len(w)) } else { L::Nil },
                                              m(s, f1, cons(Item::Seg(*ws), ks), i)),
                    },
                }
            }
        }
    }
}

pub open spec fn fuel() -> nat { 1000 }
pub open spec fn search_from(s: L<nat>, main: Re, k: nat, st: nat) -> Option<(nat, nat)> decreases k {
    if k == 0 { None } else {
        match m(s, fuel(), cons(Item::R(main), L::Nil), st) {
            L::Cons(e, _) => Some((st, e)),
            L::Nil => search_from(s, main, (k - 1) as nat, st + 1),
        }
    }
}
pub open spec fn search(main: Re, s: L<nat>) -> Option<(nat, nat)> { search_from(s, main, len(s) + 1, 0) }

// Main lemma (SEMANTICS.md, lemma F): 0xDF matches each of ss, SS, sS, Ss, and back.
pub open spec fn sharp_s_ok(w: L<nat>) -> bool {
    search(Re::ILit(cons(223, L::Nil)), w) == Some((0nat, 2nat)) && search(Re::ILit(w), cons(223, L::Nil)) == Some((0nat, 1nat))
}
pub proof fn sharp_s()
    ensures sharp_s_ok(two(115, 115)), sharp_s_ok(two(83, 83)), sharp_s_ok(two(115, 83)), sharp_s_ok(two(83, 115)),
{
    assert(sharp_s_ok(two(115, 115)) && sharp_s_ok(two(83, 83)) && sharp_s_ok(two(115, 83)) && sharp_s_ok(two(83, 115))) by (compute_only);
}

// Test cases (cases/iso-fold.tsv).
pub proof fn cases() {
    assert(search(Re::ILit(cons(115, cons(115, L::Nil))), cons(223, L::Nil)) == Some((0, 1))) by (compute_only); // cf21
    assert(search(Re::ILit(cons(223, L::Nil)), cons(115, cons(115, L::Nil))) == Some((0, 2))) by (compute_only); // cf22
    assert(search(Re::ILit(cons(223, L::Nil)), cons(83, cons(83, L::Nil))) == Some((0, 2))) by (compute_only); // if01
    assert(search(Re::ILit(cons(223, L::Nil)), cons(115, cons(83, L::Nil))) == Some((0, 2))) by (compute_only); // if02
    assert(search(Re::ILit(cons(223, L::Nil)), cons(83, cons(115, L::Nil))) == Some((0, 2))) by (compute_only); // if03
    assert(search(Re::ILit(cons(83, cons(83, L::Nil))), cons(223, L::Nil)) == Some((0, 1))) by (compute_only); // if04
    assert(search(Re::ILit(cons(115, cons(83, L::Nil))), cons(223, L::Nil)) == Some((0, 1))) by (compute_only); // if05
    assert(search(Re::ILit(cons(83, cons(115, L::Nil))), cons(223, L::Nil)) == Some((0, 1))) by (compute_only); // if06
    assert(search(Re::ILit(cons(83, cons(83, cons(98, cons(223, cons(115, cons(115, cons(99, L::Nil)))))))), cons(97, cons(223, cons(98, cons(83, cons(83, cons(223, cons(99, cons(100, L::Nil))))))))) == Some((1, 7))) by (compute_only); // if07
    assert(search(Re::ILit(cons(105, cons(115, L::Nil))), cons(105, cons(115, cons(115, L::Nil)))) == Some((0, 2))) by (compute_only); // if08
}

} // verus!

fn main() {}
