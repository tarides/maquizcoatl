# Experiment #6, milestone 2, run 3: throughput on S2 (Verus, Isabelle/HOL)

**What.** Criteria 3 and 4 for the Verus row (compiled Rust) and the
Isabelle/HOL row (`export_code` OCaml and `value [code]`) on S2 as
updated in run 2 (1,184 emitted cases), with the extrapolation to
10^6 cases against the 8-hour bar (34.7 cases/s) and the slowdown from
milestone 1.

**Why.** Work package G of the plan (`plans/06-spec-speed-m2.md`, run
3). These are the last two rows of the comparison.

## Provenance

As the [run 3 agreement entry](2026-11-24-exp-06-m2-run3-agreement.md).
`series-m2-3a.sh r3` (scripts at `5263037`) started at 18:28:30 UTC
and finished at 18:36:02 UTC on 2026-11-24. One timed run ran at a
time, under milestone 1's lock, pinned with `taskset -c
28-31,60-63`. At the 9 checks
([series log](2026-11-24-exp-06-m2-run3-raw/series-m2-3a.log)), no
other thread used more than 5% CPU on those CPUs, except at the last
check (T_spec run 3): one thread of another process used 5.8% on CPU
28. The 1-minute load was 0.86-1.88 for the throughput runs. Passes
(`reps-m2.env`) were calibrated in untimed runs on CPUs 0-15. Every
run exited with status 0, and every fold returned passes x 1,179.
Build: Verus `--compile -- -C opt-level=3`. Isabelle: `export_code` to
OCaml, then `ocamlfind ocamlopt -O3 -package zarith,unix`; `nat` is
`Z.t`.

## Raw data

Compiled or extracted (in-process timing of REPS passes, median of
three runs). End to end adds stack G's parse (213,927 cases/s, run 2's
median), as for every prover row:

| Row, mode | REPS | Search cases/s (runs) | Search median | End to end cases/s | 10^6 cases | Verdict | Milestone 1 search | Slowdown |
|-----------|-----:|---|---:|---:|---:|---|---:|---:|
| Verus, compiled Rust | 6,000 | 539,286; 539,695; 539,560 | 539,560 | 153,190 | 6.5 s | fast enough | 3,533,001 | 6.5x |
| Isabelle/HOL, `export_code` OCaml | 2,000 | 175,924; 178,050; 176,034 | 176,034 | 96,570 | 10.4 s | fast enough | 1,649,722 | 9.4x |

In-prover mode: the wall-clock of `isabelle build -c` of the session
that runs `value [code] "passes 4000 cases 0"`, minus the import-only
baseline Q0, median of three runs:

| Mode | Passes | Cases | Q0 s (runs) | QV s (runs) | Search cases/s | End to end cases/s | 10^6 cases | Verdict | Peak RSS | Milestone 1 cases/s | Slowdown |
|------|-------:|------:|---|---|---:|---:|---:|---|---:|---:|---:|
| Isabelle `value [code]` | 4,000 | 4,736,000 | 8.68 (8.62, 8.68, 8.77) | 39.46 (40.99, 39.46, 38.74) | 153,866 | 89,496 | 11.2 s | fast enough | 1.8 GB | 2,378,292 (run 1 rerun) | 15.5x |

Each QV printed `4716000 :: nat` (4,000 x 1,179). QV minus Q0 includes
the code generation and Poly/ML compilation of the tables, semantics
and cases. That is about 18 s here (untimed calibration: 1 and 10
passes took 26.9 s and 27.0 s, against 8.6 s for Q0). In milestone 1, which
had no tables, it was under 2 s: 8,000 passes took 1.93 s over Q0. Without it, the fold alone runs at
about 330,000 cases/s (untimed calibration, 990 passes in 3.5 s). The
table counts it, as milestone 1's method does.

## Analysis

- **Criteria 3 and 4 for Verus and Isabelle/HOL: every mode is fast
  enough.** The slowest, `value [code]`, needs 11 s for 10^6 cases end
  to end, about 2,600 times under the 8-hour bar.
- Verus's compiled Rust is the fastest prover row on S2 (539,560 cases/s
  search, against 140,000-250,000 for the extracted OCaml of Rocq, Lean,
  Why3 and F\*). Stack G's parse is then 72% of its end-to-end time.
- The slowdown from milestone 1 is 6.5x (Verus) and 9.4x (Isabelle
  extracted), within the band of the other extracted rows (3.1x-7.2x)
  for Verus and somewhat above it for Isabelle, whose `nat` is
  arbitrary-precision `Z.t`. `value [code]`'s 15.5x is mostly the fixed
  code generation cost, now that the session holds a table module.
- Isabelle `value [code]` evaluates compiled ML. Like Rocq's VM and
  native compiler and Lean's `#eval`, it is not a term rewriter, which
  is why it stays fast where `why3 execute` and the F\* normaliser
  dropped under the bar (run 1).
