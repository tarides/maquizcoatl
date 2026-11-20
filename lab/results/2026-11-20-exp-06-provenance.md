# Experiment #6, entry 1: provenance (milestone 1)

**What.** Run conditions of milestone 1 of experiment #6 (issue #1,
"Executable spec speed"): the bench host, the tool versions, the builds,
the pinning, and where each script lives. Every other entry of this
experiment refers here.

**Why.** Criterion 3 asks for throughput "on a stated machine (hardware
and OS recorded in the lab notebook)", and criterion 5 asks for `T_spec`
with experiment #7's protocol and tool versions, so that it compares with
experiment #7's `T_table`. The plan's gate on experiment #5 was lifted by
the maintainer on 2026-11-20 (experiment #5's milestones 1-2 found all six
tools working, so none of stacks A-F is eliminated; see the
[comment on issue #1](https://github.com/tarides/maquizcoatl/issues/1#issuecomment-7042095648)).

## Provenance (all entries of this milestone)

- Branch `exp/06-spec-speed`: harness at `57bd9bc` (extractor, stack G,
  C oracle, the four planned prover semantics, scripts), used by
  `series.sh`; the Verus and Isabelle/HOL rows, the F\* and Isabelle
  reruns (`series2.sh` to `series4.sh`), the summary script and these
  entries are in the next commit. Plan: `plans/06-spec-speed.md`.
- Upstream: `f95747b` (a read-only copy of the submodule on the bench
  host). Out-of-tree Release build, `CMAKE_BUILD_TYPE=Release`
  (`-O3 -DNDEBUG`), shared `libonig.so`; its `test_utf8`: 1554 SUCC,
  0 FAIL, 0 ERROR. The C oracle (`oracle/oracle.c`) is built with
  `gcc -O2` against it.
- Bench host: AMD EPYC 7502P (32 cores, 64 hardware threads), 503 GB
  RAM, Linux 6.8.0-100-generic, Ubuntu 24.04.5 LTS. Same host as
  experiments #7 and #12.
- Toolchain: experiment #7's shared cache (`<bench-workdir>/cache`,
  `env.sh`), unchanged: opam 2.6.1, switch `provers` with OCaml 5.4.1,
  zarith 1.14, Rocq 9.3.0 (`rocq-stdlib` 9.2.0, `rocq-native` 3), Why3
  1.9.0; F\* 2026.11.15 binary release (commit `b92b0f87`, built with
  OCaml 5.3.0; `Prims.ml` compiled in the 5.4.1 switch as in experiment
  #7); Lean 4.36.0 with elan 4.4.0 and Lake 5.0.0; GCC 13.3.0, CMake
  3.28.3, Python 3.12.3. These are the versions of experiment #7
  (`2026-11-19-exp-07-toolchains.md`), so `T_spec` and `T_table` are
  like for like. Added for the two extra rows, both already in the
  cache: Verus 0.2026.11.02.8bf68ee (Rust toolchain 1.99.1, installed by
  experiment #8) and Isabelle2026 with its prebuilt HOL heap (Poly/ML
  5.9.2).
- OCaml compilation: plain `ocamlfind ocamlopt` (no flambda) for stack G
  and every extracted OCaml target; Lean's executable by `lake build`
  (release, `-O3 -DNDEBUG`); Lean's `T_spec` by `lean -c` and
  `leanc -c -O3 -DNDEBUG`, as experiment #7.
- Pinning: every timed run (throughput, in-prover, `T_spec`, and
  experiment #7's idle rerun) under `taskset -c 28-31,60-63` (L3
  complex 7), one at a time under a lock (`series.sh`), with
  `/usr/bin/time -v`, `ulimit -v 64G`, a 20-minute timeout and the load
  average before each run (`tm.sh`, copied from experiment #7). Before
  each series, `series.sh` lists the threads of other processes above 5%
  CPU on those CPUs and logs the result (`series.log`). Untimed work
  (builds, verdict runs, calibration) on CPUs 4-7 under `nice -n 10`.
  Experiment #4's mechanism 4 had finished; the host's load average was
  0.1-3.1 during every timed run, and the CPU check found the timing
  CPUs free before every series (`series*.log`).
- Scripts: `lab/06-spec-speed/` (see its files: `cases/extract.py`,
  `cases/gen.py`, `g/g.ml`, `oracle/oracle.c`, `rocq/`, `lean/`,
  `why3/`, `fstar/`, `common.sh`, `tm.sh`, `series.sh`, `reps.env`,
  `provenance.sh`, `summarise.py`). Experiment #7's idle rerun runs its
  own scripts from `main` (`lab/07-large-tables/`, last changed at
  `2db5715`).
- Raw outputs: [2026-11-20-exp-06-raw/](2026-11-20-exp-06-raw/)
  (`provenance.txt` is `provenance.sh`'s output on the bench host).

## Analysis and open questions

Nothing to analyse here. Verus and Isabelle/HOL are standing
(experiment #5 eliminated no stack); the plan made their rows a
follow-up, to run if the budget left room after the four planned
provers. It did (the planned series took 41 minutes), so both rows are
in this milestone, from toolchains already in the cache.
