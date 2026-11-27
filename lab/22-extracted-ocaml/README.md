# Issue #22: Rocq- and F\*-extracted OCaml in experiment #12's table

Plan: `plans/12-extracted-ocaml.md`. Results: `lab/results/*-exp-12-followup-*.md`.
Experiment #12's harness (`lab/12-ffi-vs-native/`) runs every timed column;
this directory adds the extracted engines and the scripts.

- `extract.sh RUNID`: checks that experiment #9's sources are those of
  `e1b9936`, regenerates `frag.ml`/`frag.mli` (Rocq) and `Custard.ml` plus
  the release's `Prims.ml` (F\*), prints their sha256 and copies them with
  `gen/{rocq,fstar}/dune` into `<exp>/gen/`.
- `adapter/` (library `extracted22`, optional): `frag_parse.ml` (OCaml port
  of `recognise`, `lab/09-representative-proof/cases/select.py`),
  `rocq22.ml`, `fstar22.ml` (conversion, AST mapping, result mapping),
  `engine22.ml` (the position loop, subject modes, fuel; see its header),
  `extracted22.ml` (engines `Rocq`, `Rocq_scan`, `Fstar`, `Fstar_scan`).
  Out of fuel is code -2000; a backward search (outside the subset) -2001.
- `x22/x22.exe`: `astcheck`, `astwork`, `verdicts`, `conv`, `conv-subject`,
  `cata-fuel` (see its header).
- `prep22.py` (fragment subset, coverage, restricted large list),
  `run22.py` (driver, built on `lab/12-ffi-vs-native/run.py`),
  `summarise22.py` (tables), `setup.sh`, `provenance.sh`, `pins.json`.

Registration in `lab/12-ffi-vs-native/`: four engine names in `engine_of`
and in `run.py`'s `ENGINES` (left out of its default set), and a dune
`select` that links `extracted22` when it is in the same dune project and
the stand-ins of `bench/extracted.none.ml` otherwise, so experiment #12's
replay is unchanged.

Replay of run `x1` on the bench host (`CACHE=<cache> EXP=<exp>
E12=<exp12>`; the generated sources and the staging tree are outside the
repository). These are the commands run `x1` ran; the series are those
of its `series.sh` (`lab/results/2026-11-27-exp-12-followup-raw/series.sh`),
in that order:

    setup.sh clone x1; setup.sh switch x1; setup.sh cbuild x1; setup.sh subjects x1
    extract.sh x1; setup.sh engines x1
    run22.py prepare x1; run22.py checks x1; run22.py agree x1; run22.py conv x1 10
    run22.py pilot x1
    run22.py short x1 10; run22.py repeat x1 short; run22.py cata x1 10
    run22.py large x1 10 10; run22.py repeat x1 large
    provenance.sh x1

`large x1 10 10` keeps ranks 1-10 per source (the plan's reduction rule,
applied after the loss of host contact). `run22.py catafuel x1 10` was
not run in `x1`. The plan's intended sequence has `run22.py large x1 10`
(every rank) and `run22.py catafuel x1 10` after `cata`.
    summarise22.py <copy of <exp>/out/x1> lab/results/2026-11-19-exp-12-raw/summary <out>
