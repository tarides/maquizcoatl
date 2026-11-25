# Experiment #9, entry 22: run-14 review fixes (correction 9)

**What.** Three decision-free wording fixes to [entry 21](2026-11-25-exp-09-verus-m3.md)
(Verus M3, run 14), from the independent review of run 14
([issue #4 comment](https://github.com/tarides/maquizcoatl/issues/4#issuecomment-7171412264)).
Entry 21 and its raw files are not edited; this entry corrects them.
Nothing was re-run. Every figure below is read from entry 21's own raw
files (`checks.tsv`, `functions.tsv`, `drive.log`,
`rlimit-calibration.txt`). The matrix, its verdicts and the margins
table of entry 21 are unchanged.

## Fix 1: `drive.log` has the 5.3.0 seed 6 result line

Entry 21's Script incident paragraph says that the first pass "had been
stopped during 5.3.0 seed 6, whose check completed and wrote its row
(its result line is missing from `drive.log` only)". The parenthetical
is wrong and is withdrawn. `drive.log` has the line
`5.3.0 6 0 135 0 8.16 -` just before the relaunch marker
(`== relaunch after the sampler fix 18:36:24Z`). The rest of the
paragraph stands: the first pass ended after 5.3.0 seed 6, which
completed and wrote its row.

## Fix 2: the per-seed table covers the proof-module star and alternation cases only

The table that entry 21 introduces as "The most expensive functions"
shows four `proof_sim` functions. It should be titled **"The
proof-module star and alternation cases (the F\* counterparts), share of
the limit per seed"**. It does not list the most expensive function of
every cell. By `max_fn` in `checks.tsv` (33 matrix cells), the function
with the largest count is:

| `max_fn` | cells |
|---|---:|
| `proof_sim::case_star_nn` | 14 |
| `proof_sim::case_star_null` | 9 |
| `compile::ecomp_star` | 8 (4.16.0 seeds 1, 2, 3, 6; 5.3.0 seed 2; 4.15.3 seeds 1, 6, 9) |
| `compile::ecomp_alt` | 1 (5.3.0 seed 3) |
| `proof_sim::case_alt` | 1 (5.3.0 seed 8, .182) |
| `proof_sim::case_chk_null` | 0 |

Note: the review says that `case_alt` tops no cell. It tops one, 5.3.0
seed 8, as the row above and entry 21's own table (.182) show.
`case_chk_null` tops none.

The two `compile::` rows that entry 21's table leaves out, in the same
format (count / 30,000,000, default seed then seeds 1..10):

| Function | Z3 | default | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `compile::ecomp_star` | 4.16.0 | .065 | .068 | .052 | .069 | .052 | .069 | .051 | .064 | .046 | .058 | .048 |
| | 5.3.0 | .066 | .070 | .077 | .048 | .052 | .060 | .074 | .069 | .061 | .092 | .050 |
| | 4.15.3 | .040 | .077 | .053 | .053 | .063 | .075 | .078 | .078 | .060 | .074 | .056 |
| `compile::ecomp_alt` | 4.16.0 | .048 | .043 | .033 | .028 | .060 | .046 | .048 | .043 | .051 | .039 | .031 |
| | 5.3.0 | .059 | .043 | .048 | .077 | .031 | .051 | .028 | .044 | .045 | .058 | .079 |
| | 4.15.3 | .025 | .037 | .047 | .047 | .046 | .046 | .053 | .046 | .042 | .044 | .042 |

`compile::ecomp_star` reaches .092 at most (5.3.0 seed 9) and .069 under
the supported 4.16.0. Neither `compile::` function goes over 10% in any
cell, so entry 21's over-10% and over-50% counts and its highest shares
(all `case_star_nn`) are unchanged.

## Fix 3: a function's count depends on the limit it is checked with

Entry 21's Margins section should add the following. The shares are
those at Verus's default limit (`--rlimit 10`, 30,000,000 units) only.
The per-function count is not a fixed cost of the function: it depends
on the `--rlimit` it is checked with. `rlimit-calibration.txt` records
`proof_sim::case_star_null` (successful in both runs) at 812,256 units
under `--rlimit 0.3` and 2,501,172 under `--rlimit 1`. That second figure
equals its count in the matrix's 4.16.0 default-seed cell, which uses the
default `--rlimit 10`. The reason is not known. The calibration run checked
`--verify-module proof_sim` with 4 threads and the matrix checked the
whole crate with 7, so the dependence is recorded, not explained. "Share of
the limit" therefore means the count at the default limit divided by
that limit. It does not mean the fraction of any other limit that the
function would use.

## Provenance

- Local worktree at `2745342` plus this entry; GNU Awk 5.3.2, bash. No
  bench-host work; nothing measured.
- Inputs: entry 21's `verus/checks.tsv`, `verus/functions.tsv`,
  `verus/drive.log`, `verus/rlimit-calibration.txt` (unchanged).

## Effort

[effort.tsv](../09-representative-proof/effort.tsv), `14-fix` rows: a
session of a few minutes (start and end in the session row). Every
figure came right at the first attempt. 0 human interventions.

## Open

- Run 15 (M4): the comparison table. Carry entry 21's caveat that the
  Verus and F\* margins are not like for like (Verus: a per-function count,
  an upper bound per query; F\*: per query), and fix 3 above.
