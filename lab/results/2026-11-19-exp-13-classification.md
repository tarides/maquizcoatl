# Experiment #13, Part C: manual classification

Plan: [`plans/13-upgrade-cost.md`](../../plans/13-upgrade-cost.md), Part C.
Issue: https://github.com/tarides/maquizcoatl/issues/3.
Input: the tables of the recorded mining run
([`2026-11-19-exp-13-mining.md`](2026-11-19-exp-13-mining.md)).
Summary per tool:
[`2026-11-19-exp-13-part-c-summary.md`](2026-11-19-exp-13-part-c-summary.md).

## Who and how

- Done on 2026-11-19 by Claude agents in a background workflow, one agent
  per project group (Rocq, Lean, F\*, Creusot, Verus, AFP, Why3 gallery).
  Each agent read the diff of every row in the local clones, with the
  tool's own exclusions (pin files, lockfiles, workflows) and no rename
  detection, as the tool counts. Some also read PR descriptions, release
  notes and the tool's sources at the relevant tags.
- Every `*-bumps.csv` got two columns after `class`: `adaptation_share`
  (the fraction of the row's lines that is adaptation, from 0 to 1) and
  `reason` (quoted). The 13 columns written by the tool are unchanged; all
  8 tables have the same 16 columns.
- `class` is `adaptation` (the whole row follows a tool change),
  `mixed` (part of it does) or `unrelated`.
- Rows: the 48 rows the plan requires (bumps over 100 lines or 10 files,
  keyword rows, non-empty snapshots) all have a class. 18 smaller bump
  rows were classified too, since they were cheap to read and decide some
  per-release figures; their reason says so. Rows with 0 lines (19
  EverParse bumps, 13 AFP snapshots) are left empty.
- One hand correction to the tool's output: the AFP `Formula_Derivatives`
  authors (see "Decisions taken").

## Per tool

### Rocq: Warblre, Linden

- The Rocq 9.0 migration (it spans 9.0 to 9.1) dominates both projects.
  Warblre `a5a3120`: 2,379 raw lines, share 0.69 (about 1,630 lines; npm
  lockfile refresh unrelated), about 790 if its two file renames were
  detected. Linden `4312028`: 724 raw lines, 380 of adaptation (the rest is
  whitespace cleanup).
- Later releases cost tens of lines. Warblre: 9.2 about 103 (`a7fb967`
  plus the notation follow-up `5d7b76e`), 9.3 79 (`787f9e6`). Linden: 9.1
  about 12, 9.2 about 76 (of which 32 keep 9.0 and 9.1 working while
  porting to 9.2). Linden has no 9.3 bump in the window.
- Keyword rows: 2 adaptations, 2 unrelated (`f279063` matched on a branch
  name, `9211b2b` on the word "compatible").

### Lean: lean-regex

- 10,121 raw lines, about 9,750 of adaptation. Only `correctness/`
  depends on mathlib, and only for tactics and a few lemmas; no change
  was driven by mathlib, all follow Lean core and Std.
- The Lean 4.25 to 4.27 String API overhaul cost about 9,220 lines:
  4.25 about 483, 4.26 about 7,620 (`e2e33d6`, Iterator and Substring
  to ValidPos and Slice), 4.27 about 1,120 (ValidPos renamed Pos).
- The other seven series cost 5 to 332 lines each (523 in all). Median
  about 70 lines per release, mean near 975. Moving from a release
  candidate to the release cost 0 to 6 lines.

### F\*: EverParse CBOR and LowParse

- 21 F\* bumps (the update bot follows F\* master), 19 with 0 lines under
  the restricted paths.
- `a991f58`: 33 lines, adaptation, in the v2026.11.15 series (the
  unrefinement change of F\* PR 4586).
- `270f5aa`: 174 lines, adaptation, caused by an F\* fix that reached no
  release before the end of the window (F\* PR 4921): unattributed.
- Median 0 lines per release. A lower bound: the F\* team maintains
  EverParse and can fix things in F\* or outside the restricted paths.

### Why3: gallery and Creusot

- Creusot pins Why3 development commits; every pin in the window maps to
  1.9.0, so the window is one release step. Its 5 Why3 bumps change 1,222
  lines, about 990 of adaptation, almost all regenerated proof data; about
  27 lines were written by hand (renamed stdlib constants, nix build, proof
  timeouts). The 3 bumps that only move why3find are `unrelated` for Why3;
  `eef25e4` alone is 2,488 lines once file moves are detected, 117,350 as
  the tool counts them.
- Why3 gallery, snapshot 1.8.2 to 1.9.0: `mixed`, share 0.006 (see the
  decomposition below).

### Verus: Anvil

- 28 rows, 61,860 lines: about 7,806 of adaptation (12.6%), 6,182 in bumps
  and 1,624 in keyword rows. The rest is three large unrelated changes
  (controllers removed, a regenerated CRD, proof rewrites).
- Without the optional `cargo verus` migration (`0cd9f9f`, `b1d8635`,
  `6096278`), about 4,212 lines. The forced part is mostly the December
  2025 deprecation fixes (2,177 lines), the finite Map/Set split (869), and
  steady proof and rlimit stabilisation (19 to 210 lines each).
- 53 Verus releases in the window: about 147 lines per release, about 79
  without the migration.

### Isabelle: AFP regex entries

- 5 non-empty snapshot rows, 1,574 raw lines, 20 of adaptation (1.3%):
  4 lines in Isabelle2025-1, 0 in Isabelle2025-2, 16 in Isabelle2026.
  About 7 lines per release.
- Every adaptation is an AFP-wide sweep by an Isabelle developer, not by
  the entry authors. The raw figures are dominated by proof tidying and new
  lemmas.

## Why3 gallery decomposition

Table:
[`2026-11-19-exp-13-why3-gallery-decomposition.csv`](2026-11-19-exp-13-why3-gallery-decomposition.csv),
259 rows, one per top-level example and status (`new` or `existing`).
Its totals match the snapshot row (735 files, 82,849 lines). It was built
with a one-off shell and awk pipeline, not with `upgrade_mining`.

- New examples: 71 files, 11,140 lines, 23 units.
- Existing examples: 664 files, 71,709 lines: 421 session files (69,337
  lines) plus one deleted, 200 binary shape files, 23 `.mlw` files (1,162
  lines), 1,005 lines of other files.
- 417 of the 421 changed sessions change prover versions: they were
  replayed with newer provers, which 1.9.0 does not require.
- Forced by 1.9.0, as far as a diff can tell: 358 session lines from the
  `compute_specified`/`compute_in_goal` to `compute [nodef]` rename, about
  55 lines of OCaml API examples, and about 60 certain plus 42 uncertain
  `.mlw` lines in 7 to 10 examples. In all, about 470 to 513 lines, 0.6% of
  the diff.
- Tag 1.8.2 is on the 1.8 maintenance branch and is not an ancestor of
  1.9.0: their merge base is 1.8.1, so the snapshot spans 16 months of
  master, not only the release interval.
- Up to about 4,150 structural session lines cannot be attributed from the
  diff. Part A's replay of the 1.8.2 sessions with 1.9.0 and the same
  provers is the real Why3 datum.

## Decisions taken

- Line counts stay those of the tool (no rename detection); reasons give
  the rename-aware figure where it matters (Warblre `a5a3120`, Creusot
  `eef25e4`, Anvil `aa757c8`).
- Linden: `117d534` and `b6396cb` stay in the 9.2 group. They are the cost
  of keeping a version range while porting to 9.2, not work for 9.1 as a
  release.
- AFP `Formula_Derivatives`: release branches are forked from
  `afp-devel` before the release date, so the tool's date-based authors
  were one period off. Corrected by hand in the CSV: the 2025-1..2025-2
  row (0 lines) now has no author, the 2025-2..2026 row has the two
  Isabelle developers whose commits produce its diff. Both reasons say so.
  A re-run of the tool would undo this until it attributes AFP authors by
  content.
- Why3 gallery: prover replays with newer provers are `unrelated`.

## Decisions for a human

1. Should optional or larger-than-needed changes count as adaptation?
   Cases: lean-regex `e1600a1` (251 lines
   delete a broken pretty-printer instead of a one-line fix; counted
   unrelated) and `e2e33d6` (counted in full, an upper bound); EverParse
   `270f5aa` (the root-cause fix, against an 8-line workaround; counted in
   full); Anvil's optional `cargo verus` migration (counted).
2. Creusot: should why3find adaptation count towards the Why3 figure (3
   rows, now `unrelated`)?
3. Should the tool detect renames (`git diff -M`)? It would change several
   projects' raw figures, Creusot `eef25e4` by a factor of 47.
4. Most Why3 and Creusot "adaptation" lines are regenerated proof data:
   report hand-written lines next to total lines?
5. Anvil and Creusot have no per-release figure from the tool; the
   summary divides by the number of releases in the window (Anvil) or
   counts one release step (Creusot). Keep that convention?
6. lean-regex: the 141-line v4.31.0 group is by an outside contributor.
   Does the per-release figure measure maintainer effort or any effort?
7. Port the Why3 gallery decomposition and the AFP author fix into
   `upgrade_mining`, for reproducibility?

## Limits

- Lines are not effort: no hands-on time, no failed attempts, no time
  waiting for a dependency (mathlib, rocq-stdlib) to be released.
- For EverParse and the AFP, the tool's own developers pay the cost.
- Shares are agents' estimates from reading diffs; a row's share is not
  measured line by line except where the reason gives counts.
- The figures are from a one-year window and one to two projects per tool.
