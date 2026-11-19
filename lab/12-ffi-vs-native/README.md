# Experiment #12: FFI versus native OCaml

Plan: `plans/12-ffi-vs-native.md`. Results: `lab/results/2026-11-19-exp-12-*.md`.

- `vm/vm.ml` — backtracking VM for the regular subset; its parser is the
  subset classifier (`Out reason` / `Invalid onigerr`).
- `stubs/` — `[@@noalloc]` stubs (`Onig`); `ctypes/` — ctypes-foreign binding.
- `bench/main.ml` — harness (engines behind `ENGINE`): `classify`, `agree`,
  `time`, `scan`, `cata`, `alloc`, `tests`, `largeok`; `bench/cdriver.c` — C-only
  driver with the same protocol.
- `prep.py` (experiment #1 JSONL to the work format), `subset/select_tests.py`
  (`test_utf8.c` cases), `pick_large.py` (large-subject patterns),
  `summarise.py` (tables).
- `setup.sh {switches|clone|cbuild|engines}`, `subjects.sh`, `provenance.sh`,
  `run.py {prepare|pilot|short|large|cata} RUNID` — run on the bench host with
  `CACHE=<cache> EXP=<exp>`; outputs under `<exp>/out/RUNID/`.

Replay of run `r1`: `setup.sh switches; setup.sh clone; setup.sh cbuild;
setup.sh engines; subjects.sh; run.py prepare r1; run.py pilot r1;
run.py short r1 10; run.py large r1 10 16; run.py cata r1 10;
summarise.py <exp>/out/r1 <out>`.
