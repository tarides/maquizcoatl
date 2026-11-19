# Lab notebook

Append-only index of recorded runs. One entry per run; data, provenance
and analysis live in the linked `results/` directory. Paths are
repository-relative or `<workdir>/...` (a work directory outside the
repository).

| Date | Experiment | Upstream / tools | Finding | Results |
|------|------------|------------------|---------|---------|
| 2026-11-19 | #2 semantic probes: 134 probes (5 areas) on Debug and ASan/UBSan builds vs Node.js. Probes at `cda40ca`. Replay: build per [`probes/README.md`](../probes/README.md), then `probes/run.sh <workdir>/probes-build <out>` (`ASAN_OPTIONS=detect_leaks=1:abort_on_error=0`, `UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=0`, Node flags `--js-regexp-modifiers --js-regexp-duplicate-named-groups`) | `f95747b` (6.9.10); GCC 15.2.0, CMake 4.2.3, Node v22.22.1; i7-1260P, Ubuntu 26.04.1, Linux 7.0.0-43 | No crash or sanitizer report. Captures in loops, unset backrefs, empty iterations, case folding: Linden adapts. Lookbehind: rewrite (forward match from nearest start). 3 deviation candidates (D1 alt_reduce defeated by possessivisation, D2 undocumented ban on captures in negative lookbehind, D3 doc/RE empty-loop example). | [results/02-semantic-probes-2026-11-19/](results/02-semantic-probes-2026-11-19/README.md) |
