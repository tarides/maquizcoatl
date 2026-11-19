# Lab notebook

Append-only index of recorded runs. One entry per run; data, provenance
and analysis live in the linked `results/` directory. Paths are
repository-relative, `<workdir>/...` (a work directory outside the
repository), or `<cache>` and `<exp>` on the bench host
(`<bench-workdir>/cache` and `<bench-workdir>/exp/07-large-tables`).

## Experiment #1

| Date | Experiment | Finding | Link |
|---|---|---|---|
| 2026-11-19 | exp-01 workloads | VS Code, jq, PHP regex calls captured and packaged with stock `f95747b` expected results; 42 VS Code searches differ from the host's bundled Oniguruma (one grammar pattern rejected by `f95747b`) | [results](results/2026-11-19-exp-01-workloads.md) |
| 2026-11-19 | exp-01 corpus | 17,367 VS Code, 69 jq and 144 PHP occurrences from pinned sources; 5,870 / 44 / 73 distinct triples; host configurations confirmed | [results](results/2026-11-19-exp-01-corpus.md) |
| 2026-11-19 | exp-01 compile-and-classify | 96.5% of compiled triples in the linear ReDoS tier; no pattern callouts; absent operator in 2 triples; subexpression calls in 2% of triples but 18/82 VS Code grammars; proposed first subset S2 covers 97.9% | [results](results/2026-11-19-exp-01-compile-and-classify.md) |
| 2026-11-19 | exp-01 review fixes | Shift_JIS naming fixed (6 dynamic-only PHP triples now compile, 131/131); `\z` rewrite changes 10 occurrences / 7 patterns; long-subject PHP sample (18 calls, 2 synthetic subjects); VS Code searches issued 1,486,388 times for 473,134 distinct; corrects two full-capture counts of the workloads entry | [results](results/2026-11-19-exp-01-review-fixes.md) |

## Experiment #2

| Date | Experiment | Upstream / tools | Finding | Results |
|------|------------|------------------|---------|---------|
| 2026-11-19 | #2 semantic probes: 134 probes (5 areas) on Debug and ASan/UBSan builds vs Node.js. Probes at `cda40ca`. Replay: build per [`probes/README.md`](../probes/README.md) (layout used: `<workdir>/build`, `<workdir>/build-asan`, harnesses in `<workdir>/probes-build`), then `probes/run.sh <workdir>/probes-build <out>` (`ASAN_OPTIONS=detect_leaks=1:abort_on_error=0`, `UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=0`, Node flags `--js-regexp-modifiers --js-regexp-duplicate-named-groups`) | `f95747b` (6.9.10); GCC 15.2.0, CMake 4.2.3, Node v22.22.1; i7-1260P, Ubuntu 26.04.1, Linux 7.0.0-43 | No crash or sanitizer report. Captures in loops, unset backrefs, empty iterations, case folding: Linden adapts. Lookbehind: rewrite (forward match from nearest start). 3 deviation candidates (D1 alt_reduce defeated by possessivisation, D2 undocumented ban on captures in negative lookbehind, D3 doc/RE empty-loop example). | [results/02-semantic-probes-2026-11-19/](results/02-semantic-probes-2026-11-19/README.md) |
| 2026-11-19 | #2 run 2 (after review): +4 empty-iteration probes (ei17-ei20), +6 lookbehind probes (lb24/lb25 x 3 syntaxes), plus an `ONIG_DEBUG_COMPILE` bytecode dump (`probes/opcodes.sh`). Probes at `1c8ae99`. Same build layout as run 1 (`<workdir>/build`, `build-asan`, `probes-build`) plus `<workdir>/build-dbgc` and `<workdir>/probes-build-dbgc` (`-DCMAKE_C_FLAGS=-DONIG_DEBUG_COMPILE`); replay per [`probes/README.md`](../probes/README.md) | `f95747b` (6.9.10); GCC 15.2.0, CMake 4.2.3, Node v22.22.1; i7-1260P, Ubuntu 26.04.1, Linux 7.0.0-43 | Supersedes run 1's area-3 verdict and D3: the capture-status empty check (`memst`) is emitted only for groups backreferenced outside the loop (ei16 `M 0-0` vs ei19 `(?:\1a\|())*\1` `M 0-1`). Opcode claims confirmed. Lookbehind body > 65535 chars: -122 under every syntax. No sanitizer report; other areas byte-identical to run 1. | [results/02-semantic-probes-2026-11-19-r2/](results/02-semantic-probes-2026-11-19-r2/README.md) |

## Experiment #7

| Date | Experiment | Upstream / tools | Finding | Results |
|------|------------|------------------|---------|---------|
| 2026-11-19 | #7 toolchains: provers and back ends installed into a shared cache on the bench host (`lab/07-large-tables/setup.sh`) | `f95747b`; opam 2.6.1, OCaml 5.4.1, Rocq 9.3.0, Why3 1.9.0, Alt-Ergo 2.6.5, F\* 2026.11.15 (Pulse, krml 3384ecaf), Lean 4.36.0; AMD EPYC 7502P, Linux 6.8.0-100 | 12 min, 5.6 GB. F\* binary release suffices (bundled krml used instead of building KaRaMeL). Its `fstar.lib` is built by OCaml 5.3.0: `Prims.ml` compiled in the 5.4.1 switch instead | [results/2026-11-19-exp-07-toolchains.md](results/2026-11-19-exp-07-toolchains.md) |
| 2026-11-19 | #7 fidelity: parsed table vs counts, vs the upstream generator on UCD 16.0.0, C oracle and 85,772-query sample (`lab/07-large-tables/fidelity.sh`) | `f95747b`; GCC 13.3.0, Python 3.12.3 | 612 arrays / 24,443 ranges / 629 ctypes / 886 names; generator output identical. `onigenc_unicode_is_code_ctype` differs from `CR_*` on 13 code points below U+0100 (`Cntrl`, `Print`, `Word`): deviation-log candidate | [results/2026-11-19-exp-07-fidelity.md](results/2026-11-19-exp-07-fidelity.md) |
| 2026-11-19 | #7 tables: full table checked in Rocq, Lean, Why3, F\*, three timed runs each, in-prover queries (`timed.sh <tool>`) | as above | All load. Check: Why3 2 s, Rocq 25 s, F\* 30 s, Lean 35 s (< 1.6 GB). Queries: Rocq/Lean < 0.1 s, F\* about 2 s, Why3 `execute` about 2 min and 14 GB each; Why3 interpreter fails on nested list constants | [results/2026-11-19-exp-07-tables.md](results/2026-11-19-exp-07-tables.md) |
| 2026-11-19 | #7 extraction: ten targets (Rocq/Why3/F\* to OCaml, Lean to C, Why3 to C, F\* to KaRaMeL C and direct C with decision trees and with Pulse static arrays), timed and checked on the sample | as above | All targets correct (0 mismatches). Check+extract+compile: Why3 20-24 s, F\* 60-74 s, Rocq 86 s, Lean 95 s, F\*/Pulse 173-175 s. Pulse arrays give compact C (0.6 MB); trees and literals 7-15 MB | [results/2026-11-19-exp-07-extraction.md](results/2026-11-19-exp-07-extraction.md) |
| 2026-11-19 | #7 sanity lemma: sorted, disjoint, non-adjacent ranges, by computation plus checker soundness | as above | Proved in Rocq (`vm_compute`, < 0.1 s), Lean (`decide +kernel`, 3.6 s; plain `decide` fails), F\* (`assert_norm`, 6.0 s). Why3 fails: `compute_in_goal` aborts on term-size growth | [results/2026-11-19-exp-07-sanity-lemma.md](results/2026-11-19-exp-07-sanity-lemma.md) |
| 2026-11-19 | #7 provisional verdicts against the relative cap (Decision 1) | as above | All four: in-prover definition if T_table <= T_spec(#6), with T_table per target above; Why3 cannot compute with or prove over the table, so its table is data for anything stated over its contents | [results/2026-11-19-exp-07-verdicts.md](results/2026-11-19-exp-07-verdicts.md) |
