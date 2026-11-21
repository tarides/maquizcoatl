# exp-04 m4-toolchain: experiment #4's own Isabelle2026, AFP, Isabelle-LLVM and LLVM on the bench host

## What

Install of the mechanism 4 toolchain of experiment #4 (issue #7) into
experiment #4's own cache on the bench host: Isabelle2026, the AFP
release `afp-2026-11-19`, Isabelle-LLVM (branch `2026`, commit
`e42f4781`, session `Isabelle_LLVM` built) and the LLVM 23.1.5 release
binaries. It reproduces experiment #5's pinned install exactly.

## Why

Mechanism 4 (plan step 7, follow-up 2) needs Isabelle-LLVM to export a
stub to LLVM IR and clang to compile it. Option (a) was decided on
issue #7 (https://github.com/tarides/maquizcoatl/issues/7#issuecomment-7035723643):
experiment #4 installs its own copy, the same versions and hashes as
experiment #5, rather than reading another account's cache.

## Provenance

- Source of the pins and steps: experiment #5's
  `experiments/05-unverified-calls/setup.sh` (milestone 2 components
  `isabelle-llvm` and `llvm`) and `pins.json`, branch
  `exp/05-unverified-calls` at commit `1dcc3dc`, and its lab entry
  `lab/results/2026-11-20-exp-05-toolchains-m2.md` (Vincent Balat's,
  same day). Read only; nothing on that branch was changed.
- Script: `experiments/04-abi-feasibility/m4-isabelle/install.sh`
  (this branch), run as
  `nice -n 10 taskset -c 16-31 install.sh <cache> 16-31 16`
  from `<bench-workdir>/exp/04-abi-feasibility/m4/`, under `nohup`.
- Bench host: AMD EPYC 7502P (32 cores, 64 threads), 503 GiB RAM,
  Ubuntu 24.04.5 LTS, Linux 6.8.0-100. Load average 0.00 before the
  start; no Isabelle or Poly/ML process and no CPU-pinned user process
  (checked); experiment #11's reserved CPUs 4-7,36-39 avoided. CPUs
  16-31, 16 jobs, nice 10.
- Started 2026-11-20T14:07Z; exit status 0.

## Data

| Component | Version / pin | Source, sha256 | Time | Disk |
|---|---|---|---|---|
| Isabelle | Isabelle2026 | Cambridge mirror tarball, `858c995b…e48d` (as pinned by experiment #5) | 443 s with AFP, clone and session build | 1.4 GB download; `isabelle/` 3.9 GB in all |
| AFP | `afp-2026-11-19` | `9fe7a2e1…e38a` | (in Isabelle) | 102 MB download |
| Isabelle-LLVM | branch `2026`, commit `e42f478118988ff38676ff01215be26f3018f015`, session `Isabelle_LLVM` | git clone of `lammich/isabelle_llvm` | session build 5 min 56 s wall, peak RSS 4.96 GB | (in `isabelle/`) |
| LLVM | 23.1.5 (`392dfff97d29`) | GitHub release `LLVM-23.1.5-Linux-X64.tar.xz`, `f72edb0b…c78a` | 161 s | 1.9 GB download, 12 GB extracted |

All three downloads matched their pinned sha256. The session build
compiled `Automatic_Refinement` (32 s), `Refine_Monadic` (52 s) and
`Isabelle_LLVM` (4 min 6 s), total 5 min 52 s elapsed, 17 min 35 s
CPU. Free disk went from 67 GB to 48 GB (16 GB of toolchain plus 3.4 GB
of downloads kept in `<cache>/dl`).

Raw log (redacted): [`2026-11-20-exp-04-raw/m4/install.log`](2026-11-20-exp-04-raw/m4/install.log).

### Differences from experiment #5's script (all decision-free)

| Experiment #5 | Here | Why |
|---|---|---|
| pins read from `pins.json` with `jq` | pins inlined in `install.sh` | the bench host has no `jq`; same values |
| `-j 3 -o threads=4` (12 jobs) | `-j 4 -o threads=4` (16 jobs) | the run was given up to 16 jobs; does not change the result |
| CPU checks of `lib.sh` (`vu_check_cpus`) | CPU set passed explicitly, pinned-process check done by hand before the start | `lib.sh` is experiment #5's harness |
| smoke test `add1` | none; the mechanism 4 stub itself exercises `export_llvm`, a VCG proof, clang and the link with C | see the [m4-isabelle-llvm entry](2026-11-20-exp-04-m4-isabelle-llvm.md) |
| output redacted by `vu_redact` | output redacted before committing | same rule |

## Analysis

Install time, session build time (5 min 52 s against experiment #5's
6 min 2 s with 12 jobs) and sizes agree with experiment #5's entry: the
pinned install reproduces. The session build is bound by session
dependencies, not by threads (CPU factor about 3).
