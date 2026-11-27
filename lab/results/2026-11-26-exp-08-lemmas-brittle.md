# Experiment #8 follow-up (issue #34), entry 8: Verus brittleness (run 4)

**What.** Run 4 of plan `plans/08-discriminating-lemmas.md`, first part:
the Verus crate of run 3 ([entry 6](2026-11-26-exp-08-lemmas-verus.md),
unchanged since `2242606`) re-checked in full, clean, for every cell of
experiment #9's run-14 matrix. The bundled Z3 4.16.0 is the supported
solver. As an unsupported configuration, Z3 5.3.0 and 4.15.3 from the
F\* release are passed through `VERUS_Z3_PATH` with `-V
no-solver-version-check`. Each version runs with the default seed and
with `--smt-option smt.random_seed=N` for N = 1..10. That is 33 cells,
plus one cell that records Verus's refusal of Z3 5.3.0 without the
opt-out, plus a labelled replication of each failing cell. No `--rlimit`
option is passed: the proof was written with Verus's default (10) and its
sources set none.

**Result.** 31 of 33 cells pass. Under the supported Z3 4.16.0, all 11
pass, but the largest per-function share of the rlimit is **63.9%**
(`term_core`, seed 10), against 11.3% in experiment #9. Under Z3 5.3.0,
two cells fail (default seed and seed 10): `sim_a`, the induction of
direction (2a), exhausts the rlimit. Both failures replicate. Under Z3
4.15.3, all 11 pass, with at most 43.4%.

**Why.** Done-criterion 4 (decision 1: "Verus brittleness as experiment
#9's run 14 ... every failure recorded with its rlimit share"), plan
run 4, planned entry 5. The experiment's question is where SMT
automation breaks on these proofs.

## Provenance

- Bench host, as [entry 1](2026-11-26-exp-08-lemmas-provenance.md)
  (AMD EPYC 7502P, 64 logical CPUs, Linux 6.8.0-100-generic, Ubuntu
  24.04.5 LTS). Verus 0.2026.11.02.8bf68ee, release profile, Rust
  1.99.1 ([`version.txt`](2026-11-26-exp-08-lemmas-brittle-raw/verus/version.txt));
  Z3 4.16.0 bundled next to `verus`; Z3 5.3.0 and 4.15.3 from the F\*
  2026.11.15 release (`<cache>/fstar/lib/fstar/z3-<V>/bin/z3`). No tool
  installed or upgraded.
- Sources: the eight crate files at branch commit `677c70c` (bench clone
  fast-forwarded from `2242606`; the Verus files are byte-identical to
  entry 6's `sha256.txt`). SHA-256 of the eight concatenated in
  `brittle.sh`'s order (`lib fold fold_proof absent desugar absent_mono
  absent_proof cases`): `732686d2…44b5`, the same in all 36 rows of
  `checks.tsv`.
- Script: `lab/08-discriminating-lemmas/brittle.sh`, `verus` mode, as
  adapted in run 1 (unchanged since `985106f`), with
  `brittle_verus.py` unchanged. One call per (version, seed), a fresh
  directory, the whole crate (`cases.rs` included, as `axioms.sh` and
  `timed.sh` check it):
  `verus --crate-type=lib --num-threads 7 --output-json --time-expanded
  [-V no-solver-version-check] [--smt-option smt.random_seed=N] lib.rs`.
  Pinned with `taskset -c 24-27,56-59`, under `flock <exp>/timed.lock`,
  `/usr/bin/time -v`, 16 GB cgroup cap, serial; the z3 sampler on CPU 8.
- Drivers: [`drive.sh`](2026-11-26-exp-08-lemmas-brittle-raw/verus/drive.sh)
  (the matrix, order 4.16.0, refusal, 5.3.0, 4.15.3, seeds default,
  1..10) and [`drive-rep.sh`](2026-11-26-exp-08-lemmas-brittle-raw/verus/drive-rep.sh)
  (the two replications, label `rep1`). Before each cell, the driver
  records the load average, the busy share of the eight pinned CPUs over
  one second, and every thread above 1% CPU last seen on them (`ps -eLo
  user,psr,pcpu,comm`; other accounts' threads written as `other`). It
  waits 60 s while any such thread exists or the busy share is above 10%
  ([`precheck.txt`](2026-11-26-exp-08-lemmas-brittle-raw/verus/precheck.txt)).
  Matrix cells from 16:18:29Z to 16:38:37Z
  ([`drive.log`](2026-11-26-exp-08-lemmas-brittle-raw/verus/drive.log)),
  replications from 16:39:17Z to 16:41:55Z
  ([`drive-rep.log`](2026-11-26-exp-08-lemmas-brittle-raw/verus/drive-rep.log)).
- Load before the checks: 1-minute load 0.04 to 4.20; pinned CPUs 0.0% to
  0.5% busy; no thread above 1% on them before any matrix cell. Before
  the first replication, one other account's thread showed 4.7% on CPU 58,
  so the driver waited 60 s; the next precheck was clean. Peak RSS 532 to
  536 MB.
- Untimed, after the matrix (`nice -n 10`, CPUs 8-11, not in the
  matrix): a recheck of the rlimit unit,
  [`calib.sh`](2026-11-26-exp-08-lemmas-brittle-raw/verus/calib.sh) and
  [`rlimit-calibration.txt`](2026-11-26-exp-08-lemmas-brittle-raw/verus/rlimit-calibration.txt).
- Disk: 41 GB free on the bench work directory before the series (floor
  20 GB).

Raw: [verus/](2026-11-26-exp-08-lemmas-brittle-raw/verus/):
- `checks.tsv`: one row per call, 36 rows;
- `functions.tsv`: per call and function, the SMT time, rlimit count and
  success; 179 functions per cell, 6,265 rows;
- `logs.tar.xz`: every cell's `out.json`, `err.txt`, `cmd.txt`,
  `verus.time` and `z3exe.txt`, packed with numeric owner 0/0;
- uncompressed: the refusal cell `5.3.0_default_nooptout/` and the
  `err.txt` of the failing cell `5.3.0_default/`;
- [`shares.py`](2026-11-26-exp-08-lemmas-brittle-raw/verus/shares.py)
  and its output [`shares.txt`](2026-11-26-exp-08-lemmas-brittle-raw/verus/shares.txt),
  from which every share below is taken.

No script incident: every call wrote its row, and no cell ran twice
except the two labelled replications.

## Matrix

`ok` = exit 0, "179 verified, 0 errors", and every function of the JSON
breakdown successful. `FAIL` = exit 1, "178 verified, 1 errors". Wall
clock in seconds; about 19 s of each check is the 29 `compute_only`
cases (entry 6), which do not use Z3.

| Z3 \ seed | default | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 4.16.0 (bundled, supported) | ok 33.09 | ok 33.03 | ok 33.13 | ok 32.99 | ok 32.94 | ok 32.91 | ok 33.11 | ok 33.10 | ok 33.08 | ok 33.11 | ok 33.05 |
| 5.3.0 (`VERUS_Z3_PATH`, opt-out) | **FAIL** 48.19 | ok 32.99 | ok 32.96 | ok 33.10 | ok 32.92 | ok 33.10 | ok 33.23 | ok 38.52 | ok 33.05 | ok 32.84 | **FAIL** 44.50 |
| 4.15.3 (`VERUS_Z3_PATH`, opt-out) | ok 32.97 | ok 32.94 | ok 33.00 | ok 32.90 | ok 32.95 | ok 32.94 | ok 32.91 | ok 32.90 | ok 32.94 | ok 32.84 | ok 32.98 |

31 of 33 cells pass: 11 of 11 under 4.16.0, 9 of 11 under 5.3.0, 11 of
11 under 4.15.3. In every cell the `z3_started` column (the `--version`
of each z3 binary seen running in the check's directory) is the selected
version.

| Z3 | wall median (range) | CPU median (user + system) |
|---|---|---|
| 4.16.0 | 33.08 s (32.91-33.13) | 44.49 s |
| 5.3.0 | 33.10 s (32.84-48.19) | 52.46 s |
| 4.15.3 | 32.94 s (32.84-33.00) | 43.11 s |

Run 3's `timed.sh` median (4.16.0, default seed, without `--output-json
--time-expanded`) was 33.01 s.

## The two failures

Both cells fail on the same function with the same error, at the same
line ([`5.3.0_default/err.txt`](2026-11-26-exp-08-lemmas-brittle-raw/verus/5.3.0_default/err.txt)):

```
error: function body check: resource limit (rlimit) exceeded; consider rerunning with `--profile` for more details
    --> absent_proof.rs:1296:1
1296 | / pub proof fn sim_a(s: L<nat>, g: nat, f: nat, ks: L<Item>, i: nat, rr: nat, l: L<nat>, dks: L<DItem>, ns: L<(nat, nat)>, sv: L<(...
```

| Cell | `failing` column (`brittle_verus.py`) | `sim_a` rlimit count | share | wall |
|---|---|---:|---:|---:|
| 5.3.0, default seed | `failed:lib::absent_proof::sim_a; Error"function body check: resource limit (rlimit) exceeded; ..."@absent_proof.rs:1296(sim_a)` | 30,000,000 | 100% | 48.19 s |
| 5.3.0, seed 10 | same | 30,000,000 | 100% | 44.50 s |
| 5.3.0, default seed, `rep1` | same | 30,000,000 | 100% | 48.22 s |
| 5.3.0, seed 10, `rep1` | same | 30,000,000 | 100% | 44.35 s |

`sim_a` is direction (2a) of lemma 2 (`absent_desugar_eq`): the
induction on the continuation and the fuel, 101 lines (entry 7), with
the core constructors as cases and the absent constructs delegated to
`sim_a_rep`, `sim_a_gen`, `sim_a_stop`. No other function fails in
either cell. The replications fail identically, so for a given seed and
solver version the failure is deterministic. No failure was retried
away: the matrix rows are the first runs, and the `rep1` rows are extra
rows. The proof is not changed in this run, so neither cell is
"fixed"; under the supported solver the proof passes.

Under 5.3.0, `sim_a` is also the most expensive function at seed 7
(61.6%); at the other seven seeds it uses 10.1% to 15.7%.

## Refusal without the opt-out (recorded once)

Cell `5.3.0_default_nooptout`: `VERUS_Z3_PATH` = Z3 5.3.0, no `-V
no-solver-version-check`, default seed. As in experiment #9's run 14,
Verus starts the solver, then stops with exit 134 (a panic), no JSON,
in 3.30 s ([`err.txt`](2026-11-26-exp-08-lemmas-brittle-raw/verus/5.3.0_default_nooptout/err.txt)):

```
thread '<unnamed>' (…) panicked at air/src/smt_verify.rs:204:21:
The verifier expects z3 version "4.16.0", found version "5.3.0"
error: expected z3 version 4.16.0, found 5.3.0
```

followed by the second panic at `rust_verify/src/verifier.rs:437:17`
that experiment #9 recorded.

## Margins

Verus counts Z3 resource units per function (`functions.tsv`,
`rlimit`). One `--rlimit` unit is 3,000,000 units, so the default
`--rlimit 10` is 30,000,000 per function. That is experiment #9's
calibration
([`2026-11-25-exp-09-verus-m3-raw/verus/rlimit-calibration.txt`](2026-11-25-exp-09-verus-m3-raw/verus/rlimit-calibration.txt)),
rechecked on this crate: at `--rlimit 0.3`, the four functions that run
out (`term_core`, `sim_b_xs`, `sim_a`, `scan_a`) stop at exactly 900,000
([`rlimit-calibration.txt`](2026-11-26-exp-08-lemmas-brittle-raw/verus/rlimit-calibration.txt)),
and the two failing matrix cells stop `sim_a` at exactly 30,000,000.
The count covers all the queries of a function, so count / 30,000,000
is an upper bound on what any one query used, and it holds at the
default limit only (experiment #9, correction 9).

| Z3 | function checks | over 10% | over 25% | over 50% | failed | highest share of the limit |
|---|---:|---:|---:|---:|---:|---|
| 4.16.0 | 1,969 | 15 | 5 | 1 | 0 | 0.639 (`absent_proof::term_core`, seed 10) |
| 5.3.0 | 1,969 | 37 | 14 | 3 | 2 | 1.000 (`absent_proof::sim_a`, default seed and seed 10) |
| 4.15.3 | 1,969 | 17 | 1 | 0 | 0 | 0.434 (`absent_proof::term_core`, seed 2) |

Every function above 10% in some cell is in `absent_proof.rs` (lemma 2).
Lemma F's module stays at or under 1.0% in every cell (`fold_proof`,
largest `sharp_s_sym`); `absent_mono` at 0.5%; the definitions and the
`compute_only` cases at 0.1% or less.

Largest share per seed (default, 1..10) of the functions above 10%, and
of the functions the run-3 review named for a first look:

| Function | Z3 | default | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `term_core` | 4.16.0 | .407 | .366 | .073 | .127 | .076 | .074 | .484 | .059 | .065 | .303 | **.639** |
| | 5.3.0 | .118 | .064 | .157 | .062 | .074 | .074 | .069 | .193 | .079 | .066 | .272 |
| | 4.15.3 | .058 | .061 | .434 | .096 | .204 | .054 | .185 | .104 | .071 | .080 | .061 |
| `sim_a` | 4.16.0 | .071 | .074 | .054 | .032 | .168 | .099 | .036 | .034 | .035 | .214 | .027 |
| | 5.3.0 | **1.000** | .110 | .101 | .134 | .114 | .102 | .157 | .616 | .141 | .109 | **1.000** |
| | 4.15.3 | .031 | .164 | .027 | .075 | .118 | .075 | .201 | .069 | .028 | .132 | .073 |
| `scan_a` | 4.16.0 | .146 | .161 | .063 | .056 | .123 | .101 | .176 | .063 | .048 | .086 | .122 |
| | 5.3.0 | .201 | .261 | .164 | .295 | .263 | .292 | .357 | .245 | .092 | .260 | .272 |
| | 4.15.3 | .140 | .148 | .109 | .132 | .056 | .145 | .090 | .161 | .162 | .136 | .119 |
| `sim_b_xs` | 4.16.0 | .030 | .052 | .037 | .030 | .084 | .132 | .083 | .055 | .030 | .040 | .051 |
| | 5.3.0 | .149 | .169 | .035 | .142 | .077 | .044 | .177 | .331 | .084 | .036 | .114 |
| | 4.15.3 | .045 | .090 | .030 | .031 | .036 | .035 | .053 | .038 | .061 | .053 | .038 |
| `sim_b_rep` | 4.16.0 | .092 | .021 | .021 | .021 | .025 | .023 | .021 | .021 | .025 | .025 | .021 |
| | 5.3.0 | .239 | .035 | .235 | .296 | .035 | .036 | .170 | .039 | .260 | .204 | .034 |
| | 4.15.3 | .021 | .025 | .022 | .021 | .024 | .023 | .024 | .100 | .023 | .021 | .021 |
| `sim_b` | 4.16.0 | .014 | .015 | .083 | .015 | .014 | .015 | .015 | .015 | .083 | .014 | .015 |
| | 5.3.0 | .015 | .015 | .015 | .015 | .015 | .015 | .015 | .018 | .017 | .015 | .015 |
| | 4.15.3 | .031 | .015 | .015 | .015 | .015 | .014 | .014 | .014 | .015 | .015 | .031 |
| `scan_b` | 4.16.0 | .019 | .031 | .027 | .025 | .013 | .033 | .031 | .027 | .037 | .024 | .026 |
| | 5.3.0 | .016 | .034 | .023 | .043 | .061 | .062 | .045 | .023 | .033 | .056 | .057 |
| | 4.15.3 | .026 | .026 | .023 | .033 | .020 | .019 | .025 | .032 | .032 | .033 | .026 |
| `core_k` | all three | .013 at every seed | | | | | | | | | | |

## Analysis

- **Done-criterion 4 for Verus: met as stated.** Three solver versions
  (one supported, two through the documented opt-out), 11 seeds each,
  every result recorded with its per-function rlimit shares; the refusal
  without the opt-out is recorded once; the two failures are recorded
  with the failing function and its share (100%), and replicated, not
  retried away.
- **Automation is near its limit on lemma 2, not on lemma F.** Under the
  supported 4.16.0, every cell passes, but `term_core` (the termination
  of the absent-free matcher, induction on `(rr - i, size)`, 74 lines)
  uses between 5.9% and 63.9% of the limit depending on the seed, and is
  above 30% at five seeds of 11. Experiment #9's largest share under the
  same solver was 11.3%. Under 5.3.0, `sim_a` (direction (2a), 101 lines)
  runs out at two seeds and reaches 61.6% at a third, while it stays at
  or under 21.4% under the two 4.x versions. Lemma F never exceeds 1%.
- **What breaks is large inductions with many cases, as in run 3.**
  The failing and near-failing functions (`sim_a`, `term_core`,
  `scan_a`, `sim_b_xs`, `sim_b_rep`) are the large case analyses of
  lemma 2. Run 3's one development failure was the same kind (the
  unsplit `sim_b`, which the split fixed: `sim_b` now stays at or under
  8.3%). The seed spread is wide: the same function on the same solver
  moves by a factor of about 10 between seeds (`term_core` under
  4.16.0, `sim_a` under 5.3.0).
- **Versions differ in outcome here, not only in cost.** Experiment #9
  found the versions differing only in cost. Here the unsupported 5.3.0
  fails twice and has the most functions above 10% (37 of 1,969, against
  15 and 17), and it costs more CPU (median 52.46 s against 44.49 s and
  43.11 s). The wall clock hides most of that, since the `compute_only`
  cases take about 19 s of every check.
- **Not measured.** Per-query shares: Verus reports per function, so a
  function's share is an upper bound for any of its queries. The vstd
  library is not rechecked. cvc5 is not tried (not installed, as in
  experiment #9). Seeds are Z3's `smt.random_seed`. The remedies the
  plan names (a split first, a raised `rlimit` last) are not applied:
  the proof as written in run 3 is what this run measures.

## Effort

[`effort.tsv`](../08-discriminating-lemmas/effort.tsv), run-4 rows. The
first bench-host command of the session was at 16:17:41Z (the plan,
reviews and earlier entries were read before it). `brittle.sh` and `brittle_verus.py` ran unchanged at
the first attempt. 36 checks: 33 matrix cells, the refusal cell and 2
replications. One untimed calibration check. No failure was retried, and
there were no human interventions.

_Drafted by Claude Code (Opus 5.5) as part of the experiment pipeline._
