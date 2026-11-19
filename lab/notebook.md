# Lab notebook

One line per recorded run; details in `lab/results/`. Results files are
append-only.

| Date | Experiment | Finding | Link |
|---|---|---|---|
| 2026-11-19 | exp-11 builds | Seven columns built from pinned sources on the blocksci bench host; dispatch probe confirms one direct-threaded and one switch Oniguruma build | [results](results/2026-11-19-exp-11-builds.md) |
| 2026-11-19 | exp-11 agreement | 103 disagreeing patterns over 6 columns, all classified as syntax or semantic differences; switch build identical to threaded; RE2, Rust and ocaml-re run under half of the VS Code patterns | [results](results/2026-11-19-exp-11-agreement.md) |
| 2026-11-19 | exp-11 throughput | Switch dispatch runs at 0.74-0.80 of direct-threaded on real workloads; on VS Code patterns PCRE2 JIT is 2.4× Oniguruma, the interpreter 0.52×; RE2/Rust/ocaml-re are 1.2-4× faster on the under-half of patterns they accept; all cells under 2% spread | [results](results/2026-11-19-exp-11-throughput.md) |
| 2026-11-19 | exp-11 worst-case | Oniguruma's default retry limit stops catastrophic backtracking with −17 after 0.1-0.15 s (no 60 s cap reached); PCRE2 stops on its match or JIT stack limit; automaton engines answer in microseconds | [results](results/2026-11-19-exp-11-worst-case.md) |
