# Experiment #9, entry 8: run-3 review fixes (correction 3)

**What.** Three decision-free fixes from the independent review of run 3
([issue #4 comment](https://github.com/tarides/maquizcoatl/issues/4#issuecomment-7163527386)).
[Entry 7](2026-11-25-exp-09-verus-m1.md) is not edited. Its agreement
figures and its 2.28 s median still hold. Two of its statements are
corrected below: the first-attempt claim and the thread count. Nothing
was rerun or timed. On the bench host, the only new commands were
`verus --help`, once pinned and once not, and reads of the
`/usr/bin/time -v` files that runs 1-3 had already written.

## Fix 1: not every spec fn checked at the first attempt

Entry 7 ("Every spec fn and the statement checked at the first
attempt"), its notebook index row ("spec fns right at the first
attempt") and the run-3 results comment
([issue #4 comment](https://github.com/tarides/maquizcoatl/issues/4#issuecomment-7163364598))
are wrong on one point. `effort.tsv`'s `syntax.rs` row is right. The
first check of `verus/syntax.rs` failed in the **spec fn**
`is_prefix_at` (`syntax.rs:73-75`), not in its exec mirror
`eis_prefix_at`. The session transcript shows a rustc type error,
`error[E0308]: mismatched types` at `syntax.rs:74:73`, where the upper
bound of `s.subrange(pos as int, pos + l.len())` was a `nat` but an
`int` was expected. The fix was the cast `(pos + l.len()) as int`. The
correct statement is:

> Every spec fn but one (`is_prefix_at`, a missing `nat` to `int`
> cast, one failed attempt) and the statement checked at the first
> attempt.

The attempt counts in `effort.tsv` (`syntax.rs`: 2) and entry 7's table
were already right, so the 7 failed attempts of run 3 still stand. One
of them is in the spec layer and six are in the exec layer. M4's
attempts-per-item table must use this split.

## Fix 2: CPU time and thread count of the timed checks

**Thread count corrected.** Entry 7 says that Verus ran with "its
default thread count (8, the pinned CPUs)". Under the same pinning,
Verus reports a default of **7**. Without pinning it reports 63 on the
64-core bench host. Verus therefore seems to use the available
parallelism minus one. The `--help` output is in
[verus-threads.txt](2026-11-25-exp-09-correction-3-raw/verus-threads.txt).
Run 3's timed checks passed no `--num-threads`, so they ran with 7
verifier threads.

**CPU time, from files that were already written.** `timed.sh` (and
`rocq/rocq.sh time`) kept the full `/usr/bin/time -v` output of every
timed check in `time.<r>.<file>` on the bench host. The user and system
times of runs 1-3 are extracted from those files into
[cpu.tsv](2026-11-25-exp-09-correction-3-raw/cpu.tsv). The table has
33 rows: Rocq's 15 (run 1), F\*'s 15 (run 2) and Verus's 3 (run 3). Run
3's three files are copied unchanged as
[time.1.lib](2026-11-25-exp-09-correction-3-raw/time.1.lib),
[time.2.lib](2026-11-25-exp-09-correction-3-raw/time.2.lib) and
[time.3.lib](2026-11-25-exp-09-correction-3-raw/time.3.lib). They hold
no path or host detail. Totals per timed run, summed over the
definition files:

| Tool (run) | wall clock | user | system | user + system | CPU |
|---|---:|---:|---:|---:|---:|
| Rocq (1), runs 1/2/3 | 2.80 / 2.81 / 2.82 s | 1.54 / 1.58 / 1.56 s | 1.24 / 1.20 / 1.25 s | 2.78 / 2.78 / 2.81 s | 99-100% per file |
| F\* (2), runs 1/2/3 | 1.95 / 1.97 / 1.98 s | 1.45 / 1.45 / 1.45 s | 0.48 / 0.50 / 0.51 s | 1.93 / 1.95 / 1.96 s | 100% per file |
| Verus (3), runs 1/2/3 | 2.28 / 2.25 / 2.30 s | 3.30 / 3.33 / 3.33 s | 0.55 / 0.55 / 0.59 s | 3.85 / 3.88 / 3.92 s | 168-172% |

The Rocq and F\* checks are single-threaded. Their CPU time equals
their wall clock. The Verus check used about 1.7 CPUs on average, so
its 2.28 s wall clock is not like for like with the other two. Its
median CPU time is **3.88 s**. Where the M4 comparison uses check time,
it should give both figures, or CPU time.

**`timed.sh` changed for later runs.** `time.tsv` gains two columns,
user time and system time (s), after the wall clock and the RSS. The
Verus `chk` now passes `--num-threads "${VERUS_THREADS:-7}"`. The
default is 7, the value run 3 used implicitly, so later Verus figures
stay comparable with run 3's and no longer depend on Verus's default.
The header no longer says that every check is "one file at a time": F\*
checks one file at a time, and Verus checks the whole crate `lib.rs` as
one unit. `timed.sh` has not been run since this change. Its first use
will be in a later run.

## Fix 3: `FRAGMENT.md` section 7 qualifies the carry-over to the exec VM

Section 7 said that the exec mirrors are proved equal to the spec fns,
"so the theorem carries over to the exec VM", without conditions. It
now states the conditions that entry 7 gives:

- The mirrors' equalities hold under their preconditions:
  `code.len() < usize::MAX - 2` (`evm`, `estep`), `s.len() < usize::MAX`
  (`esearch_*`) and `acts_wf` (`ecompute_tree`).
- `ecompile` returns `None` when a code address overflows `usize`.

The theorem therefore carries over only to patterns that `ecompile`
compiles and to subjects within those bounds. The change is to the
prose only.

## Effort

[effort.tsv](../09-representative-proof/effort.tsv), rows `3-fix`.
Human interventions: 0.
