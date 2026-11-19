# Experiment #7, entry 2: fidelity of the parsed table, C oracle, query sample

**What.** Steps 4-6 of the plan: parse `upstream/src/unicode_property_data.c`,
check its counts, regenerate the tables with the upstream generator on
UCD 16.0.0 and compare, build the C oracle and the query sample used by
criterion 5.

**Why.** Every later number assumes the per-tool tables are the C
tables. Agreement with the generator is also evidence for the "check
the generator output" path of the report's "Generated tables" item.

## Provenance

- Scripts: `lab/07-large-tables/emit.py`, `fidelity.py`, `fidelity.sh`,
  `oracle.c`, `latin1diff.c`, `sample.py` (commit `2072e9c`).
  Command: `lab/fidelity.sh` on the bench host (CPU and OS as in entry 1).
- Upstream `f95747b`, out-of-tree `-DCMAKE_BUILD_TYPE=Release` build, GCC 13.3.0.
- UCD 16.0.0 from `https://www.unicode.org/Public/16.0.0/ucd/`
  (`GraphemeBreakProperty.txt` from `auxiliary/`, `emoji-data.txt` from
  `emoji/`); sha256 in [raw/fidelity/ucd.sha256](2026-11-19-exp-07-raw/fidelity/ucd.sha256).

## Raw data

From [raw/fidelity/fidelity.tsv](2026-11-19-exp-07-raw/fidelity/fidelity.tsv):

| Check | Value |
|-------|-------|
| `CR_*` arrays | 612 |
| ranges | 24,443 |
| `CodeRanges` entries (= `CODE_RANGES_NUM`) | 629 (612 + 17 aliases) |
| property names (= `TOTAL_KEYWORDS`) | 886, mapping onto all 629 ctypes |
| ranges violating "lo <= hi, hi + 1 < next lo" | 0 |
| generator (`make_unicode_property_data.py` on UCD 16.0.0): arrays | 612, **0 differences** |
| generator: name/ctype pairs | 886, **0 differences** |

Query sample (`sample.py gen`): **85,772** ctype queries (every range
endpoint and its neighbours `lo-1, lo, hi, hi+1`, clipped to
`[0, 0x10FFFF]`, deduplicated per ctype, for all 629 ctypes) plus the
886 names, 86,658 answer lines in all. The plan's "about 98k" was an
estimate before deduplication. sha256 of the sample files in
[raw/fidelity/sample.sha256](2026-11-19-exp-07-raw/fidelity/sample.sha256).

C oracle (`oracle.c`): table answer = `onig_is_in_code_range` on the array
returned by `onigenc_unicode_ctype_code_range`; names through
`ONIGENC_PROPERTY_NAME_TO_CTYPE`. Oracle versus the parsed table:
**86,658 lines, 0 mismatches** (the 886 names map to the same ctypes as the
gperf word list).

Generated per-tool sources (not committed; `emit.py` regenerates them),
from [raw/emitted.tsv](2026-11-19-exp-07-raw/emitted.tsv):

| File | Bytes | sha256 (prefix) |
|------|------:|-----------------|
| `rocq/Table.v` | 439,613 | 198ebf5c |
| `lean/Table.lean` | 436,408 | a80d6bf6 |
| `why3/table.mlw` | 605,937 | dc9862e2 |
| `why3/tablec.mlw` (decision trees, C target) | 2,003,141 | 6cfdc6a4 |
| `fstar/Table.fst` | 430,263 | 1db64c0a |
| `fstar/TableC.fst` (decision trees, C targets) | 1,898,462 | bb7a7f33 |
| `fstar/PulseTable.fst` (Pulse static arrays, C targets) | 771,106 | bae8e22b |

## Finding for the deviation log: `onigenc_unicode_is_code_ctype` vs `CR_*`

`latin1diff.c` compares, for the 15 standard ctypes (0-14) and every code
point below 256, `onigenc_unicode_is_code_ctype` (`upstream/src/regenc.h:186`,
which answers from the ISO-8859-1 ctype table for `ctype <= 14` and
`code < 256`) with the `CR_*` table. They disagree on exactly 13 code
points, all "in the ISO table, not in `CR_*`"
([raw/fidelity/latin1-diff.txt](2026-11-19-exp-07-raw/fidelity/latin1-diff.txt)):

| ctype | Code points |
|-------|-------------|
| 3 (`Cntrl`) | U+00AD |
| 7 (`Print`) | U+0009-U+000D, U+0085 |
| 12 (`Word`) | U+00B2, U+00B3, U+00B9, U+00BC-U+00BE |

So `\p{Cntrl}`, `\p{Print}` and `\p{Word}` below U+0100 come from the
ISO-8859-1 table, not from the Unicode data. One of the 13 (U+00B9 for
`Word`) is in the sample; that is why criterion 5 compares against the
table answer, not `is_code_ctype`. The spec must say which definition it
takes; recorded here as a candidate entry for the deviation log.
