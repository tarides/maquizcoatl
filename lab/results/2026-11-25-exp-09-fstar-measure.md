# Experiment #9, entry 14: F\* M2 measurements (run 7)

**What.** The measurement record of plan step 6 for F\*, taken in the
run that closed F\*'s M2 ([entry 13](2026-11-25-exp-09-fstar-m2.md)):
lines by `loc.py` (semantics, compiler + VM, proof), three pinned clean
full checks by `timed.sh` (median, spread, CPU time, peak RSS, load),
lemma totals and automatic share by `lemmas.py` (F\* rules added in this
run), and the effort totals.

**Why.** Done-criterion 3 for F\*; planned entry 5, F\* row. The plan
moves the measurement entry into the closing run when M2 closes early.

## Provenance

As [entry 13](2026-11-25-exp-09-fstar-m2.md) (same files, same commit).
Commands:

- Bench host: `FSTAR_FILES="Syntax Sem Compile Vm Statement ProofA
  ProofSem ProofSim Proof" BENCH_WORKDIR=<bench-workdir> flock
  <exp>/timed.lock timed.sh fstar r7`, 14:44:59Z to 14:46:36Z: three
  clean checks of the nine files in fresh directories (fresh `cache/`),
  one file at a time in dependency order, each against the `.checked`
  files of the ones before it, pinned to CPUs 28-31,60-63 (no process
  above 1% CPU on them at the start), `/usr/bin/time -v` (CPU time
  includes the Z3 child process), 16 GB cgroup cap, Z3 5.3.0, default
  seed.
- Workstation: `python3 -I loc.py <the nine files>` and
  `python3 -I lemmas.py ProofA.fst ProofSem.fst ProofSim.fst Proof.fst`.

Raw: [fstar/](2026-11-25-exp-09-fstar-m2-raw/fstar/) (`time.tsv`,
`time.load`, `time.log` with 27 "Verified module" lines, `loc.txt`,
`lemmas.txt`, `axioms.txt`, `version.txt`, `invocations.tsv`,
`querystats-ProofSim.txt`).

## Lines (non-blank, non-comment)

| Part | Files | Lines |
|---|---|---:|
| shared syntax (AST, bytecode, results, search) | `Syntax.fst` | 55 |
| semantics | `Sem.fst` | 59 |
| compiler + VM | `Compile.fst` 55, `Vm.fst` 80 | 135 |
| theorem statement (with `groups`, `mem`, `nodup`) | `Statement.fst` | 26 |
| **definitions, total** | | **275** |
| proof: lemmas (statement and body, 43) | `ProofA.fst` 90, `ProofSem.fst` 53, `ProofSim.fst` 74, `Proof.fst` 57 | 274 |
| proof: proof functions returning witnesses (17: `sim`, its 13 case and helper functions, `rep_mono`, `fuel_of`, `vm_complete`) | `ProofSem.fst` 28, `ProofSim.fst` 291, `Proof.fst` 23 | 342 |
| proof: auxiliary definitions (`code_at`, measure, `rv`, `cls`, `cget`, `capsrel`, `meq`, `gs`, `uniq`, `topg`, `npg`, `fresh`, `exe`, `simres`, `ih_t`, `re_pre`, `sem_of`) | all four | 87 |
| proof: the `rep` type, `open`s, options, module headers | all four | 65 |
| proof: the two counterexample `assert_norm`s | `Proof.fst` | 6 |
| **proof, total** | `ProofA.fst` 101, `ProofSem.fst` 100, `ProofSim.fst` 472, `Proof.fst` 101 | **774** |

Per file, the totals are `loc.py`'s spec + proof columns (`loc.txt`);
the split by kind is from `lemmas.py`'s per-item line counts
(`lemmas.txt`), since `loc.py`'s F\* rule counts a `let` as proof only
when a `Lemma`, `(requires` or `(ensures` appears on its first lines,
which splits the proof functions between its two columns (`loc.txt`:
`ProofSim.fst` 161 spec, 311 proof). Definitions went from 264 to 275
lines (`Statement.fst`: `groups`, `mem`, `nodup` and the hypothesis).
Proof-to-definitions ratio: 774 / 275 = 2.8 (Rocq 3.0, entry 11).

## Check time (`timed.sh fstar r7`, three clean full checks, pinned)

Per timed run, summed over the nine files (`time.tsv`):

| Timed run | wall clock | user | system | user + system | peak RSS |
|---|---:|---:|---:|---:|---:|
| 1 | 31.82 s | 30.65 s | 1.24 s | 31.89 s | 221,028 KB |
| 2 | 31.81 s | 30.69 s | 1.19 s | 31.88 s | 221,328 KB |
| 3 | 31.76 s | 30.67 s | 1.18 s | 31.85 s | 220,828 KB |
| **median** | **31.81 s** | | | **31.88 s** | |

Spread (max - min): 0.06 s wall clock, 0.04 s CPU. CPU time equals
wall clock (F\* and its Z3 process run one after the other). Peak RSS
is `ProofSim.fst`'s. Median per file:

| File | wall clock (median) |
|---|---:|
| `Syntax`, `Sem`, `Compile`, `Vm`, `Statement` | 0.46, 0.44, 0.32, 0.51, 0.30 s (2.03 s) |
| `ProofA.fst` | 1.49 s |
| `ProofSem.fst` | 1.58 s |
| `ProofSim.fst` | 25.64 s |
| `Proof.fst` | 1.08 s |
| proof files only | 29.79 s (runs 29.79 / 29.77 / 29.80 s) |

Load average before the checks: 1-minute value 0.83 at the first check,
at most 0.97 during the runs (`time.load`). The definitions check in
2.03 s here (1.97 s in entry 5, with the statement 11 lines shorter).
`ProofSim.fst` is 81% of the total; its SMT time is spread over the
case functions (entry 13, "SMT profile").

## Lemmas (`lemmas.py`, plan step 6's F\* definition)

| File | lemmas | automatic (body `()`) | proof functions (not lemmas) |
|---|---:|---:|---:|
| `ProofA.fst` | 14 | 1 (`code_lit`) | 0 |
| `ProofSem.fst` | 6 | 0 | 1 |
| `ProofSim.fst` | 16 | 2 (`exe_next`, `exe_fail1`) | 15 |
| `Proof.fst` | 7 | 0 | 1 |
| **total** | **43** | **3 (7%)** | **17** |

A lemma is automatic when its body is `()` with no explicit call to
another lemma. The other 40 bodies are mostly calls of the induction
hypothesis or of other lemmas (for instance `ct_mono`'s 18 lines are one
recursive call per case of `compute_tree`, and every `reveal_opaque`
lemma of `ProofSim.fst` has no other step), with the arithmetic, list
and unfolding steps left to Z3: `lemmas.txt` lists them. Counting the
17 proof functions as non-automatic items as well, the share is 3 of
60 (5%). Rocq: 0 of 48 (entry 11).

## Effort totals (F\* M2)

From [effort.tsv](../09-representative-proof/effort.tsv), run 7 rows:
one session (14:27:26Z to the end recorded there); proof compiles
14:37:22Z to 14:43:37Z; 21 compile invocations of the proof modules
(13 failing, 8 clean), of which **7 failed checks** (failures that led
to an edit); per item, 43 lemmas with 45 attempts and 17 proof functions
with 21 attempts, plus the auxiliary definition `code_at` with 2 (68 in
all, `effort.tsv`'s unit: a clean compile counts once per item it
contains); 1 statement change (2 files, 1 attempt); 3 scripts extended
(1 attempt each); human interventions 0; no person-days.

| Figure (correction 5's units) | Rocq M2 (run 4) | F\* M2 (run 7) |
|---|---:|---:|
| failed checks | 19 | 7 |
| compile invocations of the proof files | 23 | 21 |
| per-item attempts (`effort.tsv`) | 67 (48 lemmas) | 68 (43 lemmas, 17 proof functions, 1 definition) |
| proof compile window | under 9 min (bounded by other timestamps) | 6 min 15 s (recorded) |

## Analysis

- Done-criteria 1 and 3 are met for F\*; done-criterion 2 was met in
  run 2 (entry 5) and still holds (entry 13: no extracted definition
  changed). Done-criterion 4 (seeds and solver versions) is run 13.
- F\*'s figures for M4: definitions 275 lines, proof 774 lines (274
  lemma lines, 342 proof-function lines), full check 31.81 s median
  (CPU 31.88 s, proof files 29.79 s), 43 lemmas with 3 automatic (7%),
  plus 17 proof functions; 1 session, 7 failed checks, 0 interventions.
- Against Rocq on the same invariants: fewer proof lines (774 / 872)
  and fewer failed checks (7 / 19), but a check about 5 times slower
  (31.8 s / 6.5 s), almost all of it SMT time in the simulation's case
  functions. Both proofs were written by a model in one session from
  the same `FRAGMENT.md` design, F\* second, with Rocq's proof as a
  model of the invariants, so the effort figures are not independent
  (stated in M4).
