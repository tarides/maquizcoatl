## Cases

| Suite | Cases | In subset | x2 | x3 | n | e |
|-------|------:|----------:|---:|---:|--:|--:|
| `test_utf8` | 1554 | 151 | 102 | 33 | 13 | 3 |
| `test_back` | 1225 | 0 | 0 | 0 | 0 | 0 |
| `testc` | 785 | 0 | 0 | 0 | 0 | 0 |
| `testu` | 720 | 0 | 0 | 0 | 0 | 0 |
| `test_syntax` | 221 | 0 | 0 | 0 | 0 | 0 |
| `test_options` | 47 | 1 | 1 | 0 | 0 | 0 |
| `test_regset` | 13 | 0 | 0 | 0 | 0 | 0 |
| total | 4565 | 152 | 103 | 33 | 13 | 3 |

Out of the subset, by first reason met (suite-level reasons first):

| Reason | Cases |
|--------|------:|
| backward search | 1225 |
| encoding EUC_JP | 785 |
| (? group | 725 |
| encoding UTF16_BE | 720 |
| anchor | 153 |
| nested class / posix bracket | 77 |
| + | 65 |
| ctype escape (Unicode tables) | 62 |
| syntax JAVA | 60 |
| syntax PERL | 58 |
| interval | 47 |
| options | 43 |
| syntax PYTHON | 42 |
| \x{} form | 36 |
| ? | 33 |
| syntax GREP | 33 |
| \1 | 26 |
| \p | 25 |
| \p in class | 22 |
| syntax POSIX_BASIC | 16 |
| \g | 14 |
| regset API | 13 |
| \o | 11 |
| lazy star | 10 |
| syntax PERL_NG | 9 |
| \2 | 8 |
| \xHH >= 0x80 (raw byte) | 8 |
| \Y | 8 |
| class intersection | 7 |
| \R | 6 |
| \y | 6 |
| \K | 5 |
| \7 | 4 |
| \o in class | 4 |
| \X | 4 |
| \u | 4 |
| \x{} code point | 4 |
| \O | 3 |
| (* verb | 3 |
| {,n} | 3 |
| \k | 3 |
| syntax EMACS | 3 |
| \c | 2 |
| '-' after range | 2 |
| \N | 2 |
| \P | 2 |
| invalid-utf8-in-pattern | 2 |
| \C | 1 |
| \c in class | 1 |
| \0 in class | 1 |
| \h | 1 |
| \H | 1 |
| \h in class | 1 |
| \H in class | 1 |
| \u in class | 1 |
| \P in class | 1 |
| escaped non-ASCII | 1 |

Informational: accepting `+`, `?` and `(?:...)` (desugared) would put 288 cases in the subset (214 x2, 49 x3, 21 n, 4 e), 136 more.

## Agreement

C against the test files' expectations: 152/152.

| Row | x2 | x3 | n | e | e code | All regions identical to C | Out of subset |
|-----|---:|---:|--:|--:|-------:|--------------------------:|--------------:|
| stack G | 103/103 | 33/33 | 13/13 | 3/3 | 3/3 | 152/152 | 4413 |
| rocq | 103/103 | 33/33 | 13/13 | 3/3 (stack G's parser) | 3/3 | 152/152 | 4413 |
| lean | 103/103 | 33/33 | 13/13 | 3/3 (stack G's parser) | 3/3 | 152/152 | 4413 |
| why3 | 103/103 | 33/33 | 13/13 | 3/3 (stack G's parser) | 3/3 | 152/152 | 4413 |
| fstar | 103/103 | 33/33 | 13/13 | 3/3 (stack G's parser) | 3/3 | 152/152 | 4413 |
| verus | 103/103 | 33/33 | 13/13 | 3/3 (stack G's parser) | 3/3 | 152/152 | 4413 |
| isabelle | 103/103 | 33/33 | 13/13 | 3/3 (stack G's parser) | 3/3 | 152/152 | 4413 |

## Throughput

Extracted or compiled code: in-process timing of REPS passes (median of three runs); wall-clock and peak RSS of the whole process from `/usr/bin/time -v`.

| Row | Mode | REPS | Parse cases/s | Search cases/s | End to end cases/s | 10^6 cases (s) | Wall s | RSS MB | Load (1 min) |
|-----|------|-----:|-------------:|---------------:|-------------------:|---------------:|-------:|-------:|-------------|
| C library (reference) | native | 400000 | 858317 | 5788778 | 684137 | 1.5 | 170.18 | 2 | 0.10, 1.49, 2.04 |
| stack G, ocamlopt | native | 400000 | 2566443 | 5482772 | 853167 | 1.2 | 106.04 | 7 | 1.02, 2.54, 2.24 |
| Rocq, extracted OCaml | extracted | 60000 | (stack G) | 767480 | 590804 | 1.7 | 11.65 | 7 | 2.05, 1.31, 1.37 |
| Lean 4, lake native build | extracted | 50000 | (stack G) | 881968 | 656395 | 1.5 | 8.45 | 8 | 1.81, 1.24, 1.44 |
| Why3, extracted OCaml | extracted | 35000 | (stack G) | 456509 | 387570 | 2.6 | 11.43 | 7 | 1.75, 1.22, 1.48 |
| F*, extracted OCaml | extracted | 120000 | (stack G) | 1567045 | 972963 | 1.0 | 11.41 | 7 | 1.58, 1.78, 2.73 |
| Verus, compiled Rust | compiled | 250000 | (stack G) | 3533001 | 1486569 | 0.7 | 10.54 | 2 | 1.20, 0.41, 0.61 |
| Isabelle/HOL, export_code OCaml | extracted | 150000 | (stack G) | 1649722 | 1004211 | 1.0 | 13.55 | 8 | 1.16, 0.50, 0.67 |

For prover rows, end to end = stack G's parse plus the prover's search (plan step 8); 10^6 cases (s) = 10^6 / end-to-end cases/s.

In-prover evaluation: wall-clock of the evaluation command minus the import-only baseline Q0 of the same run (experiment #7's method), median of three runs.

| Prover | Mode | Passes | Cases | Eval s (median) | Q0 s (median) | Search cases/s | 10^6 cases (s) | Peak RSS MB | Load (1 min) |
|--------|------|-------:|------:|----------------:|--------------:|---------------:|---------------:|------------:|-------------|
| rocq | vm_compute | 3000 | 447000 | 26.53 | 0.48 | 17153 | 58.7 | 1688 | 2.54, 1.75, 1.27 |
| rocq | native_compute | 4000 | 596000 | 19.34 | 0.48 | 31618 | 32.0 | 1731 | 2.54, 1.49, 1.29 |
| rocq | native_compute, first call (1 pass) | 1 | 149 | 0.61 | 0.48 | 1146 | 872.9 | 268 | 2.54, 1.49, 1.29 |
| lean | #eval | 5000 | 745000 | 12.96 | 0.28 | 58800 | 17.4 | 459 | 2.10, 1.41, 1.21 |
| why3 | why3 execute | 5 | 745 | 12.48 | 0.44 | 62 | 16174.9 | 1129 | 1.86, 1.32, 1.23 |
| fstar | assert_norm (normaliser; extra mode) | 5 | 745 | 11.87 | 0.12 | 63 | 15785.6 | 483 | 2.84, 2.56, 2.32 |
| isabelle | value [code] (fold under 10 s, see QVL) | 8000 | 1192000 | 10.38 | 8.45 | 617617 | 2.0 | 1428 | 1.04, 2.10, 3.00 |
| isabelle | value [code] | 100000 | 14900000 | 15.49 | 8.61 | 2159420 | 0.9 | 1446 | 1.11, 1.30, 1.25 |

## T_spec (milestone 1)

| Prover, target | Step | Median s | Runs s | Peak RSS MB | Load (1 min) per run | Status |
|----------------|------|---------:|--------|------------:|----------------------|--------|
| rocq | rocq-check | 0.85 | 0.85, 0.84, 0.86 | 337 | 1.15, 1.22, 1.20 | 0,0,0 |
| rocq | rocq-extract | 0.50 | 0.50, 0.50, 0.49 | 260 | 1.15, 1.22, 1.18 | 0,0,0 |
| rocq | rocq-ocamlopt | 0.14 | 0.14, 0.13, 0.14 | 25 | 1.15, 1.22, 1.18 | 0,0,0 |
| lean | lean-check | 0.55 | 0.55, 0.50, 0.56 | 490 | 1.15, 1.20, 1.18 | 0,0,0 |
| lean | lean-emit-c | 0.54 | 0.54, 0.53, 0.54 | 489 | 1.22, 1.20, 1.18 | 0,0,0 |
| lean | lean-cc | 0.58 | 0.59, 0.58, 0.58 | 92 | 1.22, 1.20, 1.18 | 0,0,0 |
| why3 | why3-typecheck | 0.08 | 0.08, 0.08, 0.08 | 26 | 1.22, 1.20, 1.18 | 0,0,0 |
| why3 | why3-vcgen | 0.07 | 0.09, 0.07, 0.07 | 27 | 1.22, 1.20, 1.18 | 0,0,0 |
| why3 | why3-extract-ocaml | 0.32 | 0.33, 0.32, 0.32 | 50 | 1.22, 1.20, 1.18 | 0,0,0 |
| why3 | why3-ocamlopt | 0.07 | 0.07, 0.07, 0.08 | 21 | 1.22, 1.20, 1.18 | 0,0,0 |
| fstar | fstar-check | 0.87 | 0.81, 0.87, 0.87 | 105 | 1.22, 1.20, 1.18 | 0,0,0 |
| fstar | fstar-extract-ocaml | 0.14 | 0.13, 0.15, 0.14 | 85 | 1.22, 1.20, 1.18 | 0,0,0 |
| fstar | fstar-ocamlopt | 0.26 | 0.27, 0.26, 0.25 | 31 | 1.22, 1.20, 1.18 | 0,0,0 |
| verus | verus-check | 1.30 | 1.28, 1.30, 1.34 | 342 | 2.48, 2.23, 2.74 | 0,0,0 |
| verus | verus-rustc | 1.07 | 1.07, 1.09, 1.05 | 326 | 2.48, 2.23, 2.74 | 0,0,0 |
| isabelle | isabelle-check-base | 9.20 | 9.20, 9.17, 9.30 | 1507 | 2.36, 2.23, 2.60 | 0,0,0 |
| isabelle | isabelle-check | 13.65 | 13.61, 13.65, 13.94 | 2396 | 2.57, 3.07, 2.55 | 0,0,0 |
| isabelle | isabelle-export-code | 19.93 | 19.98, 19.93, 19.77 | 2375 | 2.37, 3.04, 2.21 | 0,0,0 |
| isabelle | isabelle-ocamlopt | 0.10 | 0.09, 0.10, 0.10 | 23 | 2.23, 2.74, 3.00 | 0,0,0 |

T_spec (sum of medians; Lean: emit-c includes elaboration, as experiment #7 counted it; Why3: type check + extraction + compile, VC generation listed apart; Verus: verification + rustc, no extraction step; Isabelle: session builds include JVM start and HOL-Library loading, isabelle-check-base is that overhead alone and is excluded from the sum):

- rocq: 1.49 s
- lean: 1.12 s
- why3: 0.47 s
- fstar: 1.27 s
- verus: 2.37 s
- isabelle: 33.68 s

## Experiment #7 T_table, idle rerun (runs 11-13)

| Label | Median s | Runs s | Peak RSS MB | Load (1 min) per run | Status |
|-------|---------:|--------|------------:|----------------------|--------|
| fstar-check | 20.91 | 21.24, 20.70, 20.91 | 652 | 2.17, 1.12, 1.20 | 0,0,0 |
| fstarc-check | 29.57 | 29.85, 29.57, 29.41 | 1380 | 1.91, 1.09, 1.15 | 0,0,0 |
| fstar-extract-ocaml | 14.45 | 14.45, 14.35, 14.60 | 1261 | 1.75, 1.11, 1.21 | 0,0,0 |
| fstar-ocamlopt | 4.69 | 4.71, 4.69, 4.68 | 520 | 1.63, 1.15, 1.16 | 0,0,0 |
| fstar-sample | 0.27 | 0.26, 0.27, 0.27 | 9 | 1.58, 1.14, 1.15 | 0,0,0 |
| fstarc-extract-krml | 7.47 | 7.47, 7.53, 7.45 | 600 | 1.58, 1.14, 1.15 | 0,0,0 |
| fstarc-krml | 6.04 | 6.11, 6.04, 6.04 | 234 | 1.65, 1.12, 1.12 | 0,0,0 |
| fstarc-gcc-krml | 7.24 | 7.28, 7.24, 7.23 | 254 | 1.60, 1.11, 1.11 | 0,0,0 |
| fstarc-sample-krml | 0.03 | 0.03, 0.03, 0.03 | 2 | 1.51, 1.10, 1.10 | 0,0,0 |
| fstarc-extract-c | 8.23 | 8.23, 8.30, 8.23 | 792 | 1.51, 1.09, 1.10 | 0,0,0 |
| fstarc-gcc-c | 6.91 | 6.96, 6.90, 6.91 | 248 | 1.47, 1.16, 1.17 | 0,0,0 |
| fstarc-sample-c | 0.03 | 0.03, 0.03, 0.02 | 2 | 1.47, 1.14, 1.16 | 0,0,0 |
| lean-check | 23.27 | 23.26, 23.27, 23.34 | 1500 | 1.18, 1.11, 1.19 | 0,0,0 |
| lean-emit-c | 23.17 | 23.35, 23.17, 23.09 | 1499 | 1.27, 1.23, 1.19 | 0,0,0 |
| lean-cc | 37.31 | 37.31, 37.38, 37.26 | 351 | 1.24, 1.50, 1.20 | 0,0,0 |
| lean-link | 0.40 | 0.41, 0.40, 0.38 | 433 | 1.13, 1.25, 1.11 | 0,0,0 |
| lean-sample | 0.08 | 0.08, 0.08, 0.09 | 20 | 1.12, 1.25, 1.10 | 0,0,0 |
| pulse-check | 118.91 | 118.91, 113.65, 119.09 | 1328 | 1.47, 1.14, 1.16 | 0,0,0 |
| pulse-extract-krml | 5.53 | 5.53, 5.47, 5.57 | 528 | 1.15, 1.06, 1.16 | 0,0,0 |
| pulse-krml | 1.26 | 1.26, 1.25, 1.27 | 93 | 1.13, 1.13, 1.15 | 0,0,0 |
| pulse-gcc-krml | 2.21 | 2.19, 2.21, 2.21 | 80 | 1.13, 1.20, 1.22 | 0,0,0 |
| pulse-sample-krml | 0.05 | 0.05, 0.04, 0.05 | 2 | 1.13, 1.20, 1.22 | 0,0,0 |
| pulse-extract-c | 5.55 | 5.51, 5.55, 5.61 | 528 | 1.13, 1.20, 1.22 | 0,0,0 |
| pulse-gcc-c | 0.71 | 0.71, 0.72, 0.71 | 58 | 1.12, 1.19, 1.20 | 0,0,0 |
| pulse-sample-c | 0.04 | 0.04, 0.04, 0.05 | 2 | 1.11, 1.19, 1.20 | 0,0,0 |
| rocq-check | 15.69 | 15.71, 15.59, 15.69 | 744 | 1.12, 1.25, 1.10 | 0,0,0 |
| rocq-extract | 8.14 | 8.05, 8.14, 8.14 | 768 | 1.09, 1.20, 1.08 | 0,0,0 |
| rocq-ocamlopt | 34.70 | 34.72, 34.62, 34.70 | 4995 | 1.08, 1.16, 1.06 | 0,0,0 |
| rocq-sample | 0.89 | 0.89, 0.89, 0.89 | 8 | 2.94, 1.20, 1.14 | 0,0,0 |
| why3-typecheck | 1.37 | 1.37, 1.36, 1.37 | 197 | 2.94, 1.20, 1.14 | 0,0,0 |
| why3-vcgen | 2.00 | 2.02, 1.95, 2.00 | 229 | 2.94, 1.20, 1.14 | 0,0,0 |
| why3c-typecheck | 1.59 | 1.59, 1.59, 1.57 | 201 | 2.78, 1.18, 1.13 | 0,0,0 |
| why3-extract-ocaml | 2.12 | 2.14, 2.11, 2.12 | 290 | 2.78, 1.18, 1.13 | 0,0,0 |
| why3-ocamlopt | 11.97 | 11.97, 11.97, 12.10 | 720 | 2.78, 1.17, 1.13 | 0,0,0 |
| why3-sample | 0.39 | 0.37, 0.39, 0.39 | 15 | 2.39, 1.14, 1.24 | 0,0,0 |
| why3c-extract-c | 2.74 | 2.75, 2.74, 2.71 | 340 | 2.39, 1.14, 1.24 | 0,0,0 |
| why3c-gcc | 8.14 | 8.17, 8.13, 8.14 | 276 | 2.39, 1.13, 1.24 | 0,0,0 |
| why3c-sample | 0.03 | 0.03, 0.03, 0.03 | 2 | 2.17, 1.12, 1.20 | 0,0,0 |

## Experiment #7's T_table at idle against milestone 1's T_spec

| Target | T_table loaded s (#7) | T_table idle s (runs 11-13) | Idle / loaded | Load (1 min) idle runs | T_spec s (milestone 1) | T_table idle / T_spec | Verdict |
|--------|------:|------:|------:|------|------:|------:|------|
| Rocq -> OCaml | 85.97 | 58.53 | 0.68 | 1.06-1.25 | 1.49 | 39 | open (#7's provisional verdict stands) |
| Lean -> C -> native | 95.38 | 60.88 | 0.64 | 1.11-1.50 | 1.12 | 54 | open (#7's provisional verdict stands) |
| Why3 -> OCaml | 24.45 | 15.46 | 0.63 | 1.13-2.94 | 0.47 | 33 | open (#7's provisional verdict stands) |
| Why3 -> C (decision trees) | 20.19 | 12.47 | 0.62 | 1.13-2.78 | 0.47 | 27 | open (#7's provisional verdict stands) |
| F* -> OCaml | 60.32 | 40.05 | 0.66 | 1.11-2.17 | 1.27 | 32 | open (#7's provisional verdict stands) |
| F* -> KaRaMeL C (decision trees) | 73.99 | 50.32 | 0.68 | 1.09-1.91 | 1.27 | 40 | open (#7's provisional verdict stands) |
| F* -> direct C (decision trees) | 65.49 | 44.71 | 0.68 | 1.09-1.91 | 1.27 | 35 | open (#7's provisional verdict stands) |
| F*/Pulse -> KaRaMeL C (static arrays) | 175.31 | 127.91 | 0.73 | 1.06-1.47 | 1.27 | 101 | open (#7's provisional verdict stands) |
| F*/Pulse -> direct C (static arrays) | 172.78 | 125.17 | 0.72 | 1.12-1.47 | 1.27 | 99 | open (#7's provisional verdict stands) |
