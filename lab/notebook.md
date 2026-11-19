# Lab notebook

Append-only index of recorded runs. One entry per run; data, provenance
and analysis live in the linked `results/` directory. Paths are
repository-relative or `<workdir>/...` (a work directory outside the
repository).

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
