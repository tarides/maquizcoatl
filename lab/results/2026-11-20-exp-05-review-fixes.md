# exp-05 review-fixes: milestones 1 and 2 re-run after the independent review

## What

The independent review of milestones 1 and 2 of experiment 5 (issue
#13) kept the six verdicts and listed nine decision-free problems, about
what is recorded rather than what is proved. This entry records the
fixes and one re-run of the six prototypes (normal run and negative
control each) from a clone of the branch at the pushed commit. Raw
outputs, redacted by the scripts, are in
[`2026-11-20-exp-05-review-fixes-raw/`](2026-11-20-exp-05-review-fixes-raw/).
The summary table is
[`experiments/05-unverified-calls/table.md`](../../experiments/05-unverified-calls/table.md).

## Why

The milestone runs used harness copies, so their provenance has no
commit; Why3 still muted a warning the maintainer asked to drop; four
builds had no guard against proof escapes; and some table entries read
stronger than what is proved.

## Setup

- Bench host and toolchains as in the `toolchains-m1` and
  `toolchains-m2` entries; versions in `provenance-m2-review.txt`.
- Runs from `<exp>/repo`, the clone of `exp/05-unverified-calls`, not
  from harness copies, so provenance records the commit:
  - `m2-review` (2026-11-20, 12:23-12:25 UTC): Why3, Pulse, Verus,
    Aeneas and VST at `5f6669e`;
  - `m2-review-isabelle` (12:26-12:28 UTC): Isabelle-LLVM at `7f727c3`,
    which only adds the `TRUSTED` fix below. `upstream/` is at
    `f95747b` in both.
- CPUs 48-51 under `nice`, 4 jobs; `run.sh` checked them against the
  reserved and pinned CPUs before each build. No other Poly/ML process
  ran during the Isabelle-LLVM run.
- Commands: `run.sh <tool> <run-id>`, then `run.sh -n <tool> <run-id>`,
  then `count-trusted.sh` on all six tools at `7f727c3`
  (`trusted.tsv`).
- Each `build.log` now starts with the sha256 of every harness file the
  run read (`run.sh`, `lib.sh`, `proto.h`, `caller/` and the tool's
  directory). All of them equal the committed files.

## Fixes

| Review item | Change | Commit |
|---|---|---|
| 1. Why3 muted `-Wunused-parameter` | A trusted val `ignore_to` prints `((void)to, 0)` and is the 0 `vu_i_apply` returns. A unit no-op printing `(void)to` was tried first: extraction erases a call that returns unit and has no effect, so the warning stayed. `-Wno-error=unused-parameter` is gone. | `13d0005` |
| 2. VST, no `semax_func` lemma | `vu_funcs` proves `semax_func` over the six bodies; `Print Assumptions vu_funcs` lists the same 6 axioms. It needs the spec list extended with VST's vacuous funspecs for CompCert's runtime functions and builtins (`old_with_library'`); against `Gprog` alone, `semax_func_cons` does not apply, which is why the milestone 2 attempt was dropped. | `5f6669e` |
| 3. Pulse and VST callout postcondition | Wording only: they say "some `int` `r` with result = rule(dir, r)" and do not name the callee's actual result (table note). | table |
| 4. Verus and Aeneas struct mirrors | `offset_of!` assertions next to the size and alignment ones in the trusted glue (15 lines each), checked to fail on a wrong offset. | `6b16c96` |
| 5. Where `vu_i_apply`'s address is taken | Re-entrancy (a) column: in trusted code for Verus (`shim.rs`) and Aeneas (`c_apply`), as already said for Why3 and Isabelle-LLVM. | table |
| 6. Why3 control by timeout | Recorded as "not proved in 10 s" (table note and below). | table |
| 7. Proof escapes guarded for two tools only | Why3 (no `val`, `axiom`, `assume` in module `Vu`), Pulse (no `admit`, `assume`, `magic`, `unsafe_coerce`, `--admit_smt_queries`, `--lax`), Isabelle-LLVM (no `sorry`, `axiomatization`, `oracle`, `quick_and_dirty`, `skip_proofs`); Verus runs `--no-cheating` and accepts refusals in `src/shim.rs` only. Each guard was checked on a copy with one escape added. | `4e8828f` |
| 8. Sources not tied to the run | `run.sh` hashes every harness source into `build.log`; runs from the clone record the commit. | `9f59c3e` |
| 9. `proto.h` cites `oniguruma.h:738` | Not changed: at `f95747b`, `OnigCallbackEachMatchFunc` is declared at `upstream/src/oniguruma.h:738`, as cited. | none |

The proof-escape guard moved the `objcopy` lines of
`isabelle-llvm/build.sh`, and its `TRUSTED` range was not moved with
them: `count-trusted.sh` at `5f6669e` gives 99 for Isabelle-LLVM.
`7f727c3` fixes the range (100 again); the committed `trusted.tsv` is
the one at `7f727c3`.

## Results

| Tool | Normal run | Wall, peak RSS | Negative control | Trusted lines |
|---|---|---|---|---|
| Why3 1.9.0 | 57 of 57 goals valid with Alt-Ergo and with Z3; no `-Wno-error`; `link=ok`, `caller_output=same` | 6.1 s, 0.1 GB | rejected: 56 of 57 goals valid with each prover; the range goal of `vu_char_len` is not proved in 10 s (Alt-Ergo `Timeout (10.00s)`, Z3 `Timeout (8.76s)`) | 128 (was 124) |
| F\* + Pulse | checks, extracts, ABI and layout checks pass; `link=ok`, `caller_output=same` | 6.1 s, 0.3 GB | rejected: F\* error 19 at `VU.fst(209,2-209,3)`, twice | 25 |
| Verus | 17 verified, 0 errors; `--no-cheating`: 3 refusals, all in `src/shim.rs`; `link=ok`, `caller_output=same` | 2.3 s, 0.3 GB | rejected: 16 verified, 1 error | 102 (was 87) |
| Charon + Aeneas | 11 theorems check; `#print axioms` on the 10 that are not `rfl` lists standard axioms only; `link=ok`, `caller_output=same` | 16.3 s, 1.6 GB | rejected: one error, in `char_len_spec` | 109 (was 94) |
| VST + CompCert | 6 `semax_body` lemmas and `vu_funcs`; only the 6 allowed axioms; `link=ok`, `caller_output=same` | 61.0 s, 1.3 GB | rejected: postcondition not proved, inside `body_vu_char_len` | 44 |
| Isabelle-LLVM | session `VU` builds, ABI and layout checks pass; `link=ok`, `caller_output=same` | 41.4 s, 3.6 GB | rejected: "Failed to finish proof" on `vu_char_len_correct` | 100 |

Every build log prints its guard line ("proof escapes: none" or the
Verus `--no-cheating` summary). The verdicts do not change: Why3,
Verus, Aeneas and Isabelle-LLVM work with a trusted shim (128, 102,
109 and 100 lines), F\* + Pulse and VST + CompCert work (25 and 44).

## Outputs and disk

Raw outputs: 620 KB. On the bench host, the two recorded runs use
60 MB of build directories, and the trial runs of the fixes
(`fixdev-*`, a harness copy in `<exp>/build/fix-dev`) about 92 MB.
Nothing was installed into `<cache>` (37 GB); about 67 GB remain free.

## Deviations

- The negative-control excerpts committed with each prototype
  (`<tool>/negative-control.txt`) still describe the milestone runs; the
  re-run's control logs are in the raw outputs.
- Isabelle-LLVM ran under its own run id: the first driver skipped it
  because its check for a running Isabelle (`pgrep -f`) matched the
  command line of the shell that launched the driver. The second
  driver checks for a `poly` process by name.
- `provenance-*.txt`: the `lean` line still fails (no elan default; Lean
  comes from the Aeneas library's `lean-toolchain`, 4.36.0-rc2).

## Open points

- Isabelle-LLVM, re-entrancy (a): compose the client hypothesis of
  `vu_fold_all` with `vu_i_apply_correct` (asked on issue #13).
- The prototype does not exercise read-only access to engine state
  through accessors: the only accessors are the two slot functions, the
  `subject` pointer is never dereferenced, and Verus, Aeneas and
  Isabelle-LLVM lend full ownership only. Accept and state the limit, or
  add a read accessor to `proto.h` and the six prototypes before
  milestone 3 (asked on issue #13).
- Follow-ups from the review, not done here: the upstream F\* report of
  the eta-reduction bug (after a check against F\* master), a Miri test
  of shape (b) for the two Rust tools, and the Aeneas warning
  "extracted external, unknown definitions".
