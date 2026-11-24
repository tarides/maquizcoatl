# Experiment #6, milestone 2, entry 3: agreement on S2 (stack G, Why3, F\*)

**What.** Criteria 1 and 2 of experiment #6 on the S2 cases for the three
rows of run 1: the semantics with their line counts, and how many of
the 1,197 S2 cases each one passes against the C library, per kind,
with the decided deviations counted as such.

**Why.** Run 1 of milestone 2 (plan `plans/06-spec-speed-m2.md`,
work packages A-C) must meet criteria 1-4 for stack G, Why3 and F\*.
Decision 1 on issue #28: the semantics implement the decided behaviour
of DEV-001 to DEV-004, and an upstream case that differs counts as
"deviation logged", with the C verdict recorded.

## Provenance

As [entry 1](2026-11-24-exp-06-m2-provenance.md). Untimed runs on the
bench host (CPUs 0-15, `nice -n 10`): `g2.sh full` (C oracle and stack
G verdicts), `why3_2.sh full`, `fstar2.sh full` (extracted drivers
printing one verdict per case), then `cases/decode2.py` and
`cases/agree2.py` with `cases/deviations-s2.tsv` on the workstation.

## Semantics (criterion 1)

| Row | File | Lines | Of which new against milestone 1 |
|-----|------|------:|------:|
| stack G | `g/g2.ml` (parser and S2 classifier, interpreter, driver) | 1,182 | whole file new; milestone 1's `g/g.ml` (494) is unchanged |
| stack G, tables | `g/tables/gen_tables.py` | 105 | new |
| Why3 | `why3/spec2.mlw` | 434 | 266 lines not in `why3/spec.mlw` (230) |
| F\* | `fstar/Spec2.fst` | 348 | 222 lines not in `fstar/Spec.fst` (184) |

In stack G, the parser is about 580 lines and the interpreter about 190.
Why3 and F\* transcribe stack G's interpreter into milestone 1's
small-step machine: new AST nodes (case-insensitive literal, class with
multi-character folds, bounded and lazy repetition, atomic group,
lookahead, lookbehind with its top-level alternatives, backreference,
anchors), class expressions (ranges, ctypes, negation, union,
intersection), and commit items that carry the backtracking list to
restore (`ICut`, `ILookOk`, `INegFail`; lookbehind with `IBTry` and
`IAtEnd`). The fold map and the property ranges are read from the table
module. Both check cleanly: Why3 type-checks; F\* verifies `Tables`
and `Spec2` with no admitted goal (termination by `decreases` on
structures or `nat` fuel).

Semantic choices, all in stack G and transcribed:

- **DEV-003** in its observably equal form (the second alternative
  listed in the entry): an empty optional iteration of an unbounded loop
  stops the loop unless a *backreferenced* group changed in it. The
  first form tried (any group of the body) is correct but made stack G
  exhaust its fuel on `a(b|)+d` against 30 `b`s (test_utf8:1757): with
  every empty iteration of `(b|)` changing group 1, each position has two
  ways on, and the search is exponential.
- **DEV-004**: `\pX` is a property only for `C L M N P S Z` (either case).
- **DEV-001, DEV-002**: no S2 case exercises them (no Perl_NG
  lookbehind case; no capture in a negative lookbehind in the suites).
  Both are implemented: lookbehind validity is decided on the parsed
  pattern; captures in a negative lookbehind are unset after it.
- Case folding is semantic (full case folds compared), and a class
  under ignore-case is closed under fold equivalence at parse time,
  with its members' multi-character folds as extra alternatives.
- `{n}?` is `{n}` then `?` (fixed interval greedy only); a reversed
  interval `{n,m}` (`n > m`) is possessive `{m,n}`; nested fixed
  intervals whose product exceeds 100,000 are rejected (-201).

## Agreement (criterion 2)

| Row | x2 (876) | x3 (82) | n (198) | e (41) | Out of S2 |
|-----|---------:|--------:|--------:|-------:|----------:|
| stack G | 876 pass | 81 pass, 1 deviation | 198 pass | 37 pass, 4 deviation | 413 |
| Why3 | 876 pass | 81 pass, 1 deviation | 198 pass | 37 inherited, 4 deviation | 413 |
| F\* | 876 pass | 81 pass, 1 deviation | 198 pass | 37 inherited, 4 deviation | 413 |

No disagreement is left: every case passes or is a logged deviation.

Deviations logged (C verdict recorded):

| Case | Pattern, subject | C (f95747b) | Spec | Entry |
|------|------------------|-------------|------|-------|
| test_utf8:742 (x3, group 1) | `(?:\1a|())*`, `a` | `MATCH 0 0`, group 1 `0 0` | `MATCH 0 1`, group 1 `1 1` | DEV-003 |
| test_utf8:1194 (e) | `\p` | -223 | compiles (literal `p`) | DEV-004 |
| test_utf8:1196 (e) | `\pQ` | -223 | compiles | DEV-004 |
| test_utf8:1200 (e) | `[\p]` | -223 | compiles | DEV-004 |
| test_utf8:1201 (e) | `[\pU]` | -223 | compiles | DEV-004 |

`e` cases rejected by both with a different code (reported
separately): 3 of 37 in stack G: test_utf8:1195 `\p(` (C -223; spec
-117, since `\p` is a literal under DEV-004 and `(` is then unclosed),
test_utf8:1461 (C -122; spec -201, the nested fixed intervals overflow
before the lookbehind length is checked) and test_utf8:1762 (C -400;
spec -206 on an invalid UTF-8 byte at the end of the pattern).

Unchecked groups: comparing the whole verdict (every group), the three
rows agree with C on 1,154 of the 1,155 emitted cases that are not
deviations, and differ on one: test_utf8:797, `x2`,
`(abc|(def|ghi|jkl|mno|pqr){0,7}?){5}\z` on `adpqrpqrpqr`. Group 0
agrees (`2 11`); group 1 is `11 11` in C and `2 11` in the spec. The
test checks group 0 only, so the case passes; the difference (the last
iteration of a bounded loop whose body can be empty) is an open point,
see below.

Raw data: [in-s2.tsv](2026-11-24-exp-06-m2-raw/in-s2.tsv),
[C verdicts](2026-11-24-exp-06-m2-raw/g/oracle-verdicts.txt),
[stack G](2026-11-24-exp-06-m2-raw/g/g-verdicts.txt),
[Why3](2026-11-24-exp-06-m2-raw/why3/verdicts-decoded.txt),
[F\*](2026-11-24-exp-06-m2-raw/fstar/verdicts-decoded.txt), and the
agreement reports `*/agreement.txt` in the same directory.

## Analysis and open points

- All three rows pass criterion 2 on S2 on the first run of the provers:
  the Why3 and F\* transcriptions agree with stack G on every emitted
  case, as in milestone 1.
- The parser stays in stack G (OCaml) for every row: the `e` cases and
  the differences between the Oniguruma and Perl_NG syntaxes are checked
  only in stack G, and the provers inherit the 37 rejections.
- Open, for the maintainer: test_utf8:797 (group 1 of a bounded loop
  with a possibly empty body). Upstream seems to apply its empty-loop
  check to the `{5}` loop as well, which the spec does only for
  unbounded loops; whether this is a deviation to log or a rule to adopt
  is not settled by this run.
- The DEV-003 form actually implemented is the "backreferenced groups"
  form the entry lists as observably equal to the decided one; the
  exponential cost of the literal form on `(b|)+` is a point for the
  entry itself (it says both are equal in results, which holds; they
  differ in cost).
