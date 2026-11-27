# Experiment #12 follow-up (issue #22), entry 10: short subjects with the columns built in flambda (run 2)

**What.** The short-subject series of run `x2`. It reruns the six
columns of run 1 (switch `ffi`). Interleaved with them are three columns
built in `ffi-flambda` with `-O3`: the Rocq- and F\*-extracted VMs
(`rocq-flambda`, `fstar-flambda`) and the hand-written VM
(`vm-flambda`). The work files are run 1's (`<fam>.agreed.work`, the
same calls) and so is the protocol.

**Why.** Decision 8 adds the flambda row to run 2 (amending decision 5).
Run 2 also includes `vm-flambda`, which decision 8 does not name. The
plan's question is extraction cost against the hand-written VM at the
same compiler (requirement 1: baselines rerun on the subset), and
without `vm-flambda` on these calls the flambda extracted columns have
no same-compiler VM to be compared with. Experiment #12's
`vm-flambda` figures are on its full subset and cannot serve. The
column costs about 25 s per series.

Provenance: [entry 9](2026-11-27-exp-12-followup-run2-setup.md).
Command: `FLAMBDA=1 run22.py short x2 10`, then `FLAMBDA=1 run22.py
repeat x2 short`. The protocol is experiment #12's: one process per
cell under `taskset -c 2`, `timeout 120`, one untimed warm-up pass, and
passes repeated for at least 0.5 s. There are 10 runs with the order
shuffled by seed r, and 36 cells per run. Series 14:24:06-14:27:51 UTC,
load average 0.87-1.20, CPU 2 idle at the start (`cpu2.log`). All 360
processes exited 0. No cell had an IQR above 10% of its median, so
`repeat` had nothing to rerun. Raw:
[`short.csv`](2026-11-27-exp-12-followup-run2-raw/short.csv),
[`summary/short-x2.md`](2026-11-27-exp-12-followup-run2-raw/summary/short-x2.md),
[`summary/short-x2-summary.csv`](2026-11-27-exp-12-followup-run2-raw/summary/short-x2-summary.csv).

## Results (median ns per call over 10 runs)

| Family | c | stubs | ctypes | vm | rocq | fstar | **vm-flambda** | **rocq-flambda** | **fstar-flambda** |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| jq | 123.2 | 133.7 | 739.0 | 81.6 | 198.5 | 349.7 | **72.7** | **157.6** | **363.6** |
| PHP | 93.8 | 105.0 | 705.2 | 88.1 | 189.2 | 317.5 | **80.9** | **150.9** | **325.8** |
| VS Code | 67.2 | 76.0 | 663.1 | 484.6 | 1,745.2 | 3,864.1 | **441.2** | **1,211.5** | **4,118.6** |
| long PHP (scan mode for the extracted columns) | 132.0 | 171.8 | 796.7 | 56.6 | 106.1 | 151.7 | **47.5** | **85.6** | **150.7** |

Minor words per call (median):

| Family | vm / vm-flambda | rocq / rocq-flambda | fstar / fstar-flambda |
|---|---|---|---|
| jq | 0.03 / 0.03 | 266.27 / 98.98 | 97.65 / 95.65 |
| PHP | 0.05 / 0.05 | 227.29 / 79.97 | 79.35 / 77.38 |
| VS Code | 0.00 / 0.00 | 3,104.20 / 529.01 | 530.58 / 528.58 |
| long PHP | 0.30 / 0.30 | 107.30 / 46.30 | 48.30 / 42.30 |

The largest IQR/median is 5.8% (long PHP `vm`). Every cell's full
figures (min, IQR, major words) are in `summary/short-x2.md`.

### Run 2's `ffi` columns against run 1's

Every one of the 24 `ffi` cells is within 1.2% of run 1's median
(largest: PHP ctypes 705.2 against 713.8). The extracted columns are
within 0.6% (Rocq VS Code 1,745.2 against 1,752.9; F\* VS Code 3,864.1
against 3,876.2). So the short-shape figures of
[entry 4](2026-11-27-exp-12-followup-short.md) replicate on the same
binaries in a series run 1 h 18 min later.

## Extraction cost by compiler

Extracted column minus the hand-written VM built with the same
compiler, in ns per call. The factor is the ratio of the medians.

| Family | Rocq - VM, `ffi` | Rocq - VM, flambda | F\* - VM, `ffi` | F\* - VM, flambda |
|---|---:|---:|---:|---:|
| jq | +116.9 (2.4x) | +84.9 (2.2x) | +268.0 (4.3x) | +290.9 (5.0x) |
| PHP | +101.1 (2.1x) | +70.0 (1.9x) | +229.4 (3.6x) | +244.8 (4.0x) |
| VS Code | +1,260.6 (3.6x) | +770.3 (2.7x) | +3,379.5 (8.0x) | +3,677.4 (9.3x) |
| long PHP | +49.5 (1.9x) | +38.0 (1.8x) | +95.1 (2.7x) | +103.1 (3.2x) |

Flambda's effect on each column (flambda median / `ffi` median):

| Family | VM | Rocq | F\* |
|---|---:|---:|---:|
| jq | 0.89 | 0.79 | 1.04 |
| PHP | 0.92 | 0.80 | 1.03 |
| VS Code | 0.91 | 0.69 | 1.07 |
| long PHP | 0.84 | 0.81 | 0.99 |

Against C: `rocq-flambda` runs at 1.28x (jq), 1.61x (PHP), 18.0x
(VS Code) and 0.65x (long PHP). With `ffi` the same columns were at
1.61x, 2.02x, 26.0x and 0.80x. `fstar-flambda` runs at 2.95x, 3.47x,
61.3x and 1.14x, against 2.84x, 3.39x, 57.5x and 1.15x with `ffi`.

## Analysis

- **Flambda helps the Rocq-extracted VM more than the hand-written
  one.** The Rocq column is 19-31% faster with flambda, against 8-16%
  for the VM. The gain comes with 2.3-5.9x fewer minor words per call
  (VS Code: 3,104 down to 529). The extraction overhead over the VM
  falls by 23-39% (jq 117 to 85 ns, VS Code 1,261 to 770 ns).
  `rocq-flambda`'s words per call come down to the F\* column's level
  (99 against 98 on jq, 529 against 531 on VS Code), and the F\* column
  already allocated about that much under `ffi`. Which allocations
  flambda removes was not investigated; the generated code was not
  inspected.
- **Flambda does not help the F\*-extracted VM.** F\* is 3-7% slower on
  jq, PHP and VS Code and unchanged on long PHP, with 1-12% fewer minor
  words. Its allocation was already at the level flambda brings Rocq
  to, so the gain Rocq gets has no counterpart here, and what remains
  includes the `Z.t` arithmetic on every pc, position and fuel
  operation. Neither the absence of a gain nor the small slowdown was
  investigated. The slowdown holds across the 10 interleaved runs
  (IQR 0.4-1.6%).
- **The order of the columns does not change.** C, stubs and the VM
  keep their places. Rocq with flambda is still 1.3-1.6x C on jq and
  PHP and 18x on VS Code, and still 1.8-2.7x the VM at the same
  compiler. F\* with flambda is 1.8-2.3x Rocq with flambda on jq, PHP and
  long PHP, and 3.4x on VS Code (with `ffi`: 1.4-1.8x and 2.2x).
- **Experiment #12's `vm-flambda` gain is reproduced on the subset.**
  On the fragment subset flambda saves 8-16% on the hand-written VM.
  Experiment #12 found 11-31% on its full subset (issue #22's question
  4). That is the same order, smaller here because these calls are
  shorter.

Only the short shape was built and timed with flambda, as decision 8
says. The large and catastrophic shapes stay `ffi`-only.
