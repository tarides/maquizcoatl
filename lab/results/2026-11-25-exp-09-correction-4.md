# Experiment #9, entry 9: Rocq timed-check log of run 1 (correction 4)

**What.** The item that [correction 2](2026-11-25-exp-09-correction-2.md)
left pending: run 1's Rocq raw set has no usable `time.log`. Run 4
added a `rocq` case to `timed.sh` and reran the three pinned clean
checks of run 1's five definition files with it, so that the Rocq
figures now come with the checker's log and with the user and system
columns that [correction 3](2026-11-25-exp-09-correction-3.md) added to
`time.tsv`. This was the first use of `timed.sh` since correction 3;
the new columns work. [Entry 3](2026-11-25-exp-09-rocq-m1.md) is not
edited, and its figures still hold (below).

**Why.** Entry 3's check times could not be checked against a log of
the checks; correction 2 said the log would be added when run 4 reran
the Rocq timed checks.

## Provenance

As [entry 1](2026-11-25-exp-09-provenance.md): same bench host, Rocq
9.3.0 on OCaml 5.4.1. Bench clone at `a1b40c5` with the new `timed.sh`
copied over it (committed unchanged with this entry). The five files
`Syntax.v`, `Sem.v`, `Compile.v`, `Vm.v` and `Statement.v` were run 1's,
byte for byte (no `.v` file changed between `4525896` and `a1b40c5`);
this run's change to `Statement.v` came after this check. Command:

    BENCH_WORKDIR=<bench-workdir> flock <exp>/timed.lock timed.sh rocq r4c

at 13:38:46Z; no process above 1% CPU on CPUs 28-31,60-63 before the
start; 1-minute load average 0.71-0.75 before every check.

What changed in `timed.sh`: a `rocq` case (`ROCQ_FILES`, default the
five definition files; one file at a time; `rocq compile -R . S`), whose
`chk` prints `Checked <file>.v` after a successful compile, because
`rocq compile` prints nothing on success. Run 1's own `time.log`
(written by `rocq/rocq.sh time`) exists on the bench host and is
**0 bytes** for that reason, so there was nothing to copy.

Raw: [rocq/](2026-11-25-exp-09-correction-4-raw/rocq/) (`time.tsv` with
the user and system columns, `time.load`, and `time.log`: 15 `Checked`
lines, five files times three runs, nothing else).

## Result

| Timed run | wall clock | user | system | user + system | peak RSS |
|---|---:|---:|---:|---:|---:|
| 1 | 2.85 s | 1.57 s | 1.26 s | 2.83 s | 275,100 KB |
| 2 | 2.80 s | 1.58 s | 1.22 s | 2.80 s | 275,100 KB |
| 3 | 2.81 s | 1.57 s | 1.22 s | 2.79 s | 275,104 KB |
| median | **2.81 s** | | | **2.80 s** | |

Entry 3 had 2.80 / 2.81 / 2.82 s (median 2.81 s) and correction 3's
`cpu.tsv` a CPU median of 2.78 s for the same files: the rerun agrees
(wall-clock median identical, CPU within 0.02 s), so entry 3's figures
stand. The checks are single-threaded (CPU time equals wall clock).

## Effort

[effort.tsv](../09-representative-proof/effort.tsv), run 4 rows
(`timed.sh (rocq case)`: 1 attempt). Human interventions: 0.
