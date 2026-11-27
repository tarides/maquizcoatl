# Experiment #8 follow-up (issue #34), entry 12: termination of the direct matcher (run 5)

**What.** Run 5 of plan `plans/08-discriminating-lemmas.md`, its reserve
run, used for decision 8 of issue #34, answered (a). In both tools it
proves that the direct matcher `m` terminates on every in-scope pattern
(`m_term`). From that and direction (2a) of `absent_desugar_eq`, it
proves lemma 2 without its condition (`absent_desugar_total`): at every
start with `i <= rr <= length s`, `m` and `md` on the desugared tree
both return complete results with the same list of ends. Both proofs
closed. The run then redid the measurements of runs 2-4 on the changed
sources:
- `axioms.sh` for both tools;
- `timed.sh` for both tools, plus Verus without the cases file;
- `loc.py` and `lemmas.py`;
- the Verus brittleness matrix, under a new run id (`r5`).

**Why.** The PR review of PR #40
([entry 11](2026-11-26-exp-08-lemmas-pr-review.md), problem 1) found that
lemma 2 was conditional. Both directions assumed that one side had
returned `Some`, so at a start where both matchers run out of fuel at
every fuel, the theorem held vacuously. Only the 29 cases showed that it
was not vacuous. Decision 8 (issue body, answered (a)) asks for one
termination lemma in each tool and a new axioms check, in run 5. The
plan's stop rule allows run 5 as a second proof run for each tool. This
is the first proof run after run 2 for Rocq and after run 3 for Verus.

## Provenance

- Branch `exp/08-discriminating-lemmas`. The proofs are commit `9b54ef0`
  (parent `6005b04`). That commit changes `rocq/AbsentProof.v`,
  `verus/absent_proof.rs` and `axioms.sh`; `axioms.sh` gains the two
  `Print Assumptions` targets. Every other source is unchanged since
  entries 4 and 6.
- New source hashes are in the raw `rocq/sha256.txt` and
  `verus/sha256.txt`. The sources measured earlier keep the hashes
  recorded in entries 4 and 6.
  - `AbsentProof.v`: `f2d597ec442f0b1d52f5aad8c6f8ba722f1efadccc4b795f455b0781a47c039f`.
  - `absent_proof.rs`: `623a68f366744957ecb7b1ca51d7d5714683e4ee48a2601b4c08b9c63de4c5ae`.
- Bench host: the run-1 pins (entry 1), unchanged. Rocq 9.3.0 (OCaml
  5.4.1, switch `provers`); Verus 0.2026.11.02.8bf68ee, with Z3 4.16.0
  bundled; Z3 5.3.0 and 4.15.3 from the F\* 2026.11.15 release. AMD EPYC
  7502P.
- Timed checks: CPUs 24-27,56-59, one at a time under
  `flock <exp>/timed.lock`. Before each one, `ps -eLo user,psr,pcpu,comm`
  showed no thread above 1% on those CPUs, and the load average was
  recorded (`precheck.txt`). Untimed work ran under `nice -n 10` on CPUs
  8-11.
- Disk: 41 GB free before the timed checks and before the matrix (floor
  20 GB).
- Drivers, in the run-5 work directory on the bench host, copied to the
  raw data:
  - `drive-r5.sh`: run 4's `drive.sh` with run id `r5`, the two
    `timed.sh` series first, and no refusal cell (recorded once in run 4);
  - `timed-nocases-r5.sh`: the no-cases Verus series under `timed.sh`'s
    conditions, as entry 7 describes for run 3;
  - `rchk.sh` and `vchk.sh`: the logged development checks. `vchk.sh` is
    run 3's, with its build and output directories taken from the
    environment.
- Session: first bench-host command 2026-11-26T19:13:49Z; end 2026-11-26T19:54:57Z (before the run-5 notebook commit).

Raw data are in [`2026-11-26-exp-08-lemmas-termination-raw/`](2026-11-26-exp-08-lemmas-termination-raw/):
- `dev/`: `invocations.tsv` and one log per development check;
- `rocq/` and `verus/`: `axioms.txt`, `time.*`, `loc.txt`, `lemmas.txt`
  and `sha256.txt`;
- `verus-nocases/`;
- `brittle/`: `checks.tsv`, `functions.tsv`, `precheck.txt`,
  `drive.log`, `shares.txt` and the per-cell logs as `logs.tar.xz`;
- `drivers/`.

## The proofs

**Statements.** Both are stated the same way in Rocq and Verus. Verus
writes `exists` in `ensures`, and "is Some" for Rocq's `= Some l`.

    Theorem m_term : forall s r i rr, in_scope r = true -> i <= rr -> rr <= length s ->
      exists g f l, m s g f [R r] i rr = Some l.

    Theorem absent_desugar_total : forall s r i rr, in_scope r = true -> i <= rr -> rr <= length s ->
      exists g f l f' rs, m s g f [R r] i rr = Some l
        /\ md s f' [DR (fst (desugar r 0))] i rr [] = Some (rs, rr) /\ ends rs = l.

`absent_desugar_eq` is unchanged. `absent_desugar_total` is `m_term`
followed by direction (2a).

**Induction** (`m_term_stack`, shared design in `LEMMAS.md`,
"Termination").
- **Item stacks.** In-scope `R` and `Chk` items, and `SetRR k` items
  with `k <= max q (length s)`; the register is also at most
  `max q (length s)`. An `Ends` item appears only at the top, where it
  is handled by `ends_term` (Rocq) or `m_ends_b` (Verus).
- **Measure.** `(length s - q, tmu ks q)`, lexicographically. This is
  `term_core`'s measure, with the first component taken against the
  subject length instead of the register, since the register changes. An
  `AbsExp a e` weighs `2 + size e`.
- **Absent constructs.**
  - The cut exists at some inner fuel (`cut_term`), and lies between the
    position and the register (`scan_ge`, plus the new `scan_le`).
  - `AbsRep`'s ends either stay at `q`, on the rest of the stack, or move
    forward. A forward end is at most the cut, hence at most the
    register and `length s`.
  - Fuels are merged by `m_mono` and `cut_mono` in Rocq, and by
    `mmax`/`mmax_ok` in Verus (already used by `sim_b_rep`).

**Reused:** `cut_term`, `scan_ge`, `downs_mem`/`mem_downs`, `m_mono`,
`cut_mono`, `m_absrep_eq`/`m_absexp_eq`/`m_stopper_eq` (Rocq), and
`mterm`/`mmax_ok`/`m_ends_b` (Verus). `mb_term` and `term_core` are used
through `cut_term`.

**New lemmas (9 per tool).**
- Rocq: `tsz_pos`, `toks_mono`, `at_len`, `scan_le`, `ends_term`,
  `oapp_term`, `m_term_stack`, `m_term`, `absent_desugar_total`.
- Verus: `tsz_pos`, `toks_mono`, `nth_len`, `at_len`, `scan_le`,
  `cut_bounds`, `m_term_stack` (returns its fuels), `m_term`,
  `absent_desugar_total`.

**Development** (`dev/invocations.tsv`).
- **Rocq: 5 logged compiles, 4 failing, all tactic-script errors.**
  - A duplicated `rewrite` in the `Star` case.
  - A `rewrite` on a hypothesis that was already reduced.
  - Twice, `lia` on a weight that `simpl` had not unfolded (`tw` in the
    `Chk` case).

  One more untimed compile, outside the logger, printed that goal. It is
  a read, so it is not counted as a failed check (entry 5's convention).
  Window 19:16:24Z-19:17:28Z.
- **Verus: 2 checks, 0 failing.**
  - The module checked at the first attempt (104 verified, 19:19:01Z).
  - One explicit trigger was then added to a `choose` to silence a
    low-confidence note, and the full crate checked: 191 verified,
    19:19:22Z.

## Done-criterion 1 (axioms)

- **Rocq** (`rocq/axioms.txt`). `Print Assumptions` of `sharp_s_sym`,
  `absent_desugar_eq`, `m_term` and `absent_desugar_total`: "Closed
  under the global context" for each. The scan is empty.
- **Verus** (`verus/axioms.txt`). `191 verified, 0 errors`, plain and
  with `--no-cheating` (exit 0 both). The scan is empty.

## Figures beside runs 2-4

| | Rocq runs 2-4 | Rocq run 5 | Verus runs 2-4 | Verus run 5 |
|---|---:|---:|---:|---:|
| proof lines (proof files) | 1,222 | 1,361 (+139) | 2,142 | 2,336 (+194) |
| auxiliary spec in the proof files | 84 | 100 | 166 | 188 |
| lemmas (proof files) | 105 | 114 | 99 (24 returning) | 108 (25 returning) |
| automatic | 0 | 0 | 4 | 5 (`tsz_pos`) |
| full check, median of 3 | 11.19 s (11.17-11.20) | 12.29 s (12.28-12.30) | 33.01 s (with cases) | 33.08 s (32.96-33.21) |
| CPU (user + system), median | 11.15 s | 12.26 s | - | 43.61 s |
| without the cases file (Verus) | - | - | 13.72 s | 11.88 s (11.71-11.94; CPU 13.23 s) |
| peak RSS, median | - | 513,220 KB (`AbsentProof.v`) | 519,376 KB (no cases) | 547,384 KB (with cases); 529,356 KB (no cases) |
| verified | - | - | 179 | 191 |
| failed checks in the proof run | 27 (run 2) | 4 | 9 (run 3) | 0 |

Sources:
- runs 2-4: entries 4, 5, 6 and 7; the Rocq time is entry 5's
  correction;
- run 5: `rocq/` and `verus/` `time.tsv`, `loc.txt`, `lemmas.txt`. Line
  and lemma counts are over `FoldProof`, `AbsentMono` and
  `AbsentProof`, as in entries 4 and 6.
- `lemmas.py` is the version fixed by entry 11, so the Verus automatic
  count needs no hand correction.

## Verus brittleness, rerun (run id `r5`)

Seven passes of experiment #9's run-14 matrix: Z3 4.16.0 (bundled),
then 5.3.0 and 4.15.3 through `VERUS_Z3_PATH` and
`-V no-solver-version-check` (unsupported). Each version ran with the
default seed and `smt.random_seed` 1-10, under the default rlimit, on 7
threads, pinned, one check at a time. `brittle.sh` and `shares.py` are
run 4's, unchanged.
- Window: cells started 19:24:26Z-19:45:23Z, driver done 19:45:58Z; the 33 cells, then 19:47:17Z-19:53:02Z
  for the replications.
- Every cell checked the committed sources: `sha256_sources`
  `03f76b0b…` in all 41 rows.
- The Z3 started was the one selected in every cell (`z3_version` =
  `z3_started`).

**25 of 33 pass. Every failure is an rlimit failure, and all 8 failing
cells failed again, identically, in a labelled replication (`rep1`).**
No cell was retried away.

| Z3 | pass | failing cells (function) | function checks over 10% / 25% / 50% | highest share of a passing function |
|---|---:|---|---:|---|
| 4.16.0 (supported) | 9 / 11 | seeds 9, 10 (`m_term_stack`) | 35 / 11 / 6 of 2,101 | 0.905 (`term_core`, seed 1); `m_term_stack` 0.899 (seed 7) |
| 5.3.0 | 8 / 11 | seeds 1, 10 (`m_term_stack`); seed 3 (`sim_a`) | 67 / 41 / 13 of 2,101 | 0.988 (`sim_a`, seed 6) |
| 4.15.3 | 8 / 11 | seeds 2, 6, 9 (`m_term_stack`) | 32 / 12 / 7 of 2,101 | 0.749 (`term_core`, seed 1) |

Share of the limit per seed (default, 1..10; from `shares.txt`):

| Function | Z3 | default | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `m_term_stack` (new) | 4.16.0 | .150 | .558 | .133 | .204 | .148 | .111 | .191 | .899 | .232 | **1.000** | **1.000** |
| | 5.3.0 | .817 | **1.000** | .718 | .115 | .121 | .207 | .111 | .226 | .983 | .470 | **1.000** |
| | 4.15.3 | .563 | .204 | **1.000** | .115 | .164 | .203 | **1.000** | .176 | .148 | **1.000** | .204 |
| `term_core` (unchanged) | 4.16.0 | .064 | .905 | .292 | .347 | .152 | .472 | .146 | .120 | .155 | .237 | .532 |
| | 5.3.0 | .214 | .606 | .295 | .299 | .059 | .211 | .066 | .547 | .328 | .047 | .390 |
| | 4.15.3 | .181 | .749 | .724 | .263 | .091 | .657 | .171 | .120 | .048 | .400 | .319 |
| `sim_a` (unchanged) | 4.16.0 | .025 | .026 | .033 | .026 | .052 | .444 | .085 | .101 | .385 | .026 | .051 |
| | 5.3.0 | .087 | .162 | .103 | **1.000** | .102 | .137 | .988 | .045 | .684 | .093 | .680 |
| | 4.15.3 | .117 | .239 | .117 | .036 | .036 | .096 | .026 | .142 | .199 | .348 | .291 |
| `sharp_s_sym` (lemma F) | all | .010 in every cell | | | | | | | | | | |

Wall clock per cell: median 33.21 s under 4.16.0, 39.58 s under 5.3.0
(33.28-67.30 s), and 33.23 s under 4.15.3.

**Analysis.**
- **`m_term_stack` is the most brittle function of the crate.** It
  passes with the default seed under the supported Z3, at 15.0% of the
  limit, which is what the axioms and timed checks ran. It exceeds the
  limit at 2 of 11 seeds under 4.16.0, and at 5 of the 22 unsupported
  cells.
  - Like `sim_b` in run 3, it is one large case analysis: 15 match
    arms, one of them (`AbsRep`) with recursive calls inside an
    `assert forall`.
  - The plan's first remedy is a split into smaller `proof fn`s
    (plan, "Risks"). It was not applied in this run: the matrix measures
    the crate as written, and a split would be a new crate with its own
    matrix. That choice is left to the maintainer (the progress comment
    on issue #34).
- **Unchanged functions moved.** `term_core` and `sim_a` are textually
  unchanged, yet their shares moved:
  - `term_core` under 4.16.0: at most .905 now, .639 in run 4;
  - `sim_a` under 5.3.0: now fails at seed 3 and passes at the default
    seed and seed 10, the two seeds that failed in run 4.

  Adding definitions and lemmas to the module (`tsz`, `tmu`, `toks`)
  changes the context of every function of `absent_proof`. That is the
  likely cause of the shift, but it is unverified. Comparing the SMT
  queries of the two crates for `term_core` (Verus's `--log-smt`) would
  settle it. So the per-function margins of run
  4 do not carry over to a changed module, even for code that did not
  change. This is experiment #9's sensitivity to the solver's seed,
  extended to the content of the module.
- **The no-cases timing (11.88 s) is below run 3's 13.72 s**, although
  the crate grew. The single-seed default path differs between the two
  crates. At the default seed under 4.16.0, the summed per-function SMT
  time is 8,399 ms in run 5, against 10,591 ms in run 4
  (`functions.tsv`, `time_ms`): a 2.2 s difference, of the same order as the 1.84 s drop.
  `term_core`'s share dropped from .407 to .064. The with-cases median is unchanged (33.08 s against
  33.01 s), because the 29 `compute_only` cases dominate it.

## Comparison update

Entry 9's table (experiment #9's columns) changes in these rows. The
other rows stand.

- **Done-criterion 1.**
  - Rocq: add `m_term` and `absent_desugar_total`, both closed under
    the global context.
  - Verus: 191 verified, 0 errors, plain and with `--no-cheating`.
- **Proof** lines: Rocq 1,361, Verus 2,336. "Of which lemma 2", now with
  termination: Rocq 1,271, Verus 2,135.
- **Lemmas** and automatic share: Rocq 114 (0 automatic), Verus 108
  (5 automatic, 25 returning witnesses).
- **Full check:**
  - Rocq 12.29 s (CPU 12.26 s);
  - Verus without cases 11.88 s (CPU 13.23 s), against run 3's 13.72 s (see the analysis below);
  - Verus with cases 33.08 s.
- **Effort.** The proof runs used are now 2 of 2 for each tool (runs 2
  and 5 for Rocq, runs 3 and 5 for Verus). Run 5 added 4 Rocq failed
  checks and 0 Verus failed checks. That makes 31 and 9 in total for
  this follow-up, with 34 and 13 failing invocations.
- **Brittleness:** 25 of 33, not 31 of 33. Under the supported Z3
  4.16.0, 9 of 11 pass: `m_term_stack` fails at seeds 9 and 10, so the
  highest share there is 1.000, not 63.9%. Under 5.3.0, 8 of 11 pass;
  under 4.15.3, 8 of 11. Function checks above 10% are 35 / 67 / 32 of
  2,101, against 15 / 37 / 17 of 1,969. All 8 failures are
  deterministic (replicated).
- **Limits.** "Termination is not proved" (entry 11) is withdrawn. Lemma
  2 is unconditional at every start with `i <= rr <= length s`.
  Termination of `md` is proved only through direction (2a), so only on
  desugared in-scope patterns. Fuel adequacy is still not covered.

**Verdict update.** Entry 9's lemma verdict stands, and is now sharper.
Lemma 2 is where the tools differ, and termination adds to the
difference:
- **Rocq:** 139 proof lines and 4 failed checks, closed in one compile
  window of about one minute.
- **Verus:** 194 lines, closed at the first check. The new function is
  also the crate's first to fail under the supported solver: 2 of 11
  seeds, against none in run 4 and in experiment #9.

Entry 9's per-tool verdict for Verus ("on a proof of this size, Verus's
default limit is no longer wide") now applies under the supported
solver too.

## Effort

`effort.tsv`, run 5:
- the proofs: Rocq 6 attempts, Verus 2;
- axioms, timed, no-cases and matrix runs: drivers written for this run,
  each run once;
- session wall clock: first bench-host command 19:13:49Z to 2026-11-26T19:54:57Z.

No human intervention.

_Drafted by Claude Code (Opus 5.5) as part of the experiment pipeline._
