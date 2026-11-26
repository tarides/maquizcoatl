# Experiment #8 follow-up (issue #34), entry 6: Verus proofs (run 3)

**What.** Run 3 of plan `plans/08-discriminating-lemmas.md`: the Verus
transcription of the definitions (changes C1-C6, the desugaring, the
state-threaded matcher), agreement on the 29-case corpus by
`compute_only`, the Verus proofs of both lemmas, the range clear and
the decision-6 stretch, and experiment #9's measurements (`axioms.sh
verus` plain and `--no-cheating`, `timed.sh verus`, `loc.py`,
`lemmas.py`). Result: the crate checks with `179 verified, 0 errors`,
also under `--no-cheating`, and the scan finds nothing. Closed:
`sharp_s_sym` (lemma F, F1 and F2, fuel `f >= 7`), `absent_desugar_eq`
(lemma 2, (2a) and (2b), for `AbsRep`, `AbsExp` on both paths, the
stopper and the range clear, under `i <= rr <= len(s)`), and the stretch
`fold_lit`. C, `m` and `md` agree on all 29 cases, and `m` and `md` give
the same list of ends at every start. One SMT failure was recorded: the
first version of `sim_b` (direction (2b) in one function) exceeded the
default rlimit. Splitting it into smaller functions fixed it, as the
plan's first remedy prescribes. No `rlimit` attribute is used.

**Why.** Run 3's done-when: "`0 errors`, `--no-cheating` clean, scan
clean; measurement entry". Decision 1 makes experiment #9's units the
measure. Decision 4 requires the agreement on the corpus before the
proofs: `compute_only`, not `compute`, so that Z3 cannot stand in for
the interpreter. Decision 2 asks for the range clear, proved or named
out. Decision 6 asks for the stretch outcome. The experiment's question
is where SMT automation breaks on these proofs.

**Provenance.** See [entry 1](2026-11-26-exp-08-lemmas-provenance.md)
for the host, the CPU sets and the toolchain. Verus is
0.2026.11.02.8bf68ee (release profile, Rust 1.99.1) with its bundled
Z3 4.16.0 ([`version.txt`](2026-11-26-exp-08-lemmas-verus-raw/verus/version.txt)).
Sources are at branch commit `2242606`, with their SHA-256 in
[`sha256.txt`](2026-11-26-exp-08-lemmas-verus-raw/sha256.txt). The
session started at 2026-11-26T15:30:31Z. The proofs were written
interactively on the bench host with `dev/vchk.sh` (`verus
--crate-type=lib --num-threads 4 lib.rs [--verify-module <m>]`, `nice
-n 10`, `taskset -c 8-11`, one job). Every invocation is logged in
[`invocations.tsv`](2026-11-26-exp-08-lemmas-verus-raw/invocations.tsv)
(UTC, rc, SHA-256 of the target file and of all sources, first error
line). Measurement commands, run on `<exp>/repo` at `2242606`:

    BENCH_WORKDIR=<bench-workdir> axioms.sh verus r3                       # untimed, CPUs 8-11
    flock <exp>/timed.lock env CPUS=24-27,56-59 timed.sh verus r3           # timed
    python3 -I loc.py fold.rs absent.rs desugar.rs fold_proof.rs absent_mono.rs absent_proof.rs cases.rs lib.rs
    python3 -I lemmas.py fold_proof.rs absent_mono.rs absent_proof.rs

All four commands exit with status 0. Before the timed series, no
thread was above 1% on CPUs 24-27,56-59, and the load average was 2.05
(1-minute, rising from this session's own untimed checks; 0.99 over 5
minutes) ([`precheck.txt`](2026-11-26-exp-08-lemmas-verus-raw/verus/precheck.txt)).
During the series the load average was 1.5-1.9.
Raw data: [raw](2026-11-26-exp-08-lemmas-verus-raw/).

## Agreement on the corpus (criterion 2, Verus)

`cases.rs` transcribes `rocq/Cases.v`: one `proof fn abNN` per case,
each one `assert(agree(p, s, SRes::Match(st, e))) by (compute_only)` at
fuels `fuel_g() = fuel_f() = 1000`. `agree` checks three things. The
direct `search` and the desugared `dsearch` each equal the C result,
which is the same on the Debug and ASan builds
([entry 2](2026-11-26-exp-08-lemmas-cases.md)). And `m` and `md` give
the same complete list of ends at every start. All 29 cases pass, from
the first check of the definitions onward (15:34:20Z, `rc=0`, no change
to any definition needed). The case table is therefore entry 2's,
with a Verus column that agrees on every row:

| Cases | C Debug | C ASan | `m` (Verus) | `md` (Verus) | lists of ends |
|-------|---------|--------|-------------|--------------|---------------|
| ab01-ab11 (experiment #8) | as entry 2 | = | = | = | equal at every start |
| ab12-ab29 (restore cases) | as entry 2 | = | = | = | equal at every start |

## Lemmas closed

| Plan item | Verus | File | Status |
|-----------|-------|------|--------|
| Lemma F (F1, F2), fuel `f >= 7` in `requires` | `sharp_s_sym` | `fold_proof.rs` | closed |
| Stretch (decision 6): one-level fold for every literal | `fold_lit` (+ `segs_m`, `seg_alts`) | `fold_proof.rs` | closed |
| (b) monotonicity, determinism of `mb`, `scan`/`cut`, `m` (both fuels), `md` | `mb_mono`, `scan_mono`, `cut_mono`, `m_mono`, `md_mono`, `*_det` | `absent_mono.rs` | closed |
| (a)/(c) absent-free stack + engine continuation; termination | `core_k`, `term_core`, `mb_term`, `attempt`, `attempt_inv` | `absent_proof.rs` | closed |
| (d) scan for a general step (`DAnyO`, `DChr c`) | `scan_a`, `scan_b` | `absent_proof.rs` | closed |
| direct side: cut, `Ends`, `x*` | `scan_spec`, `scan_intro`, `cut_top`, `m_ends_a/b`, `mstar_a/b`, `cut_term` | `absent_proof.rs` | closed |
| (e) `AbsExp` general path, (f) stopper, (h) range clear | `sim_a_gen`, `sim_a_stop`, `sim_b_gen`, `sim_b_stop`, cases of `sim_a`/`sim_b` | `absent_proof.rs` | closed |
| (d) on the simple path | `sim_a_rep`, `sim_a_xs`, `sim_b_rep`, `sim_b_xs` | `absent_proof.rs` | closed |
| (g) main theorem | `sim_a` (2a), `sim_b` (2b), `absent_desugar_eq` | `absent_proof.rs` | closed |

Statements match Rocq's. `sharp_s_sym` states F1 as `memn(i + 2, m(s,
f, [R (ILit [223])], i)) <==> exists a b. nth(s, i) == Some(a) && nth(s,
i + 1) == Some(b) && is_ss(a, b)`, and F2 for every spelling. Under
`in_scope(r)` and `i <= rr <= len(s)`, `absent_desugar_eq` states
(2a): for every `g, f` with `m` complete, there are `f2, rs` with
`md(f2, ...) == Some((rs, rr))` and `ends(rs)` equal to `m`'s list. It
states (2b): for every `f2` with `md` complete, the final register is
`rr` and some `g, f` make `m` equal `ends(rs)`. As in Rocq, the
statement carries the register hypothesis `rr <= len(s)` that run 2
added. The constant `fuel()` of `fold.rs` appears in no statement or
proof; the only other `1000`s are the case fuels of `cases.rs`.

**Range clear (decision 2): proved, in scope in Verus too.** It needs
four helper lemmas (`rclear_unfold` 23 lines, `rrinit_eq` 11,
`rclear_intro` 11, `rclear_inv` 32) and one case in each direction (6
and 7 lines). That is about 90 lines in all, against about 47 in Rocq.

**Stretch (decision 6): closed.** `fold_lit`: for every `w`, `s`, `i`,
`e` and `f` with `cost(unravel(w)) <= f`, `memn(e, m(s, f + 1, [R (ILit
w)], i)) <==> fold_rel(s, i, unravel(w), e)`. Rocq's inductive
`fold_rel` is a recursive spec fn with an existential. The bound is
Rocq's (alternatives plus 2; `cost_df`: 6, so fuel 7 for `[0xDF]`). It
checked on the first attempt.

**Encoding differences from the Rocq proof (same statements).**
- Rocq's `Forall2` over the ends of a scan is replaced. Fuel
  monotonicity gives one fuel for every end, and the results at that
  fuel are concatenated (`dcat`, `mcat`).
- The per-end fuels that the induction hypothesis returns are merged
  with `choose` and a maximum over the range (`dfuel`/`dmax`,
  `mfuel`/`mmax`).
- Rocq's step predicate and register function `h` become a `DRe` (`stp`)
  and an `Option<nat>` (`hh`).
- Rocq's inductive `rel` becomes a recursive spec fn that takes the ids
  of each item as a list `ns`.
- Rocq's `dseq` lists are written as the nested `DSeq` they unfold to
  (`ds2`, `ds3`, `ds4`).

## Axiom report (`axioms.sh verus`)

[`axioms.txt`](2026-11-26-exp-08-lemmas-verus-raw/verus/axioms.txt):

    == verus --crate-type=lib --num-threads 4  lib.rs                 verification results:: 179 verified, 0 errors / exit code 0
    == verus --crate-type=lib --num-threads 4 --no-cheating lib.rs    verification results:: 179 verified, 0 errors / exit code 0
    == scan (assume|admit|external_body|verifier::external|assume_specification|exec_allows_no_decreases_clause|no_verify|rlimit) ...
    == end of scan                                                    (no hit)

The 179 items include the 29 `compute_only` case checks and
experiment #8's unchanged `fold.rs`, with its own `sharp_s` and
`cases()` at `fuel()`.

## Check time (`timed.sh verus`, CPUs 24-27,56-59, `--num-threads 7`, three clean full checks)

| Timed run | wall clock | user | system | peak RSS (KB) |
|---|---:|---:|---:|---:|
| 1 | 33.01 s | 44.73 s | 0.89 s | 535,148 |
| 2 | 32.96 s | 44.84 s | 0.90 s | 534,188 |
| 3 | 33.05 s | 44.83 s | 0.89 s | 535,160 |
| **median** | **33.01 s** | 44.83 s | 0.89 s | |

The spread is 0.09 s wall clock. `timed.sh` as adapted in run 1 checks
the whole crate, `cases.rs` included. The Rocq figure of run 2 (11.19 s)
excludes `Cases.v` (`ROCQ_FILES` default), so the two are not like for
like.

**Supplementary (by hand, same conditions as `timed.sh`).** The same
three checks were run on the crate without `pub mod cases;`: `flock`,
`taskset -c 24-27,56-59`, `--num-threads 7`, `/usr/bin/time -v`,
16 GB cgroup, load average recorded, and no busy thread on the pinned
CPUs. They took 13.72, 13.74 and 13.65 s, median **13.72 s** (user
14.25 s, system 0.83 s, peak RSS 519,380 KB), `147 verified`
([`verus-nocases/`](2026-11-26-exp-08-lemmas-verus-raw/verus-nocases/)).
That figure is like for like with Rocq's 11.19 s. Removing the cases
also implies that the 29 `compute_only` cases take about 19 s.
Neither figure is chosen here; run 4's comparison should state which
one it uses.

## Size (`loc.py`) and lemmas (`lemmas.py`)

| File | Origin | Spec | Proof | Cases |
|------|--------|------|-------|-------|
| fold.rs | experiment #8, unchanged | 96 | 5 | 13 |
| absent.rs | experiment #8 with C1-C6 | 133 | 33 | 0 |
| desugar.rs | new definitions (run 3) | 125 | 0 | 0 |
| cases.rs | run 3 | 46 | 0 | 117 |
| lib.rs | crate root | 7 | 0 | 0 |
| fold_proof.rs | run 3 | 32 | 201 | 0 |
| absent_mono.rs | run 3 | 4 | 164 | 0 |
| absent_proof.rs | run 3 | 130 | 1777 | 0 |

Run 3 wrote 2142 proof lines: lemma F and the stretch 201, lemma 2 1941
(monotonicity 164, the rest 1777). It also wrote 166 spec lines of
auxiliary definitions (`core`, `in_scope`, `rel`, the measure, `dcat`,
`mcat`, the fuel maxima, `fold_rel`). Rocq needed 1222 proof lines.
[`loc.txt`](2026-11-26-exp-08-lemmas-verus-raw/loc.txt).

`lemmas.py` counts 99 lemmas (12 in `fold_proof.rs`, 8 in
`absent_mono.rs`, 79 in `absent_proof.rs`), 24 of which return a
witness (`returns`). Three are automatic (`rsz_pos`, `at_lt`,
`downs_hd`, empty bodies), and none is admitted. That is an automatic
share of 3%, against Rocq's 0 of 105. `step_eq` also has an empty body
(`{ }`) but the script counts it as manual. The figure is reported as
the script gives it. The largest bodies are `sim_a` (101 lines), `sim_b`
(80), `sharp_s_sym` (65) and `sim_b_xs` (56).
[`lemmas.txt`](2026-11-26-exp-08-lemmas-verus-raw/lemmas.txt).

## Effort

| Measure | Value |
|---------|-------|
| Session | start 15:30:31Z; first proof check 15:36:30Z, last 15:56:35Z (20 min 05 s); measurements 15:59Z-16:02Z; end at this entry's commit |
| Check invocations | 25: 12 passing, 13 failing |
| Failing invocations | 13 (`fold_proof` 1, `absent_mono` 1, `absent_proof` 11) |
| Failed checks | 9: the failing invocations less the 4 rejected before verification (a parse error on `->0.1`, a `let` variable in a trigger, a field projection `->t`, a trigger Verus could not infer) |
| Per-lemma attempts | `lab/08-discriminating-lemmas/effort.tsv`, run-3 rows |
| Human interventions | none |

The 9 verification failures:
- 7 were missing unfoldings: a recursive spec fn needed fuel 2 or 3
  (`embs`, `core_items`, `mu`, `lookup`, `ends`, `downs`, `dcat`,
  `mcat`), added with `reveal_with_fuel` or an intermediate `assert`.
- 1 was a fuel off by one in a precondition (`m_seg` needs
  `len(alts) + 1`, not `+ 2`).
- 1 was the rlimit failure below.

No lemma statement was weakened after a failure.

**Where SMT automation broke.** The first `sim_b` held all of direction
(2b) in one function, with every constructor as a case. It failed with
"function body check: resource limit (rlimit) exceeded" at the default
rlimit (15:54:42Z, [`dev/sim_b-unsplit-rlimit.log`](2026-11-26-exp-08-lemmas-verus-raw/dev/sim_b-unsplit-rlimit.log)).
`sim_a`, built the same way, passed. Moving the `Alt` and `Star` cases
of `sim_b` into their own functions (`sim_b_alt`, `sim_b_star`) made it
pass at the next check. The absent constructs had been split from the
start, as mutually recursive functions with lexicographic `decreases
f, 0/1`. This is the plan's first remedy; no `rlimit` attribute was
added. The rlimit shares per function (brittleness, run 4) are not
measured in this run.

## Analysis and limits

- Verus closed both lemmas and the stretch in one run. That took 26
  minutes from session start to the last proof check (22 minutes from
  the first definition check), of which 20 minutes were proof checks. Rocq's run 2 took 55 minutes of proof
  compiles. The Verus proofs transcribe Rocq's lemma structure, which
  run 2 had already found, so this is not a fresh-design comparison.
  Run 4 should say so.
- Verus needed more lines (2142 proof lines against 1222). Most of the
  extra lines are explicit unfoldings. The SMT solver does not unfold
  `md` more than one level by itself, so every unfolding step of the
  desugared trees (`simple_unfold`, `gen_unfold`, `rclear_unfold`,
  `tail_unfold`) and every two-level list equation is an `assert`.
- Automation broke once, on size rather than difficulty: one function
  of about 15 cases exceeded the default rlimit, and splitting it fixed
  the failure. The margins (rlimit shares) of the passing functions are
  run 4's measurement.
- What the theorem does not cover is the same as in Rocq:
  - faithfulness of `md` to the C library beyond the 29 first matches
    (decision 4);
  - fuel adequacy (decision 3);
  - nested absent constructs;
  - registers above the subject length;
  - on the simple path, the dispatch rests on reading
    `upstream/src/regparse.c:3194-3236`, not on a C case.

_Drafted by Claude Code (Opus 5.5) as part of the experiment pipeline._
