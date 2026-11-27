# Experiment #12 follow-up (issue #22), entry 13: conclusion restated with run 2 (done-criterion 2)

**What.** [Entry 7](2026-11-27-exp-12-followup-conclusion.md)'s
conclusion, restated with run 2's figures. Run 2 added the large
patterns run 1 dropped, including every alternation
([entry 11](2026-11-27-exp-12-followup-run2-large.md)), the
fuel-exhaustion rows ([entry 12](2026-11-27-exp-12-followup-run2-catafuel.md))
and the short-shape columns built with flambda
([entry 10](2026-11-27-exp-12-followup-run2-short.md)). This entry
supersedes entry 7's table rows for the large shape and its large-shape
limit. Entry 7's other statements stand unless restated below.

**Why.** Done-criterion 2 of issue #22, which asks whether verified
extraction changes which way the evidence points on the report's open
question "OCaml library: native code or bindings?" (state-of-the-art
report, "Deliverables: libonig drop-in and OCaml library",
https://claude.ai/artifact/8w6PVuiTsLCKpugpCowMHc). Decision 7 asked
for the alternation patterns because they could change the large-shape
figures.

Sources: entries 4-7 (run 1), 10-12 (run 2). Table:
[`summary/conclusion.md`](2026-11-27-exp-12-followup-run2-raw/summary/conclusion.md)
(both runs merged), [`summary/large.md`](2026-11-27-exp-12-followup-run2-raw/summary/large.md),
[`summary/short-x2.md`](2026-11-27-exp-12-followup-run2-raw/summary/short-x2.md).

## FFI crossing against engine cost, per workload shape (fragment subset, both runs)

| Shape | Workload | C driver | stubs - C (FFI) | ctypes - C (FFI) | VM - C (engine) | Rocq - C (engine) | F\* - C (engine) | cheapest OCaml option |
|---|---|---:|---:|---:|---:|---:|---:|---|
| short, ns/call (run 1) | jq | 123.2 | +10.9 (1.1x) | +617 (6.0x) | -41.8 (0.7x) | +74.4 (1.6x) | +226 (2.8x) | VM |
| short, ns/call (run 1) | PHP | 93.8 | +11.3 (1.1x) | +620 (7.6x) | -5.9 (0.9x) | +96.2 (2.0x) | +223 (3.4x) | VM |
| short, ns/call (run 1) | VS Code | 67.4 | +8.6 (1.1x) | +599 (9.9x) | +416 (7.2x) | +1,686 (26.0x) | +3,809 (57.5x) | stubs |
| synthetic long PHP, ns/call (run 1) | long PHP | 131.6 | +40.8 (1.3x) | +664 (6.0x) | -74.4 (0.4x) | -25.7 (0.8x) | +19.7 (1.1x) | VM |
| short, flambda columns, ns/call (run 2) | jq / PHP / VS Code / long PHP | 123.2 / 93.8 / 67.2 / 132.0 | | | vm-flambda 0.59x / 0.86x / 6.6x / 0.36x | rocq-flambda 1.28x / 1.61x / 18.0x / 0.65x | fstar-flambda 2.95x / 3.47x / 61.3x / 1.14x | VM (flambda), stubs on VS Code |
| large, ms/MiB, median over all 14 / 15 patterns | log 1 MiB | 1.581 | +0.005 | +0.004 | +15.66 (10.9x) | +36.4 (24.0x) | +51.2 (33.4x) | stubs or ctypes (within 0.3% of C) |
| large, ms/MiB, median over all 14 / 15 patterns | log 16 MiB | 1.578 | -0.000 | +0.001 | +15.63 (10.9x) | +37.2 (24.6x) | +52.2 (34.1x) | stubs |
| large, ms/MiB, median over all 14 / 15 patterns | src 1 MiB | 2.016 | +0.130 (1.1x) | +2.03 (2.0x) | +15.24 (8.6x) | +36.9 (19.3x) | +51.9 (26.8x) | stubs |
| large, ms/MiB, median over all 14 / 15 patterns | src 16 MiB | 2.337 | +0.224 (1.1x) | +1.80 (1.8x) | +14.96 (7.4x) | +37.4 (17.0x) | +51.9 (23.2x) | stubs |
| large, per pattern, alternations only (run 2) | 4 patterns x 2 sources x 2 sizes | 98.7-261 MB/s | 1.0-1.2x | 1.0-4.2x | 5.7-14.3x | 36-97x | 90-235x | stubs |
| catastrophic, complete search (run 1) | `(a\|aa)*b` n = 16 / `(aa*)*b` n = 16 / `(a\|aa)*b` n = 32 | c-noopt 0.126 / 1.54 / 266 ms | stubs = C | ctypes = C | 4.5x / 4.2x / -17 at 258 ms | 87x / 79x / 108x | 149x / 138x / 208x | (C optimiser rejects all three in about 1 µs) |
| catastrophic, fuel exhaustion (run 2, not comparable) | both patterns, n = 32-512 | - | - | - | - | 1.4-8.5 s per 10^7 instructions | 2.7-22.1 s | - |

The large rows replace entry 7's (ranks 1-10 only). The run 2 short
`ffi` columns replicate run 1's within 1.2% (entry 10), so the short
rows keep run 1's figures.

## Conclusion (restated)

1. **FFI crossing cost: unchanged.** Stubs cost 8.6-11.3 ns per call
   over C on short subjects (40.8 ns on long PHP). On large subjects
   they cost 0-1% over C on log and 6-10% on source, measured as
   medians over all patterns. Run 1's 0-4% held for the literals only.
   On the source alternations with dense matches (rank 11: 1.0-1.2x C),
   the per-match crossing shows, as experiment #12 found on its own
   list. ctypes costs about 600 ns and 329 words per call, and up to
   4.2x C on dense large matches.
2. **Verified extraction multiplies the engine cost, and more on
   alternations than run 1 showed.** On literals the Rocq column takes
   2.1-2.7x the hand-written VM's time per byte and F\* 3.0-3.8x, as in
   run 1. On the alternations of the large list, Rocq takes 4.1-7.1x
   and F\* 10.2-16.8x the VM's time, growing with the number of
   alternatives. Against C that is 36-97x (Rocq) and 90-235x (F\*),
   the same order as the complete backtracking searches (79-108x and
   138-208x). Over all patterns the medians stay at 17-25x (Rocq) and
   23-34x (F\*) C, because the ranked list is mostly literals.
3. **Flambda narrows the Rocq column's gap, not F\*'s, and changes no
   ranking.** On short subjects flambda makes the Rocq column 19-31%
   faster, cutting its allocation 2.3-5.9x, and the hand-written VM
   8-16% faster. The Rocq extraction overhead over the VM at the same
   compiler falls from 101-117 ns to 70-85 ns per call on jq and PHP.
   F\* is 3-7% slower with flambda. Even with flambda, Rocq stays
   1.3-1.6x C on jq and PHP and 18x on VS Code, and stays 1.8-2.7x the
   VM.
4. **The representation costs stand as findings, not defects** (entry
   7, item 3): a list subject, a state record per instruction, a list
   stack, an association list of captures, one `IStr` per literal, no
   optimiser, and `Z.t` arithmetic in F\*. Run 2 adds two observations.
   Alternations go through an allocating `IPush` per failing
   alternative and start position (entry 11). The time per instruction
   grows with the subject length on backtracking-heavy searches, from
   about 140 ns at n = 32 to about 800 ns at n = 512 for Rocq
   (entry 12).
5. **The evidence points the same way, more strongly than in entry 7.**
   Experiment #12 concluded "on cost, bindings". Run 1 found that
   verified extraction, as written in experiment #9, moves native code
   further from bindings on every shape. Run 2's alternation patterns
   widen the gap where the ranked list is costliest: 4-7x (Rocq) and
   10-17x (F\*) the hand-written VM. Flambda reduces Rocq's cost by a
   fifth to a third but does not bring any extracted column level with
   stubs on any shape. Alternation patterns do not change the
   conclusion. They make the price of the proof larger than run 1's
   literal-only large shape suggested.

As in entry 7, this measures cost only. It does not weigh assurance or
portability. A verified native engine competitive with bindings would
need a different extracted representation (arrays or strings with
integer positions, mutable captures, machine integers, an optimiser).
That is a design question for the implementation phase.

## Limits (restated)

- **Fragment only.** The fragment covers 41.9% of jq calls, 15.0% of
  PHP calls and 18.0% of VS Code searches (16.8% by frequency).
- **Large shape.** The large shape now covers every fragment pattern of
  experiment #12's ranked lists (14 log, 15 source). It was timed in
  two series: ranks 1-10 in run 1 (13:24-13:43 UTC) and the rest in
  run 2 (14:28-15:16 UTC), on the same binaries, CPU and protocol. On the four
  alternations run 2's `c` and `vm` are within 1.2% of experiment #12's
  (entry 11). The run 1 VM speed-up over experiment #12 shows only on
  the literal patterns.
- **Catastrophic.** Three comparable points (run 1). The fuel rows
  cover n = 32-512. n = 1024-4096 are not run (decision 7), and run 1's
  pilot gives F\* capped at 2048. One fuel cell is noisy (F\*
  `(aa*)*b` n = 128, IQR 11.1%), and step 12 has no repeat rule. There
  is no retry-budget measurement for the extracted columns
  (decision 3).
- **Flambda.** The short shape only (decision 8). The large and
  catastrophic shapes are `ffi`-only. The flambda columns take
  experiment #12's `-O3` through `oflags.sexp`.
- **Single host.** One host, CPU 2, 10 runs per cell.
