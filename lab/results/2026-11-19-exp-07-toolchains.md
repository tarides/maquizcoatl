# Experiment #7, entry 1: toolchains on the bench host

**What.** Installation of the four provers and their extraction back
ends for experiment #7 (issue #11) into a shared, reusable cache on the
blocksci bench host, with what was installed, how long it took and how
much disk it uses.

**Why.** Criterion 2 needs stated tool versions, and the cache
(`~/maquizcoatl-work/cache/` on that host, written `<cache>`) is meant to
be reused by experiments #13 (issue #3) and #5 (issue #13).

## Provenance

- Scripts: `lab/07-large-tables/setup.sh`, `pins.json` (branch
  `exp/07-large-tables`, commit `2072e9c`); `setup.sh opam|lean|fstar|karamel|onig`,
  run under `taskset -c 8-27,40-59` (CPUs 4-7 and 36-39 are pinned by
  experiment #11 and were not used), at most 12 parallel jobs (`--jobs=8`
  for opam, the other steps in parallel).
- Host: AMD EPYC 7502P 32-Core Processor, 64 hardware threads, 503 GB RAM,
  Ubuntu 24.04.5 LTS, Linux 6.8.0-100-generic. Shared: experiment #3
  (fuzzing) kept the 1-minute load average between 41 and 50 throughout.
- Date: 2026-11-19, 12:15-12:27 UTC.

## Installed

| Tool | Version | How |
|------|---------|-----|
| opam | 2.6.1 | release binary in `<cache>/bin`, sha256 checked; `OPAMROOT=<cache>/opam` (the host's own opam 2.1.5 root untouched) |
| OCaml | 5.4.1 | switch `provers` (`ocaml-base-compiler.5.4.1`) |
| Rocq | rocq-core 9.3.0, rocq-stdlib 9.2.0, rocq-native 3 | opam. The `rocq-prover` meta-package stops at 9.0.0 in opam-repository, so its parts were named; rocq-stdlib 9.2.0 is the latest stdlib release and installs with rocq-core 9.3.0 |
| Why3 | 1.9.0 | opam |
| Alt-Ergo | 2.6.5 | opam (latest on the day, pinned in `pins.json`) |
| F\* | 2026.11.15 (commit b92b0f8), Pulse included | Linux binary release, sha256 checked; no source build |
| Z3 | 4.8.5, 4.13.3, 4.15.3, 5.3.0 | bundled in the F\* binary release; 5.3.0 used (`--z3version 5.3.0`) |
| KaRaMeL | 3384ecaf (`krml` bundled in the F\* release) | not built separately, see below |
| elan | 4.4.0 | release binary, `ELAN_HOME=<cache>/elan`, `--no-modify-path` |
| Lean 4 | 4.36.0 (commit 611c117) | elan |
| GCC | 13.3.0 (Ubuntu 13.3.0-6ubuntu2~24.04.1) | system |
| CMake | 3.28.3 | system |
| Python | 3.12.3 | system, run with `-I` |

Added later for the F\* OCaml target: `ppx_deriving_yojson` 3.10.0 (and
`ppx_deriving`, `yojson`) in the switch.

## Raw data

| Step | Wall-clock |
|------|-----------|
| `setup.sh opam` (opam binary, init, switch with OCaml 5.4.1, Rocq, Why3, Alt-Ergo, zarith, ocamlfind) | 11 min 21 s (user 33 min 34 s) |
| `setup.sh fstar` (download and unpack, 251 MB tarball) | under 2 min |
| `setup.sh lean` (elan and the v4.36.0 toolchain) | 20 s |
| `setup.sh onig` (clone, out-of-tree Release build of `upstream/`, `test_utf8`: 1554 SUCC, 0 FAIL) | 8.5 s |

Disk use of `<cache>`: 5.6 GB. `<cache>/env.sh` sets `OPAMROOT`,
`ELAN_HOME`, `WHY3CONFIG` (`<cache>/why3.conf`, Alt-Ergo detected) and `PATH`.

## Analysis

- **Setup took 12 minutes, not the 60 planned**, because the F\* binary
  release was enough: it ships the Pulse-enabled `fstar.exe`, the Z3
  versions, and a `krml` built at KaRaMeL commit 3384ecaf.
- **KaRaMeL: bundled `krml` used instead of `master`.** The plan pinned
  KaRaMeL `master` (6bd5918) built against F\*; the release's own `krml`
  is the one F\* v2026.11.15 is tested with, so it was used and the build
  skipped. Deviation from the plan, recorded here.
- **OCaml 5.4.1 kept, with one consequence.** The F\* binary release's
  `fstar.lib` is compiled by OCaml 5.3.0, so it cannot be linked with
  code compiled by the 5.4.1 switch. The extracted F\* code uses only
  `Prims`, whose source ships in the release (`lib/fstar/lib/app/Prims.ml`);
  it is compiled in the switch together with the extracted code
  (needs `zarith`, `yojson`, `ppx_deriving.show`, `ppx_deriving_yojson`).
  The pin is therefore not wrong, but anything that needs more of
  `fstar.lib` will need either a 5.3.0 switch or a build of
  `fstar.lib` from source. Rocq, Why3 and Alt-Ergo installed on 5.4.1
  without trouble.
- Running `why3 config detect` once wrote `~/.why3.conf` on the host; it
  was moved to `<cache>/why3.conf` and `WHY3CONFIG` points there.
