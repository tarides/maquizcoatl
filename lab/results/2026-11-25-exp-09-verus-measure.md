# Experiment #9, entry 17: Verus M2 measurements (run 10)

**What.** The measurement record of plan step 6 for Verus, taken in the
run that closed Verus's M2 ([entry 16](2026-11-25-exp-09-verus-m2.md)):
lines by `loc.py` (semantics, compiler + VM, exec mirrors, proof), three
pinned clean full checks by `timed.sh` (median, spread, CPU time,
threads, peak RSS, load), lemma totals and automatic share by
`lemmas.py` (Verus rules added in this run), and the effort totals.

**Why.** Done-criterion 3 for Verus; planned entry 5, Verus row. The plan
moves the measurement entry into the closing run when M2 closes early.

## Provenance

As [entry 16](2026-11-25-exp-09-verus-m2.md) (same files, same commit).
Commands:

- Bench host: `BENCH_WORKDIR=<bench-workdir> flock <exp>/timed.lock
  timed.sh verus r10`, 15:27:11Z to 15:27:27Z: three clean checks of
  the crate `lib.rs` (the ten files: definitions, exec mirrors and the
  four proof modules) in fresh directories, `verus --crate-type=lib
  --num-threads 7`, pinned to CPUs 28-31,60-63 (idle at the start by
  `mpstat`; issue #25's CPUs 24-27,56-59 not used), `/usr/bin/time -v` (CPU time includes the
  Z3 processes), 16 GB cgroup cap, Z3 4.16.0, default seed.
- Workstation: `python3 -I loc.py` on the crate's files and on the
  definition files split at their `// ---- exec` marker (entry 7's
  method), and `python3 -I lemmas.py proof_a.rs proof_sem.rs
  proof_sim.rs proof.rs`.

Raw: [verus/](2026-11-25-exp-09-verus-m2-raw/verus/) (`time.tsv`,
`time.load`, `time.log` with 3 "135 verified, 0 errors" lines,
`loc.txt`, `lemmas.txt`, `axioms.txt`, `version.txt`, `invocations.tsv`,
`build.log`, `trigger-toy.txt`).

## Lines (non-blank, non-comment)

| Part | Files | Lines |
|---|---|---:|
| shared syntax (AST, bytecode, results, search), spec part | `syntax.rs` | 59 |
| semantics, spec part | `sem.rs` | 93 |
| compiler + VM, spec part | `compile.rs` 76, `vm.rs` 131 | 207 |
| theorem statement (with `groups`, `main_theorem_at`) | `statement.rs` | 31 |
| **definitions (spec), total** | | **390** |
| exec mirrors, code (unchanged since entry 7) | `syntax.rs` 112, `sem.rs` 220, `compile.rs` 191, `vm.rs` 234 | 757 |
| exec mirrors, proof lines (`assert`, `by`; unchanged) | same | 55 |
| crate root | `lib.rs` | 9 |
| proof: lemmas not returning a value (46, statement and body) | `proof_a.rs` 163, `proof_sem.rs` 82, `proof_sim.rs` 291, `proof.rs` 75 | 611 |
| proof: lemmas returning witnesses (16: `sim`, its 12 case fns, `choice`, `fuel_of`, `vm_complete`) | `proof_sem.rs` 69, `proof_sim.rs` 512, `proof.rs` 38 | 619 |
| proof: the two evaluated counterexample checks | `proof.rs` | 13 |
| proof: auxiliary definitions (`code_at`, measure, `disj`, `gsr`, `gd`, `capv`, `cls`, `cget`, `capsrel(_at)`, `meq(_at)`, `capeq`, `gs`, `uniq`, `topg`, `npg`, `fresh`, `stt`, `exe`, the `Rep` type, `hpc`, `hacts`, `hp`, `hx`, `rep`, `same_checks`, `simres`, `sim_pre`, `sim_post`, `sem_of`, `nested_same_group`), `use` and `broadcast` lines, `verus!` wrappers | all four | 313 |
| **proof, total** | `proof_a.rs` 178, `proof_sem.rs` 186, `proof_sim.rs` 1044, `proof.rs` 148 | **1,556** |

Per file, the totals are `loc.py`'s spec + proof columns (`loc.txt`);
the split by kind is from `lemmas.py`'s per-item line counts
(`lemmas.txt`), since `loc.py`'s Verus rule does not recognise `pub
broadcast proof fn` and puts auxiliary spec fns between proof fns in
its spec column. The definitions' spec part went from 376 (entry 7) to
390 lines: `statement.rs` 17 to 31 (`groups` and decision 5's
hypothesis in run 7, `main_theorem_at` in this run). Proof-to-definitions
ratio, counting the spec part only: 1,556 / 390 = 4.0 (Rocq 3.0, F\*
2.8).

## Check time (`timed.sh verus r10`, three clean full checks, pinned)

| Timed run | wall clock | user | system | user + system | peak RSS |
|---|---:|---:|---:|---:|---:|
| 1 | 5.20 s | 8.56 s | 0.87 s | 9.43 s | 508,288 KB |
| 2 | 5.33 s | 8.60 s | 0.89 s | 9.49 s | 508,280 KB |
| 3 | 5.27 s | 8.59 s | 0.90 s | 9.49 s | 512,708 KB |
| **median** | **5.27 s** | | | **9.49 s** | |

Spread (max - min): 0.13 s wall clock, 0.06 s CPU. Verus runs 7
verifier threads (`--num-threads 7`, timed.sh's default, as entry 7)
on the 8 pinned CPUs, so CPU time exceeds wall clock (ratio 1.8). The
crate is one unit for Verus, so there is no per-file time; the
definitions alone took 2.28 s (entry 7, 56 items), and the crate with
the proof 5.27 s (135 items). Load average before the checks: 1-minute
value 0.14, 0.21 and 0.28 (`time.load`).

## Lemmas (`lemmas.py`, plan step 6's Verus definition)

| File | lemmas | automatic (empty body) | of which return witnesses | examples (not lemmas) |
|---|---:|---:|---:|---:|
| `proof_a.rs` | 13 | 0 | 0 | 0 |
| `proof_sem.rs` | 5 | 0 | 1 | 0 |
| `proof_sim.rs` | 36 | 3 (`disj_union`, `lemma_cget_push`, `exe_next`) | 14 | 0 |
| `proof.rs` | 8 | 0 | 1 | 2 |
| **total** | **62** | **3 (4.8%)** | **16** | **2** |

A `proof fn` is a lemma whether or not it returns a value (plan step 6);
F\*'s 17 witness-returning functions were not lemmas by F\*'s rule
(a `let` whose type is a `Lemma`), so for a like-for-like count with F\*
Verus has 46 lemmas without the witness-returning ones (3 automatic,
6.5%), F\* 43 (3 automatic, 7%) plus 17 functions; counting every item,
Verus 3 of 62 (4.8%), F\* 3 of 60 (5%), Rocq 0 of 48. The three
automatic bodies: the two-sided set fact `disj_union`, the lookup of a
pushed capture `lemma_cget_push` (broadcast) and the one-step run
`exe_next`. Everything else has explicit steps, mostly calls to other
lemmas and `assert`s that unfold a recursive spec fn one level further
(entry 16).

## Effort totals (Verus M2)

From [effort.tsv](../09-representative-proof/effort.tsv), rows `10`: one
session (15:06:27Z to the end recorded there); proof compiles 15:13:04Z
to 15:25:15Z (12 min 11 s); 12 compile invocations of the proof modules
(6 failing, 6 clean), all 6 failing ones **failed checks**, read off the
source digests in `invocations.tsv`; per item, 62 lemmas with 80
attempts, 2 examples with 2, 1 statement change, auxiliary definitions
right at the first check; 3 scripts extended (1 attempt each); 4
invocations outside the edit loop (toy crates, negative test); human
interventions 0; no person-days.

| Figure (correction 6's units) | Rocq M2 (run 4) | F\* M2 (run 7) | Verus M2 (run 10) |
|---|---:|---:|---:|
| failing invocations | 19 | 13 | 6 |
| failed checks | 19 | 7 (session record) | 6 (from the raw digests) |
| compile invocations of the proof files | 23 | 21 | 12 (one module per invocation, `--verify-module`, or the crate) |
| per-item attempts (`effort.tsv`) | 67 (48 lemmas) | 68 (43 lemmas, 17 proof functions, 1 definition) | 80 (62 lemmas), plus 2 examples and 1 statement change |
| proof compile window | under 9 min (bounded by other timestamps) | 6 min 15 s (recorded) | 12 min 11 s (recorded) |

## Analysis

- Done-criteria 1 and 3 are met for Verus, subject to the maintainer's
  answer on the trigger-only statement change (entry 16); done-criterion
  2 was met in run 3 (entry 7) and still holds (entry 16: identical
  driver verdicts). Done-criterion 4 (seeds and solver versions) is run
  14.
- Verus's figures for M4: definitions 390 lines (spec part; plus 757
  lines of exec mirrors with 55 proof lines, which the other tools do
  not have), proof 1,556 lines (611 in lemmas, 619 in witness-returning
  lemmas), full check 5.27 s median (CPU 9.49 s on 7 threads, definitions
  and exec mirrors included), peak RSS 513 MB; 62 lemmas with 3
  automatic (4.8%); 1 session, 6 failed checks, 0 interventions.
- Against F\* on the same invariants: twice the proof lines (1,556 /
  774), mostly `proof_sim.rs`'s case fns, which restate the derivations
  and their indices that F\*'s indexed type carried implicitly, and the
  intermediate unfolding asserts; a check about 6 times faster (5.3 s /
  31.8 s wall clock), on 7 threads where F\* uses one. As for F\*, the
  proof was written by a model in one session from the same
  `FRAGMENT.md` design, after the Rocq and F\* proofs, so the effort
  figures are not independent (stated in M4).
