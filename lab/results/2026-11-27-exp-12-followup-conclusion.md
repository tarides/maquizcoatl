# Experiment #12 follow-up (issue #22), entry 7: conclusion (done-criterion 2)

**What.** Experiment #12's conclusion
([2026-11-19-exp-12-conclusion.md](2026-11-19-exp-12-conclusion.md),
corrected in [2026-11-19-exp-12-review-fixes.md](2026-11-19-exp-12-review-fixes.md))
restated with the Rocq- and F\*-extracted columns of run `x1`, on the
fragment subset.

**Why.** Done-criterion 2 of issue #22. The question is whether verified
extraction changes which way the evidence points on the report's open
question "OCaml library: native code or bindings?" (state-of-the-art
report, "Deliverables: libonig drop-in and OCaml library",
https://claude.ai/artifact/8w6PVuiTsLCKpugpCowMHc).

Sources: entries [4](2026-11-27-exp-12-followup-short.md) (short),
[5](2026-11-27-exp-12-followup-large.md) (large),
[6](2026-11-27-exp-12-followup-catastrophic.md) (catastrophic),
[2](2026-11-27-exp-12-followup-checks.md) (conversion). Table:
[`summary/conclusion.md`](2026-11-27-exp-12-followup-raw/summary/conclusion.md).

## FFI crossing against engine cost, per workload shape (fragment subset)

| Shape | Workload | C driver | stubs - C (FFI) | ctypes - C (FFI) | VM - C (engine) | Rocq - C (engine) | F\* - C (engine) | cheapest OCaml option |
|---|---|---:|---:|---:|---:|---:|---:|---|
| short, ns/call | jq | 123.2 | +10.9 (1.1x) | +617 (6.0x) | -41.8 (0.7x) | +74.4 (1.6x) | +226 (2.8x) | VM |
| short, ns/call | PHP | 93.8 | +11.3 (1.1x) | +620 (7.6x) | -5.9 (0.9x) | +96.2 (2.0x) | +223 (3.4x) | VM |
| short, ns/call | VS Code | 67.4 | +8.6 (1.1x) | +599 (9.9x) | +416 (7.2x) | +1,686 (26.0x) | +3,809 (57.5x) | stubs |
| synthetic long PHP, ns/call | long PHP | 131.6 | +40.8 (1.3x) | +664 (6.0x) | -74.4 (0.4x) | -25.7 (0.8x) | +19.7 (1.1x) | VM |
| large, ms/MiB | log 1 MiB | 1.581 | +0.002 | +0.002 | +13.15 (9.3x) | +36.2 (23.9x) | +50.3 (32.8x) | stubs |
| large, ms/MiB | log 16 MiB | 1.578 | +0.000 | +0.000 | +13.15 (9.3x) | +37.2 (24.6x) | +52.1 (34.0x) | stubs |
| large, ms/MiB | src 1 MiB | 1.686 | +0.043 | +0.999 (1.6x) | +13.36 (8.9x) | +37.2 (23.1x) | +52.1 (31.9x) | stubs |
| large, ms/MiB | src 16 MiB | 1.842 | +0.078 | +1.352 (1.7x) | +13.16 (8.1x) | +37.4 (21.3x) | +52.2 (29.3x) | stubs |
| catastrophic, complete search | `(a\|aa)*b` n = 16 / `(aa*)*b` n = 16 / `(a\|aa)*b` n = 32 | c-noopt 0.126 / 1.54 / 266 ms | stubs = C | ctypes = C | 4.5x / 4.2x / -17 at 258 ms | 87x / 79x / 108x | 149x / 138x / 208x | (C optimiser rejects all three in about 1 µs) |

Large shape: ranks 1-10 per source, all literals (entry 5). C is the
default libonig with its optimiser, except in the catastrophic row,
where the comparable C figure is the `-DONIG_DONT_OPTIMIZE` build.

## Conclusion

1. **FFI crossing cost, on the fragment subset, is what experiment #12
   measured on its own subset.** `[@@noalloc]` stubs cost 8.6-11.3 ns
   per call over C on short subjects (40.8 ns on long PHP, where each
   call reads one capture pair more) and 0-4% on large subjects. ctypes
   costs about 600 ns and 329 words per call.
2. **Verified extraction multiplies the engine cost.** On top of the
   hand-written VM, the Rocq-extracted VM adds about 100-120 ns per call
   on jq and PHP (0.9-1.1x the C figure) and runs at 2.6x the VM's time
   on large subjects. The F\*-extracted VM adds about 230-270 ns per call
   (2.2-2.4x the C figure) and runs at 3.6x the VM's time on large
   subjects. Against C, extraction puts the
   native engine at 1.6-3.4x on short jq and PHP calls, 26-58x on VS
   Code's multi-position searches, 21-34x on large subjects, and
   79-208x on a complete backtracking search.
3. **The cost comes from the representation, as a set of findings, not
   defects** (the extracted code is the proved code, run as is):
   - the subject is a list with one element per byte, so `IStr` walks
     the suffix from its start at every literal step
     (`rocq/Vm.v:73-75`);
   - every instruction allocates a fresh state record, and the backtrack
     stack is a list;
   - captures are an association list that grows with every group write
     (`rocq/Vm.v:17-23`);
   - each fragment literal compiles to its own `IStr`;
   - F\* adds `Z.t` arithmetic on every pc, position and fuel operation:
     1.7-2.2x Rocq's time on short subjects, with fewer words
     allocated;
   - there is no search optimiser (experiment #12 found the optimiser
     to be about 72% of the C-to-VM gap on the large shape).
   Converting the subject costs 1-9% of the short-shape time and is
   outside the scan timings (entry 2).
4. **The evidence points the same way, more strongly.** Experiment #12
   concluded "on cost, bindings": stubs are the cheapest OCaml option
   except on tiny searches, and a naive native VM only pays off with an
   optimiser. The extracted VMs move native code further from bindings
   on every shape. The only rows where an extracted column is cheaper
   than C are long PHP's 10 first-position matches, where the
   hand-written VM is cheaper still. So verified extraction, as
   experiment #9 wrote it (specification-shaped code, lists and
   unbounded integers), does not change the answer on cost. It adds a
   price for the proof of 2.6-3.6x over a hand-written native VM on
   large subjects and more on backtracking.

This run measures cost only. It does not weigh the assurance that a
proved engine gives, or the portability argument for native code, both
of which experiment #12 also left to the maintainer. A verified native
engine competitive with bindings would need a different extracted
representation: arrays or strings with integer positions, mutable
captures, machine integers in F\*, and an optimiser. That is a design
question for the implementation phase, not something this run
measured.

## Limits

- Fragment only: literals, concatenation, `|`, greedy `*`, plain
  groups. This is 41.9% of jq calls, 15.0% of PHP calls and 18.0% of
  VS Code searches (16.8% by frequency).
- Large shape reduced to ranks 1-10 per source (all literals): run
  `x1` has no alternation pattern in the large series (entry 5).
- Catastrophic: two patterns and three comparable points. The
  fuel-bounded rows were not run in `x1` (pilot figures only, entry 6).
  There is no retry-budget measurement for the extracted columns
  (decision 3).
- Switch `ffi` only (decision 5). The flambda row was not run.
- One host, CPU 2, 10 runs per cell; no cell exceeded the IQR gate.
