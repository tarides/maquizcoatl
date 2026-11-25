# Experiment #9, entry 6: run-2 review fixes (correction 2)

**What.** Three decision-free fixes from the independent review of run 2
([issue #4 comment](https://github.com/tarides/maquizcoatl/issues/4#issuecomment-7162950723)).
No figure of [entry 5](2026-11-25-exp-09-fstar-m1.md) changes, and
entry 5 is not edited. Nothing was rerun or timed.

## Fix 1: run 2's wall-clock note in `effort.tsv`

The run-2 `session` row of
[effort.tsv](../09-representative-proof/effort.tsv) said that its window
covered the notebook entry. Entry 5 is right: the end,
2026-11-25T12:44:11Z, was taken before writing entry 5 and before the
commit (`f2db986`, 12:44:54Z). The note now says that the window covers
the issue comment on the bytecode answer, the F\* work and the bench
runs, and not entry 5, the commit, the results comment, the push or
the dashboard update. The start and end are unchanged.

## Fix 2: `time.log` added to run 2's raw set

Entry 5's "Exit 0, 15 'Verified module' lines" for `timed.sh fstar r2`
could not be checked from the repository, because `timed.sh`'s
`time.log` was not copied. It is now in
[2026-11-25-exp-09-fstar-m1-raw/fstar/time.log](2026-11-25-exp-09-fstar-m1-raw/fstar/time.log)
(30 lines, copied unchanged from the bench run's output directory
`<bench-workdir>/exp/09-representative-proof/out/r2/fstar/`). It holds
15 `Verified module` lines, one per file (`Syntax`, `Sem`, `Compile`,
`Vm`, `Statement`) and per timed run (3), each followed by "All
verification conditions discharged successfully". It contains no
hostname, address or path. `timed.sh`'s header now says what
`time.log` holds and that `time.tsv`, `time.load` and `time.log` go to
the run's raw set.

Run 1's Rocq raw set
([2026-11-25-exp-09-raw/rocq/](2026-11-25-exp-09-raw/rocq/)) has the
same gap. As the review asks, its `time.log` will be added when run 4
reruns `rocq/rocq.sh time`.

## Fix 3: the comment of `fstar/Extract.fst`

The comment said that the extraction root names the fragment's modules
so that they are loaded. In fact it names only `Compile`, `Syntax` and
`Spec2`. `Vm` and `Sem` are brought in by the `--custard_entry` flags
of `fstar/fstar.sh` (`Vm.vm`, `Sem.sem`). The comment now says this.
The change is to the comment only: the code (7 lines by `loc.py`) and
the extraction are unchanged, so entry 5's outputs still hold.

## Effort

[effort.tsv](../09-representative-proof/effort.tsv), rows `2-fix`.
Human interventions: 0.
