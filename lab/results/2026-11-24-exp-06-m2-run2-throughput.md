# Experiment #6, milestone 2, run 2: throughput on the updated S2 (Rocq, Lean 4; C, stack G, Why3, F\* extracted)

**What.** Criteria 3 and 4 for the Rocq and Lean 4 rows on the updated
S2 (1,243 cases; 1,184 emitted to the provers). Rocq is measured with
`vm_compute`, `native_compute` and extracted OCaml, Lean with `#eval`
and the `lake` native build, and each mode gets an extrapolation to
10^6 cases against the 8-hour bar (34.7 cases/s). The C library, stack
G and the extracted Why3 and F\* drivers are measured again on the
updated cases, so all rows share one case set. The interpreted modes of
Why3 and F\* were not run again: run 1 answered question 1 for them.

**Why.** Work package E of the plan (`plans/06-spec-speed-m2.md`, run
2). Criteria 3 and 4 for two more rows. S2 gained the 46 code point
list cases (decision 3 after run 1), and the semantics changed slightly
(DEV-008), so run 1's figures are no longer on the same cases.

## Provenance

[provenance.txt](2026-11-24-exp-06-m2-run2-raw/provenance.txt): bench
host, AMD EPYC 7502P (64 hardware threads), 503 GB, Linux
6.8.0-100-generic, Ubuntu 24.04.5. OCaml 5.4.1 (switch `provers`,
`ocamlfind ocamlopt -O3`, falling back to the default flags if `-O3`
is refused), Rocq 9.3.0 (rocq-stdlib 9.2.0, rocq-native),
Lean 4.36.0 (lake 5.0.0, `leanc -O3`), Why3 1.9.0, F\* 2026.11.15,
GCC 13.3.0, C library `f95747b` Release (`-O3 -DNDEBUG`). Scripts at
`e293368`: `series-m2-2a.sh r2`, started 16:16:46 UTC and done
16:47:54 UTC on 2026-11-24. One timed run at a time under milestone 1's
lock, pinned with `taskset -c 28-31,60-63`. No other thread above 5%
CPU on those CPUs at any of the 12 checks
([series log](2026-11-24-exp-06-m2-run2-raw/series-m2-2a.log)), and
the 1-minute load was 0.66-1.35 for every run. Passes
(`reps-m2.env`) were calibrated in untimed runs on CPUs 0-15 so that
each fold lasts at least 10 s. Every run exited with status 0, and
every fold returned the expected count: passes x 1,179 (the 1,184
emitted cases minus the 5 logged deviations).

## Raw data

Per-run wall-clock, peak RSS and load: `*/times.tsv`, and the driver
outputs `*.log`, in
[the run 2 raw directory](2026-11-24-exp-06-m2-run2-raw/).

Extracted or compiled code (in-process timing of REPS passes, median of
three runs). End to end, for the prover rows, adds stack G's parse
(213,927 cases/s, this run's median), as in milestone 1:

| Row, mode | REPS | Search cases/s (runs) | Search median | End to end cases/s | 10^6 cases | Verdict | Run 1 (end to end) |
|-----------|-----:|---|---:|---:|---:|---|---:|
| C library (reference) | 30,000 | 3,479,854; 3,457,607; 3,478,079 | 3,478,079 (parse 316,080) | 275,174 | 3.6 s | reference | 273,483 |
| stack G, ocamlopt | 9,000 | 1,045,754; 1,039,903; 1,056,090 | 1,045,754 (parse 213,927) | 171,686 | 5.8 s | fast enough | 168,525 |
| Rocq, extracted OCaml | 1,500 | 140,779; 140,564; 139,075 | 140,564 | 84,827 | 11.8 s | fast enough | - |
| Lean 4, lake native build | 1,500 | 137,203; 138,183; 137,720 | 137,720 | 83,783 | 11.9 s | fast enough | - |
| Why3, extracted OCaml | 1,500 | 146,748; 150,744; 151,950 | 150,744 | 88,431 | 11.3 s | fast enough | 87,622 |
| F\*, extracted OCaml | 2,000 | 248,066; 249,474; 253,238 | 249,474 | 115,169 | 8.7 s | fast enough | 107,945 |

(C and stack G: medians of the per-run parse, search and end-to-end
rates that the drivers print. For C, "parse" is `onig_new`.)

In-prover modes: wall-clock of the evaluation command minus the
import-only baseline Q0 of the same run, median of three runs. The
"Command s" column is the command's wall-clock with Q0 included.

| Mode | Passes | Cases | Q0 s | Command s (runs) | Search cases/s | End to end cases/s | 10^6 cases | Verdict | Peak RSS | Milestone 1 cases/s | Slowdown |
|------|-------:|------:|---:|---|---:|---:|---:|---|---:|---:|---:|
| Rocq `vm_compute` | 80 | 94,720 | 0.49 | 12.76 (12.86, 12.74, 12.76) | 7,720 | 7,451 | 2.2 min | fast enough | 598 MB | 17,153 | 2.2x |
| Rocq `native_compute` | 300 | 355,200 | 0.49 | 15.53 (15.59, 15.53, 15.51) | 23,617 | 21,270 | 47 s | fast enough | 1.3 GB | 31,618 | 1.3x |
| Lean 4 `#eval` | 100 | 118,400 | 0.28 | 14.09 (14.14, 14.08, 14.09) | 8,574 | 8,244 | 2.0 min | fast enough | 472 MB | 58,800 | 6.9x |

`native_compute` includes the on-demand native compilation of the
evaluated term, as in milestone 1. Extracted slowdowns against
milestone 1 (search): Rocq 767,480 / 140,564 = 5.5x, Lean 881,968 /
137,720 = 6.4x.

## Analysis

- **Criteria 3 and 4 for Rocq and Lean 4: every mode is fast enough.**
  The slowest, Rocq `vm_compute`, needs 2.2 minutes for 10^6 cases,
  about 215 times under the 8-hour bar. The S2 semantics costs Rocq
  and Lean a factor of 1.3-6.9 against milestone 1, far from the 16.8x
  and 6.8x that pushed `why3 execute` and the F\* normaliser under the
  bar in run 1. Their evaluators (Rocq's bytecode VM and native
  compiler, Lean's IR interpreter over compiled imports) are compiled
  machines, not term rewriters.
- The extracted rows (Rocq, Lean, Why3, F\*) are within a factor of 1.4
  of each other (83,783-115,169 cases/s end to end). Stack G's parse is
  40-54% of their end-to-end time.
- On the updated cases, C, stack G and the extracted Why3 and F\*
  drivers are within 7% of run 1's figures. The 46 code point list
  cases and DEV-008 change no verdict of criterion 4.
- Not rerun: `why3 execute` and the F\* normaliser. Run 1 answered
  question 1 for them (3.7 and 9.3 cases/s), and a one-line change in
  the semantics plus 24 more cases cannot bring them over 34.7 cases/s.
