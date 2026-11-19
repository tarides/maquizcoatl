# Experiment #12, entry 6: catastrophic patterns under the retry budget

**What.** Criterion 3: experiment #11's three labelled worst-case
patterns, one per family, on subjects `"a"*n "!"` for n = 16 .. 4096
(doubling), each engine under the same retry budget (10,000,000 per
start position, 0 = unlimited per search): outcome and time to reach the
budget.

**Why.** Retry limits are Oniguruma's only ReDoS guard; a native engine
must give the same outcome and a bounded time.

## Provenance

As [entry 1](2026-11-19-exp-12-provenance.md). Command:
`EXP=<exp> python3 -I run.py cata r1 10`, 2026-11-19 17:27-17:30 UTC,
load average 1.93-2.12, experiment #11 running. One process per
(engine, pattern, n) and run, `taskset -c 2`, `timeout 60` (`cap`), one
`onig_search` (or equivalent) over the whole subject, timed around the
call. 10 interleaved runs (seed r). No point reached `cap`, so no row
was cut short.

Patterns: jq `(a+)+$` (Perl_NG, options 256), PHP `(a|aa)+$` (Ruby,
options 12), VS Code `(\w+\s?)+$` (Oniguruma, options 256).

## Results (outcome over 10 runs, median time of the search)

| Pattern | n | C driver | stubs | ctypes | VM `ffi` | VM `ffi-flambda` | ocaml-re |
|---|---|---|---|---|---|---|---|
| jq `(a+)+$` | 16 | no match 1.77 ms | no match 1.76 ms | no match 1.78 ms | no match 7.17 ms | no match 6.60 ms | no match 0.02 ms |
| jq | 32 .. 4096 | -17, 129.7-130.7 ms | -17, 129.5-130.0 ms | -17, 129.7-130.0 ms | -17, 270.3-273.2 ms | -17, 243.8-247.5 ms | no match 0.02-0.03 ms |
| PHP `(a\|aa)+$` | 16 | no match 0.19 ms | 0.20 ms | 0.20 ms | 0.64 ms | 0.56 ms | 0.04 ms |
| PHP | 32 .. 4096 | -17, 84.8-85.8 ms | -17, 84.9-86.0 ms | -17, 85.1-86.1 ms | -17, 286.8-288.6 ms | -17, 245.5-252.6 ms | no match 0.04-0.05 ms |
| VS Code `(\w+\s?)+$` | 16 | no match 4.55 ms | 4.55 ms | 4.59 ms | 11.13 ms | 9.56 ms | 0.03 ms |
| VS Code | 32 .. 4096 | -17, 113.1-113.8 ms | -17, 113.4-113.6 ms | -17, 113.3-113.8 ms | -17, 278.1-280.6 ms | -17, 238.6-239.9 ms | no match 0.03-0.04 ms |

-17 is `ONIGERR_RETRY_LIMIT_IN_MATCH_OVER`. Per-length table:
[`summary/cata.md`](2026-11-19-exp-12-raw/summary/cata.md), all runs:
[`cata.csv`](2026-11-19-exp-12-raw/cata.csv).

**Outcome agreement:** every engine (stubs, ctypes, VM in both
switches) gives the C driver's outcome at every one of the 27 points, in
all 10 runs. `ocaml-re` has no backtracking and no budget (reference
only): it answers "no match" in microseconds at every length.

## Analysis

- The budget is reached at the first start position for n >= 32 in
  every engine, so the time is the cost of 10,000,000 retries: 8.5-13 ns
  per retry in Oniguruma, 24-29 ns in the VM (`ffi`), 24-25 ns with
  flambda. The VM takes 2.1-3.4x longer to give up, bounded and
  independent of n.
- At n = 16 (no limit reached) the VM is 2.4-4x slower than Oniguruma,
  which also uses its optimiser (`$` anchoring, exact heads).
- FFI crossing is invisible here (one call per search).
- Retry-count fidelity holds for these three patterns; it does not hold
  in general (one PHP workload call differs, see
  [entry 3](2026-11-19-exp-12-agreement.md)).
