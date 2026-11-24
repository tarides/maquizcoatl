# exp-05 toolchains-m1: Why3, F\* + Pulse and Verus on the bench host

## What

Approach steps 2 to 4 of `plans/05-unverified-calls.md` for milestone 1
(issue #13), on the bench host: clone of the branch with `upstream/`,
out-of-tree upstream build and its two sanity tests, `setup.sh 1`
(toolchains of Why3, F\* + Pulse with KaRaMeL, and Verus, each
smoke-tested on a hello world), and the caller check. Raw logs, all
redacted by the scripts, are in
[`2026-11-19-exp-05-toolchains-m1-raw/`](2026-11-19-exp-05-toolchains-m1-raw/).

## Why

The prototypes of step 5 need three working toolchains and a caller
whose output is known to match `expected.txt` on the host where they
run. This entry fixes the versions and shows each tool can verify,
extract or compile a trivial function before any prototype work.

## Setup

- Repository at `exp/05-unverified-calls` `3e53f36` (the recorded
  `setup.sh 1` run), cloned with `--recurse-submodules` into
  `<exp>/repo`; `upstream/` at
  `f95747b462de672b6f8dbdeb478245ddf061ca53`, both as gitlink and as
  checkout (`pinned=yes`).
- Bench host: AMD EPYC 7502P (64 CPUs online), Ubuntu 24.04.5 LTS,
  Linux 6.8.0-100, GCC 13.3.0, CMake 3.28.3. Load average 0.41 at start.
- CPUs: no process on the host had a restricted affinity when checked.
  The upstream build ran on CPUs 8-11, `setup.sh` on 12-15 and the
  caller check on 16-17, all under `nice -n 10`, 4 jobs at most. CPUs
  4-7 and 36-39 were not used.
- Caches: `<cache>` is this account's own cache, `<shared-cache>`
  experiment #7's (read only). See the deviations below.

## Upstream build and sanity tests (step 2)

`cmake -S <exp>/repo/upstream -B <exp>/build/onig
-DCMAKE_BUILD_TYPE=Debug`, `make -j4` (4 s), then:

| Test | Result |
|---|---|
| `test_utf8` | SUCC: 1554, FAIL: 0, ERROR: 0 |
| `test_back` | SUCC: 1225, FAIL: 0, ERROR: 0 |

`upstream/` stays clean after the build (0 changed files).

## Toolchains (step 3)

| Tool | Version | Source | Smoke test | Disk (in `<cache>`) |
|---|---|---|---|---|
| Why3 | 1.9.0 | `<shared-cache>`, switch `provers` (read only) | `add1` on `int32` proved by Alt-Ergo (7 steps) and Z3 4.15.3 (1255 steps), extracted with `why3 extract -D c`, compiled with `cc -std=c11` | 16 KB (`why3/`: configuration and Z3 link) |
| Alt-Ergo | opam package 2.6.5; the binary prints `v2.6.4-1-g997f541` | same switch | used by the Why3 smoke test | (shared) |
| Z3 for Why3 | 4.15.3 | F\* bundle in `<cache>/fstar` | registered in `<cache>/why3/why3.conf` | (in F\*) |
| F\* + Pulse | 2026.11.15 (commit `b92b0f87`) | release tarball, sha256 as pinned, in `<cache>/fstar` | `#lang-pulse` function checked, extracted with `--codegen KrmlC --custard_entry Smoke.add1`, `krml -skip-compilation`, compiled with `cc -std=gnu11` (`Smoke_add1` in `Custard.c`) | 718 MB (+ 240 MB tarball) |
| KaRaMeL | `3384ecaf` (bundled with F\*) | same | same | (in F\*) |
| rustup | 1.29.3 | `rustup-init`, sha256 as pinned | | 21 MB (`cargo/`) |
| Rust | 1.99.1 (`58cf8f9c3`), components rustc, rust-std, cargo, rustfmt, rustc-dev, llvm-tools | rustup in `<cache>` | | 1.5 GB |
| Verus | 0.2026.11.02.8bf68ee (commit `8bf68ee7`) | release zip, sha256 as pinned | `add1` verified (2 verified, 0 errors), then compiled with `--compile` and run | 133 MB (+ 35 MB zip) |
| jq | 1.8.2 | release binary, sha256 pinned in `lib.sh` | reads `pins.json` | 2.2 MB |

Install times (first runs): Rust toolchain 21 s, Verus 2 s, F\* 10 s.
The recorded run is idempotent and takes 9 s. Total `<cache>` use
after milestone 1: 2.6 GB (downloads 296 MB of it); `<exp>`: 53 MB.
About 101 GB remain free on the disk.

## Caller check (step 4)

On the bench host, `caller/caller.c` and `caller/reference.c` built with
`cc -std=c11 -Wall -Wextra -Wpedantic -Werror
-fsanitize=address,undefined -fno-sanitize-recover=all`: exit 0, output
equal to `caller/expected.txt` (`failures=0`), nothing on stderr. Through
the harness, `run.sh reference m1-caller-check` (CPUs 16-17):
`build_status=0`, `link=ok`, `caller_status=0`, `caller_output=same`.

## Usable per tool

- **Why3**: usable. Why3 and Alt-Ergo from the shared switch, Z3 4.15.3
  registered in this account's configuration; proof and C extraction
  work.
- **F\* + Pulse with KaRaMeL**: usable from this account's own copy of
  the same release. Check, `KrmlC` extraction, `krml` and C compilation
  work.
- **Verus**: usable. Verification and compilation work with Rust 1.99.1
  from this account's rustup.

## Deviations found on the bench host

These add to the deviations decided on issue #13 (recorded in the
`harness` entry and the plan).

- **F\* is not used from the shared cache.** About 1,400 files of the
  shared F\* (among them 377 of the 378 `.checked` files of its standard
  library and 233 of Pulse's 235) are readable only by their owner.
  From this account F\* reports them as corrupt, rechecks the library,
  and then refuses to write a
  `.checked` file for the user's module, so extraction fails
  ("Cross-module inlining expects all modules to be checked first").
  The same release (v2026.11.15, the pinned sha256) is installed into
  `<cache>/fstar`, and Why3's Z3 is taken from it. The shared cache is
  used only for the switch `provers` (Why3, Alt-Ergo).
- **jq** is not installed on the bench host, and the scripts read
  `pins.json` with it: `setup.sh` installs the jq 1.8.2 release binary
  into `<cache>/bin` (sha256 pinned in `lib.sh`).
- **Alt-Ergo's version string.** The opam package is 2.6.5 but the
  binary prints `v2.6.4-1-g997f541`, which Why3 1.9.0 does not parse:
  Alt-Ergo is registered with an empty version, as in experiment #7's
  configuration. Why3 still runs it (the smoke test proves its goal).
- **Why3's Z3 detection.** `why3 config detect` takes the first `z3` on
  `PATH`; Verus's directory holds Z3 4.16.0, which Why3 1.9.0 does not
  know. Detection now puts the F\* Z3 4.15.3 first, and `setup.sh`
  checks the registered version.
- **F\* v2026.11.15's command line** differs from the plan's smoke
  command: `--codegen KrmlC` and `--custard_entry` instead of
  `--codegen krml` and `--extract`, with a check pass first (experiment
  #7's commands). krmllib's headers need `-std=gnu11` (they use
  `htole64` and friends).
