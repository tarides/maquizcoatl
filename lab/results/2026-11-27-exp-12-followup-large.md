# Experiment #12 follow-up (issue #22), entry 5: large subjects

**What.** Find-all scan throughput of the two extracted columns of run
`x1`, in scan mode (`rocq-scan`, `fstar-scan`), beside freshly rerun
`c`, `stubs`, `ctypes` and `vm`. The subjects are experiment #12's
(Loghub SSH log and OCaml sources, 1 MiB and 16 MiB), and the patterns
are experiment #12's ranked list restricted to the fragment, with ranks
1-10 per source.

**Why.** Issue #10's large-subject shape. This is where an engine's
per-byte cost dominates and the FFI crossing does not matter, so the
extraction cost shows directly.

Provenance: [entry 1](2026-11-27-exp-12-followup-provenance.md).
Command: `run22.py large x1 10 10`, then `run22.py repeat x1 large`.
This is experiment #12's `scan` find-all loop: the warm-up scan is
untimed and includes the extracted columns' one conversion per subject;
then one timed scan, 10 interleaved runs on CPU 2, `timeout 120`.
Series 13:24-13:43 UTC, load average 1.02-2.07. All 2,400 processes
exited 0; no timeout; no cell had an IQR above 10% of its median. Raw:
[`large.csv`](2026-11-27-exp-12-followup-raw/large.csv),
[`summary/large.md`](2026-11-27-exp-12-followup-raw/summary/large.md),
[`summary/large-patterns.csv`](2026-11-27-exp-12-followup-raw/summary/large-patterns.csv),
[`work/large.list`](2026-11-27-exp-12-followup-raw/work/large.list).

## Pattern set: experiment #12's reduction rule applied

The fragment keeps 14 log patterns and 15 source patterns of experiment
#12's 16 + 16 ([entry 1](2026-11-27-exp-12-followup-provenance.md)).
The pilot projected this large series at 75 minutes, under decision 4's
90-minute gate, so the fallback (extracted columns at 1 MiB only) did
not apply and the 16 MiB extracted cells were run.

The whole run still projected over its 4 hours. The pilot ended at 11:08
UTC, but the series could not start until 13:06: the session lost
contact with the bench host for about two hours. The plan's step 9 then
applies experiment #12's reduction rule to the large series: patterns
are removed from the bottom of each source's ranking, and the 10 runs
are kept. Ranks 1-10 per source were kept. These are 10 patterns per
source, the same 10 in both sources: `"`, `'`, `\(`, `\{`, `,`, `\+\+`,
`--`, `=>`, `;`, `\.\.\.`. All are literals. The dropped ranks are the
log ranks 11, 12, 15, 16 and the source ranks 11, 12, 14, 15, 16.
They include every alternation pattern (`%|\*|/|-|\+`, `/\*`,
`\&|~|\^|\|`, `<<|>>>|>>`, `<=|>=|<>|<|>`). In the pilot these took
24-58 s per run for the six columns together, against about 5.6 s for a
literal.

## Results (median over the 10 patterns of each cell's median MB/s)

| Source | Size | c | stubs | ctypes | vm | rocq | fstar | experiment #12 c / vm, same patterns (context) |
|---|---|---:|---:|---:|---:|---:|---:|---|
| log | 1 MiB | 663.4 | 662.7 | 662.5 | 71.2 | 27.7 | 20.2 | 662.9 / 58.1 |
| log | 16 MiB | 664.5 | 664.5 | 664.4 | 71.2 | 27.1 | 19.5 | 664.2 / 58.2 |
| src | 1 MiB | 622.0 | 606.4 | 390.6 | 69.7 | 27.0 | 19.5 | 521.3 / 58.0 |
| src | 16 MiB | 569.4 | 546.1 | 328.3 | 69.9 | 26.8 | 19.4 | 448.7 / 57.9 |

The per-pattern medians of the extracted columns range over
26.1-28.6 MB/s (Rocq) and 19.2-20.8 MB/s (F\*). The match counts are
identical across the six columns for every (source, size, pattern).

As time per MiB (median over patterns): C 1.58-1.84 ms; the hand-written
VM 8.1-9.3x C; Rocq 21.3-24.6x C, 2.6x the VM; F\* 29.3-34.0x C, 3.6x
the VM. Stubs are within 0-4% of C. ctypes is within 0-1% on log and
1.6-1.7x C on the denser source matches.

## Analysis

- **Scan mode works as planned.** The extracted columns hold the same
  throughput at 1 MiB and at 16 MiB (27.7 against 27.1 MB/s on log),
  even though a 16 MiB subject is a 419 MB live list
  ([entry 2](2026-11-27-exp-12-followup-checks.md)). The conversion
  happens in the warm-up, and the major GC work on the live list does
  not show at this resolution.
- **Extraction cost per byte.** On literal patterns, every start
  position runs one extracted `vm` call: an initial state, a stack with
  `EFinish`, one `IStr` (`is_prefix` on the suffix), then a pop. That
  costs about 37 ns per byte for Rocq and 51 ns for F\*, against 14 ns
  for the hand-written VM. The gap between Rocq and F\* is `Z.t`
  arithmetic, not allocation: F\* allocates fewer words per match.
- **The hand-written VM is faster than in experiment #12** (70-71
  against 58 MB/s on the same patterns, with the same binary flags in
  switch `ffi`). The cause was not investigated in this run: the build
  is from this branch, where `bench/dune` adds a `select` and the
  executable links the extracted libraries. Either the link order or
  host conditions could explain it.
- **Not covered.** Alternation patterns are outside this run's large
  shape (the reduction above). The pilot's single runs put the extracted
  columns at 0.9-6 MB/s on them, so the extraction cost per byte is
  higher on alternations than on literals. `pilot.txt` has these
  figures, but they are not a series.
