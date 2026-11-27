# Experiment #12 follow-up (issue #22), entry 9: run 2 setup, checks, agreement and pilot

**What.** Run `x2` of `plans/12-extracted-ocaml.md`, for issue #22's
decisions 7 and 8. This entry records what run 2 set up and checked
before timing: the four F\* packages installed into `ffi-flambda`, the
harness built a second time in that switch, the checks before timing
and the agreement on every new column, and the pilot of the cells that
run 2 times. The series are entries 10-12, and the restated conclusion
is entry 13.

**Why.** Run 1 left three items out
([entry 1](2026-11-27-exp-12-followup-provenance.md), the run 1 review
and [entry 8](2026-11-27-exp-12-followup-correction.md)). The maintainer
decided on 2026-11-27:

- **Decision 7, (a).** Rerun the large-series patterns that run 1
  dropped: log ranks 11, 12, 15, 16 and source ranks 11, 12, 14, 15, 16,
  every alternation included. Run the fuel-exhaustion catastrophic rows
  (`cata-fuel`) for n = 32-512. The longer fuel lengths are recorded
  from run 1's pilot as not run.
- **Decision 8, yes.** Install zarith, yojson, ppx_deriving and
  ppx_deriving_yojson into `ffi-flambda` at the `ffi` switch's versions.
  The short-shape series then adds the Rocq and F\* columns built with
  flambda. This amends decision 5 for run 2.

## Provenance

- **Code.** Repository `71ca7cf` on `exp/12-extracted-ocaml`, cloned on
  the bench host. Upstream `f95747b`. The extracted sources are run 1's
  and were not regenerated (`<exp>/gen/`, regenerated from `e1b9936` in
  run 1, with four sha256 equal to experiment #9's copies, entry 1).
  `71ca7cf` adds run 2's subcommands to `run22.py` (`reuse`, `pilot2`,
  `large ... ">N"`, `catafuel ... MAXLEN`, and `FLAMBDA=1` for the
  columns built in `ffi-flambda`) and two subcommands to `setup.sh`
  (`switch-flambda`, `engines-flambda`). The `provenance.sh` line for
  `ffi-flambda` and the merge of the two runs in `summarise22.py` are
  in the commit of these entries.
- **Run 1's build.** Run 2 reuses `<exp>/bin/main-ffi.exe`, `x22.exe`,
  `cdriver` and `cdriver-noopt` of run 1, unchanged (built 10:48 UTC),
  together with the libonig builds and the subjects. `run22.py reuse x2
  x1` copied run 1's `work/`, `work12/` and `extract/` records (39 work
  files, all identical by sha256 to run 1's, `reused.txt`). It also
  copied the decision 6 lengths from run 1's pilot: `c-noopt`
  completes at n >= 32 only for `(a|aa)*b` at n = 32. This is a
  deterministic retry count, and that cell stays a `cata` cell, not a
  `cata-fuel` one.
- **Machine and protocol.** These are run 1's ([entry 1](2026-11-27-exp-12-followup-provenance.md)):
  the bench host, AMD EPYC 7502P, timed processes one at a time under
  `taskset -c 2`, with the `schedutil` governor; untimed jobs under
  `nice -n 10 taskset -c 0-3,32-35`, with at most 4 jobs. The limits are
  `timeout 120` (short, large) and `timeout 60` (`cata-fuel`), with 10
  interleaved runs and the IQR gate. Before each series `run22.py`
  listed the threads on CPU 2 (`ps -eLo user,psr,pcpu,comm`), measured
  CPU 2's use and logged the load average (`cpu2.log`). Every check found CPU 2
  idle (0.0% use), and no other experiment was detected
  (`conditions.csv`).
- **Timeline (UTC).** Run start 14:16:57 (`start.txt`); dry run and package install
  14:17-14:17:58; flambda build 14:18:07; checks 14:18:30;
  agreement 14:18:37; pilot 14:18:44-14:23:58; series 14:24:04 onwards
  (entries 10-12).
- **Effort.** Claude Code (Opus 5.5), one session; about 15 minutes of
  code before the run.

Raw: [`2026-11-27-exp-12-followup-run2-raw/`](2026-11-27-exp-12-followup-run2-raw/).

## Decision 8: the four packages in `ffi-flambda`

`setup.sh switch-flambda x2` first checked that the four packages are
at the pinned versions in `ffi` (zarith 1.14, yojson 3.0.0,
ppx_deriving 6.2.0, ppx_deriving_yojson 3.10.0). It then exported
`ffi-flambda`, ran `opam install --dry-run` and checked that the
solution upgrades, downgrades, recompiles, reinstalls and removes
nothing, installed, and exported again.

- **Dry run** (`setup/opam-dry-run-flambda.txt`): 10 installs, the same
  10 as `ffi` received in run 1. These are conf-gmp 5, cppo 1.8.0,
  ocaml-compiler-libs v0.17.0, ppx_derivers 1.2.1, ppx_deriving 6.2.0,
  ppx_deriving_yojson 3.10.0, ppxlib 0.39.0, sexplib0 v0.17.0, yojson
  3.0.0 and zarith 1.14. No upgrade and no removal.
- **Installed** (`setup/f-star-packages-flambda.txt`): the four at the
  pinned versions.
- **Exports** (`setup/switch-ffi-flambda.{before,after}.export`): the
  diff only adds lines. Every package of experiment #12's `ffi-flambda`
  is unchanged.

No `opam update` was run. The opam root was not upgraded, and the
default switch was not changed.

## The harness built in `ffi-flambda`

`setup.sh engines-flambda x2` built a second staging tree,
`<exp>/src-flambda/`, as `setup.sh engines` does. It holds one dune
project with lab/12, lab/22 and the generated sources, and it was built
with `dune build -j 4 --profile release` in `ffi-flambda` (OCaml
5.4.1+options, flambda). The binaries are `<exp>/bin/main-ffi-flambda.exe`
and `x22-flambda.exe`. The dune log is empty: no warning and no error.

Compiler flags. Experiment #12's `vm-flambda` column passes `-O3` to
`ocamlopt` through `lab/12-ffi-vs-native/oflags.sexp` (`-O3` under
flambda, empty otherwise). The plan asks for the extracted libraries
to use the same profile as the hand-written VM. So `engines-flambda`
adds the same `(:include .../oflags.sexp)` to the `ocamlopt_flags` of
`rocq_extracted`, `fstar_extracted`, `extracted22` and `x22`, in the
staging copy only. The committed dune files and run 1's `ffi` build are
unchanged, and under `ffi` the file is empty anyway. `dune rules`
confirms `-O3` on `frag.cmx`, `custard.cmx`, `prims.cmx`, the three
adapter modules and `vm.cmx` (`setup/o3-check.txt`). The linked engine
module is the adapters, not the stand-ins (`setup/select-flambda.txt`:
`include Extracted22`).

## Checks before timing (requirement 6, on the flambda build)

`FLAMBDA=1 run22.py checks x2` runs the checks of plan step 6 with
`x22-flambda.exe` (`checks-flambda/summary.txt`). All of them pass:

- (i) The parser port matches on 70/70 cases.
- (ii) Every admitted pattern parses the same in OCaml and Python:
  jq 10/10, PHP 21/21, VS Code 277/277, long PHP 1/1, large 15/15.
- (iii) The Rocq and F\* `vm` verdicts through the flambda-built
  adapters are byte-identical to experiment #9's reference files. That
  is 339 lines on `fragment.tsv` and 14 on `extra.tsv` for each engine
  (Rocq: `2026-11-25-exp-09-correction-1-raw`, `2026-11-25-exp-09-raw`;
  F\*: `2026-11-25-exp-09-fstar-m1-raw`).

## Agreement (issue #10's criterion 7, every column including the new ones)

`FLAMBDA=1 run22.py agree x2` reran `agree` on every `<fam>.frag.work`
for `c`, `stubs`, `ctypes`, `vm`, `rocq`, `fstar` and the three new
columns `vm-flambda`, `rocq-flambda` and `fstar-flambda`. On long PHP it
also covered the four scan modes `rocq-scan`, `fstar-scan`,
`rocq-flambda-scan` and `fstar-flambda-scan`. That makes 40 jobs, all
with rc 0 (`agree.txt`, `summary/agreement-x2.md`).

| Family | Calls | every column = C | C limit codes | agreed (timed) |
|---|---:|---|---:|---:|
| jq | 91 | 91 (9 columns) | 0 | 91 |
| PHP | 63 | 63 (9 columns) | 0 | 63 |
| VS Code | 77,067 | 77,067 (9 columns) | 0 | 77,067 |
| long PHP | 10 | 10 (9 columns and 4 scan modes) | 0 | 10 |

The agree outputs of the six run 1 columns are byte-identical to run
1's. The rewritten `<fam>.agreed.work` files are byte-identical to
run 1's (`agreed-before.sha256`), so run 2 times the same calls as run
1.

## Pilot (decision 4's gate on run 2's large cells)

`FLAMBDA=1 run22.py pilot2 x2 ">10"` made one untimed run of each
short cell (36 cells) and of each large cell of the dropped ranks:
9 patterns, 6 columns and 2 sizes, 108 cells. The order is plan step
9's, with the extracted 16 MiB cells projected as 16 times their 1 MiB
wall time before any of them runs (`pilot.txt`, `pilot.json`).

| Pattern | Ranks (log / src) | one run of the 12 cells (s): log / src |
|---|---|---|
| `%\|\*\|/\|-\|\+` | 11 / 11 | 50.5 / 51.9 |
| `/\*` | 12 / 12 | 5.5 / 5.6 |
| `\&\|~\|\^\|\|` | 15 / 14 | 34.4 / 34.9 |
| `<<\|>>>\|>>` | 16 / 15 | 24.5 / 24.6 |
| `<=\|>=\|<>\|<\|>` | - / 16 | - / 58.2 |

- **Projections.** The extracted 16 MiB cells project to 257 s in all,
  37 s at most per cell, so all are under the 120 s timeout. The large
  series projects to 10 x pilot x 1.1 = **53.6 minutes**, under
  decision 4's 90 minutes, so the fallback does not apply and the
  extracted 16 MiB cells run.
- **Other series.** The short series projects to 4.1 minutes. Run 1's
  pilot gives `cata-fuel` at n = 32-512 about 22.6 minutes (123 s per
  run of the four rows). That makes about 80 minutes of series, inside
  the 4-hour cap.
- **Run 1's figures.** The per-pattern costs match the run 1 pilot's
  (50-51, 5.5, 34, 24.5 and 58 s), and so does the review's 53-minute
  estimate.

All 144 pilot processes exited 0.
