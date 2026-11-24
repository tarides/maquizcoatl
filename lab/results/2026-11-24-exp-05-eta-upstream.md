# exp-05 eta-upstream: F\* eta-reduction bug filed upstream, rerun on master

## What

Closes step 3 of issue #29 (experiment #5 follow-up). The F\*
eta-reduction miscompilation found in milestone 1
([prototypes-m1](2026-11-19-exp-05-prototypes-m1.md), finding
"eta-reduction drops a parameter") and still present in run B
([runB](2026-11-21-exp-05-runB.md), section "F\* master (issue #29)") is
filed upstream as
[FStarLang/FStar#4932](https://github.com/FStarLang/FStar/issues/4932),
"Custard: an entry point whose body is a tail call on its last parameter
is emitted with one parameter fewer".

Before filing, `pulse/probes/eta.sh` was rerun against the current F\*
master built from source, and one claim of the draft report was checked:
what a caller that includes the generated header gets.

Raw outputs are in
[`2026-11-24-exp-05-eta-upstream-raw/`](2026-11-24-exp-05-eta-upstream-raw/).

## Why

Issue #29 is done when the upstream issue is filed and linked. Run B
tested master `fc1776afe5`; master had moved to `6e901139c6` by the time
of filing. The draft also said a caller including the generated header
would "presumably" be rejected by the C compiler, which had not been
checked.

## Provenance

- F\* master `6e901139c6d8c01ba13d15429e0a0b14d12cb7dd` (2026-11-22,
  prints `F* 2026.11.22~dev`), KaRaMeL submodule `6bd5918c`, bundled
  Pulse. It differs from run B's `fc1776afe5` only by the version bump
  (`fstar.opam`, `version.txt`).
- Built from source with `make -j 12 ADMIT=1 3` (the build of run B and of
  F\*'s opam package: library SMT checks skipped, `EtaD.fst` itself fully
  checked); OCaml 5.5.2 (run B: 5.4.1).
- Z3 5.3.0, from F\*'s `.scripts/get_fstar_z3.sh`.
- GCC 15.2.0 (Ubuntu 15.2.0-16ubuntu1) (run B: 13.3.0).
- Machine: 12th Gen Intel Core i7-1260P, Ubuntu 26.04.1 LTS, kernel
  7.0.0-43-generic (a workstation, not the bench host).
- Commands: `PATH=<fstar>/out/bin:<z3>:$PATH VU_FSTAR_HOME=<fstar>/out
  bash pulse/probes/eta.sh <workdir>/eta`, with the probe files of
  branch `exp/05-unverified-calls` at `9e2f5a3`. Header check: the
  caller with its prototype line replaced by `#include "Custard.h"`
  ([`caller_hdr.c`](2026-11-24-exp-05-eta-upstream-raw/caller_hdr.c)),
  compiled with `cc -std=gnu11 -Wall -Wextra -I kc -I
  <fstar>/out/include/krml -I <fstar>/out/lib/krml/dist/minimal -c
  caller_hdr.c`. (`-std=c11` stops earlier, in krmllib's endianness
  helpers: `le64toh` is undeclared, unrelated to this bug.)
- Run by Claude Code (Opus 5.5) on 2026-11-24.

## Raw data

[`eta-master.txt`](2026-11-24-exp-05-eta-upstream-raw/eta-master.txt):
`EtaD.fst` verifies; both C emitters give `eta_d` one parameter and
return `g`:

```c
int32_t (*eta_d(int32_t (*g)(int32_t *x0)))(int32_t *x0)
{
  return g;
}
```

```
eta_d(g, &41) = -1243242135, g called 0 time(s); expected 42, 1
eta_caller status=1
```

[`caller-header.log`](2026-11-24-exp-05-eta-upstream-raw/caller-header.log):
`kc/Custard.h` declares the reduced prototype
`int32_t (*eta_d(int32_t (*g)(int32_t *x0)))(int32_t *x0);` and the
caller is rejected (`cc_status=1`):

```
caller_hdr.c:9:15: error: too many arguments to function 'eta_d'; expected 1, have 2
```

## Analysis

- The bug is unchanged on master `6e901139c6`, as expected from a
  version-bump-only difference; the run confirms it with a different
  OCaml, GCC and machine.
- The failure is silent only for a C caller that declares the prototype
  from the F\* signature, as `eta_caller.c` does. A caller that includes
  the generated header gets a compile error. Either way the public C
  signature no longer matches the F\* type, which is what the upstream
  report states.
- Cause, as given in the report: `eta_reduce` in
  `src/custard/FStarC.Custard.Simplify.fst` shortens `eta_d g a = g a` to
  `eta_d g = g`; `eta_expand_decl` restores an argument for a body whose
  head is a parameter only when an internal caller supplies it
  (`doc/ref/custard.md` §30.16), and an entry point has none. Related:
  FStarLang/FStar#4771, the same shape for a head from a linked unit,
  fixed in `6ed1d80807`.
- Open: the report's Fix section offers a PR with a regression test next
  to `tests/custard/EtaVar.fst`; who takes it is for the owner of the
  upstream report to confirm (issue #29). Experiment #5's prototype keeps
  its workaround (the result bound before returning) and `abi_check.c`
  until a fix is released.
