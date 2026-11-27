# Experiment #12 follow-up (issue #22), entry 12: fuel-exhaustion catastrophic rows, n = 32-512 (run 2)

**What.** This entry covers the `cata-fuel` rows of decision 3, which
are labelled not comparable. The Rocq and F\* columns search `"a"*n
"!"` with a stated fuel of 10,000,000 VM instructions per start
position, and each cell is timed until the first result that is not
`NoMatch`, here `OutOfFuel` at the first start position. The patterns
are `(a|aa)*b` (`php-frag`) and `(aa*)*b` (`jq-frag`), at n = 32, 64,
128, 256 and 512. The cell `(a|aa)*b` at n = 32 is excluded, because it
is decision 6's comparable `cata` cell, timed in run 1. That leaves 18
cells.

**Why.** Decision 7 (a). Run 1's pilot projected the full `cata-fuel`
series (n = 32-4096) at about 97 minutes, so run 1 did not run it
([entry 6](2026-11-27-exp-12-followup-catastrophic.md)). Decision 7
runs n = 32-512, and the longer lengths are recorded from run 1's pilot
as not run.

Provenance: [entry 9](2026-11-27-exp-12-followup-run2-setup.md).
Command: `run22.py catafuel x2 10 512`, using run 1's `x22.exe`
(switch `ffi`). There were 10 interleaved runs on CPU 2 under `timeout
60`, with seed r shuffling the 18 cells. Series 15:16:22-15:37:07 UTC
(20.8 minutes, against 22.6 projected), load average 1.00-2.79. All 180
processes exited 0, and every run of every cell ended `OutOfFuel`
(result -2000); none was capped. Raw:
[`catafuel.csv`](2026-11-27-exp-12-followup-run2-raw/catafuel.csv),
[`summary/cata.md`](2026-11-27-exp-12-followup-run2-raw/summary/cata.md).

## Results (not comparable with C; time to exhaust 10,000,000 instructions)

| Pattern | n | rocq median (min..max) | rocq IQR/median | fstar median (min..max) | fstar IQR/median | fstar / rocq |
|---|---:|---|---:|---|---:|---:|
| `(a\|aa)*b` | 64 | 1.881 s (1.868..1.949) | 1.5% | 4.095 s (3.971..4.462) | 3.9% | 2.2x |
| `(a\|aa)*b` | 128 | 2.819 s (2.793..2.858) | 1.3% | 6.571 s (6.340..7.320) | 2.1% | 2.3x |
| `(a\|aa)*b` | 256 | 4.732 s (4.680..4.782) | 1.4% | 11.754 s (11.266..13.368) | 1.3% | 2.5x |
| `(a\|aa)*b` | 512 | 8.492 s (8.369..8.601) | 1.3% | 22.086 s (20.804..23.186) | 6.0% | 2.6x |
| `(aa*)*b` | 32 | 1.375 s (1.366..1.396) | 1.0% | 2.678 s (2.614..2.773) | 0.9% | 1.9x |
| `(aa*)*b` | 64 | 1.804 s (1.792..1.834) | 0.9% | 3.840 s (3.706..4.062) | 4.1% | 2.1x |
| `(aa*)*b` | 128 | 2.632 s (2.611..2.657) | 1.3% | 6.004 s (5.877..6.915) | **11.1% (noisy)** | 2.3x |
| `(aa*)*b` | 256 | 4.377 s (4.322..4.429) | 1.2% | 10.504 s (10.222..11.793) | 3.3% | 2.4x |
| `(aa*)*b` | 512 | 7.768 s (7.658..7.810) | 1.2% | 19.407 s (18.909..22.563) | 6.9% | 2.5x |

One cell, F\* `(aa*)*b` at n = 128, has an IQR above 10% of its
median. Its spread comes from one run at 6.915 s; the other nine are
5.88-6.17 s. The plan's repeat of noisy cells (10 more runs) is a rule
of the short and large series (steps 10-11). Step 12 has none, and
`run22.py repeat` takes `short` or `large` only. So the cell is
reported as noisy and was not repeated.

**Not run (decision 7):** n = 1024, 2048 and 4096 for both patterns and
both columns. Run 1's pilot gives one run each
([`pilot.txt` of run 1](2026-11-27-exp-12-followup-raw/pilot.txt)):

- Rocq: 14.3, 27.9 and 53.9 s (`(aa*)*b`); 16.0, 31.2 and 60.0 s
  (`(a|aa)*b`).
- F\*: 37.0 s at 1024 and the 60 s cap at 2048 (`(aa*)*b`); 43.6 s at
  1024 and the cap at 2048 (`(a|aa)*b`).
- F\* at 4096 was not run in the pilot, because the row stops at its
  first cap.

The run 2 medians agree with run 1's single pilot runs within 1.3% for
Rocq. For F\* they agree within 6%, except `(aa*)*b` at n = 256, where
the pilot took 12.07 s against a median of 10.50 s (+15%).

## Analysis

- **The time to exhaust a fixed fuel grows with n.** The same 10,000,000
  instructions take 1.4 s at n = 32 and 7.8-8.5 s at n = 512 for Rocq,
  and 2.7 s and 19.4-22.1 s for F\*. That is about 140 ns per
  instruction at n = 32 and about 800 ns at n = 512 for Rocq. Time per
  instruction therefore depends on the subject length, not only on the
  instruction count. A reading that fits the code, not measured here:
  the backtrack stack and the captures list grow deeper with n, and
  each `IStr` and each state record works on a longer list suffix,
  which adds GC work. The figures measure the extracted VM's
  per-instruction cost on these shapes. They do not measure the time
  to a verdict: a complete search at these lengths would take far
  longer (decision 6's n = 32 point took 28.6 s and 55.2 s).
- **F\* takes 1.9-2.6x Rocq's time**, and the gap widens with n. That is
  the same order as on the comparable points (1.7-2.0x at n = 16 and 32,
  entry 6).
- **Why these are not comparable with C.** C's budget counts backtracks
  (10,000,000 retries); the extracted VM's fuel counts instructions.
  The rows are therefore not on the same scale as `c-noopt`'s -17 times
  (110-116 ms), and no ratio to C is given. This is decision 3's
  labelling.
