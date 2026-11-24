# exp-04 review fixes: sharper readings and revised verdicts

## What

Corrections to the [verdicts entry](2026-11-19-exp-04-verdicts.md) and
to the [m1a](2026-11-19-exp-04-m1a-krml.md),
[m1b](2026-11-19-exp-04-m1b-custard.md) and
[m3](2026-11-19-exp-04-m3-rust-cdylib.md) entries of experiment #4
(issue #7), after the automated results review
(https://github.com/tarides/maquizcoatl/issues/7#issuecomment-7015643287)
and the maintainer's decisions
(https://github.com/tarides/maquizcoatl/issues/7#issuecomment-7019890064).
Those entries are left as recorded; this entry supersedes the parts
listed below. New data comes only from the
[exports entry](2026-11-19-exp-04-exports.md).

## Why

The review confirmed every number but asked for three sharper readings
before the results feed a stack decision (exported callback symbols,
the Custard route's reliance on symbol preemption, the Why3 verdict
being construct-level only), one narrower wording ("no mechanism is
eliminated"), and a provenance line for the plan's machine budget. The
maintainer accepted all points and decided the leaked-internals
question.

## Provenance

No run of its own. Branch `exp/04-abi-feasibility` rebased on `main`
at `82b7ada`; data from the exports entry (bench host, CPUs 8-11 and
40-43, 2026-11-19).

## Corrections

1. **Exported callback symbols (review problem 3).** The m1a and m1b
   entries and the verdicts table called the 16 / 17 extra symbols
   (`s_init`, `s_mbc_enc_len`, ..., `custard_init_globals`) "not needed
   by the harness". Sharper reading: they are an ABI hazard. With
   default visibility, ELF interposition lets a client or another
   shared object that defines `s_init` bind to libonig's, or override
   it. A drop-in must not export them. Resolution (maintainer decision,
   measured in the exports entry): an anonymous version script listing
   the 208 / 216 public names. After it, 1a and 1b export exactly the
   public names, with 0 extras, and every check still passes. The
   version script is an obligation outside the proofs for every
   mechanism. It hides the 114 upstream internals as well.
2. **Custard route relies on preemption (review problem 4).** The m1b
   entry and criterion 5 for 1b must also state the following.
   `custard_init_globals()` fills the public records at load time
   through the GOT (`R_X86_64_GLOB_DAT`). A client executable reads
   its own copies of them (`R_X86_64_COPY`). The route works only
   because the data symbols are preemptible. Measured: with
   `-Bsymbolic` the client reads all-zero encodings and
   `OnigDefaultSyntax != &OnigSyntaxOniguruma`, and `check-stub.sh`
   still passes. Build rule for 1b: version script, default
   visibility, no `-Bsymbolic`, no protected visibility, and a
   data-value test (`data_init`) in the drop-in checks.
3. **Why3 is construct-level only (review problem 2).** The verdicts
   table gives the Why3 binary verdict as "yes only with a hand-written
   C data layer". That verdict is inferred from the construct table.
   No Why3-extracted library was built or run through `check-stub.sh`.
   Read it as "inferred, not built".
4. **"No mechanism is eliminated" (review problem 2).** Read "none of
   the three mechanisms measured (1, 2, 3) is eliminated at stub
   level". Mechanism 4 is pending, so criterion 6 is incomplete.
5. **Leaked internals (verdicts, analysis bullet 2).** The verdicts
   entry left this open as a scope question. It is now decided: a
   drop-in exports only the public API (208 / 216). This is a
   deviation from `f95747b`, `spec/deviations.md` DEV-005, decided by
   the maintainer 2026-11-19. The evidence is Vincent Balat's survey of
   five clients (jq, PHP `ext/mbstring`, vscode-oniguruma, the Rust
   `onig` crate, Python `onigurumacffi`), none of which uses an
   internal symbol, and the rebuilt stubs.
6. **Rust variadic (m3 entry, review follow-up).** "A C object linked
   into the cdylib is not exported" holds for `--export-dynamic-symbol`
   only. A user version script listing the public names exports the C
   variadic directly (exports entry). The naked trampoline is therefore
   one of two working routes, and the "outside the proofs" cell for 3
   becomes "the C body of the variadic, plus either a one-instruction
   naked trampoline or the version-script entry".
7. **Plan budget (review problem 5).** A note in the plan's "Machine
   budget" section now records that the run moved to the bench host
   (at most 12 jobs, about 35 minutes for milestone 1 plus follow-up 1).
8. **`onigposix.h`.** The oracle entry's "linkage is unaffected" is
   right for linkage, but the mismatch is a memory error.
   `onig_copy_syntax` writes 24 bytes past an `onigposix.h`-only
   client's `OnigSyntaxType` (exports entry). It is recorded as a
   candidate in `spec/deviations.md` (DEV-006, not yet decided).

## Revised verdicts (supersede the verdicts entry's criterion 6 table)

| Mechanism | Binary drop-in | Source drop-in | Outside the proofs (criterion 5, revised) |
|---|---|---|---|
| 1a F\*/Pulse, KaRaMeL | yes (stub level, measured with the version script) | yes (measured) | 43 data-name renames, `OnigDefaultSyntax`, variadic in C, version script, build glue |
| 1b F\*/Pulse, Custard | yes (stub level, measured with the version script) | yes (measured) | load-time constructor, which needs preemptible data (no `-Bsymbolic` or protected visibility, measured), `OnigDefaultSyntax`, variadic in C, version script, build glue |
| 2 C, VST | yes (stub level, measured with the version script) | yes (measured) | version script and build glue; `va_arg` helpers need VST specifications (unchecked) |
| 2 C, Why3 | inferred, not built: only with a hand-written C data layer | inferred: same build as the C stub | the 44 data symbols, every mixed-case name, variadic, version script |
| 3 Rust `cdylib` | yes (stub level) | predicted: needs Rust | C body of the variadic, exported by a naked trampoline or a version-script entry (both measured); soname and install glue |
| 4 Isabelle-LLVM | deferred | predicted: binary level only | not run; scheduled when the bench host is quiet, after experiment #13's builds |

## Analysis

- The stack question is unchanged: none of the three mechanisms
  measured is eliminated by the ABI. The export rule adds the same
  small piece of build glue to each of them. It also turns 1b's
  constructor from a convenience into a constraint on that glue.
- What remains for the experiment is mechanism 4. Criterion 6 is not
  complete without it, so issue #7 stays open.
