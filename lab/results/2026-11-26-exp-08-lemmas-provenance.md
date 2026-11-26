# Experiment #8 follow-up (issue #34), entry 1: provenance (run 1)

**What.** The machine, tool and solver versions, pinning and commits of
the follow-up of experiment #8 on discriminating lemmas (issue #34, plan
`plans/08-discriminating-lemmas.md`, draft PR #40), recorded at run 1.
Later runs add a new entry only if something changes.

**Why.** Planned entry 1 of the plan's "Lab notebook" section; every
measurement of runs 2-4 refers to it.

## Provenance

- Machine: the bench host (`provenance.sh` output,
  [raw](2026-11-26-exp-08-lemmas-raw/provenance.txt)): AMD EPYC 7502P
  32-Core, 64 logical CPUs, 503 GiB RAM; Linux 6.8.0-100-generic; Ubuntu
  24.04.5 LTS.
- Repository: branch `exp/08-discriminating-lemmas`, bench clone
  `<bench-workdir>/exp/08-discriminating-lemmas/repo` at `50295c4` for
  the recorded run (scripts at `985106f`, adapted from the unchanged
  copies of `f1c051d`); upstream `f95747b`. During development the
  worktree's files were copied over the clone; the recorded run used the
  clean clone at `50295c4`.
- Toolchains: the shared cache of experiments #6-#9, unchanged, through
  `<cache>/env.sh`: opam 2.6.1; switch `provers`: OCaml 5.4.1, Rocq
  9.3.0, rocq-stdlib 9.2.0, ocamlfind 1.9.8; Verus 0.2026.11.02.8bf68ee,
  Rust 1.99.1, Z3 4.16.0 bundled; F\* 2026.11.15 (commit `b92b0f87ce32`)
  with Z3 4.8.5, 4.13.3, 4.15.3 and 5.3.0 bundled (5.3.0 and 4.15.3 are
  for Verus brittleness only); GCC 13.3.0, CMake 3.28.3, Python 3.12.3.
  Identical to experiment #9's pins (`lab/08-discriminating-lemmas/pins.json`).
  No tool was installed or upgraded; opam's default switch untouched.
- C library: experiment #8's Debug and ASan/UBSan builds
  (`<bench-workdir>/exp/08-hard-features/build/onig-debug` and
  `onig-asan`, shared libraries, `CMAKE_BUILD_TYPE=Debug`, upstream
  checkout `f95747b`), both present, reused read-only; the harness is
  built under `<exp>/build/harness` by the adapted `cases/run-cases.sh`.
- Pinning: timed checks (none in run 1) on CPUs 24-27,56-59 under
  `flock <exp>/timed.lock`, `/usr/bin/time -v`, 16 GB cgroup cap.
  Untimed work in run 1 (case runs, Rocq builds by `vm_compute`):
  `nice -n 10`, `taskset -c 8-11`, one job at a time. CPUs 20-23,52-55
  and 28-31,60-63 were not used.
- Load average at the recorded run's start (2026-11-26T13:56:35Z): 1.57,
  1.90, 1.22. Free disk: 41 GB (floor 20 GB).
- Run 1 by Claude Code (Opus 5.5), launched by the maintainer; session
  start 2026-11-26T13:45:22Z.

## Script adaptations

One commit (`985106f`) against the unchanged copies (`f1c051d`), so the
diff is reviewable: `timed.sh`, `axioms.sh`, `brittle.sh`,
`provenance.sh` change only the experiment directory, the file lists,
the `Print Assumptions` targets (`sharp_s_sym`, `absent_desugar_eq`) and
the CPU defaults (timed 24-27,56-59; untimed 8-11; the Z3 sampler of
`brittle.sh` on CPU 8); `cases/run-cases.sh` takes the case files and
the two C builds as arguments and builds no nest-limit harness;
`loc.py`, `lemmas.py`, `brittle_verus.py` are unchanged; experiment
#8's `join.py` is called in place. The new case ids continue experiment
#8's numbering (ab12-ab29) so that `loc.py`'s case-id pattern counts
them as cases without a change.
