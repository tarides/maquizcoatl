# Experiment #9, entry 1: provenance (run 1)

**What.** The machine, tool and solver versions, pinning and commits of
experiment #9 ("Representative proof", issue #4, plan
`plans/09-representative-proof.md`), recorded at run 1 (M0 + Rocq M1).
Later runs add a new entry only if something changes.

**Why.** Planned entry 1 of the plan's "Lab notebook" section; every
measurement of the experiment refers to it.

## Provenance

- Machine: the bench host (`provenance.sh` output,
  [raw](2026-11-25-exp-09-raw/provenance.txt)): AMD EPYC 7502P 32-Core,
  64 logical CPUs, 503 GiB RAM; Linux 6.8.0-100-generic; Ubuntu 24.04.5 LTS.
- Repository: branch `exp/09-representative-proof`, bench clone at
  `1dbf4ba` (the plan at `b17781f` merged with `main` at `f0d0727`),
  with the run's scripts copied over it before each step; upstream
  `f95747b`. The committed scripts are the ones that ran (the Rocq
  comments were corrected after the first build; a rebuild gave
  byte-identical verdicts and was discarded as a deterministic re-run).
- Toolchains (the shared cache of experiments #6-#8, unchanged, through
  `<cache>/env.sh`): opam 2.6.1; switch `provers`: OCaml 5.4.1, Rocq
  9.3.0, rocq-stdlib 9.2.0, ocamlfind 1.9.8; F\* 2026.11.15 (commit
  `b92b0f87ce32`) with Z3 4.8.5, 4.13.3, 4.15.3 and 5.3.0 bundled; Verus
  0.2026.11.02.8bf68ee, Rust 1.99.1, Z3 4.16.0 bundled; GCC 13.3.0, CMake
  3.28.3, Python 3.12.3. Pins: `lab/09-representative-proof/pins.json`.
- C library: Oniguruma `f95747b`, `CMAKE_BUILD_TYPE=Release`, static
  (`-DBUILD_SHARED_LIBS=OFF`), out of tree in `<exp>/build/onig`.
- Pinning: timed checks on CPUs 28-31,60-63 (one L3 complex) under a
  lock (`<exp>/timed.lock`, `flock`; the locks of experiments #6 and #7
  were free), `/usr/bin/time -v`, a 16 GB cgroup memory cap
  (`systemd-run --user --scope -p MemoryMax=16G`); the plan's `ulimit -v
  16G` makes OCaml 5's `rocq` fail with "Not enough heap memory to
  reserve minor heaps", so the cgroup cap of experiment #8's `check.sh`
  is used instead. Untimed work: `nice -n 10`, CPUs 4-7, at most 4 jobs.
  Free disk at the start: 51 GB.
- Run 1 by Claude Code (Opus 5.5), launched by the maintainer; session
  start 2026-11-25T10:37:44Z.

## Analysis and open questions

- Versions match experiments #6-#8's pins; no newer release was
  installed. Z3 4.13.3 is present for F\*'s third data point (M3).
- The memory cap mechanism differs from the plan's wording (`ulimit -v`)
  for the reason above; the cap value (16 GB) is the plan's.
