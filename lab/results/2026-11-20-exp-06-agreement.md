# Experiment #6, entry 3: the semantics and their agreement with the C library

**What.** Criteria 1 and 2 for milestone 1: an executable semantics of
experiment #9's subset in stack G (plain OCaml) and in six provers
(Rocq, Lean 4, Why3, F\*, and, since the budget left room, Verus and
Isabelle/HOL), run on the 152 in-subset upstream cases and compared,
case by case, with Oniguruma `f95747b`.

**Why.** A semantics that disagrees with the library is not a usable
oracle for differential fuzzing; its speed (entry 4) only matters if it
agrees. Experiment #5 eliminated no stack, so the issue's criteria apply
to all six provers; Verus and Isabelle/HOL were planned as follow-ups
and were done in this milestone.

## Provenance

As [entry 1](2026-11-20-exp-06-provenance.md). Untimed, on the bench
host (CPUs 4-7, `nice -n 10`): `g/g.sh build m1`, `g/g.sh full m1` (C
oracle and stack G verdicts), `<tool>/<tool>.sh full m1` for each prover
(build the semantics with the generated case module, extract or
compile, run the artefact once, one verdict per case). Comparison:
`summarise.py` (section "Agreement").

## The semantics (criterion 1)

One design for all rows, transcribed by hand from stack G:

- AST: `Eps`, `Lit` (bytes of one code point), `Cls` (negated flag,
  sorted code-point ranges), `Cat`, `Alt`, `Star` (greedy), `Group`.
  `.` is `Cls` negated on `[\n]`. Escapes `\t\n\r\f\e\a\v` and `\xHH`
  (< 0x80) and `\x{...}` become literals.
- Subjects are bytes; UTF-8 decoding follows `upstream/src/utf8.c`
  (`EncLen_UTF8` under `USE_RFC3629_RANGE`, `mbc_to_code` without
  checking trailing bytes, failure when the encoded length runs past the
  end); results are byte offsets.
- Matching: stack G is big-step (`step` over a list of pending items:
  node, close-group, loop-check; `Alt` tries the left branch first and
  the right on failure; `Star` tries one more iteration first). The
  provers transcribe it as the equivalent small-step machine: the same
  pending items plus an explicit list of backtracking points (one
  machine step per call of stack G's `step`), with fuel structural in
  each tool (Rocq: a `positive` iterated by halving, so that 10^7 costs
  no unary number; Lean, Isabelle: `Nat`; Why3: an `int` variant; F\*:
  `nat` with `decreases`; Verus: `u64` with `decreases`). Fuel is
  10,000,000 steps per start position (the C default retry limit,
  `upstream/src/regint.h:111`, counted in steps, not retries; see
  experiment #12 on why the counts differ).
- Captures: the last iteration's region wins; group 0 is the match.
- Empty iterations: experiment #2 run 2's plain check (an iteration
  that ends where it started leaves the loop); no case in the subset has
  a backreference, so `OP_EMPTY_CHECK_END_MEMST` never applies.
- Search: forward, start positions 0 to the subject length advanced by
  `enc_len`, first match wins.
- The parser is not re-specified in the provers (plan step 4): cases are
  fed as ASTs built by stack G's parser (`cases/gen.py`).

Per-tool shape, beyond transliteration:

- Why3: every sequence type is monomorphic (`bytes`, `ranges`,
  `items`, `frames`, `caps`) and no `option` or tuple carries a list,
  because `why3 execute` (1.9.0) fails with "Type mismatch between ...
  and int" on any value of a polymorphic constructor (`Cons`, `Some`)
  that contains a list. Reproduced in isolation: `Some l` for
  `l : list int`, and `Cons (P l l) Nil`, both fail; `Some (Q 1 2)`
  works. Experiment #7 hit the same bug on nested list constants. The
  generated case module uses one function per case and a dispatch on the
  index, as planned.
- F\*: no `FStar.List.Tot` (own `len` and counting loop), so the
  extracted OCaml needs only `Prims`.
- Isabelle/HOL: recursion on `nat` by `if n = 0` rather than `0`/`Suc`
  patterns, because with `Code_Target_Numeral` the code generator
  rejects `0` as a constructor in code equations.
- Verus: exec code only, verified for safety (bounds, overflow,
  termination by `decreases`) with no functional specification: 31
  items verified, 0 errors. Rust shape: the pattern is an arena of
  nodes (literal bytes and class ranges in side pools), the pending
  items a `Vec` used as a stack and cloned into each backtracking point;
  an index outside the arena is read as `Eps` (the generator only emits
  well-formed arenas).

Line counts (physical lines; "code" excludes blank and comment-only
lines, roughly):

| Row | File | Lines | Code |
|-----|------|------:|-----:|
| stack G | `g/g.ml` (whole program) | 494 | 439 |
| stack G | of which semantics (AST, UTF-8, machine, search) | about 125 | |
| stack G | of which parser and subset classifier (from experiment #12) | 219 | |
| Rocq | `rocq/Spec.v` | 217 | 180 |
| Lean 4 | `lean/Spec.lean` | 166 | 129 |
| Why3 | `why3/spec.mlw` | 230 | 182 |
| F\* | `fstar/Spec.fst` | 184 | 143 |
| Verus | `verus/spec.rs` | 356 | 306 |
| Isabelle/HOL | `isabelle/Spec.thy` | 156 | 117 |

Engineering effort (session time to write and get each one to agree,
approximate): stack G and the extractor about 30 min; Rocq 10 min;
Lean 10 min; Why3 25 min (most of it isolating the interpreter bug);
F\* 10 min; Isabelle/HOL 20 min; Verus 15 min (verified at the first
attempt). These are for a 7-constructor fragment transcribed from an
existing interpreter; they say little about the 1-3 weeks per tool the
report estimates for a full spec.

## Agreement (criterion 2)

Per kind, as the issue defines it: `x2` group-0 region equal to C's,
`x3` region of group `mem` equal to C's, `n` no match, `e` rejected.
"All regions identical to C" compares the whole verdict (every group's
region, or the error code). For prover rows, `e` is stack G's parser
(no parser in the prover), identical by construction.


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


Raw verdicts: [oracle-verdicts.txt](2026-11-20-exp-06-raw/g/oracle-verdicts.txt),
[g-verdicts.txt](2026-11-20-exp-06-raw/g/g-verdicts.txt) and
`<tool>/verdicts.txt` (one encoded verdict per line, in the order of
`ids.txt`; byte-identical across the six provers).

## Analysis and open questions

- Every row agrees with the C library on every in-subset case, for all
  groups, not only the one the test checks. No deviation needed
  logging; no case reached the retry limit, so the fuel-versus-retry
  difference (experiment #12) is not exercised here.
- The agreement is cheap evidence: 152 cases of a small fragment, most
  of them short. It shows that the transcriptions are faithful to stack
  G and that stack G's semantics (priority order, last-iteration
  captures, plain empty check, byte-level UTF-8) matches Oniguruma on
  this fragment; it says nothing yet about anchors, lazy and possessive
  quantifiers, lookaround or backreferences (milestone 2).
- Why3's interpreter bug constrains how a Why3 spec may be written if
  `why3 execute` is to be used at all; that is a real cost for stack E.
  Worth reporting upstream (not done here).
