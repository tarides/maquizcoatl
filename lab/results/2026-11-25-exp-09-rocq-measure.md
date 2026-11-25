# Experiment #9, entry 11: Rocq M2 measurements (run 4)

**What.** The measurement record of plan step 6 for Rocq, taken in the
run that closed Rocq's M2 ([entry 10](2026-11-25-exp-09-rocq-m2.md)):
lines by `loc.py` (semantics, compiler + VM, proof), three pinned clean
full checks by `timed.sh` (median, spread, CPU time, peak RSS, load),
lemma totals and automatic share by `lemmas.py`, and the effort totals.

**Why.** Done-criterion 3 for Rocq; planned entry 5, Rocq row. The plan
moves the measurement entry into the closing run when M2 closes early.

## Provenance

As [entry 10](2026-11-25-exp-09-rocq-m2.md) (same files, same commit).
Commands:

- Bench host: `ROCQ_FILES="Syntax Sem Compile Vm Statement ProofA
  ProofSem ProofSim Proof" BENCH_WORKDIR=<bench-workdir> flock
  <exp>/timed.lock timed.sh rocq r4` at 13:47:43Z: three clean checks
  of the nine files in fresh directories, one file at a time, pinned to
  CPUs 28-31,60-63 (no process above 1% CPU on them before the start),
  `/usr/bin/time -v`, 16 GB cgroup cap.
- Workstation: `python3 -I loc.py <the nine files>` and
  `python3 -I lemmas.py ProofA.v ProofSem.v ProofSim.v Proof.v`
  (`lemmas.py` is new in this run; its rules are the plan's step 6).

Raw: [rocq/](2026-11-25-exp-09-rocq-m2-raw/rocq/) (`time.tsv`,
`time.load`, `time.log` with 27 `Checked` lines, `loc.txt`,
`lemmas.txt`, `axioms.txt`, `version.txt`).

## Lines (non-blank, non-comment, `loc.py`)

| Part | Files | Lines |
|---|---|---:|
| shared syntax (AST, bytecode, results, search) | `Syntax.v` | 49 |
| semantics | `Sem.v` | 67 |
| compiler + VM | `Compile.v` 62, `Vm.v` 91 | 153 |
| theorem statement | `Statement.v` | 21 |
| **definitions, total** | | **290** |
| proof: lemma statements and proofs | `ProofA.v` 120, `ProofSem.v` 105, `ProofSim.v` 459, `Proof.v` 59 | 743 |
| proof: auxiliary definitions (measure, `rep`, `capsrel`, `meq`, `uniq`, `exec`, ...) and the two counterexample `Example`s | `ProofA.v` 8, `ProofSem.v` 23, `ProofSim.v` 87, `Proof.v` 11 | 129 |
| **proof, total** | | **872** |

`loc.py` counts a declaration that is not a `Lemma`/`Theorem` (with its
proof) as specification, so the 129 lines of the proof files' own
definitions and `Example`s appear in its "spec" column (`loc.txt`); they
exist only for the proof and are counted as proof here. Definitions
went from 282 to 290 lines (`Statement.v`: `groups` and the
hypothesis). Proof-to-definitions ratio: 872 / 290 = 3.0. The single
lemma `sim` (statement and proof) is 413 tactic sentences and most of
`ProofSim.v`'s 459 lines.

## Check time (`timed.sh rocq r4`, three clean full checks, pinned)

Per timed run, summed over the nine files (`time.tsv`):

| Timed run | wall clock | user | system | user + system | peak RSS |
|---|---:|---:|---:|---:|---:|
| 1 | 6.47 s | 3.88 s | 2.54 s | 6.42 s | 414,436 KB |
| 2 | 6.50 s | 3.91 s | 2.53 s | 6.44 s | 414,436 KB |
| 3 | 6.54 s | 3.85 s | 2.63 s | 6.48 s | 414,436 KB |
| **median** | **6.50 s** | | | **6.44 s** | |

Spread (max - min): 0.07 s wall clock, 0.06 s CPU. Single-threaded: CPU
time equals wall clock. Peak RSS is `ProofSim.v`'s. Median per file:

| File | wall clock (median) |
|---|---:|
| `Syntax.v`, `Sem.v`, `Compile.v`, `Vm.v`, `Statement.v` | 0.57, 0.60, 0.55, 0.62, 0.48 s (2.82 s) |
| `ProofA.v` | 0.76 s |
| `ProofSem.v` | 0.84 s |
| `ProofSim.v` | 1.46 s |
| `Proof.v` | 0.62 s |
| proof files only | 3.67 s (runs 3.67 / 3.67 / 3.73 s) |

Load average (1, 5, 15 min) before the checks: 1-minute value 0.20 at
the first check, at most 0.50 during the runs (`time.load`). As in
entry 3, each file pays about 0.45 s of Rocq start-up and Stdlib load,
so the proof's own checking time is about 3.67 - 4 x 0.45 = 1.9 s.

## Lemmas (`lemmas.py`)

| File | lemmas | automatic |
|---|---:|---:|
| `ProofA.v` | 13 | 0 |
| `ProofSem.v` | 7 | 0 |
| `ProofSim.v` | 24 | 0 |
| `Proof.v` | 4 | 0 |
| **total** | **48** | **0 (0%)** |

No proof is a single call of `lia`, `auto`, `eauto`, `easy`,
`congruence`, `intuition` or `firstorder`: every one but `region_rv`
starts with `intros`, `induction` or `unfold`, and `lia` closes many
subgoals inside longer scripts. The plan's definition counts lemmas, not subgoals, so
Rocq's automatic share is 0 of 48. `region_rv` is a single
`reflexivity` and `length_skipn'` a single compound sentence; neither
counts (plan step 6). The two `Example`s are not lemmas.

## Effort totals (Rocq M2)

From [effort.tsv](../09-representative-proof/effort.tsv), run 4 rows:
one session (13:25:52Z to the end recorded there), 48 lemmas with 67
check attempts (19 failed), 1 definition change (`Statement.v`,
1 attempt), 3 new scripts or cases (`timed.sh` rocq case, `axioms.sh`,
`lemmas.py`, 1 attempt each); human interventions 0; no person-days.

## Analysis

- Done-criteria 1 and 3 are met for Rocq; done-criterion 2 was met in
  run 1 (entries 3 and 4) and still holds (entry 10's driver rerun).
- Rocq's figures for M4: definitions 290 lines, proof 872 lines (743
  lemma lines), full check 6.50 s median (CPU 6.44 s), proof files
  3.67 s, 48 lemmas, 0% automatic, 1 session, 19 failed checks, 0
  interventions.
