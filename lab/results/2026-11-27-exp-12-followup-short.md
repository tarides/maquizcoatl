# Experiment #12 follow-up (issue #22), entry 4: short subjects, extracted columns beside fresh baselines

**What.** Time and allocation per call of the two extracted columns of
run `x1`, Rocq (`rocq`) and F\* (`fstar`), on the fragment subset of
experiment #1's short-subject workloads. The four baselines are rerun in
the same interleaved series: the C-only driver (`c`), the `[@@noalloc]`
stubs, ctypes, and the hand-written VM (`vm`, switch `ffi`). Experiment
#12's full-subset figures are kept beside them as context.

**Why.** Issue #10's criterion 2, restricted to what experiment #9's
fragment can run (decision 2). Experiment #12's figures are per family
pass over its own, larger subset, so no fragment-subset figure can be
derived from them, and every baseline is rerun (requirement 1).

Provenance: [entry 1](2026-11-27-exp-12-followup-provenance.md).
Command: `run22.py short x1 10`, then `run22.py repeat x1 short`.
This is experiment #12's protocol, unchanged: one process per cell under
`taskset -c 2` and `timeout 120`, one untimed warm-up pass, then passes
repeated for at least 0.5 s; 10 runs, interleaved, with the order
shuffled by seed r. Series 13:06-13:09 UTC, 1-minute load average
0.53-2.86, CPU 2 measured idle before the series (`cpu2.log`), governor
`schedutil`. All 240 processes exited 0. No cell had an IQR above 10% of
its median, so none was repeated. Raw:
[`short.csv`](2026-11-27-exp-12-followup-raw/short.csv),
[`summary/short.md`](2026-11-27-exp-12-followup-raw/summary/short.md).

Calls per pass: jq 91, PHP 63, VS Code 127,660 (77,067 searches weighted
by the frequency profile's `count`), long PHP 10 (one 2 MiB subject,
pattern `a`, start 0..4). The long-PHP row is the large shape's labelled
synthetic row, so it runs the extracted engines in scan mode
(`rocq-scan`, `fstar-scan`).

## Results (median ns per call over 10 runs; IQR/median in parentheses)

| Family | c | stubs | ctypes | vm | rocq | fstar | experiment #12 c / vm, full subset (context) |
|---|---:|---:|---:|---:|---:|---:|---|
| jq | 123.2 (2.4%) | 134.1 (0.3%) | 740.3 (1.2%) | 81.4 (0.8%) | 197.6 (1.5%) | 349.6 (1.2%) | 123.2 / 83.7 |
| PHP | 93.8 (0.3%) | 105.1 (0.8%) | 713.8 (2.0%) | 87.9 (1.9%) | 190.0 (1.5%) | 316.8 (0.8%) | 6,899 / 12,780 |
| VS Code | 67.4 (0.5%) | 76.0 (0.9%) | 666.3 (1.0%) | 483.6 (3.3%) | 1,752.9 (1.5%) | 3,876.2 (2.0%) | 78.3 / 646.7 |
| long PHP | 131.6 (1.0%) | 172.3 (1.2%) | 795.3 (1.0%) | 57.2 (5.1%) | 105.9 (3.9%) | 151.3 (2.1%) | 14,368 / 39,618 |

Minor words allocated per call:

| Family | c | stubs | ctypes | vm | rocq | fstar |
|---|---:|---:|---:|---:|---:|---:|
| jq | 0 | 0.03 | 329.0 | 0.03 | 266.3 | 97.7 |
| PHP | 0 | 0.05 | 328.5 | 0.05 | 227.3 | 79.4 |
| VS Code | 0 | 0.00 | 329.0 | 0.00 | 3,104.2 | 530.6 |
| long PHP | 0 | 0.30 | 329.3 | 0.30 | 107.3 | 48.3 |

Major words per call: below 0.01 everywhere except Rocq on VS Code
(1.20) and F\* on VS Code (0.18). The `ffi-flambda` VM and `ocaml-re`
are not rerun (plan, Engines). Their experiment #12 figures are in
[`summary/short.md`](2026-11-27-exp-12-followup-raw/summary/short.md),
labelled as not rerun.

## Costs on the same subset (differences of medians, ns per call)

| Family | FFI crossing: stubs - C | ctypes - C | engine: VM - C | Rocq - C | F\* - C | extraction: Rocq - VM (net of conversion) | F\* - VM (net) |
|---|---:|---:|---:|---:|---:|---:|---:|
| jq | +10.9 | +617 | -41.8 | +74.4 (1.6x) | +226 (2.8x) | +116 (+98.7) | +268 (+251) |
| PHP | +11.3 | +620 | -5.9 | +96.2 (2.0x) | +223 (3.4x) | +102 (+89.3) | +229 (+216) |
| VS Code | +8.6 | +599 | +416 | +1,686 (26.0x) | +3,809 (57.5x) | +1,269 (+1,240) | +3,393 (+3,364) |
| long PHP | +40.8 | +664 | -74.4 | -25.7 (0.8x) | +19.7 (1.1x) | +48.7 | +94.1 |

"Net of conversion" subtracts the extracted column's median per-call
conversion cost ([entry 2](2026-11-27-exp-12-followup-checks.md)) before
subtracting the VM. On long PHP the extracted columns run in scan mode,
so conversion is already outside the figure. Raw tables:
[`summary/costs.md`](2026-11-27-exp-12-followup-raw/summary/costs.md),
[`summary/conv.md`](2026-11-27-exp-12-followup-raw/summary/conv.md).

## Analysis

- **The fragment subset is much cheaper than experiment #12's subset**
  on PHP and long PHP: C costs 94 ns and 132 ns per call here, against
  6,899 ns and 14,368 ns there. Experiment #12's PHP and long-PHP
  figures were dominated by calls whose patterns are outside the
  fragment (classes, anchors, `\s`, backtracking-heavy shapes). On jq
  and VS Code the C figures are close to experiment #12's (123 against
  123 ns, 67 against 78 ns), and so are the baselines' differences:
  stubs cost 8.6-11.3 ns over C (40.8 ns on long PHP), and ctypes
  about 600 ns plus 329 words.
- **Extraction cost.** On top of the hand-written VM, the Rocq column
  costs about 100-120 ns per call on jq and PHP, and the F\* column
  about 230-270 ns. On VS Code the cost grows with the work done: 3.6x
  the VM for Rocq and 8.0x for F\*. These searches walk many start
  positions (16.5 bytes per call on average, scanner members with
  several alternatives), and every position allocates a fresh VM state
  and stack. Conversion explains only 13-29 ns of these gaps.
- **Allocation.** The extracted VMs allocate on every instruction: a
  state record, stack cells, and an association-list cell per capture
  write. Rocq allocates 3,104 words per VS Code call, F\* 531. F\*
  allocates less than Rocq, yet it is 2.2x slower. Its `Z.t` arithmetic
  goes through zarith's out-of-line calls for every pc, position and
  fuel operation, and that costs more time than the extra words do.
- **Against C.** On short subjects the Rocq column is 1.6-2.0x C on jq
  and PHP and 26x on VS Code; the F\* column is 2.8-3.4x and 57.5x. On
  long PHP, where each call matches at its first position, Rocq is
  slightly faster than C (106 against 132 ns), as the hand-written VM
  already was (57 ns). Each call reads the subject only at the start
  position and does a single `IStr`, so per-call overhead decides it.
