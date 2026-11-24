# Experiment #12, entry 8: provenance addendum (opam repository, packages, `test_utf8`)

**What.** Two provenance items that the plan's step 2 promised and
[entry 1](2026-11-19-exp-12-provenance.md) did not record: the
opam-repository commit behind the switches `ffi` and `ffi-flambda`, with
every installed package version, and the `test_utf8` sanity check of the
C builds. Also the `test_utf8` result of the `ONIG_DONT_OPTIMIZE` build
of [entry 9](2026-11-19-exp-12-optimiser-share.md).

**Why.** Automated results review on issue #10
([comment](https://github.com/tarides/maquizcoatl/issues/10#issuecomment-7017131208)),
problem 2: `provenance.txt` has an empty `opam_repo_default:` line, and
the transitive dependencies (ctypes' `integers`, for instance) were not
pinned, so the switches were not reproducible from the record; no
`test_utf8` output was kept. Issue #22 will reuse these switches.

## Provenance

Collected 2026-11-19 17:45-17:57 UTC on the bench host (AMD EPYC 7502P,
Ubuntu 24.04.5 LTS, Linux 6.8.0-100-generic), opam 2.6.1, under
`taskset -c 0-3,32-35`; nothing timed. The switches are those of
entry 1, unchanged since run `r1`.

## opam repository

The shared opam root has one repository for both switches, `default` =
`https://opam.ocaml.org` (`opam repository list --all`). It is an HTTP
index, not a git clone, which is why `setup.sh`'s `git rev-parse` probe
found nothing. The index tarball (fetched 2026-11-19 12:15 UTC, sha256
`d810ed6a…cc1d`) carries `stamp: "5719d66ea0fbe260bfd1e245c4d608ab26a1afb2"`
in its `repo` file. That stamp is the opam-repository commit
**`5719d66ea0fbe260bfd1e245c4d608ab26a1afb2`** (2026-11-18 22:59 UTC, a
merge commit on `master`). The `opam update default` that preceded the
switch creation at 16:49 UTC reported no change, so both switches were
solved against this commit.

## Installed packages (both switches)

| Package | `ffi` | `ffi-flambda` |
|---|---|---|
| compiler | `ocaml-base-compiler.5.4.1`, `ocaml-options-vanilla.1` | `ocaml-variants.5.4.1+options`, `ocaml-option-flambda.1` |
| `ocaml`, `ocaml-compiler` | 5.4.1 | 5.4.1 |
| `ocaml-config` | 3 | 3 |
| `base-bigarray`, `base-domains`, `base-effects`, `base-nnp`, `base-threads`, `base-unix` | base | base |
| `dune`, `dune-configurator` | 3.25.0 | 3.25.0 |
| `ctypes`, `ctypes-foreign` | 0.24.0 | 0.24.0 |
| `integers` | 0.8.0 | 0.8.0 |
| `re` | 1.14.0 | 1.14.0 |
| `mtime` | 2.2.0 | 2.2.0 |
| `conf-libffi` | 2.0.0 | 2.0.0 |
| `conf-pkg-config` | 5 | 5 |
| `csexp` | 1.5.2 | 1.5.2 |
| `ocamlbuild` | 0.16.1 | 0.16.1 |
| `ocamlfind` | 1.9.8 | 1.9.8 |
| `stdlib-shims` | 0.3.0 | 0.3.0 |
| `topkg` | 1.1.1 | 1.1.1 |

`bigarray-compat`, which the review named, is not installed in either
switch. `opam switch import` of the export files below, against
opam-repository `5719d66`, recreates the switches.

Raw: [`r2/opam-repository.txt`](2026-11-19-exp-12-raw/r2/opam-repository.txt),
[`r2/opam-list.txt`](2026-11-19-exp-12-raw/r2/opam-list.txt),
[`r2/switch-ffi.export`](2026-11-19-exp-12-raw/r2/switch-ffi.export),
[`r2/switch-ffi-flambda.export`](2026-11-19-exp-12-raw/r2/switch-ffi-flambda.export).

## `test_utf8` sanity check

`test/test_utf8` of each out-of-tree build of `f95747b`, run from its
build directory:

| Build | Type, `CMAKE_C_FLAGS` | Result |
|---|---|---|
| `onig-release` (the library timed in run `r1`) | Release `-O3 -DNDEBUG`, empty | `RESULT   SUCC: 1554,  FAIL: 0,  ERROR: 0      (by Oniguruma 6.9.10)` |
| `onig-debug` | Debug `-g`, empty | `RESULT   SUCC: 1554,  FAIL: 0,  ERROR: 0      (by Oniguruma 6.9.10)` |
| `onig-noopt` ([entry 9](2026-11-19-exp-12-optimiser-share.md)) | Release `-O3 -DNDEBUG`, `-DONIG_DONT_OPTIMIZE` | `RESULT   SUCC: 1554,  FAIL: 0,  ERROR: 0      (by Oniguruma 6.9.10)` |

Raw: [`r2/test_utf8.txt`](2026-11-19-exp-12-raw/r2/test_utf8.txt).
`onig-dbgc` (the `ONIG_DEBUG_COMPILE` library used only for the
optimiser dump) was built without its tests, as entry 1 records.

## Analysis

- The record now pins the whole switch: the opam-repository commit and
  every installed version, transitive dependencies included.
- All three timed or tested C builds pass the full UTF-8 suite, so the
  libraries the C driver, the stubs and ctypes link against are correct
  on Oniguruma's own tests. Compiling the search optimiser out does not
  change any of the 1,554 results.
