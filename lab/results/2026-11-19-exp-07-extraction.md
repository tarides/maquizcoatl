# Experiment #7, entry 4: extraction, compilation and the sample check (criteria 2, 5)

**What.** Each tool's path from the table to running code, ten targets in
all: Rocq to OCaml; Lean to native code through C; Why3 to OCaml and to
C; F\* to OCaml, and to C through KaRaMeL and through F\*'s direct C
backend, each for two representations (decision trees and Pulse static
arrays). For each: time and memory to extract and to compile (median of
three clean runs), size of the artefacts, and the answers of the compiled
program on the 85,772 ctype queries and 886 names of entry 2, compared
with the C oracle.

**Why.** Second half of the question (issue #11): if the table stays in
the verified artefact, what does it cost to get it into the OCaml library
and the C drop-in replacement, and is the result right? Decision 4
(option b) asks for KaRaMeL and the direct C backend as separate targets.

## Provenance

As entry 3 (same timed runs, same host, same lock and pinning; commit
`2072e9c`). Exact commands are in the per-tool scripts; the ones that
matter:

- Rocq: `Extraction "rocq_mem.ml" ctype_mem lookup_name.` with
  `ExtrOcamlBasic`, `ExtrOcamlZInt` (Z as native `int`) and
  `ExtrOcamlNativeString`; `ocamlfind ocamlopt -O2 rocq_mem.mli rocq_mem.ml main.ml`
  (`-O2` is ignored without flambda).
- Lean: `lean -R . Table.lean -o Table.olean -c Table.c` (elaboration and
  C emission together; `lake` was not used, the `lean` and `leanc`
  invocations are timed directly), `leanc -c -O3 -DNDEBUG Table.c`,
  `leanc -o e07 Main.o Mem.o Table.o`.
- Why3: `why3 extract -D ocaml64 -L . --recursive mem.Mem -o why3_mem.ml`,
  `ocamlfind ocamlopt -package zarith -linkpkg why3_mem.ml main.ml`;
  `why3 extract -D c -L . --recursive tablec.TableC -o tablec.c`,
  `gcc -O2`.
- F\*: `fstar.exe --cache_checked_modules --cache_dir cache --z3version 5.3.0`
  then `--codegen OCaml --custard_entry Mem.ctype_mem --custard_entry Mem.lookup_name`
  (one `Custard.ml`), compiled with `Prims.ml` from the release
  (`-package zarith,yojson,ppx_deriving.show,ppx_deriving_yojson`, see
  entry 1); `--codegen KrmlC --custard_entry TableC.ctype_mem` then
  `krml -skip-compilation` (bundled krml 3384ecaf) then `gcc -O2` with
  the krmllib headers; `--codegen C --custard_entry TableC.ctype_mem` then
  `gcc -O2`. Same for `PulseTable.ctype_mem`.
- The C targets are driven by `fstar/driver_c.c` (ctype queries only); the
  OCaml targets by `main_ml.ml` (queries and names); Lean by `Main.lean`.

## Raw data

Medians of three runs (all runs and statuses in
[raw/summary-timed.md](2026-11-19-exp-07-raw/summary-timed.md)); check
times from entry 3 repeated for the total. `T_table` = check + extract +
compile, the figure the relative cap of Decision 1 is applied to.

| Target | Check s | Extract s (RSS MB) | Compile s (RSS MB) | T_table s | Peak RSS MB |
|--------|--------:|-------------------:|-------------------:|----------:|------------:|
| Rocq -> OCaml | 24.92 | 12.51 (768) | 48.54 (4,995) | **85.97** | 4,995 |
| Lean -> C -> native | (35.33, included in emit) | 34.56 (1,510), elaboration + C | 60.39 (351) + link 0.43 | **95.38** | 1,510 |
| Why3 -> OCaml | 3.09 | 3.25 (289) | 18.11 (719) | **24.45** | 719 |
| Why3 -> C (decision trees) | 2.44 | 4.20 (340) | 13.55 (276) | **20.19** | 340 |
| F\* -> OCaml | 30.45 | 22.79 (1,261) | 7.08 (519) | **60.32** | 1,261 |
| F\* -> KaRaMeL C (decision trees) | 40.56 | 11.89 (599) + krml 9.48 (233) | 12.06 (253) | **73.99** | 1,410 |
| F\* -> direct C (decision trees) | 40.56 | 13.17 (791) | 11.76 (247) | **65.49** | 1,410 |
| F\*/Pulse -> KaRaMeL C (static arrays) | 162.91 | 8.50 (528) + krml 1.50 (92) | 2.40 (79) | **175.31** | 1,292 |
| F\*/Pulse -> direct C (static arrays) | 162.91 | 8.73 (528) | 1.14 (57) | **172.78** | 1,292 |

Artefact sizes (bytes, timed run 1; `sizes.1.tsv` per tool):

| Target | Source in | Extracted source | Object / binary |
|--------|----------:|-----------------:|----------------:|
| Rocq -> OCaml | `Table.v` 439,613 (`Table.vo` 1,093,305) | `rocq_mem.ml` 11,580,786 | `rocq_e07` 7,874,072 |
| Lean -> C | `Table.lean` 436,408 (`Table.olean` 38,511,504) | `Table.c` 14,850,049 | `Table.o` 14,129,144; `e07` 10,705,128 |
| Why3 -> OCaml | `table.mlw` 605,937 | `why3_mem.ml` 2,159,563 | `why3_e07` 10,675,096 |
| Why3 -> C | `tablec.mlw` 2,003,141 | `tablec.c` 6,838,250 | `c_e07` 607,976 |
| F\* -> OCaml | `Table.fst` 430,263 | `Custard.ml` 1,400,181 | `fstar_e07` 8,560,456 |
| F\* -> KaRaMeL C | `TableC.fst` 1,898,462 | `Custard.c` 12,107,609 | `krml_e07` 583,608 |
| F\* -> direct C | `TableC.fst` 1,898,462 | `Custard.c` 9,921,014 | `c_e07` 523,432 |
| F\*/Pulse -> KaRaMeL C | `PulseTable.fst` 771,106 | `Custard.c` 615,524 | `krml_e07` 395,808 |
| F\*/Pulse -> direct C | `PulseTable.fst` 771,106 | `Custard.c` 665,411 | `c_e07` 256,632 |

For scale: upstream's `unicode_property_data.c` is 712 KB.

## Sample check (criterion 5)

Every target, in each of its three runs, answers all 85,772 ctype
queries exactly as the C oracle (`onig_is_in_code_range` on the `CR_*`
array, entry 2): **0 mismatches on every target**. The OCaml targets
(Rocq, Why3, F\*) and Lean also answer the 886 names through the name
lookup: 0 mismatches (86,658 lines). The C targets (Why3, F\* KaRaMeL,
F\* direct, both representations) have no name lookup: for those tools
the names are checked through the same tool's OCaml target only.
Files: `sample*.txt` under [raw/timed/](2026-11-19-exp-07-raw/timed/).

Answering the whole sample takes 0.03-0.06 s in C, 0.1 s in Lean,
0.4-1.6 s in OCaml (list scans and arbitrary-precision integers).

## What did not work, and why the C representations differ from the plan

- **Why3, list representation to C.** `why3 extract -D c` of the
  list-of-`int` table produces an empty file and 629 diagnostics
  ("unspecified number format for type int" 617 times, "pattern
  matching", "Ddata", "type without syntax")
  ([raw/explore/why3-c-list-representation.log](2026-11-19-exp-07-raw/explore/why3-c-list-representation.log)).
  Why3's C fragment has no lists and no unbounded integers, so the C
  target uses generated decision trees over `uint32` (the plan's
  secondary representation).
- **F\*, C targets.** The plan's primary C representation (Pulse static
  arrays) and a decision-tree variant were both run; the decision-tree
  variant came first because it needs no Pulse code, the Pulse one was
  added once the first worked. Both are correct. The Pulse membership
  function (`mem_arr`, a linear scan with a loop invariant over a
  read-only array) is verified once and serves all 612 arrays.
- **F\* OCaml and `fstar.lib`.** See entry 1: `Prims.ml` is compiled in the
  OCaml 5.4.1 switch because the release's `fstar.lib` is built by 5.3.0.
- **Compiler stacks.** `ulimit -s unlimited` was set for every step; no
  stack overflow occurred. Rocq's `ocamlopt` on the 11.6 MB extracted
  file is the largest memory user of the experiment (5.0 GB).

## Analysis

- Every route produces correct code from the full table. No target needed
  the table to be split.
- Cost order, check plus extraction plus compilation: Why3 (20-24 s),
  F\* OCaml and decision-tree C (60-74 s), Rocq (86 s), Lean (95 s), F\*/Pulse
  (173-175 s).
- Size: representation matters more than tool. Decision trees and nested
  list literals blow the 712 KB C table up to 7-15 MB of generated source
  and 0.5-14 MB of object code; Pulse static arrays give 0.6 MB of C and a
  257-396 KB binary, close to upstream's own form (`static const` arrays).
  KaRaMeL and the direct C backend are within 10 % of each other on time
  and size for both representations.
