# exp-03 provenance: sanitizer and fuzzing run on the bench host

## What

Run conditions shared by every exp-03 entry: the machine, toolchain,
builds, flags and sanitizer options used for the test-suite passes and
the fuzzing campaign of experiment #3 (issue #9, plan
`plans/03-sanitizers-fuzzing.md`).

## Why

Every result of #3 (test passes, fuzzing coverage, reproducers) depends on
the compiler, the sanitizer runtimes and the flags; a later replication
or a follow-up campaign has to start from the same conditions.

## Provenance

- Repository commit (scripts, patch, `split.tsv`):
  `7cf12308278221f0a1e4120faa9d7b90e46086d4` on `exp/03-sanitizers-fuzzing`.
- `upstream` at `f95747b` (checked by `setup.sh`); `git -C upstream status`
  clean after the builds.
- Machine: the blocksci bench host, shared with experiments #7 and #11.
  AMD EPYC 7502P 32-Core Processor (1 socket, 32 cores, 64 threads, 1
  NUMA node), 503 GiB RAM, Ubuntu 24.04.5 LTS, Linux 6.8.0-100-generic,
  glibc 2.39. `ulimit -s` = 8192 (KiB).
- CPU use: every build, test and fuzzing process pinned with
  `taskset -c 8-31,40-63` (48 CPUs; #11 pins CPUs 4-7 and their SMT
  siblings 36-39); at most 40 concurrent fuzzing workers.
- Toolchain: official LLVM release `LLVM-21.1.8-Linux-X64.tar.xz`,
  2,019,005,384 bytes, SHA-256
  `b3b7f2801d15d50736acea3c73982994d025b01c2f035b91ae3b49d1b575732b`;
  `clang version 21.1.8 (https://github.com/llvm/llvm-project 2078da43e25a4623cab2d0d60decddf709aaea28)`.
  libFuzzer runtime at
  `lib/clang/21/lib/x86_64-unknown-linux-gnu/libclang_rt.fuzzer.a`
  (per-target layout). A trivial target linked with
  `-fsanitize=fuzzer,address,undefined` ran 100 inputs. Symbolizer: the
  release's `llvm-symbolizer` (`ASAN_SYMBOLIZER_PATH`,
  `UBSAN_SYMBOLIZER_PATH`).
- Host tools: CMake 3.28.3, GNU Make 4.3, Python 3.12.3 (run with `-I`),
  git 2.43.0, tmux 3.4.
- Deviation from plan step 0: the tarball was not pre-downloaded on the
  workstation; it was downloaded and checked on the host (size as
  expected; the libFuzzer path found is the per-target one).
- Run by Claude Code (Opus 5.5) in the experiment pipeline, 2026-11-19,
  12:10-15:10 UTC window.

## Builds

All `cmake -S <hostdir>/src/maquizcoatl/upstream -B <hostdir>/build/<name>`
with `CC`/`CXX` from the toolchain (`build.sh`):

| Build | CMake options | `CMAKE_C_FLAGS` |
|---|---|---|
| `fuzz` | `-DBUILD_SHARED_LIBS=OFF -DBUILD_TEST=OFF -DCMAKE_BUILD_TYPE=` | `-O1 -g -fno-omit-frame-pointer -fsanitize=fuzzer-no-link,address,undefined -fno-sanitize-recover=undefined` |
| `plain` | `-DBUILD_SHARED_LIBS=OFF -DBUILD_TEST=OFF -DCMAKE_BUILD_TYPE=` | `-O1 -g -fno-omit-frame-pointer` |
| `tests` | `-DCMAKE_BUILD_TYPE=Debug -DENABLE_POSIX_API=ON` (shared `libonig.so`) | `-fno-omit-frame-pointer -fsanitize=address,undefined -fsanitize-recover=address,undefined` (+ `-g` from Debug; same sanitizer flags at link) |
| `arith` | `-DCMAKE_BUILD_TYPE=Debug -DENABLE_POSIX_API=ON` | `-fno-omit-frame-pointer -fsanitize=unsigned-integer-overflow,implicit-conversion -fsanitize-recover=unsigned-integer-overflow,implicit-conversion` |

Harnesses (`<hostdir>/harness/`), `-I upstream/src -Wall -O1 -g
-fno-omit-frame-pointer`:

- fuzz targets: `-fsanitize=fuzzer,address,undefined
  -fno-sanitize-recover=undefined`, linked with `build/fuzz/libonig.a`,
  `-D` flags as `upstream/harnesses/makefile:22-62`;
- `read-*` replay binaries (`base.c`, `regset.c`, `deluxe.c`,
  `base-deep.c`): `-fsanitize=fuzzer-no-link,address,undefined
  -fno-sanitize-recover=undefined -DSTANDALONE` (input on stdin);
- `read-deep-plain`: `-DSTANDALONE`, no sanitizer, linked with
  `build/plain/libonig.a`;
- `fuzzer-deep`/`read-deep`/`read-deep-plain` from
  `upstream/harnesses/base.c` plus
  `experiments/03-sanitizers-fuzzing/fuzzer-deep.patch`:
  `PARSE_DEPTH_LIMIT` 8 to 4096, `MAX_SUBEXP_CALL_NEST_LEVEL` 8 to 20,
  two-byte pattern size (`NUM_CONTROL_BYTES` 7 to 8), and the
  `STANDALONE` input buffer made static so that the plain replay measures
  the library's stack and not a 4 MB harness array;
- dictionaries: `ascii_compatible.dict`, and `dict_conv.py utf16_be` /
  `utf16_le` conversions of it.

## Sanitizer options

- Test passes: `ASAN_OPTIONS=halt_on_error=0:detect_leaks=1:log_path=...`,
  `UBSAN_OPTIONS=halt_on_error=0:print_stacktrace=1:log_path=...`.
- Fuzzing: `ASAN_OPTIONS=detect_leaks=1`, `UBSAN_OPTIONS=print_stacktrace=1`;
  libFuzzer flags in `fuzz.sh`.
