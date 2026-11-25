# Experiment #9, entry 23: M4, comparison of Rocq, F\* and Verus (run 15)

**What.** The comparison of plan step 8 (M4) across the three tools the
maintainer selected (decision 1 of issue #4): Rocq (stack A), F\* +
Pulse (stack C, here total F\*) and Verus (stack D). One table per
measure (done-criteria 1 to 4 and the effort of the Cost section), the
limits that apply to all three, and a short verdict per tool. No prover
was run in this run: every figure is copied from, or recomputed on the
workstation from, the entries and raw files already on the branch, and
each row names its source. Where a later correction changes an earlier
entry's figure, the correction's figure is used and the row says so.

**Why.** Done-criterion 5 ("a comparison table across the tools, with a
short verdict on each, posted on this issue"), planned notebook entry 7,
and the input to the stack choice (stacks A to G in the maintainer's
[state-of-the-art report](https://claude.ai/artifact/8w6PVuiTsLCKpugpCowMHc),
"Experiments before deciding", rows #9 and #10). The plan posts the
table on issue #4 only after the maintainer's review, so this entry
holds the full table and the derivations; the issue comment drafted from
it is not posted by this run.

## Provenance

- Local worktree of branch `exp/09-representative-proof` at `88fbc04`
  (correction 9, the last commit before this run). No bench-host work,
  no prover, no timed or untimed check.
- Recomputed on the workstation (Python 3.14.4, `python3 -I`, stdlib
  only): `loc.py` on the 28 definition and proof files; the Verus
  definition files split at their `// ---- exec` marker (entry 7's
  method); `lemmas.py` on the twelve proof files (output equal to the
  committed `lemmas.txt` of entries 11, 14 and 17 except for the path
  prefix, since it was run from the parent directory); attempts and
  session windows from `effort.tsv`; brittleness pass counts, medians
  and margins from run 13's `querystats.tsv.xz`, correction 8's
  `checks.tsv`, and run 14's `checks.tsv` and `functions.tsv`. Every
  recomputed figure equals the one its entry reports.
- Sources read in full: the plan (`plans/09-representative-proof.md`),
  issue #4's body (decisions 1-7) and its comments (run reports,
  automated reviews of runs 1, 2, 3, 4, 7, 10, 13, 14 and the fix
  comments), entries 1-22 with their raw directories, `effort.tsv` and
  `FRAGMENT.md`.

## Caveats that apply to every effort and size figure

- **One sample per tool, not independent.** Each proof was written by
  the same model (Claude Code, Opus 5.5) in one session, from the same
  shared design (`FRAGMENT.md`), in the order Rocq (run 4), F\* (run 7),
  Verus (run 10), each later tool with the earlier proofs as a model of
  the invariants (entries 14 and 17 say so). The figures measure this
  sequence, not three independent efforts, and person-days do not apply
  (no human wrote proof).
- **Session windows** are those recorded in `effort.tsv`: they cover the
  work, the bench runs and the notebook entries, not the commit, issue
  comment, push and dashboard update; several starts are "no later than"
  the first recorded timestamp. The automated reviews' own time is not
  recorded and not counted.
- **Shared work sits in one tool's row.** Run 1 (Rocq M1) also did M0:
  `FRAGMENT.md`, the case selection, the C oracle and the provenance,
  used by all three tools. Run 7 (F\* M2) also transcribed decision 5
  into the Verus statement.

## 1. Proof effort (Cost section of issue #4; plan step 8's units)

| Figure | Unit | Rocq | F\* | Verus | Source |
|---|---|---:|---:|---:|---|
| M1 session (definitions, driver, agreement) | wall clock | at least 15 min 36 s (includes M0) | 4 min 37 s | 12 min 54 s | `effort.tsv` runs 1 (amended in correction 1), 2, 3 |
| M2 session (lemmas (a)-(e), axioms, measurements) | wall clock | 25 min 51 s | 23 min 27 s | 25 min 16 s | `effort.tsv` runs 4, 7, 10 |
| M2 proof compile window (first to last proof compile) | wall clock | under 9 min, bounded by other timestamps (13:38:46Z-13:47:43Z), not recorded | 6 min 15 s (recorded) | 12 min 11 s (recorded) | correction 5; entries 13, 16 |
| M3 session (brittleness matrix) | wall clock | not applicable | 25 min 11 s | 16 min 00 s | `effort.tsv` runs 13, 14 |
| review-fix sessions | wall clock | 3 min 51 s (runs 1-fix, 4-fix) | 3 min 48 s (2-fix, 7-fix, 13-fix) | 4 min 12 s (3-fix, 10-fix, 14-fix) | `effort.tsv` |
| all recorded sessions | wall clock | 45 min 18 s | 57 min 03 s | 58 min 22 s | sums of the rows above |
| M2 runs used | runs of 3 planned | 1 | 1 | 1 | entries 10, 13, 16 |
| human interventions | count | 0 | 0 | 0 | `effort.tsv`, every session (16 rows `human interventions`, all 0) |
| maintainer decisions raised by the tool's runs | count | 1 (decision 5, `NoDup (groups r)`, applies to all three) | 1 (decision 7, brittleness failure left as is) | 1 (decision 6, trigger of the statement) | issue #4 body |
| M2 failing invocations | proof-file compiles with a non-zero exit | **19** | **13** | **6** | entry 10; correction 6 (F\*, from `invocations.tsv`); entry 16 |
| M2 failed checks | failing invocations that led to an edit | **19** | **7** (session record: 6 of the 13 reran an unchanged file) | **6** (read off the source digests) | correction 6; entry 16 |
| M2 compile invocations of the proof files | edit-loop compile calls | 23 | 21 | 12 (plus 5 outside the loop: 4 verified toy or negative tests, 1 rejected at trigger inference) | correction 5; entry 13; entry 16 and correction 7 |
| M1 failed attempts | per-module attempts in `effort.tsv` | 0 | 0 | 7 (1 in the spec fn `is_prefix_at`, 6 in the exec mirrors) | entries 3, 5; correction 3 (supersedes entry 7's "every spec fn at the first attempt") |
| M2 per-item attempts, **not comparable** | `effort.tsv`: a clean compile counts once per item it contains; the items differ per tool | 67 (48 lemmas) | 68 (43 lemmas, 17 proof functions, 1 definition) | 80 (62 lemmas), plus 2 examples and 1 statement change | recomputed from `effort.tsv` (runs 4, 7 after correction 6's row split, 10) |

The comparable effort figures are the session windows, failing
invocations and failed checks. The per-item attempts are not comparable
(the plan, step 8): the unit is per item, the items are counted under
different rules (F\*'s proof functions are not lemmas, Verus's
witness-returning `proof fn`s are), and a clean compile of a file counts
once for every item in it. F\*'s 7 failed checks rest on the session
record; its 13 failing invocations are the figure recomputable from the
raw file, and the one comparable with Rocq's 19 and Verus's 6.

The report's estimate was 2-4 weeks per tool. Each tool's main theorem
closed in one M2 session of about 25 minutes of wall clock, with a
model writing the proof and the shared design already in place; the
caveats above apply.

## 2. Size (lines of spec, compiler + VM, proof)

**Counting method, the same for the three tools:** non-blank,
non-comment lines of each file, comments stripped by `loc.py`'s
`strip_comments` (Rocq and F\* `(* *)`, F\* and Rust `//`, Rust
`/* */`), the file's total being the sum of `loc.py`'s three columns.
Lines are grouped by file, not by `loc.py`'s per-tool spec/proof
classifier, whose rules differ between tools (its proof column gives
Rocq 743, F\* 507, Verus 1,227 for the same proof files). Verus's four
definition files are split at their `// ---- exec` marker: the part
before it is the spec, comparable with the Rocq and F\* files; the part
after it is the exec mirror, reported on its own row. Not counted:
drivers and extraction roots (`main.ml`, `Extract.*`, `TablesStub.*`,
`main.rs`), Verus's crate root `lib.rs` (9 lines).

| Part | Files | Rocq | F\* | Verus |
|---|---|---:|---:|---:|
| spec: syntax, results, search | `Syntax` | 49 | 55 (10 of them `length`, `append`, `skipn`, `nth`, which Rocq imports from Stdlib) | 59 |
| spec: reference semantics | `Sem` | 67 | 59 | 93 |
| spec: theorem statement | `Statement` | 21 | 26 | 31 |
| **spec, total** | | **137** | **140** | **183** |
| compiler | `Compile` | 62 | 55 | 76 |
| VM | `Vm` | 91 | 80 | 131 |
| **compiler + VM, total** | | **153** | **135** | **207** |
| definitions, total | | 290 | 275 | 390 |
| exec mirrors (exec code proved equal to the spec fns; Verus only) | the four definition files after the marker | - | - | 812 (757 code + 55 `assert`/`by` lines) |
| **proof, total** | `ProofA`, `ProofSem`, `ProofSim`, `Proof` | **872** (128 + 128 + 546 + 70) | **774** (101 + 100 + 472 + 101) | **1,556** (178 + 186 + 1,044 + 148) |
| proof / definitions | | 3.0 | 2.8 | 4.0 |

Recomputed in this run; every total equals entries 11, 14 and 17. The
proof's split by kind (from `lemmas.py`'s per-item line counts, entries
11, 14 and 17): Rocq 743 lines of lemmas and 129 of auxiliary
definitions and examples, the single lemma `sim` being 413 tactic
sentences; F\* 274 lines of lemmas, 342 of witness-returning proof
functions, 87 of auxiliary definitions, 65 of the `rep` type, options
and headers, 6 of examples; Verus 611 lines of lemmas, 619 of
witness-returning lemmas, 313 of auxiliary definitions and wrappers, 13
of examples. Verus's larger proof comes mostly from `proof_sim.rs`'s
case functions, which restate the derivation's indices that F\*'s
indexed type carries implicitly, and from intermediate unfolding asserts
(entry 17). Verus's 812 exec-mirror lines are the price of running a
Verus spec (Rocq and F\* extract to OCaml instead); they are neither
spec nor theorem proof, and their refinement proofs are inline, so they
contain no lemma.

## 3. Full check time (done-criterion 3)

Three clean full checks of all definition and proof files, pinned to
CPUs 28-31,60-63, 16 GB cgroup cap, `/usr/bin/time -v` (CPU time
includes the Z3 processes). Medians of the three.

| Figure | Rocq | F\* | Verus | Source |
|---|---:|---:|---:|---|
| wall clock | 6.50 s (spread 0.07 s) | 31.81 s (spread 0.06 s) | 5.27 s (spread 0.13 s) | entries 11, 14, 17 (`time.tsv`) |
| CPU (user + system) | 6.44 s | 31.88 s | 9.49 s | same |
| threads | 1 (one file at a time) | 1 (one file at a time; F\* and Z3 alternate) | 7 verifier threads (`--num-threads 7`) on 8 CPUs, whole crate | entries 11, 14, 17; correction 3 |
| what is checked | 9 files | 9 modules | crate: definitions, exec mirrors and proof | same |
| proof files alone | 3.67 s | 29.79 s (`ProofSim.fst` 25.64 s) | not separable (one crate) | entries 11, 14 |
| peak RSS | 414 MB | 221 MB | 513 MB | same |
| solver | none | Z3 5.3.0, default seed | Z3 4.16.0, default seed | entries 13, 16, correction 7 |
| M3 baseline cell, for reference | - | 32.0 s median of 11 seeds (with `--query_stats`) | 5.30 s median of 11 seeds (with `--output-json --time-expanded`) | entries 19, 21 (recomputed from `checks.tsv`) |
| definitions only (M1), wall / CPU | 2.81 s / 2.80 s | 1.97 s / 1.95 s | 2.28 s / 3.88 s (includes exec mirrors) | correction 4 (Rocq); correction 3 (CPU for F\* and Verus) |

Rocq pays about 0.45 s of start-up and Stdlib load per file (entry 11);
F\*'s time is almost all SMT time in `ProofSim.fst`'s case functions
(entry 13). On CPU time, Rocq is cheapest (6.44 s), then Verus (9.49 s),
then F\* (31.88 s); on wall clock, Verus is fastest because it is
parallel.

## 4. Lemmas and automatic share (done-criterion 3)

Done-criterion 3's definition, as the plan (step 6) makes it concrete:
a lemma is a named statement (Rocq `Lemma`, `Theorem`, `Corollary`,
`Fact`, `Proposition`; F\* a top-level `val`/`let` whose type is a
`Lemma`; Verus a `proof fn`); it is automatic when its proof is a single
call of the tool's automation (Rocq: one call of `lia`, `auto`, `eauto`,
`easy`, `congruence`, `intuition` or `firstorder`; F\*: body `()` with no
explicit call to another lemma; Verus: empty body).

| Figure | Rocq | F\* | Verus | Source |
|---|---:|---:|---:|---|
| lemmas (plan's definition) | 48 | 43 | 62 | entries 11, 14, 17; `lemmas.py` rerun |
| automatic | 0 (0%) | 3 (7.0%): `code_lit`, `exe_next`, `exe_fail1` | 3 (4.8%): `disj_union`, `lemma_cget_push`, `exe_next` | same |
| witness-returning proof items | none (Rocq states existentials) | 17 proof functions, not lemmas by F\*'s rule | 16, counted among the 62 | entries 13, 16 |
| like for like: all items | 0 of 48 | 3 of 60 (5.0%) | 3 of 62 (4.8%) | entry 17 |
| like for like: without witness-returning items | 0 of 48 | 3 of 43 (7.0%) | 3 of 46 (6.5%) | entry 17 |
| examples (counterexample checks, not lemmas) | 2 `Example`s | 2 `assert_norm`s | 2 `by (compute_only)` | entries 10, 13, 16 |
| largest item | `sim`, 413 tactic sentences | `ProofSim.fst`: 503 SMT queries | `case_group`, 77 lines | entries 11, 13; Verus `lemmas.txt` |

The definition counts a lemma automatic only when its whole proof is one
automation call, so the share is low in all three and does not measure
how much the automation did inside longer proofs: Rocq's `lia` closes
many subgoals inside `sim`; F\* and Verus leave the arithmetic, list and
unfolding steps to Z3, and their "manual" bodies are mostly calls of
other lemmas or of the induction hypothesis (F\*) plus one-level
unfolding asserts (Verus). The lines of section 2 and the solver figures
of section 7 are the better indicators of what was written by hand.

## 5. Axiom and admit report (done-criterion 1)

| Tool | Check | Outcome | Trusted base | Source |
|---|---|---|---|---|
| Rocq | `Print Assumptions main_theorem.` after a clean build; scan for `Admitted`, `admit`, `Axiom(s)`, `Parameter(s)`, `Conjecture`, `Hypothesis`/`Hypotheses`, `Abort` | **"Closed under the global context"**; scan empty | Rocq's kernel and Stdlib | entry 10, `rocq-m2-raw/rocq/axioms.txt` |
| F\* | clean check of the nine modules, each with `--admit_smt_queries false` explicit; scan for `admit`, `assume`, `magic`, `admit_smt_queries true`, `--lax`, `#lang-` | **9 "Verified module" lines, no warning**; scan empty | F\*'s `Prims`, `FStar.Classical`, `FStar.Pervasives`, Z3 5.3.0 | entry 13, `fstar-m2-raw/fstar/axioms.txt` |
| Verus | full crate check, and a second with `--no-cheating`; scan for `assume`, `admit`, `external_body`, `verifier::external`, `assume_specification`, `exec_allows_no_decreases_clause`, `no_verify`, `rlimit` | **"135 verified, 0 errors" twice**, exit 0; scan empty | vstd (`Seq`/`Set` axioms, broadcast lemmas), Z3 4.16.0 | entry 16; rechecked with the solver version recorded in correction 7 (`correction-7-raw/verus/axioms.txt`) |

All three state the same proposition (`FRAGMENT.md` section 7) with the
same hypothesis `NoDup (groups r)` (decision 5). Verus's statement has
its body inside the open spec fn `main_theorem_at(r, s, p)`, the outer
trigger (decision 6). The only options in the SMT proofs: F\* `--fuel 2
--ifuel 1 --z3rlimit 10` in the four proof modules, `--fuel 4` on
`length_comp`, `--z3rlimit 20` on `case_cat`; Verus none (default rlimit
10). None affects soundness (reviews of runs 7 and 10).

## 6. Agreement with C (done-criterion 2)

| Figure | Rocq | F\* | Verus | Source |
|---|---:|---:|---:|---|
| upstream cases of the fragment | 66 (52 x2, 13 x3, 1 n; 65 `test_utf8`, 1 `test_options`) | same | same | correction 1 (supersedes entry 2's 50) |
| searches (`onig_search`) agreeing, VM / semantics / experiment #6's `Spec2` | 66/66 each | 66/66 each | 66/66 each | correction 1; entries 5, 7 |
| start positions (`onig_match` at every position) agreeing | 273/273 each | 273/273 each | 273/273 each | same |
| experiment #2's loop probes (extra, counted apart) | 4/4 searches, 10/10 positions each | same | same | entries 3, 5, 7 |
| cases excluded at the C retry limit | 0 | 0 | 0 | entry 2, correction 1 |
| driver output | 1,017 + 42 lines | byte-identical to Rocq's | byte-identical to Rocq's and F\*'s | entries 5, 7 |

The C search agrees with each upstream test's expectation on 66/66 and
with experiment #2 on the 4 probes. The VM and semantics that ran are
the extracted ones (Rocq, F\*) and the exec mirrors proved equal to the
spec fns (Verus). The statement changes made after the drivers ran
(decisions 5 and 6) touched no extracted or exec definition (entries
10, 13, 16: driver outputs unchanged). No upstream fragment
case has a star over a nullable body: the empty check is exercised by
the 4 probes only, and by the theorem.

## 7. SMT brittleness (done-criterion 4)

| Figure | Rocq | F\* | Verus | Source |
|---|---|---|---|---|
| applies | no (no SMT solver; the kernel checks the proof) | yes | yes | plan |
| solver versions | - | Z3 5.3.0 (baseline), 4.15.3, 4.13.3, bundled with F\* and selected by `--z3version` | Z3 4.16.0 (bundled, the only supported one); 5.3.0 and 4.15.3 through `VERUS_Z3_PATH` + `-V no-solver-version-check`, **unsupported** | entries 19, 21 |
| seeds | - | default + `--z3seed` 1..10 | default + `smt.random_seed` 1..10 | same |
| full clean checks passing | - | **32 of 33** | **33 of 33** (11 of 11 supported, 22 of 22 unsupported) | recomputed from `checks.tsv` (correction 8 for F\*, entry 21 for Verus) |
| failures | - | Z3 4.15.3, seed 4: `ProofSim.case_star_null` goal 29 (`pc' == pcB`, a type-index equality on a returned `rep` witness) exhausts its rlimit of 10; replicated identically (`rep1`); `case_star_nn`, `case_group` and `sim` then go unchecked in that cell | none | entry 19, correction 8 (`failed:ProofSim.case_star_null,2,goal29 x1`) |
| same goal across cells | - | 5.3.0: at most 0.028 of its rlimit at every seed; 4.15.3: 0 to 10.000; 4.13.3: 0 to 8.193 | - | entry 19 |
| margin, baseline / supported solver | - | highest query 74.0% of its rlimit (`case_chk_null` goal 20, seed 5); 26 queries over 50%, 0 over 80% | highest function 11.3% of the default limit (`case_star_nn`, seed 9); 2 functions over 10%, 0 over 50% | recomputed from `querystats.tsv.xz` and `functions.tsv` |
| margin, other versions | - | 4.15.3: 100% (the failure), 21 over 50%, 4 over 80%; `case_chk_null` goal 20 up to 90.6% (seed 8). 4.13.3: 89.6% (`case_chk_null` goal 20, seed 4), 24 over 50%, 2 over 80% | 5.3.0: 34.0% (`case_star_nn`, seed 7), 9 over 10%; 4.15.3: 14.1%, 1 over 10%; 0 over 50% anywhere | same |
| check time per version (median wall clock) | - | 32.0 / 35.3 / 33.7 s | 5.30 / 8.55 / 5.38 s | recomputed from `checks.tsv` |
| refusal of another solver version | - | none: F\* accepts its bundled versions by name | without the opt-out, Verus refuses Z3 5.3.0 ("expected z3 version 4.16.0, found 5.3.0") through a panic, exit 134, followed by a second panic while unwinding; recorded once | entry 21 |

Decision 7: the F\* proof stays as written, so done-criterion 4 reports
F\* at 32 of 33 cells; the failing goal (`case_star_null` goal 29) and
the near-limit goal (`case_chk_null` goal 20, about 91% of its rlimit
under Z3 4.15.3) are not hardened.

The two margins are not like for like (entry 21, correction 9). F\*'s
are per query against that query's rlimit. Verus's are a function's
total resource count (all its queries) against the per-query limit of
30,000,000 units, so they are an upper bound on any one query, and they
hold at the default limit only: a function's count depends on the
`--rlimit` it is checked with (`case_star_null` 812,256 units at
`--rlimit 0.3`, 2,501,172 at 1 and at the default; reason unknown). The
same star cases are the most expensive goals in both SMT proofs. F\*'s
proof sets `--z3rlimit 10` per query and spells out fewer steps (774
lines); Verus's default limit is large for these goals and its proof
spells out more (1,556 lines).

## 8. Stated limits (all three tools)

- **Unbounded VM, not the C retry limit.** The theorem is about the VM
  with fuel, completeness giving some fuel that finishes. The C library
  stops at `DEFAULT_RETRY_LIMIT_IN_MATCH` = 10,000,000
  (`upstream/src/regint.h:111`); that limit is not modelled
  (`FRAGMENT.md` section 5). No case of done-criterion 2 hits it.
- **`NoDup (groups r)`** (decision 5). The statement is false for a
  group nested in a group of the same number (checked by computation in
  all three tools); the hypothesis excludes no pattern the parser
  produces, since `f95747b` numbers groups in order and has no branch
  reset. `p <= |s|` is in the three statements but unused by the three
  proofs.
- **Verus's trigger wrapper** (decision 6). The statement's body is
  unchanged inside `main_theorem_at(r, s, p)`, the outer trigger; a
  trigger is a solver hint, not part of the proposition. The Verus exec
  VM inherits the theorem only under its mirrors' preconditions
  (`code.len() < usize::MAX - 2`, `s.len() < usize::MAX`, `acts_wf`) and
  when `ecompile` does not overflow `usize` (`FRAGMENT.md` section 7).
- **DEV-008's termination obligation is covered by no experiment**
  (decision 4, amended). Without backreferences DEV-008 is upstream's
  plain empty check, so the fragment's measure is (remaining input,
  pattern size). DEV-008's own obligation, that a continued empty
  iteration must change a group named by a backreference, is exercised
  by no experiment (decision 4).
- **Also outside the theorem:** the peephole opcodes
  (`OP_PUSH_OR_JUMP_EXACT1`, `OP_PUSH_IF_PEEK_NEXT`, `OP_ANYCHAR_STAR*`,
  the `OP_STR_*` variants; `FRAGMENT.md` section 2); the compiler equals
  upstream's by reading `regcomp.c`, not by a bytecode dump (the
  maintainer found the dump not needed); F\*'s VM is total F\* over
  lists, not Pulse (the Pulse VM is experiment #10's), and its proof is
  about the same list functions as Rocq's rather than `FStar.Seq`.

## 9. Verdicts

**Rocq.** The main theorem is closed under the global context, with no
SMT solver in the trusted base, so done-criterion 4 does not apply and no
solver version or seed can break the proof. It took one 26-minute M2
session but the most failed checks (19, all local tactic fixes), and by
done-criterion 3's definition no lemma is automatic (0 of 48): `lia`
closed subgoals inside long scripts such as `sim` (413 sentences).
Size is between the other two (872 proof lines) and the check is the
cheapest in CPU time (6.44 s, single-threaded). For experiment #10 its
route is extraction to OCaml, with no native C or Rust VM; for issue #34
it is the interactive tool that issue already proposes.

**F\* (total F\*, not Pulse).** It has the smallest proof (774 lines)
and the fewest failed checks on the session record (7; 13 failing
invocations), closed in one 23-minute session, with Z3 discharging the
arithmetic and list steps Rocq wrote by hand. It has the slowest full
check (31.81 s, 81% of it `ProofSim.fst`) and the only brittleness
failure: 32 of 33 cells, deterministic, at a type-index equality in
`case_star_null` under Z3 4.15.3 seed 4, with a baseline margin of 74%
and a near-limit goal at about 91% under 4.15.3 (decision 7: not
hardened). The verified VM is total F\* over lists, so experiment #10's
Pulse-to-C route starts from this specification and invariants, not
from verified imperative code. For issue #34, F\*'s fragility shows up
at its tightest per-query rlimits.

**Verus.** The main theorem is closed with "135 verified, 0 errors" in
a plain and a `--no-cheating` check, after one 25-minute session with 6
failed checks (all read off source digests), but only after a
statement change that is a trigger wrapper (decision 6). It has the
largest proof (1,556 lines, 4.0 times the definitions) plus 812 lines of
exec mirrors proved equal to the spec fns, which no other tool needed.
It has the fastest wall-clock check (5.27 s on 7 threads, 9.49 s CPU)
and no brittleness failure (33 of 33), with margins up to 11.3% under
its only supported solver; other Z3 versions run only through an
unsupported opt-out, and without it Verus refuses them with a panic.
For experiment #10 it supplies an exec Rust VM already proved equal to
the spec VM within `usize` bounds; for issue #34, it is the SMT
candidate with the wider margins, at about twice F\*'s proof size.

**Across the three, for the maintainer.** Done-criteria 1-4 are met for
the three tools, each in one M2 run of three planned. Effort figures
(sessions of 23-26 minutes, 6-19 failed checks) are close and not
independent; the differences that are measured, not sampled once, are
check cost (CPU 6.4 s / 31.9 s / 9.5 s), proof size (872 / 774 /
1,556), the SMT behaviour (F\* 32 of 33, Verus 33 of 33 with a single
supported solver, Rocq not exposed), and what each produces for
experiment #10 (OCaml extraction, a pure F\* specification for Pulse,
an exec Rust VM). This entry does not choose a stack.

## Effort (this run)

[effort.tsv](../09-representative-proof/effort.tsv), rows `15`: session
from no later than 2026-11-25T19:08:01Z (first file written, after `git
pull` and reading the plan and issue #4) to the end recorded there;
no prover, no bench-host work; 0 human interventions.

## Open

- Maintainer's review of this comparison before it is posted on issue
  #4 as the done-criterion-5 comment (plan step 8). The draft comment
  is the table and verdicts above, shortened.
- Outside this run: lemmas.py's F\* branch still prints `admitted 0` as
  a literal (correction 7, Open); run 13's `logs.tar.xz` carries a local
  username as tar owner (run-14 review follow-up, the maintainer's
  call).
