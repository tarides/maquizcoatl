# Experiment #12, entry 1: provenance, subjects and subset coverage

**What.** Run conditions of experiment #12 (issue #10, "FFI versus native
OCaml"): the two opam switches, the out-of-tree builds of `f95747b`, the
large subjects, and how much of experiment #1's workloads the regular
subset covers.

**Why.** Criterion 5 asks for provenance on every run; criterion 1 asks
for the subset's coverage of the experiment #1 workloads. The switches
`ffi` and `ffi-flambda` in the shared cache are meant to be reused by
issue #22 (generated OCaml).

## Provenance (all entries of this experiment)

- Branch `exp/12-ffi-vs-native`: code at `3d11767` (VM, bindings, harness,
  scripts), C driver hex-decoding fix at `37370a2` (C driver rebuilt before
  the timed series; the change is outside the timed region). Plan:
  `plans/12-ffi-vs-native.md`.
- Upstream: `f95747b`. Builds out of tree on the bench host under
  `<bench-workdir>/exp/12-ffi-vs-native/build/`:
  `onig-release` (`CMAKE_BUILD_TYPE=Release`, `BUILD_SHARED_LIBS=ON`,
  effective flags `-O3 -DNDEBUG`, `CMAKE_C_FLAGS` empty) used by the C
  driver, the stubs and ctypes (one shared `libonig.so`); `onig-debug`
  (`Debug`, `-g`) for the test suite; `onig-dbgc` (`Debug`,
  `-DONIG_DEBUG_COMPILE`, library only) for the optimiser dump, never timed.
- Toolchain: opam 2.6.1 (shared `<cache>`; `opam update` found no
  change), OCaml 5.4.1 in two new switches: `ffi`
  (`ocaml-base-compiler.5.4.1`, `flambda: false`) and `ffi-flambda`
  (`ocaml-variants.5.4.1+options` + `ocaml-option-flambda`,
  `flambda: true`); both `flat_float_array: true`. Packages in both:
  dune 3.25.0, ctypes 0.24.0, ctypes-foreign 0.24.0, re 1.14.0,
  mtime 2.2.0, conf-libffi 2.0.0; libffi 3.4.6 (Ubuntu package; the
  issue mentions 3.5.2). OCaml code built with `dune --profile release`;
  in `ffi-flambda`, `-O3` is added to `ocamlopt` (there is no
  `ocaml-option-O3` opam package, so `-O3` is a per-build flag, see
  `lab/12-ffi-vs-native/dune`). `-unsafe` not used. C driver and stubs:
  GCC 13.3.0 `-O2`. CMake 3.28.3, Python 3.12.3 (`-I`).
- Host: the bench host, AMD EPYC 7502P 32-Core Processor, 64 hardware
  threads, 503 GiB RAM, Ubuntu 24.04.5 LTS, Linux 6.8.0-100-generic.
  Builds and untimed jobs: `taskset -c 0-3,32-35`, at most 4 jobs.
  Timed processes: `taskset -c 2`, one at a time, nothing else of this
  experiment running. CPU 2 governor `schedutil` throughout.
- Wall-clock: run started 16:49 UTC (switches), timed series
  17:12-17:30 UTC; about 1 h in total on the host.
- Other load: per series, see `conditions.csv` in the raw directory
  (1-minute load average before and after every interleaved run, and
  the experiments detected in the process list, by number). Short
  series: load 0.29-1.04, no other experiment detected. Large series:
  1.01-2.01, experiment #11 detected from 17:2x. Catastrophic series:
  1.93-2.12, experiment #11 running. Experiment #4 was not detected
  during any series. No series started above the load-16 flag.
  Unrelated services (a database server, a web server) ran on other
  cores.
- Full machine-readable record: [`provenance.txt`](2026-11-19-exp-12-raw/provenance.txt).

## Large subjects

Built by `lab/12-ffi-vs-native/subjects.sh`, cut at a line boundary.

| Subject | Source | Bytes | Lines | ASCII only | sha256 |
|---|---|---|---|---|---|
| `src-1m` | OCaml 5.4.1 tarball (sha256 `d4528517…e89a`, from the opam download cache): every `.ml`, `.mli`, `.c`, `.h`, sorted by path, whole files | 1,048,516 | 28,513 | no | `3cf852ad…4910` |
| `src-16m` | same | 16,777,184 | 486,404 | no | `1dd6e261…a5ec` |
| `log-1m` | Loghub `SSH.tar.gz` (Zenodo record 8196385, sha256 `296610a3…2712`), `SSH.log` (73,417,506 bytes) | 1,048,533 | 9,484 | yes | `37929e1f…59be` |
| `log-16m` | same | 16,777,073 | 152,559 | yes | `82ef8ecc…1727` |

Full hashes: [`subjects-manifest.txt`](2026-11-19-exp-12-raw/subjects-manifest.txt), `lab/12-ffi-vs-native/pins.json`.

## Subset coverage of experiment #1's workloads

The classifier is the VM's parser in strict mode
(`lab/12-ffi-vs-native/vm/vm.ml`), applied per call with its subject
(the ASCII rule for `\d \w \s`: admitted when the matching `*_IS_ASCII`
option is set or the subject is ASCII only).

| Family | Triples in subset / total | Calls in subset / total | Weighted calls (frequency profile) | Top rejection reasons (calls) |
|---|---|---|---|---|
| jq | 21 / 44 | 136 / 217 (62.7%) | - | `(?` group 41, option IGNORECASE 26, FIND_NOT_EMPTY 6, `\b` 5 |
| PHP | 61 / 187 | 159 / 421 (37.8%) | - | non-UTF-8 encoding 151, nested class / POSIX bracket 39, `(?` group 23, EXTEND 14, Unicode ctype on non-ASCII subject 12 |
| VS Code | 949 / 4,221 | 123,982 / 429,020 (28.9%) | 198,837 / 759,850 (26.2%) | `(?` group (lookaround, inline options) 397,571, `\b` 95,818, nested class / POSIX bracket 29,221, possessive 21,512, escaped non-ASCII 10,785 |
| PHP long subjects (synthetic) | 4 / 5 | 13 / 18 | - | IGNORECASE 5 |

Triples are counted per (syntax, options, retry limit, stack limit,
pattern). VS Code calls are the 11,263 committed scanner searches
expanded to one `onig_search` per member triple (429,020 searches,
weighted by the frequency profile: 759,850 per pass). No in-subset
workload call is a compile error. Per-call classification:
`work/*.coverage.tsv` in the raw directory.

VS Code coverage (26-29%) is above the plan's 20% alarm level but low:
the short-subject VS Code figures describe the regular quarter of the
call mix, dominated by literal and alternation-of-literal patterns.

## Plan deviations recorded here

- `ffi-flambda` has no `ocaml-option-O3` (the package does not exist);
  `-O3` is passed per build.
- Ties in the large-subject pattern ranking are broken by family then
  pattern bytes, not by experiment #1's triple id.
- `ONIG_DEBUG_COMPILE` build: only the `onig` target was built.
