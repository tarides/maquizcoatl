# exp-03 tests under ASan + UBSan

## What

The 7 default test binaries and `testp` (POSIX API) of `upstream/test/`,
built with ASan and recoverable UBSan (`build/tests`, see
[provenance](2026-11-19-exp-03-provenance.md)), run once each, in
parallel, with every sanitizer report sent to a log file.

## Why

Done-criterion 1 of issue #9. The test suite under UBSan and `testp`
are the surfaces OSS-Fuzz exercised least (issue, "Prior").

## Provenance

Commit `7cf1230`, bench host, LLVM 21.1.8. Command (from
`<hostdir>/src/maquizcoatl`): `sh experiments/03-sanitizers-fuzzing/run-tests.sh tests`;
wall-clock 0.2 s for all 8 binaries; every binary exited 0.

## Raw data

| Binary | RESULT line | Exit | ASan reports | UBSan reports | Leaks |
|---|---|---|---|---|---|
| `test_utf8` | `SUCC: 1554, FAIL: 0, ERROR: 0` | 0 | 0 | 0 | 0 |
| `test_back` | `SUCC: 1225, FAIL: 0, ERROR: 0` | 0 | 0 | 0 | 0 |
| `testc` | `SUCC: 785, FAIL: 0, ERROR: 0` | 0 | 0 | 0 | 0 |
| `testcu` | `SUCC: 720, FAIL: 0, ERROR: 0` | 0 | 0 | 0 | 0 |
| `test_syntax` | `SUCC: 221, FAIL: 0, ERROR: 0` | 0 | 0 | 0 | 0 |
| `test_options` | `SUCC: 47, FAIL: 0, ERROR: 0` | 0 | 0 | 0 | 0 |
| `test_regset` | `SUCC: 13, FAIL: 0, ERROR: 0` | 0 | 0 | 0 | 0 |
| `testp` | `SUCC: 506, FAIL: 0, ERROR: 0` | 0 | 0 | 0 | 0 |

The counts match the unsanitized expectations in the issue (CLAUDE.md
counts, 506 for `testp`). No sanitizer log file was created
(`log_path` writes one only on a report), and stderr is empty for every
binary. The instrumentation was checked: `test_utf8` and `libonig.so`
contain the ASan and UBSan runtime hooks (698 and 135 symbols).

Raw stdout/stderr/exit files: [`2026-11-19-exp-03-raw/tests/`](2026-11-19-exp-03-raw/tests/).

## Analysis

No memory error, undefined behaviour or leak is reachable from the
upstream test suite, `testp` included. So no deviation-log candidate
comes from this pass; any bugs have to come from the fuzzing campaign.
