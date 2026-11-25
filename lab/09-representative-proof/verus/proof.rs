// Experiment #9, Verus M2, lemma (d) for the VM and lemma (e): the main
// theorem (statement.rs), from the simulation (proof_sim::sim) at the
// empty continuation (code OP_END, stack [EFinish]) and the fuel of the
// semantics (proof_sem::fuel_of), after fstar/Proof.fst and rocq/Proof.v.
// The VM's completeness comes out of the simulation itself: `sim`
// returns the number of VM steps.
use vstd::prelude::*;
use crate::syntax::*;
use crate::sem::*;
use crate::compile::*;
use crate::vm::*;
use crate::statement::*;
use crate::proof_a::*;
use crate::proof_sem::*;
use crate::proof_sim::*;

verus! {

broadcast use group_lists;

pub proof fn run_mono(code: Seq<Instr>, s: Seq<u8>, n: nat, st: State, n2: nat)
    requires run(n, code, s, st) is Some, n <= n2,
    ensures run(n2, code, s, st) == run(n, code, s, st),
    decreases n,
{
    match step(code, s, st) {
        Outcome::Next(st2) => run_mono(code, s, (n - 1) as nat, st2, (n2 - 1) as nat),
        Outcome::Halt(_) => {}
    }
}

pub proof fn run_det(code: Seq<Instr>, s: Seq<u8>, n1: nat, n2: nat, st: State)
    requires run(n1, code, s, st) is Some, run(n2, code, s, st) is Some,
    ensures run(n1, code, s, st) == run(n2, code, s, st),
{
    run_mono(code, s, n1, st, n1 + n2);
    run_mono(code, s, n2, st, n1 + n2);
}

pub proof fn exe_run(code: Seq<Instr>, s: Seq<u8>, n: nat, st: State, r: Option<(nat, MCaps)>)
    requires exe(code, s, n, st) == Outcome::Halt(r),
    ensures run(n, code, s, st) == Some(r),
    decreases n,
{
    match step(code, s, st) {
        Outcome::Next(st2) => exe_run(code, s, (n - 1) as nat, st2, r),
        Outcome::Halt(_) => {}
    }
}

pub proof fn vm_det(n1: nat, n2: nat, code: Seq<Instr>, k: nat, s: Seq<u8>, p: nat)
    requires vm(n1, code, k, s, p) != Res::OutOfFuel, vm(n2, code, k, s, p) != Res::OutOfFuel,
    ensures vm(n1, code, k, s, p) == vm(n2, code, k, s, p),
{
    run_det(code, s, n1, n2, init(p));
}

pub proof fn region_spans(n: nat, m: MCaps, g: GMap)
    requires capeq(m, g),
    ensures region(n, m) == spans(n, g),
{
    assert forall|i: int| 0 <= i < n implies #[trigger] region(n, m)[i] == spans(n, g)[i] by {
        let k = (i + 1) as nat;
        assert(capv(mget(k, m)) == gget(k, g));
    }
    assert(region(n, m) =~= spans(n, g));
}

pub open spec fn sem_of(r: Regex, t: Tree) -> Res {
    match first_match(t) {
        None => Res::NoMatch,
        Some((e, g)) => Res::Match(e, spans(ncap(r), g)),
    }
}

// lemma (d), VM: the VM on compile(r) finishes with the semantics'
// result (the fuel is returned)
pub proof fn vm_complete(r: Regex, s: Seq<u8>, p: nat, f: nat, t: Tree) -> (n: nat)
    requires
        groups(r).no_duplicates(),
        compute_tree(f, s, seq![Action::ARe(r)], p, Seq::empty()) == Some(t),
    ensures vm(n, compile(r), ncap(r), s, p) == sem_of(r, t),
{
    let code = compile(r);
    let stk0 = seq![Entry::EFinish];
    code_compile(r);
    gd_of(r);
    let hend = Rep::REnd(clen(r));
    let h = Rep::RRe(0, r, 0, false, p, Box::new(hend));
    assert(rep(code, hend, p, stk0));
    assert(rep(code, h, p, stk0));
    assert(hacts(hend) == Seq::<Action>::empty());
    assert(hacts(h) == Seq::<Action>::empty().push(Action::ARe(r)));
    assert(hacts(h) =~= seq![Action::ARe(r)]);
    assert(cls(Seq::<Action>::empty()) == Seq::<(nat, nat)>::empty());
    assert(cls(hacts(h)) =~= Seq::<(nat, nat)>::empty());
    assert(gs(Seq::<Action>::empty()) == Set::<nat>::empty());
    assert(uniq(Seq::<Action>::empty()));
    assert(uniq(hacts(h)));
    capsrel_init(hx(h));
    let o = sim(code, s, f, h, p, Seq::empty(), t, stk0, Seq::empty());
    assert(stt(0, p, Seq::empty(), stk0) == init(p));
    match first_match(t) {
        Some((e, g)) => {
            exe_run(code, s, o.0, init(p), Some((e, o.1)));
            region_spans(ncap(r), o.1, g);
            o.0
        }
        None => {
            assert(fail(stk0, o.1) == Outcome::Halt(None));
            exe_run(code, s, o.0, init(p), None);
            o.0
        }
    }
}

pub proof fn main_aux(r: Regex, s: Seq<u8>, p: nat)
    requires groups(r).no_duplicates(), p <= s.len(),
    ensures
        forall|fv: nat, fs: nat| #![trigger vm(fv, compile(r), ncap(r), s, p), sem(fs, r, s, p)]
            (vm(fv, compile(r), ncap(r), s, p) != Res::OutOfFuel && sem(fs, r, s, p) != Res::OutOfFuel)
            ==> sem(fs, r, s, p) == vm(fv, compile(r), ncap(r), s, p),
        exists|fs: nat| #[trigger] sem(fs, r, s, p) != Res::OutOfFuel,
        exists|fv: nat| #[trigger] vm(fv, compile(r), ncap(r), s, p) != Res::OutOfFuel,
{
    let acts = seq![Action::ARe(r)];
    let f0 = fuel_of(s, acts, p, Seq::empty());
    let t0 = compute_tree(f0, s, acts, p, Seq::empty())->Some_0;
    let n0 = vm_complete(r, s, p, f0, t0);
    assert(sem(f0, r, s, p) == sem_of(r, t0));
    assert forall|fv: nat, fs: nat| #![trigger vm(fv, compile(r), ncap(r), s, p), sem(fs, r, s, p)]
        vm(fv, compile(r), ncap(r), s, p) != Res::OutOfFuel && sem(fs, r, s, p) != Res::OutOfFuel
        implies sem(fs, r, s, p) == vm(fv, compile(r), ncap(r), s, p) by {
        ct_det(s, fs, f0, acts, p, Seq::empty());
        vm_det(n0, fv, compile(r), ncap(r), s, p);
    }
    assert(sem(f0, r, s, p) != Res::OutOfFuel);
    assert(vm(n0, compile(r), ncap(r), s, p) != Res::OutOfFuel);
}

// lemma (e)
pub proof fn main_theorem()
    ensures main_theorem_statement(),
{
    assert forall|r: Regex, s: Seq<u8>, p: nat| #[trigger] main_theorem_at(r, s, p) by {
        if groups(r).no_duplicates() && p <= s.len() {
            main_aux(r, s, p);
        }
    }
}

// Why statement.rs needs groups(r).no_duplicates(): a group nested in a
// group with the same number (no parser writes it; the AST type allows
// it).  The VM keeps the inner group's start, the semantics the outer
// one's (as rocq/Proof.v and fstar/Proof.fst), by evaluation.
pub open spec fn nested_same_group() -> Regex {
    Regex::Group(1, Box::new(Regex::Cat(Box::new(Regex::Lit(seq![97u8])),
        Box::new(Regex::Group(1, Box::new(Regex::Lit(seq![98u8])))))))
}

pub proof fn nested_same_group_vm()
    ensures vm(100, compile(nested_same_group()), 1, seq![97u8, 98u8], 0)
        == Res::Match(2, seq![Some((1nat, 2nat))]),
{
    assert(vm(100, compile(nested_same_group()), 1, seq![97u8, 98u8], 0)
        == Res::Match(2, seq![Some((1nat, 2nat))])) by (compute_only);
}

pub proof fn nested_same_group_sem()
    ensures sem(100, nested_same_group(), seq![97u8, 98u8], 0) == Res::Match(2, seq![Some((0nat, 2nat))]),
{
    assert(sem(100, nested_same_group(), seq![97u8, 98u8], 0) == Res::Match(2, seq![Some((0nat, 2nat))]))
        by (compute_only);
}

} // verus!
