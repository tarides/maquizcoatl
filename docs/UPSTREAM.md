# Upstream reports

This file records the bugs the experiments found in third-party tools, and what was reported to those tools' projects. Only the maintainer files anything on an external project (CLAUDE.md). The pipeline finds and reproduces bugs, drafts reports, and tracks each report in an issue here.

Oniguruma itself is not listed. `kkos/oniguruma` is archived, so a bug found in the C library becomes a deviation in `spec/deviations.md`, not an upstream report.

## Filed

| Tool | Upstream item | Filed | Status (2026-11-27) | Found by | Tracked in |
|------|---------------|-------|---------------------|----------|------------|
| F\* (Custard back end) | Issue [FStarLang/FStar#4932](https://github.com/FStarLang/FStar/issues/4932): "Custard: an entry point whose body is a tail call on its last parameter is emitted with one parameter fewer" | 2026-11-24 | open | experiment #5, milestone 1 | issue #29 (closed); [`lab/results/2026-11-24-exp-05-eta-upstream.md`](../lab/results/2026-11-24-exp-05-eta-upstream.md) |
| F\* (Custard back end) | Pull request [FStarLang/FStar#4933](https://github.com/FStarLang/FStar/pull/4933): "Custard: a root keeps its binders on fixed-arity backends (#4932)", a proposed fix | 2026-11-24 | open | follow-up of #4932 | not recorded elsewhere in this repository |
| Why3 (`why3 execute`) | Post on the why3-club mailing list: type mismatch on a polymorphic constructor value holding a list. No link to the post is recorded. | 2026-11-25 | no answer recorded | experiment #6, milestone 1; confirmed on Why3 master by milestone 2 | issue #36 (closed); [`lab/06-spec-speed/why3/bug/`](../lab/06-spec-speed/why3/bug/) |

### F\* eta-reduction (FStarLang/FStar#4932)

**The bug.** F\*'s direct C back end (Custard) eta-reduces an extraction root whose body is a tail call on its last parameter. In the generated C, `eta_d` takes one parameter instead of two and returns the function `g` rather than calling it. A caller that declares the F\* signature compiles silently and gets garbage. A caller that includes the generated header is rejected by the C compiler.

**What was checked.**
- The bug reproduces without Pulse, in plain F\*: see the follow-up comment on the issue.
- It is unchanged on F\* master `6e901139c6`.

**What experiment #5 did.** It works around the bug in its Pulse prototype.

### Why3 `execute` type mismatch (why3-club)

**The bug.** `why3 execute` fails with "Type mismatch between ... and int" on a polymorphic constructor value that holds a list. The module type-checks, and `why3 extract` produces correct OCaml for it.

**What was checked.** It reproduces on Why3 1.9.0 and on master `5c30f60`. The reproducer is `lab/06-spec-speed/why3/bug/bug.mlw`.

**What experiment #6 did.** It works around the bug in its Why3 semantics. Experiment #7 hit what is probably the same bug on a list constant built from list constants (`lab/results/2026-11-19-exp-07-review-fixes.md`, follow-ups).

## Found, not reported

Each of these is recorded in the lab notebook but has not been filed upstream. Whether to report any of them is the maintainer's decision.

| Tool | Problem | Where recorded | Next step if reported |
|------|---------|----------------|-----------------------|
| Why3 1.9.0 | `-a compute` dies with `anomaly: File "src/core/trans.ml", line 503, characters 29-35: Assertion failed` | [`lab/results/2026-11-19-exp-07-sanity-lemma.md`](../lab/results/2026-11-19-exp-07-sanity-lemma.md); listed as "worth reporting" in `2026-11-19-exp-07-review-fixes.md` | Reduce it to a tiny module and check it on master |
| Verus 0.2026.11.02 | Given a Z3 version it does not support, without the opt-out flag, Verus panics (`air/src/smt_verify.rs:204`), then panics again while unwinding, instead of printing a clean error. Refusing the solver is the documented behaviour; the panic is not. | [`lab/results/2026-11-25-exp-09-verus-m3.md`](../lab/results/2026-11-25-exp-09-verus-m3.md); seen again in issue #34's run 4 | Check it on Verus's main branch |
