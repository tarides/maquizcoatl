# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Maquizcoatl is a planned formally verified reimplementation of the
Oniguruma regex library (abandoned upstream on 2025-04-24). The work has
two phases:

1. Reverse-engineer a specification from the original C sources.
2. Build a verified implementation against that specification.

The specification language and the implementation language are still
undecided. Do not assume a toolchain (Rocq, Lean, F*, Rust/Verus, OCaml, …)
until the user picks one. The state-of-the-art survey that frames the
options is the Claude Doc "Verified reimplementation of Oniguruma: state
of the art" (https://claude.ai/artifact/8w6PVuiTsLCKpugpCowMHc).

## Layout

- `upstream/` — git submodule of `kkos/oniguruma`, pinned to its final
  commit `f95747b`. It is reference material only: never edit it, and
  never build inside it (that dirties the submodule).
- `spec/` — the specification being written. `spec/SOURCES.md` records
  provenance (commit, SWHID, BSD-2-Clause licence).

## Citing the original code

Write references to the C sources as `upstream/<path>:<line>` or
`upstream/<path>:<start>-<end>`. They always refer to commit `f95747b`.
Code quoted from upstream must keep Oniguruma's copyright notice and
BSD-2-Clause conditions.

## Building and testing the upstream C library

Build out of tree, outside the repository (for example in the
session scratchpad):

    cmake -S upstream -B <builddir> -DCMAKE_BUILD_TYPE=Debug
    make -C <builddir> -j

There are no CTest targets (`ctest` finds nothing). Run the test
binaries directly. Each one prints a `RESULT  SUCC: n, FAIL: n, ERROR: n`
line.

    <builddir>/test/test_utf8      # 1554 cases, UTF-8 Oniguruma API
    <builddir>/test/test_back      # 1225 cases, backward search
    <builddir>/test/testc          #  785 cases, EUC-JP
    <builddir>/test/testcu         #  720 cases, UTF-16
    <builddir>/test/test_syntax    #  221 cases, syntax flavours
    <builddir>/test/test_options   #   47 cases, options
    <builddir>/test/test_regset    #   13 cases, regset API

`testp` (POSIX API) is only built with `-DENABLE_POSIX_API=ON`.
The binaries have no per-case filter. To check a single pattern, write a
small program against `upstream/src/oniguruma.h` (`upstream/sample/` has
minimal examples) or copy one test macro into a scratch file. The test
macros in `upstream/test/test_utf8.c` (around line 141) are:
`x2(pattern, subject, from, to)` expects a match at `[from, to)`,
`x3(…, mem)` checks capture group `mem`, `n(pattern, subject)`
expects no match, and `e(pattern, subject, error)` expects a compile
error.

libFuzzer harnesses are in `upstream/harnesses/` (`libfuzzer-onig.cpp`,
`base.c`, `deluxe.c`, `regset.c`).

## Upstream architecture (what the spec must cover)

The core is about 25k lines across three files. Each one is the source of
truth for one layer of the spec:

- `upstream/src/regparse.c` — the parser. It handles each syntax flavour
  (`regsyntax.c` defines Ruby, Perl, Python, Java, Emacs, grep, POSIX and
  Oniguruma's own), escapes, character classes and named groups. It
  produces the `Node` AST (`regparse.h`).
- `upstream/src/regcomp.c` — AST rewriting, case-fold expansion, the
  optimiser, and compilation to bytecode. It chooses the search strategy
  (`OPTIMIZE_STR`, `_STR_FAST` (Sunday/BMH) or `_MAP`; see `regint.h:364`)
  and computes anchors and length bounds.
- `upstream/src/regexec.c` — the backtracking VM. `match_at` is a
  direct-threaded opcode loop (`USE_DIRECT_THREADED_CODE`) with an
  explicit backtrack stack. `search_in_range` is the outer search loop.
  Retry and stack limits are the only ReDoS guards; see `regint.h:110`.
- Encodings — `regenc.[ch]` defines the `OnigEncodingType` vtable, with
  one file per encoding (`utf8.c`, `sjis.c`, `gb18030.c`, …). `unicode.c`
  plus the generated `unicode_*_data.c` tables cover properties, case
  folding, grapheme clusters and word breaks. The tables are produced by
  the `make_unicode_*.py` and `.sh` scripts, so treat them as data, not
  logic.
- Public API — `oniguruma.h`. `regext.c` adds `onig_new_deluxe`,
  `regtrav.c` the capture history, `regposix.c` and `reggnu.c` the
  compatibility wrappers.

Feature switches are compile-time `#define USE_*` macros in `regint.h`
(for example `USE_CALL`, `USE_CALLOUT`, `USE_BACKREF_WITH_LEVEL`). Check
them before deciding that a feature exists in the default build.

Prose documentation of intended behaviour is in `upstream/doc/RE`
(syntax), `doc/API`, `doc/SYNTAX.md` (per-flavour differences) and
`doc/CALLOUTS.*`. Where the docs and the code disagree, the code is the
reference. Record each such disagreement in the spec as a deliberate
deviation or a confirmed behaviour.
