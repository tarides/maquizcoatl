# Experiment #9, entry 4: run-1 review fixes (correction 1)

**What.** Three decision-free fixes from the run-1 review
([issue #4 comment](https://github.com/tarides/maquizcoatl/issues/4#issuecomment-7160423453)):
done-criterion 2's case count goes from 50 to **66**, because 16 pure
ASCII literal cases written with escapes the recogniser did not read
are now included; the session wall-clock of run 1 is recorded where the
plan asks for it; three citation ranges in `FRAGMENT.md` are corrected.
This entry supersedes the counts of
[entry 2](2026-11-25-exp-09-cases.md) and the agreement figures of
[entry 3](2026-11-25-exp-09-rocq-m1.md) for the fragment's cases. It
also records the start and end of run 1's session, which
[entry 1](2026-11-25-exp-09-provenance.md) and entry 3 did not record
in full. Those entries are not changed.

**Why.** The fragment of done-criterion 2 is "literals, concatenation,
`|`, `*` and plain groups, no multibyte literal". Run 1's recogniser
(`cases/select.py`) read only `\xHH`, `\x{H}` with one code point, and
escaped metacharacters. It rejected 16 in-context cases whose patterns
are pure ASCII literals. None of them is in experiment #6's `in.tsv`,
because #6's parser does not read these escapes either. So entry 2's
claim that no case outside experiment #6's subset belongs to the
fragment was true only for the escapes the recogniser covered.

## Provenance

As [entry 1](2026-11-25-exp-09-provenance.md): same pins, the same bench
host, and the same C library build (Release, static, reused). Rocq is
9.3.0 on OCaml 5.4.1 (`rocq/version.txt`). Branch
`exp/09-representative-proof`, on top of `4525896`. Commands:

- Workstation, untimed:
  `python3 -I lab/06-spec-speed/cases/extract.py upstream > all.tsv`
  gives 4,565 cases (sha256 `d0386ccf...ecc88f`, unchanged). Then
  `python3 -I lab/09-representative-proof/cases/select.py
  lab/results/2026-11-20-exp-06-raw/in.tsv all.tsv
  lab/09-representative-proof/cases` (exit 0) rewrites
  `cases/fragment.tsv` and `cases/counts.md`.
- Bench host, untimed (`nice -n 10`, CPUs 4-7, load 0.03 to 0.10):
  `BENCH_WORKDIR=<bench-workdir> oracle/oracle.sh r1c`, then
  `rocq/rocq.sh build r1c`, with the new `fragment.tsv` copied over
  the bench clone. Both exited 0, from 11:01:33Z to 11:01:39Z.
- Workstation: `python3 -I cases/agree.py` on both case files (exit 0
  for both).

Nothing was timed. No `.v` file changed, so the check times of entry 3
still hold.

## Fix 1: the recogniser reads more escape forms (count 50 → 66)

`recognise()` in `cases/select.py` now also reads the following forms,
using `upstream/src/regparse.c` as the reference:

- `\cX` and `\C-X`, which give `X & 0x9f`. `\c?` gives `0x7f`, and `X`
  may be an escaped non-alphanumeric ASCII character
  (`regparse.c:4772-4801`).
- `\o{...}` and `\x{...}` with one or more code points, separated by
  spaces or newlines, with at most 11 octal or 8 hex digits each, and
  optional separators before the `}` (`:5855-5903`, `:3723-3738`,
  `:3811-3859`). A quantifier after a sequence of several code points
  is left out conservatively.
- `\uHHHH`, with exactly 4 hex digits (`:5917-5927`).

The ill-formed forms are still rejected, and their test cases are kind
`e`: too many digits, a missing `}`, or a stray character such as `/`.

`select.py` now adds a case to `fragment.tsv` when the recogniser accepts
it in context, the case is not in `in.tsv`, and it is not of kind `e`.
The added row uses the recogniser's AST (`Cat` of `Lit`) and the
extraction's columns. The `index` column is the row number in `all.tsv`,
as in `in.tsv`. A case that is in `in.tsv` but was dropped there is
still a re-check failure. The 50 rows of run 1 are unchanged.

| | x2 | x3 | n | e | total |
|---|---:|---:|---:|---:|---:|
| fragment, from experiment #6's `in.tsv` | 36 | 13 | 1 | 0 | 50 |
| fragment, added from the full extraction | 16 | 0 | 0 | 0 | 16 |
| **fragment, total** | 52 | 13 | 1 | 0 | **66** |

Re-check over the full extraction: OK, with 66 in-context cases of
fragment syntax.

The 16 added cases, all from `test_utf8`:

| Line | Pattern | AST |
|---|---|---|
| 167 | `\ca` | `L01` |
| 168 | `\C-b` | `L02` |
| 169 | `\c\\` | `L1c` |
| 750 | `\o{101}` | `L41` |
| 1363 | `@` | `L40` |
| 1604 | `\x{000A 002f}` | 2 literals |
| 1605 | `\x{000A 002f }` | 2 literals |
| 1606 | `\x{007C     001b}` | 2 literals |
| 1607 | `\x{1 2 ... f}` | 15 literals |
| 1608 | `a\x{000A 002f}@` | 4 literals |
| 1609 | `a\x{0060`(newline)`0063}@` | 4 literals |
| 1617 | `\o{102}` | `L42` |
| 1618 | `\o{102 103}` | 2 literals |
| 1619 | `\o{0160 0000161}` | 2 literals |
| 1620 | `\o{1 2 ... 17}` | 15 literals |
| 1621 | `\o{0007 0010 }` | 2 literals |

The table in `counts.md` that lists fragment syntax outside the context
is informational and changed with the recogniser: backward search
47 → 52, EUC-JP 44 → 48, and one new PYTHON case. Its other rows are
unchanged.

### C oracle and Rocq agreement on the 66 cases

Raw: [oracle/](2026-11-25-exp-09-correction-1-raw/oracle/) and
[rocq/](2026-11-25-exp-09-correction-1-raw/rocq/), fragment files only.
The four extra probes gave byte-identical files (`extra.*.txt`,
`extra.verdicts.txt`), so they are deterministic duplicates of
entries 2 and 3 and are not recorded again. The new raw files contain
every line of run 1's fragment files unchanged, plus 16 search
verdicts, 72 start-position verdicts and 264 driver lines.

| Cases | Engine | search = C | every start position = C |
|---|---|---:|---:|
| fragment (66, none excluded) | vm | 66/66 | 273/273 |
| | sem | 66/66 | 273/273 |
| | e06 (experiment #6's `Spec2.v`) | 66/66 | 273/273 |
| extra probes (4) | vm, sem, e06 | 4/4 each | 10/10 each |

The C search agrees with the upstream test expectation on 66/66. No
case hits the retry limit or a C error (`excluded.txt` is empty). The
driver has 1,017 lines = 3 × (273 + 66). The added cases exercise only
`IStr`, so nothing changes about loops: the empty check is still
exercised only by the 4 probes.

## Fix 2: session wall-clock of run 1

- Run 1 started no later than **2026-11-25T10:35:00Z**. That is the time
  of merge commit `1dbf4ba` (origin/main into the branch), the run's
  first recorded action. The exact start was not recorded.
- Run 1 ended at **2026-11-25T10:50:36Z**, the time of the run-1 commit
  `4525896`.
- The start recorded in entries 1 and 3, 10:37:44Z, was taken after
  the merge. The window from 10:37:44Z to 10:50:36Z covers the bench
  work and the commit, but not the merge or anything done before it.
  Run 1's session therefore took at least 15 min 36 s, not 12 min 52 s.
- This fix session started at 2026-11-25T10:59:48Z, the first timestamp
  taken after reading the review. It ended at 2026-11-25T11:02:57Z, a timestamp taken just
  before the commit that carries this entry. The window covers
  applying the three fixes, the reruns and the commit, but not the
  issue comment and dashboard update that came after.

These times are also recorded in
[effort.tsv](../09-representative-proof/effort.tsv), in rows appended
under run label `1-fix`.

## Fix 3: citation ranges in FRAGMENT.md

The other upstream citations were confirmed by the review.

| Where | Was | Now |
|---|---|---|
| section 2, peephole variants | `regcomp.c:1444-1485` | `:1464-1488`, and `:1444-1452` for the jump prefix of `lower == 1` |
| section 3, plain `OP_PUSH` | `:1488-1497` | `:1489-1498` |
| `push_mem_end` | `:7550-7557` | `:7547-7551` (the `USE_CALLOUT` branch) |

## Analysis and open questions

- The fragment's upstream count is 66. All 16 additions are straight-line
  literals, so they add breadth to the literal and concatenation cases
  but none to the loop cases.
- The review's follow-ups are not applied here. They are: make an unknown
  AST operator a drop reason in `drop_reason`, compare with
  `ONIG_DEBUG_COMPILE`, and add random differential testing.
- Next in the plan: run 2 (F\* M1).
