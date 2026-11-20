# Experiment #4: corrections to mechanism 4 after the results review

**What.** Corrections to the 2026-11-20 entries
[m4-toolchain](2026-11-20-exp-04-m4-toolchain.md),
[m4-isabelle-llvm](2026-11-20-exp-04-m4-isabelle-llvm.md) and
[verdicts-m4](2026-11-20-exp-04-verdicts-m4.md), required by the
automated results review on issue #7
([comment](https://github.com/tarides/maquizcoatl/issues/7#issuecomment-7042219743)),
problems 1, 2 and 4. No new run: problem 1 is settled by reading the
installed Isabelle-LLVM sources, problem 4 by the existing logs and one
version query. The three entries stay as recorded; this entry
supersedes the passages it names.

**Why.** The review confirmed every number of mechanism 4, but found
that the verdict overstates the function-pointer gap, that criterion 2
for mechanism 4 measures the C shell rather than Isabelle-LLVM, and
three wording or provenance slips.

## Provenance

Isabelle-LLVM `e42f4781` (branch `2026`) as installed in `<cache>` by
the [m4-toolchain entry](2026-11-20-exp-04-m4-toolchain.md); read, not
rebuilt. Experiment #5's Isabelle-LLVM result: issue #13,
[results comment](https://github.com/tarides/maquizcoatl/issues/13#issuecomment-7039631438)
(branch `exp/05-unverified-calls` at `1dcc3dc`).

## Corrections

### 1. Function-pointer calls (m4-isabelle-llvm, criterion 5; verdicts-m4)

The m4 entry says a real implementation "would also need C for every
call through a function pointer", and verdicts-m4 says Isabelle-LLVM
"would need C for every encoding vtable and callback call". That is too
strong. Isabelle-LLVM can call a **named** external C function from HOL:

- `thys/basic/kernel/LLVM_Codegen.thy:1135-1138` (`intrinsic_builder`)
  emits `LLVM_Builder.mk_external_call` for a HOL constant registered as
  external;
- `thys/examples/Scratch.thy:6-13` declares `external_fun` and registers
  it with `LLVM_EXTERNALI[of external_fun "''external_fun''"]`;
  `regression/src/test_external_fun.c` defines the C side and checks
  `uses_external_fun(42) == 44`.

What Isabelle-LLVM lacks is an **indirect** call through a pointer value
(no HOL-level function-pointer type). Criterion 5 for mechanism 4 now
reads: *indirect calls (the encoding vtables of `OnigEncodingType`, the
warn and callout callbacks, `onig_foreach_name`-style iterators) go
through a C trampoline declared to Isabelle-LLVM as an external
function, one per signature; direct calls to named C functions are
expressible.* Experiment #5 measured this route for Isabelle-LLVM: it
works with an 8-line C shim, the callee contracts stated as theorem
hypotheses, 100 trusted lines in all (issue #13, results comment above).
The same correction applies to the "Outside the proofs" cell of mechanism 4
in verdicts-m4's table ("every call through a function pointer" →
"every indirect call, through one C trampoline per signature").

### 2. Criterion 2 for mechanism 4 (m4-isabelle-llvm; verdicts-m4; results comment)

The 10/10 and 12/12 struct layouts pass because the stub ships
upstream's headers and every struct of the library lives in the C shell
(`shell_data.c`, mechanism 2's initialisers); on the Isabelle-LLVM side
every pointer is `uint8_t*`. So criterion 2 for mechanism 4 measures
the C shell, not Isabelle-LLVM. The only layout evidence about
Isabelle-LLVM itself is the probe: a struct with plain fields gets the
declared layout, a struct with a function-pointer field gets a silently
wrong one.

### 4. Provenance and wording

- (a) m4-toolchain: "free disk went from 67 GB to 48 GB". The committed
  log records 61 GB after Isabelle and 48 GB after LLVM; the 67 GB
  starting figure was read before the run and is not in a committed
  file. Read: "61 GB after Isabelle, 48 GB after LLVM (log)".
- (b) verdicts-m4, first analysis point: "all four give a binary
  drop-in with a hand-written C shell" omits the table's own caveat.
  Read: "all four give a binary drop-in with a hand-written C shell,
  measured for 1a, 1b, VST, Rust and Isabelle-LLVM; inferred, not built,
  for Why3".
- (c) m4-isabelle-llvm cites `-fuse-ld=bfd`, GNU ld 2.42; the toolchain
  table lists no binutils. The linker is the host's GNU ld (GNU Binutils
  for Ubuntu) 2.42, `ld.bfd`.

## Not changed

- Problem 3 (labels, PR state) is fixed on GitHub: the issue is
  `stage:done` and PR #16 is marked ready for review.
- The review's follow-ups (the cheap layout check on a
  function-pointer-free struct, the typed-pointer IR dependence of
  stack F, the option-matrix update) are left to the maintainer.
