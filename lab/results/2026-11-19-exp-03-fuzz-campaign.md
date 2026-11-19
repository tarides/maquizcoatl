# exp-03 fuzzing campaign: 9 libFuzzer targets, 3.06 CPU-days

## What

One fork-mode libFuzzer campaign over the 8 upstream harnesses of
`upstream/harnesses/` and `fuzzer-deep` (patched copy of `base.c`,
parse depth limit 4096, two-byte pattern size), all built with ASan +
UBSan against `f95747b`, from empty corpora, 40 workers for 110 minutes.

## Why

Done-criterion 2 of issue #9: find the crashes, memory errors and
undefined behaviour that remain in Oniguruma at `f95747b`. The prior
(issue, "Prior") is a low yield, since these harnesses ran under
OSS-Fuzz for years; a low yield is itself the result.

## Provenance

- Same conditions as [provenance](2026-11-19-exp-03-provenance.md):
  commit `7cf1230` of `exp/03-sanitizers-fuzzing`, the blocksci bench
  host (AMD EPYC 7502P, Linux 6.8.0-100-generic), LLVM 21.1.8, `fuzz`
  build flags, every process pinned to CPUs 8-31,40-63.
- Command: `sh experiments/03-sanitizers-fuzzing/fuzz.sh 6600`, i.e. per
  target `-fork=<workers> -ignore_crashes=1 -ignore_timeouts=1
  -ignore_ooms=1 -max_total_time=6600 -timeout=30 -rss_limit_mb=2048
  -print_final_stats=1 -dict=<dict>` (and `-max_len=16384` for
  `fuzzer-deep`), `ASAN_OPTIONS=detect_leaks=1`,
  `UBSAN_OPTIONS=print_stacktrace=1`. Started about 12:15 UTC
  2026-11-19, every target exited 0 by 14:06 UTC.
- Final statistics: `sh experiments/03-sanitizers-fuzzing/stats.sh`
  (one `-runs=0` pass per final corpus, then a `tar -cJf` of each
  corpus). The corpus tarballs are kept outside the repository
  (`<workdir>/exp03-results/corpus-tar/`); only hash and size are
  recorded here.
- Seeds: libFuzzer's own (printed at the top of each log excerpt);
  fork mode makes the run non-reproducible bit for bit.

## Parameters and raw data

Split: planned and actual are identical (`split.tsv`); no worker
restart beyond libFuzzer's own fork jobs. CPU time below is workers ×
libFuzzer's elapsed time (nominal worker-seconds, not measured CPU
time).

| Target | Workers | Time (s) | Worker-hours | Executions | `cov` / `ft` (`-runs=0`) | `cov` / `ft` (fork parent, last) | Corpus files | Corpus bytes | crash / timeout / oom / leak |
|---|---|---|---|---|---|---|---|---|---|
| `fuzzer-encode` | 4 | 6651 | 7.39 | 46,645,431 | 6137 / 30414 | 6137 / 30408 | 9,595 | 490,194 | 0 / 0 / 0 / 0 |
| `fuzzer-syntax` | 4 | 6652 | 7.39 | 49,836,493 | 6353 / 31458 | 6353 / 31417 | 10,215 | 565,184 | 0 / 0 / 0 / 0 |
| `fuzzer-utf16-be` | 3 | 6604 | 5.50 | 26,266,639 | 4808 / 20885 | 4808 / 20879 | 5,646 | 373,652 | 0 / 0 / 0 / 0 |
| `fuzzer-utf16-le` | 3 | 6606 | 5.51 | 25,303,456 | 4836 / 21496 | 4836 / 21479 | 5,826 | 412,822 | 0 / 0 / 0 / 0 |
| `fuzzer-regset` | 6 | 6600 | 11.00 | 86,851,092 | 4982 / 26439 | 4996 / 26978 | 7,252 | 437,224 | 0 / 0 / 0 / 6 |
| `fuzzer-deluxe` | 6 | 6612 | 11.02 | 83,802,591 | 5889 / 31046 | 5888 / 31030 | 9,375 | 714,843 | 0 / 0 / 0 / 0 |
| `libfuzzer-onig` | 3 | 6606 | 5.51 | 57,659,875 | 4405 / 25544 | 4468 / 25600 | 7,661 | 432,588 | 0 / 0 / 0 / 0 |
| `libfuzzer-onig-full` | 3 | 6609 | 5.51 | 54,094,244 | 4488 / 25700 | 4488 / 25690 | 7,729 | 411,850 | 0 / 0 / 0 / 0 |
| `fuzzer-deep` | 8 | 6631 | 14.74 | 79,496,674 | 6229 / 32934 | 6229 / 32924 | 10,855 | 747,855 | 0 / 0 / 0 / 0 |
| **Total** | **40** | | **73.56** (3.06 CPU-days) | **509,956,495** | | | **74,154** | **4,586,212** | **0 / 0 / 0 / 6** |

`fuzzer-regset`'s fork parent counts the 6 leaks as "crash: 6".

Corpus tarballs (`<target>.tar.xz`):

| Target | Bytes | SHA-256 |
|---|---|---|
| `fuzzer-encode` | 519,116 | `f79b5ed5c5e0b00432766d6916f3e90234d9c03e83f739a3f5fc105403c7cd75` |
| `fuzzer-syntax` | 561,292 | `7f7e960000f3fa7f53c42dcbf45f247cb16900a888a6d6338d60634470506fc9` |
| `fuzzer-utf16-be` | 302,108 | `995a085952d8cbfc0e7051ab2b2b6b073d2e88020aa91f147f21a98ae10dcf85` |
| `fuzzer-utf16-le` | 314,084 | `c9db5295a4af64eb8b6dcb8c55629e82ad4b1fadcb4d315d6ec78ef4f1965e2e` |
| `fuzzer-regset` | 399,336 | `bfffa327171b3946cc02e4f254f2b4bcaf0874259d38258de59fc432178262c9` |
| `fuzzer-deluxe` | 540,264 | `f57b614cb027140eb4a36ac79633f2c9067002864724c8f315f7ec2f32fe0bca` |
| `libfuzzer-onig` | 394,408 | `5b2e3db465e978fa82c8a947ac4d3dba23ef7e8dfaa6d3f5543f0f983652fb77` |
| `libfuzzer-onig-full` | 392,204 | `999ad467062314611008c09d58b6beac95fed0491d89f812514f17a3797715da` |
| `fuzzer-deep` | 620,476 | `eb1d5ec6bf757f157985380af95c80f803f567af898d836a21005d168b35e5d0` |

Raw data (paths rewritten to `<hostdir>`):
[`stats/stats.tsv`](2026-11-19-exp-03-raw/stats/stats.tsv), the
`-runs=0` status lines in [`stats/`](2026-11-19-exp-03-raw/stats/), and
per-target log excerpts (header, every 20th status line, tail) in
[`fuzz/`](2026-11-19-exp-03-raw/fuzz/). The full logs stay in
`<workdir>/exp03-results/logs/fuzz/`.

## Analysis and open questions

- **Yield as expected from the prior.** 510 million executions found
  no crash, no ASan or UBSan report and no timeout in the library. The
  only artifacts are 6 leaks from `fuzzer-regset`, all one group, caused
  by the harness (see [triage](2026-11-19-exp-03-triage.md)).
- **`fuzzer-deep` did not reach depth.** Its largest corpus input is 277
  bytes and the deepest parenthesis nesting in its corpus is 36: within
  110 minutes libFuzzer's length control never grew inputs towards the
  16384-byte `-max_len`. The patched harness therefore exercised depth
  only up to about 36, far from the 4096 limit. The depth question of
  decision 3 was answered instead by the directed probe recorded in the
  [triage](2026-11-19-exp-03-triage.md) entry.
- **Coverage still growing at the end.** `fuzzer-deep`'s `ft` rose
  from 32327 to 32924 in its last 25 minutes, and the other targets show
  the same slow growth; the campaign did not saturate.
- Follow-up (out of this run's 3-hour cap): a longer campaign (for
  example a CPU-week) seeded with these corpora, with `fuzzer-deep`
  seeded by the probe inputs and run with `-len_control=0`, so that it
  actually explores deep patterns.
