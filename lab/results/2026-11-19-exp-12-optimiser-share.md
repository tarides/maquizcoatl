# Experiment #12, entry 9: the search optimiser's share of the large-subject gap

**What.** A fourth out-of-tree build of `f95747b` with the search
optimiser compiled out (`-DONIG_DONT_OPTIMIZE`,
`upstream/src/regint.h:39`), run through the existing C driver on the
large-subject shape of [entry 5](2026-11-19-exp-12-large.md), interleaved
with the optimised C driver and the VM (`ffi` switch). Run `r2`.

**Why.** Automated results review on issue #10
([comment](https://github.com/tarides/maquizcoatl/issues/10#issuecomment-7017131208)),
problem 3: entries 5 and 7 said that the VM's 7-11x large-subject gap
"comes mostly from the missing search optimiser, not from OCaml". That
was inferred from the optimiser's choices, not measured. Removing the
optimiser from Oniguruma itself splits the gap into "no search
optimiser" (optimised C to unoptimised C) and "the rest of the engine"
(unoptimised C to the VM).

## What `ONIG_DONT_OPTIMIZE` removes

In `upstream/src/regcomp.c:7561-7572` it skips
`set_optimize_info_from_tree` after `clear_optimize_info`. The regex
keeps `OPTIMIZE_NONE`, no exact string or first-byte map, no anchor
information and no `dmin`/`dmax` bounds. `onig_search` then calls
`match_at` at every start position. The bytecode compiler, including
the peephole ops that [entry 3](2026-11-19-exp-12-agreement.md) relates
to the retry-count difference (`upstream/src/regcomp.c:1430-1460`), is
unchanged. What remains is Oniguruma's matcher without search skipping,
which is how the VM searches.

## Provenance

- Branch `exp/12-ffi-vs-native` at `5bb7b02` (`setup.sh cbuild-noopt`, the
  `c-noopt` engine and `ENGINES_ONLY` in `run.py`; no change to the C
  driver or the harness).
- Build `<bench-workdir>/exp/12-ffi-vs-native/build/onig-noopt`:
  `CMAKE_BUILD_TYPE=Release` (`-O3 -DNDEBUG`), `BUILD_SHARED_LIBS=ON`,
  `CMAKE_C_FLAGS=-DONIG_DONT_OPTIMIZE`, GCC 13.3.0, CMake 3.28.3.
  `cdriver-noopt` is `bench/cdriver.c` compiled as in run `r1` (GCC
  `-O2`) and linked with rpath to that build (checked with `ldd`).
  `test_utf8` of this build: 1,554 / 0 / 0
  ([entry 8](2026-11-19-exp-12-provenance-addendum.md)).
- Other columns: the `r1` binaries, unchanged (`cdriver` against
  `onig-release`, `main-ffi.exe` VM).
- Host: the bench host, AMD EPYC 7502P, Ubuntu 24.04.5 LTS, Linux
  6.8.0-100-generic, CPU 2 governor `schedutil`.
- Command: `ENGINES_ONLY=c,c-noopt,vm EXP=<exp> python3 -I run.py large r2 10 16`
  on a copy of `r1`'s `work/` directory (same `large.list`, same
  patterns, same subjects), 2026-11-19 17:47:30-17:56:12 UTC. Same
  protocol as entry 5: one process per (engine, source, size, pattern)
  and run, under `taskset -c 2` and `timeout 120`; subject loaded, one
  untimed warm-up scan, one timed scan; 10 interleaved runs, run r in an
  order shuffled with seed r. 192 cells, 1,920 processes, every exit
  code 0.
- Load: 1-minute load average 1.11-2.23 over the series. Experiment #11
  was detected at the start only (one of its timed processes, CPU
  affinity 0-63, not pinned off CPU 2), and not at any later check. The
  other load was unrelated services on other cores. The `r1` columns
  reproduce within 0.3% of entry 5 (for example C on `log-1m` 660.6
  against 662.0 MB/s, VM on `src-16m` 57.9 against 57.9).

Raw: [`r2/large.csv`](2026-11-19-exp-12-raw/r2/large.csv) (one row per
run and cell, with seed and order),
[`r2/conditions.csv`](2026-11-19-exp-12-raw/r2/conditions.csv),
per pattern (min, median, IQR):
[`r2/large-patterns.csv`](2026-11-19-exp-12-raw/r2/large-patterns.csv).
No cell has an IQR above 10% of its median. All three engines find the
same number of matches on all 64 (subject, pattern) pairs.

## Results: median over the 16 patterns of each pattern's median (10 runs), MB/s

| Subject | C, optimised | C, `ONIG_DONT_OPTIMIZE` | VM `ffi` | C opt. / C no-opt. | C no-opt. / VM | optimiser's share of the C-to-VM time gap |
|---|---|---|---|---|---|---|
| log-1m | 660.6 (35.1..1,204) | 78.1 (35.9..79.0) | 58.1 (17.6..69.1) | 8.5x | 1.34x | 72% |
| log-16m | 664.1 (35.2..1,225) | 78.1 (36.0..79.0) | 58.2 (17.6..69.3) | 8.5x | 1.34x | 72% |
| src-1m | 513.3 (98.9..1,231) | 76.3 (30.7..78.6) | 58.0 (15.8..67.4) | 6.7x | 1.32x | 72% |
| src-16m | 441.8 (129.4..1,212) | 74.8 (32.5..78.8) | 57.9 (16.0..67.3) | 5.9x | 1.29x | 72% |

MB = 10^6 bytes; ranges are min..max of the per-pattern medians. The
share is computed per pattern on time per byte, as
(t_no-opt − t_opt) / (t_VM − t_opt), and the median over the 16
patterns is shown. Per pattern it ranges from 41% to 90% on `src` and
from −8% to 95% on `log`.
The −8% is `\s*(\[)`, where the optimised build is slower than the
unoptimised one (35.2 against 37.3 MB/s): the `\s*` prefix defeats
the exact-`[` skip (`dmax` infinite), so the optimiser only adds work.

Per pattern on the 16 MiB subjects, C no-opt. / VM is 1.04-1.16x on
single-byte literals, 1.35-1.37x on two- and three-byte literals
(`\+\+`, `--`, `=>`, `/\*`, `\.\.\.`) and 1.87-2.19x on alternations
(`%|\*|/|-|\+`, `\&|~|\^|\|`, `<<|>>>|>>`, `<=|>=|<>|<|>`) and on
`\s*(\[)` (1.82x).

## Analysis

- **The optimiser is most of the gap, now measured.** Without its
  search optimiser, Oniguruma itself drops from 440-660 MB/s to
  75-78 MB/s (5.9-8.5x) on these patterns. That is about 72% of the
  time the VM loses against optimised Oniguruma. Expressed per MiB on
  `log`, the gap is 1.6 ms (C) → 13.4 ms (no optimiser) → 18.0 ms (VM).
  Entries 5 and 7's reading ("mostly the missing search optimiser") is
  confirmed on these patterns.
- **The rest of the gap is the engine:** the VM is 1.3x slower than
  Oniguruma's unoptimised matcher (median), 1.1-1.4x on literals and
  about 2x on alternations, where the VM pushes one choice point per
  alternative at each byte. Why Oniguruma's matcher does better on
  alternations was not measured. The residual is in the range of the
  2-3.4x per retry on catastrophic patterns
  ([entry 6](2026-11-19-exp-12-catastrophic.md)), which also involve no
  search skipping.
- The large-subject patterns are all literals or literal alternations
  (entry 5); on patterns that defeat the optimiser the share is smaller
  (`\s*(\[)`: none). A second pattern ranking, by VM time per call,
  would measure where the optimiser matters least (follow-up).
- The `ONIG_DONT_OPTIMIZE` column also gives issue #22 an
  optimiser-free C baseline for generated OCaml.
