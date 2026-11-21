# exp-03 depth probe re-run with the scripted steps (workstation)

## What

A re-run of the directed depth probe of the
[triage](2026-11-19-exp-03-triage.md) entry on a second machine, using
the scripted versions of the two steps that were first run by hand: the
`read-deep-ns` replay and the `ulimit -s` bisection of the plain build.
Every outcome of the first run is reproduced; the plain-build stack
needs agree within one bisection step.

## Why

The results review on issue #9 (problem 5) found that
`read-deep-ns.tsv`, `plain-small-stack.tsv` and `plain-min-stack.tsv`
came from steps that existed only as prose. `build.sh` and
`deep-probe.py` now do them; this run checks that the scripts reproduce
the recorded tables, and gives a second-machine data point for the
5.6 MiB stack need of `absent` at depth 2047.

## Provenance

- Commit `6b9a908` of `exp/03-sanitizers-fuzzing` (scripts),
  `upstream` at `f95747b`, submodule clean after the build.
- Machine: the maintainer's workstation (not the bench host), 12th Gen
  Intel Core i7-1260P (16 threads), 16 GB RAM, Ubuntu, Linux
  7.0.0-43-generic, glibc 2.43, `ulimit -s` = 8192 KiB; not pinned.
- Toolchain: Ubuntu clang 21.1.8 (`6ubuntu1`), not the LLVM release
  tarball of the first run; CMake 4.2.3, Python 3.14.4.
- Builds: the `fuzz` and `plain` library builds and the `read-deep`,
  `read-deep-ns` and `read-deep-plain` lines of `build.sh`, run by hand
  out of tree with the same flags (`-O1 -g -fno-omit-frame-pointer`;
  ASan + UBSan `-fno-sanitize-recover=undefined` for the sanitized
  ones).
- Command: `python3 -I experiments/03-sanitizers-fuzzing/deep-probe.py
  <harness-dir> <out-dir>`; exit 0, 44 s wall-clock. Run 2026-11-19
  around 16:10 UTC.

## Raw data

[`raw/probe-rerun-local/`](2026-11-19-exp-03-raw/probe-rerun-local/):
`probe.tsv` (stdout), `read-deep-ns.tsv`, `plain-small-stack.tsv`,
`plain-min-stack.tsv`. The 20 generated inputs are byte-identical to
[`repro/deep-probe/`](2026-11-19-exp-03-repro/deep-probe/).

Comparison with the first run ([`raw/probe/`](2026-11-19-exp-03-raw/probe/)):

- `probe.tsv`: same k for every shape (2047, `cclass` 4094); same
  `read-deep-plain` outcomes; `read-deep` again aborts on the harness's
  `base.c:98` UBSan report for all 20 inputs.
- `read-deep-ns.tsv`: identical (only `absent-2047` overflows, under
  ASan; `lookbehind-2047` hits the retry limit; every k+1 input gets
  `parse depth limit over`).
- `plain-small-stack.tsv`: identical (SIGSEGV, exit 139, for all 10
  inputs at 1024, 512 and 256 KiB).
- `plain-min-stack.tsv` (largest crashing / smallest passing
  `ulimit -s`, KiB):

| Input | First run | This run |
|---|---|---|
| `absent-2047` | 5770 / 5784 | 5756 / 5770 |
| `cclass-4094` | 2550 / 2564 | 2564 / 2578 |
| `alt`, `atomic`, `option` at 2047 | 1402 / 1416 | 1416 / 1430 |
| `group`, `noncap`, `lookahead`, `lookbehind`, `quant` at 2047 | 1416 / 1430 | 1416 / 1430 |

## Analysis

- The scripted steps reproduce the hand-run tables; the triage entry's
  conclusions (no plain-build overflow within the depth limit at 8 MiB;
  `absent` an ASan-only resource finding, about 5.6 MiB in the plain
  build) hold on a second machine and compiler build.
- The stack needs differ by at most one bisection step (14 KiB). The
  measurement is not fully deterministic: a first scratch run of the
  same script on this machine gave `absent-2047` 5770 / 5784, so the
  boundary moves by a step between runs (stack placement, environment
  size). Quote these figures as ±16 KiB.
