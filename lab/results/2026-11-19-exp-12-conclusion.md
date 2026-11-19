# Experiment #12, entry 7: conclusion, FFI crossing cost versus engine cost

> Erratum: items 2 and 4 of the conclusion are restated in [entry 10](2026-11-19-exp-12-review-fixes.md) (measured optimiser share, crossing as an upper bound, cost-only answer to the open question).

**What.** Criterion 6: for each workload shape, the FFI crossing cost
(stubs or ctypes minus the C-only driver) and the engine cost (OCaml VM
minus the C-only driver), which option costs less, and which way the
evidence points on the report's open question "OCaml library: native
code or bindings?" (maintainer's state-of-the-art report,
https://claude.ai/artifact/8w6PVuiTsLCKpugpCowMHc).

**Why.** This is the decision input the experiment exists for.

## Provenance

Derived from entries [4](2026-11-19-exp-12-short.md),
[5](2026-11-19-exp-12-large.md) and [6](2026-11-19-exp-12-catastrophic.md)
by `lab/12-ffi-vs-native/summarise.py` (medians of 10 interleaved runs
per cell). Raw: [`summary/conclusion.md`](2026-11-19-exp-12-raw/summary/conclusion.md).

## Table

| Shape | Workload | C driver | FFI, stubs | FFI, ctypes | Engine, VM `ffi` | Engine, VM flambda | Cheapest OCaml option |
|---|---|---|---|---|---|---|---|
| short, ns/call | jq | 123.2 | +3.5 (+3%) | +628 (+510%) | -39.5 (-32%) | -48.8 (-40%) | VM |
| short, ns/call | PHP | 6,899 | -15 (0%) | +612 (+9%) | +5,881 (+85%) | +3,475 (+50%) | stubs |
| short, ns/call | VS Code | 78.3 | +7.8 (+10%) | +613 (+782%) | +568 (+725%) | +466 (+594%) | stubs |
| synthetic long PHP, ns/call | 11 calls | 14,368 | +1,068 (+7%) | +1,714 (+12%) | +25,250 (+176%) | +12,849 (+89%) | stubs |
| large, ms per MiB | log 1 MiB | 1.584 | +0.001 | +0.003 | +16.5 (11.4x) | +15.3 (10.6x) | stubs |
| large, ms per MiB | log 16 MiB | 1.579 | +0.001 | +0.007 | +16.5 (11.4x) | +15.2 (10.6x) | stubs |
| large, ms per MiB | src 1 MiB | 2.046 | +0.113 | +2.097 | +16.0 (8.8x) | +14.8 (8.2x) | stubs |
| large, ms per MiB | src 16 MiB | 2.374 | +0.173 | +2.601 | +15.7 (7.6x) | +14.4 (7.1x) | stubs |
| catastrophic, time to budget | 3 patterns, n >= 32 | 85-131 ms | +0 | +0 | 2.1-3.4x | 1.9-2.9x | stubs (all outcomes agree) |

Large: median over 16 patterns of the time per MiB (from median
throughput).

## Conclusion

1. **The FFI crossing is cheap with hand-written `[@@noalloc]` stubs**:
   3-8 ns per call on short subjects (3-10%), nothing measurable on
   large subjects with few matches, 5-7% on large subjects with a match
   every few bytes. **ctypes-foreign is not a viable binding for this
   library**: about 610 ns and 329 words allocated per call, 6-9x a
   short VS Code or jq search, and half the throughput when matches are
   dense.
2. **The engine cost of a naive native OCaml VM is large and comes
   mostly from the missing search optimiser, not from OCaml**: the VM
   beats Oniguruma on jq's tiny searches (-32% to -40%), but is 7-8x
   slower on VS Code line scans and 7-11x on large subjects, exactly the
   cases where Oniguruma skips ahead with Sunday/BMH or a first-byte map;
   on pure backtracking (catastrophic patterns, no skipping possible) it
   pays 2-3.4x per retry. flambda `-O3` recovers 11-31%.
3. **Which costs less today:** bindings through `[@@noalloc]` stubs, on
   every shape except jq's tiny searches.
4. **Which way the evidence points on the open question:** the FFI tax
   of a good binding (a few ns per call, zero allocation) is smaller than
   the engine gap of a first native VM by one to two orders of
   magnitude, so "native code to avoid FFI cost" is not justified by
   crossing cost alone. A native OCaml engine is competitive only if it
   carries a search optimiser (exact-string and first-byte skipping,
   anchors) and tighter backtracking; the per-call results on jq and the
   2-3x per-retry gap suggest that gap can be closed, but this
   experiment did not show it. The stub binding is the low-risk default
   for the OCaml deliverable; a native engine is a performance project
   in its own right, and its retry-count semantics (one PHP call
   differs) needs a spec decision on whether retry counts are
   observable.

## Limits

- Regular subset only: 29% of VS Code calls (26% weighted), 63% of
  jq's, 38% of PHP's. The large-subject patterns are all literal or
  alternation-of-literal VS Code patterns (as the plan's ranking
  selects).
- One host, one compiler version (OCaml 5.4.1 for issue #22's sake);
  `ocaml-re` here is not comparable with experiment #11's 5.5.2 figures.
- The VM has no match-stack limit and an approximate retry count
  ([entry 3](2026-11-19-exp-12-agreement.md)).
- Not done (follow-up, outside this budget): the full VS Code set
  (473,134 searches), more large-subject patterns, a ctypes `cstubs`
  column, and the generated-OCaml columns (issue #22).
