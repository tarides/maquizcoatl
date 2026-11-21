# Experiment 13, Part C: observed adaptation cost per release (version 2)

Plan: [`plans/13-upgrade-cost.md`](../../plans/13-upgrade-cost.md).
Issue: https://github.com/tarides/maquizcoatl/issues/3. Review addressed:
https://github.com/tarides/maquizcoatl/issues/3#issuecomment-7013400316
(problems 2, 3, 5, 6, 8 and 10; problems 4 and 7 are left open below).

This file replaces [the first summary](2026-11-19-exp-13-part-c-summary.md),
which is kept as it was. It is computed from the re-run
([`2026-11-19-exp-13-rerun.md`](2026-11-19-exp-13-rerun.md)), whose
EverParse rows cover the sources' former paths. The F\* row of the first
summary is withdrawn.

**Part A (builds of a pinned project against the next release) is still
to come.** Everything below comes from project history only. Window:
2025-11-19 to 2026-11-19.

## Convention

One convention is used for every tool:

- **Lines** are added plus removed, with the tool's exclusions (pin files,
  lockfiles it knows, generated files) and no rename detection.
- **Adaptation lines of a row**: all its lines for `adaptation`, 0 for
  `unrelated`, and for `mixed` the count given in its `reason`. Rounded
  shares are not used, except for the two mixed rows whose reason gives no
  count (Linden `2af06b3`, lean-regex `153ed60`), where lines times share
  is used. The mixed rows are listed below.
- **Series and spans** are those of the tool's per-release table
  ([`2026-11-19-exp-13-rerun-per-release.csv`](2026-11-19-exp-13-rerun-per-release.csv)),
  with one addition: a keyword row whose classification ties it to a
  release joins that series (Warblre `5d7b76e` joins 9.2, Linden `a8c1859`
  joins 9.1). Every other row is unattributed, as are the rows of a series
  the tool gives no span (F\* 2026.10.11, Creusot 1.9, Anvil).
- **Per release crossed**: one value per stable release spanned by a
  series with a span. Each release of a series gets the series'
  adaptation lines divided by its span. The median and the mean are both
  taken over these values, so the mean is attributed adaptation lines
  divided by releases crossed.
- **Per year**: all adaptation lines in the window, attributed or not.
  **Cadence**: the tool's stable release series whose first stable
  release falls in the window (patch releases and pre-releases do not
  count), checked against `experiments/13-upgrade-cost/releases/*.tsv`.
  **Yearly total / cadence** charges every line to the tool's own release
  rate. It is the only per-release figure for Anvil and Creusot, and it is
  a different quantity from the mean per release crossed: the two are in
  separate columns and never compared with each other.

Table: [`2026-11-19-exp-13-per-release-classified.csv`](2026-11-19-exp-13-per-release-classified.csv),
one row per (project, series reached) plus one `unattributed` row per
project. Its adaptation lines sum to the yearly totals below.

## Summary

| Tool | Project | Releases crossed | Median per release crossed | Mean per release crossed | Cadence | Yearly adaptation lines (raw) | Yearly total / cadence | Main caveat |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Rocq | Warblre | 5 | 544 | 363 | 2 | 1,815 (2,580) | 908 | Crosses 8.20, 9.0 and 9.1 (all released before the window) in one 1,633-line migration, about 790 with rename detection; then 103 (9.2) and 79 (9.3) |
| Rocq | Linden | 5 | 127 | 93 | 2 | 468 (851) | 234 | Crosses 8.19, 8.20 and 9.0 (before the window) in one 380-line migration; then 12 (9.1) and 74 (9.2); no 9.3 bump |
| Lean | lean-regex | 10 | 70.5 | 973 | 11 | 9,733 (10,131) | 885 | 4.25 to 4.27 String API overhaul: 9,210 lines (95%); 4.26 is an upper bound; dormant since 2026-09-30 |
| F\* | EverParse CBOR, LowParse | 16 | 0 | 155 | 28 | 4,585 (6,864) | 164 | 2,098 lines unattributed, 1,918 of them `6c006b0` (span 0); with its 12 releases counted by hand: 28 crossed, median 160, mean 157. Paid by the F\* team |
| Why3 | Why3 gallery | 1 | 515 | 515 | 1 | 515 (82,849) | 515 | 473 to 515 forced lines, upper bound used; mostly regenerated sessions |
| Why3 | Creusot | 0 | none | none | 1 | 992 (118,591) | 992 | Lower bound: pins cover about 11 of the 16.5 months of the 1.9 cycle; counted as one release step: 992 (open decision 5); 23 hand-written lines |
| Verus | Anvil | 0 | none | none | 52 | 7,804 (61,860) | 150 | 4,210 and 81 without the elective `cargo verus` migration; the division is open (review problem 7) |
| Isabelle | AFP regex entries | 3 | 4 | 6.7 | 3 | 20 (1,574) | 6.7 | AFP-wide sweeps by Isabelle developers |

Raw yearly lines are all rows of the project, classified or not
(Creusot's include the 117,369 lines of its three why3find-only bumps).

## Per tool

### Rocq

- The Rocq 9.0 migration was merged in the window (2026-03-02 in both
  projects), but the releases it crosses were not: Warblre `a5a3120`
  spans 8.20, 9.0 and 9.1, Linden `4312028` spans 8.19, 8.20 and 9.0.
  This replaces "the 9.0 migration (it spans 9.0 to 9.1)" of the
  classification file and "spread over 3 releases" of the first summary
  (review problem 8). Because those releases predate the window, the
  yearly total / cadence of both projects charges an older catch-up to
  9.2 and 9.3 and overstates the rate.
- Warblre `a5a3120`: 1,633 adaptation lines as the tool counts them
  (2,379 minus the npm lockfile, 742, and a pip bump, 4). This includes
  108 lines of `flake.lock`, a lockfile the tool does not exclude (1,525
  without it). With rename detection (`git diff -M`, pin files excluded)
  the adaptation is about 790 lines, closer to the work done. Linden
  `4312028`: 380 lines (`git diff -w`, whitespace cleanup excluded).
- After the migration: Warblre 9.2 103 (`a7fb967` 36 plus the notation
  follow-up `5d7b76e` 67), 9.3 79; Linden 9.1 12, 9.2 74. Linden 9.2 was
  76 in the first run; the re-run leaves `b6396cb` (2 lines, a version
  bound) unattributed.

### Lean

- Per series: 481 (4.25), 7,607 (4.26), 1,122 (4.27), 5, 332, 141 over
  two releases (4.30, 4.31), 10, 35 over two releases (4.33, 4.34).
- Review problem 2: the tool's mining summary gives a median of 201 with
  one value per series (8 values). With one value per release crossed (10
  values, as here) the median is 70.5. Classification does not explain
  the difference: one value per series gives 201 on adaptation lines too
  ((70.5 + 332) / 2). The first classification notebook line read as if
  it did.
- 4.34.0, 4.35 and 4.36 are not observed: the project is at v4.34.0-rc1
  and dormant since 2026-09-30. Part A covers them in one step.

### F\*

- The 16 releases crossed with the tool's spans include the 11 of series
  2026.07.05, all at 0: EverParse followed an F\* branch (`fstar1`), and
  the only non-empty PR of that series, `b3544a1`, is feature work. That
  is where the median of 0 comes from.
- Series 2026.10.11 (`6c006b0`, 1,918 lines, the move to F\* `fstar2`)
  has no span: its starting pin is in no F\* release. Counted by hand it
  spans the 12 releases v2026.07.12 to v2026.10.11. With that span the
  project crosses all 28 F\* releases of the window: median 160, mean 157,
  180 lines unattributed. The tool's figure is kept in the table; the
  choice is an open point.
- `77921d0` (2,264) and `6c006b0` (1,918) carry 4,182 of the 4,585 lines;
  both are upper bounds and neither share has been checked by a human.
- A lower bound in another sense: the F\* team maintains EverParse and can
  fix things in F\* itself.

### Why3

- Gallery, 1.8.2 to 1.9.0: 473 to 515 forced lines (358 session lines of
  the `compute` rename, about 55 lines of OCaml API examples, about 60
  certain and 42 uncertain `.mlw` lines), out of 82,849. The snapshot
  spans 16.5 months of master, from the merge base 1.8.1 (2025-06-04).
- Creusot is a lower bound (review problem 6). Its Why3 pins move from
  `51e0579b` (2025-10-29) to `05bf4ddf` (2026-09-22): about 11 of the 16.5
  months between 1.8.1 and 1.9.0 (2026-10-19). Of its 992 lines, 23 are
  hand-written (2 + 8 + 13 in `b22069f`, `e072997`, `7c3d1e8`), 31 with
  the nix build lines of `5ba3ac9`. 60 lines are nix files: `flake.lock`
  36, `flake.nix` 20, `nix/deps/why3.nix` 4. `flake.nix` and `flake.lock`
  carry pins the tool does not exclude. The rest is regenerated proof
  data.

### Verus

- 7,804 adaptation lines: 6,182 in bumps, 1,622 in keyword rows. Without
  the elective `cargo verus` migration (`0cd9f9f` 3,478, `b1d8635` 104,
  `6096278` 12): 4,210.
- Cadence 52, not 53: `releases/verus.tsv` lists
  `dependency/singular-4.3.2` (2026-02-02) as a stable row. It is a
  dependency, not a Verus release, and the tool's mining summary counts
  it in its 53 series.
- No span for any row: the pins name Verus commits or vstd versions on
  the starting side, and Anvil follows Verus HEAD for most of the year.

### Isabelle

- 4 lines (2025-1), 0 (2025-2), 16 (2026). All by Isabelle developers in
  AFP-wide sweeps.

## Mixed rows: adaptation lines used

| Project | Row | Raw lines | Share | Adaptation lines | Source |
| --- | --- | --- | --- | --- | --- |
| warblre | `a5a3120` | 2,379 | 0.69 | 1,633 | reason: minus 742 + 4 unrelated |
| linden | `4312028` | 724 | 0.52 | 380 | reason |
| linden | `a8c1859` | 31 | 0.06 | 2 | reason |
| linden | `2af06b3` | 13 | 0.8 | 10.4 | share (no count) |
| linden | `31aa384` | 47 | 0.9 | 44 | reason: minus 3 unrelated |
| lean-regex | `e1600a1` | 732 | 0.66 | 481 | reason |
| lean-regex | `e2e33d6` | 7,695 | 0.99 | 7,607 | reason: minus 47 + 21 + 20 unrelated |
| lean-regex | `153ed60` | 1,175 | 0.95 | 1,116 | share (no count) |
| everparse-cbor | `77921d0` | 2,637 | 0.86 | 2,264 | reason |
| everparse-cbor | `56f47c8` | 607 | 0.01 | 6 | reason |
| creusot | `5ba3ac9` | 238 | 0.03 | 8 | reason |
| why3-gallery | `1.8.2..1.9.0` | 82,849 | 0.006 | 515 | reason (upper bound; lower 473) |
| afp-regex | Regular-Sets, 2025-1 | 32 | 0.12 | 4 | reason |
| anvil | `a65d68c` | 10,779 | 0.21 | 2,299 | reason |
| anvil | `cc8ab6a` | 6,728 | 0.05 | 360 | reason |
| anvil | `0cd9f9f` | 30,728 | 0.11 | 3,478 | reason |
| anvil | `b1d8635` | 129 | 0.8 | 104 | reason |
| anvil | `6096278` | 14 | 0.85 | 12 | reason |
| anvil | `aa757c8` | 1,192 | 0.13 | 150 | reason |

## Corrections to earlier files

The earlier files are append-only and left unchanged. Where they differ
from this file, this file holds (review problems 8 and 10, and checks
made here):

- [`classification.md`](2026-11-19-exp-13-classification.md): lean-regex
  has 10,131 raw lines, not 10,121.
- Lean, from counts instead of shares: 4.25 481 (not 483), 4.26 7,607
  (not about 7,620), 4.25 to 4.27 9,210 (not 9,220), total 9,733 (not
  about 9,750).
- Anvil: keyword adaptation 1,622 (not 1,624), total 7,804 (not 7,806),
  4,210 without the migration (not 4,212); over 52 releases, 150 and 81
  (not 147 and 79 over 53).
- Why3 gallery forced range: 473 to 515 from its parts (not 470 to 513).
- Creusot: 23 hand-written lines, 31 with the nix build lines of
  `5ba3ac9` (not about 27). `a049fe8` (4 lines) and `5ba3ac9` count
  `flake.nix` pin lines as adaptation, and so do `b22069f`, `e072997` and
  `7c3d1e8` with `flake.lock` and `flake.nix`: 60 nix lines in the 992.
- Rocq: the wording on the 9.0 migration (see Rocq above); Warblre's 1,630
  is about 790 with rename detection and includes 108 `flake.lock` lines;
  Linden 9.2 is 74 after the re-run (not 76).
- Lean "median about 70" (classification notebook line) is the
  per-release-crossed median; the tool's 201 is per series (problem 2).
- The first summary's per-release column mixed medians (Lean, F\*) and
  means (Verus, Isabelle) (problem 3); the table above gives both for
  every tool.

## Open points, for the maintainer

1. **Normalisation by project size (review problem 4), not decided.**
   Sizes measured in the local clones at the commit at D, no fetch;
   physical lines (`git grep -c ''`), blanks and comments included:

   | Project | Measured | Files | Lines |
   | --- | --- | --- | --- |
   | Warblre | `*.v` at `d4b0e22` | 34 | 8,864 |
   | Linden | `*.v` at `3ef2cb4` | 65 | 24,108 |
   | lean-regex | `*.lean` at `32af6f3` | 124 | 13,701 (regex 6,295, correctness 7,406) |
   | EverParse | `.fst`/`.fsti` under `lib/everparse/{cbor,lowparse}` at `270f5aa` | 243 | 126,578 (cbor 57,785, lowparse 68,812) |
   | Why3 gallery | `.mlw` under `examples/` at 1.9.0 | 427 | at least 101,344 (2 blobs not local) |
   | Creusot | `*.rs` at `601d978` | 765 | 94,430 (plus 4,239 `.coma` files) |
   | Anvil | `*.rs` at `e83ea0f` | 364 | 85,908 |
   | AFP entries | `*.thy` of the six entries at `afp-2026` | 78 | 23,162 |

   Creusot's size is the Rust tool, not the Why3 code it generates.
2. **Verus division (review problem 7), not decided.** Anvil's last
   commit is 2026-10-12; 3 of the 52 releases come after it (0.2026.10.18,
   0.2026.10.26, 0.2026.11.02). The starting pin of `a65d68c`
   (`8bd7c32`) could not be dated without a fetch, so its 2,299 lines may
   pay for releases before the window.
3. **Spans the tool cannot compute**: F\* 2026.10.11 (12 by hand) and
   Creusot 1.9 (one step by the convention of open decision 5). A tool fix
   (span from the last release reached) or a convention.
4. **Human spot check** of agent-estimated shares, at least lean-regex
   `e2e33d6` (0.99), Anvil `cc8ab6a` (0.05), the Why3 gallery (0.006),
   and EverParse `77921d0` (0.86) and `6c006b0` (1.00).
5. **Open decisions 1 to 7 of
   [`classification.md`](2026-11-19-exp-13-classification.md)**: optional
   or oversized changes as adaptation; why3find in the Why3 figure; rename
   detection; hand-written versus regenerated lines; the Anvil and Creusot
   conventions; maintainer versus any effort; porting the gallery
   decomposition and the AFP author fix into the tool.
6. **Verus release list**: `dependency/singular-4.3.2` should leave the
   cadence, by a filter in the tool or a fix of `releases/verus.tsv`.
