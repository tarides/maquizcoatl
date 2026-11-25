# Experiment #6, milestone 2, run 2: agreement on the updated S2 (stack G, Why3, F\*, Rocq, Lean 4)

**What.** Criteria 1 and 2 of experiment #6 after the maintainer's
decisions on run 1. S2 now includes the `\x{..}`/`\o{..}` code point
lists, so it has 1,243 cases instead of 1,197. The empty-iteration rule
is DEV-008 (it supersedes DEV-003), and the nested-interval rule now
follows upstream. The entry gives the semantics of all five rows run so
far, with their line counts, and their agreement with the C library per
kind. It also adds a measurement that DEV-008 needed: stack G under
DEV-003's literal form. This entry supersedes the counts of run 1's
[agreement entry](2026-11-24-exp-06-m2-agreement.md), which is kept
unchanged.

**Why.** Run 2 of the plan (`plans/06-spec-speed-m2.md`, work package
E, section "Maintainer decisions after run 1"). These are the
maintainer's decisions after run 1
(https://github.com/tarides/maquizcoatl/issues/28#issuecomment-7136902494):
DEV-003's implemented form is made normative (1); upstream's empty check
applies to bounded loops, test_utf8:797 (2); the code point lists join
S2 (3). Also from the review, without a decision: remove the invented
nested-interval product rule (test_utf8:1461). Rocq and Lean 4 get
their S2 semantics (criteria 1 and 2 for two more rows).

## Provenance

As [run 2's provenance](2026-11-24-exp-06-m2-run2-raw/provenance.txt)
(bench host: AMD EPYC 7502P, 503 GB, Linux 6.8.0-100, Ubuntu 24.04.5;
milestone 1's pins: OCaml 5.4.1, Rocq 9.3.0, Lean 4.36.0, Why3 1.9.0,
F\* 2026.11.15). Scripts at `e293368` (branch `exp/06-spec-speed-m2`).
Untimed runs on the bench host, at most 4 jobs on CPUs 0-15 under
`nice -n 10`: `g2.sh classify|full|gen`, then `why3_2.sh full`,
`fstar2.sh full`, `rocq2.sh full` and `lean2.sh full` (the extracted
or compiled drivers print one verdict per case). `cases/decode2.py` and
`cases/agree2.py`, with `cases/deviations-s2.tsv`, ran on the
workstation. Run 1's generated files are kept on the bench host
(`<exp>/m2/gen-r1/`).

## Changes against run 1

- **Empty iteration (DEV-008).** In stack G (`g/g2.ml:1089-1092`), Why3
  (`why3/spec2.mlw:325`) and F\* (`fstar/Spec2.fst:253`), the condition
  `c > mn && mx < 0 && pos = p0 && same_refs ...` becomes
  `pos = p0 && same_refs ...`: every loop, bounded or not, and also
  below its minimum. The groups compared are still the backreferenced
  ones.
- **Nested fixed intervals.** Run 1 rejected a fixed interval on a
  fixed interval whose product exceeded 100,000 (-201). Upstream has no
  such threshold, as the review says. It does multiply the two counts,
  though: `onig_reduce_nested_quantifier`
  (`upstream/src/regparse.c:4449-4455`) fails with -201 only when the
  product overflows a C `int` (`onig_positive_int_multiply`,
  `upstream/src/regcomp.c:345-352`). Removing the rule altogether made
  three `e` cases fail: test_utf8:1770 `x{55380}{77590}`, 1771
  `(xyz){40000}{99999}(?<name>vv)` and 1772
  `f{90000,90000}{80000,80000}`. Their products, 4.30, 4.00 and 7.20 x
  10^9, overflow, and C rejects them with -201. So stack G now applies
  upstream's overflow test instead of the 100,000 threshold. test_utf8:1461
  (32,774 x 65,521 = 2,147,385,254, below 2^31 - 1) is then reduced,
  and the lookbehind check rejects it with C's -122. This keeps a rule
  that the maintainer's decision describes as removed, but with its
  upstream source, so it is listed for review below.
- **Code point lists.** `\x{61 62}` and `\o{141 142}` are parsed as
  upstream's tokenizer reads them: one code point token at a time
  (`code_point_continue`, `upstream/src/regparse.c:5297-5313`,
  `:5583-5594`), so a quantifier binds the last code point. In a class,
  `-` between two code points of the list is a range
  (`get_next_code_point`, `:3864-3897`). The list is validated first,
  as `check_code_point_sequence` and `check_code_point_sequence_cc` do
  (`:3747-3861`), with -400 and -212 (`ONIGERR_TOO_LONG_WIDE_CHAR_VALUE`)
  as there.
- **Evidence switch.** With `G2_EMPTY_ALL_GROUPS=1`, stack G compares
  every group of the pattern in the empty check. A group outside a loop
  cannot change during one of its iterations, so this is DEV-003's
  literal form, "every group of the loop body".

## Semantics (criterion 1)

| Row | File | Lines | Against milestone 1 |
|-----|------|------:|------|
| stack G | `g/g2.ml` | 1,289 | run 1: 1,182; milestone 1's `g/g.ml` (494) unchanged |
| Why3 | `why3/spec2.mlw` | 435 | run 1: 434 (one comment line) |
| F\* | `fstar/Spec2.fst` | 349 | run 1: 348 (one comment line) |
| Rocq | `rocq/Spec2.v` | 412 | new; 190 distinct lines not in `rocq/Spec.v` (217) |
| Lean 4 | `lean/Spec2.lean` | 335 | new; 179 distinct lines not in `lean/Spec.lean` (166) |

Rocq and Lean transcribe F\*'s S2 machine (`fstar/Spec2.fst`, itself
transcribed from stack G) item for item. They have the same items
(`ICut`, `ILookOk`, `INegFail`, `IBTry`, `IAtEnd`, `IIter`), the same
class expressions, and fold and property lookups through a generated
table module (`Tables.v`, `Tables.lean`: the fold map in full and the
24 used ctypes, balanced decision trees, as for Why3 and F\*). Rocq
keeps milestone 1's choices: fuel is a `positive` iterated by halving,
positions and group numbers are `nat` (`ExtrOcamlNatInt`), and bytes,
code points and repetition counts are `N` (`ExtrOcamlZInt`). The
backtracking frames are nested in the `item` type through `list` and
`prod`. All definitions are structural `Fixpoint`s, and the nested
class union uses an inner `fix`. Lean has structural recursion
throughout, a `mutual` block for the nested class expressions, `Nat`
fuel, and `Option Nat` for the upper bound. Neither file contains an `Axiom`,
`Admitted` or `sorry`, and both build cleanly: Lean without warnings,
Rocq with warnings only (no `All` scheme for the types nested in
`list`, the deprecated `-native-compiler` option, the default
extraction directory).

## Cases

S2 in the pool of 1,610 UTF-8 forward cases of the three syntaxes:
**1,243 cases** (run 1: 1,197). The 46 code point list cases are
included (24 `x2`, 22 `e`), 367 cases are out of S2, and 1,184 are
emitted to the provers (run 1: 1,160).

| Suite | x2 | x3 | n | e | Total |
|-------|---:|---:|--:|--:|------:|
| test_utf8 | 886 | 82 | 196 | 63 | 1,227 |
| test_options | 10 | 0 | 0 | 0 | 10 |
| test_syntax (Perl_NG) | 4 | 0 | 2 | 0 | 6 |
| **Total** | **900** | **82** | **198** | **63** | **1,243** |

Of the 63 `e` cases, stack G's parser rejects 59 (inherited by the
provers, as in milestone 1); 4 compile under DEV-004. Out-of-S2
reasons: as run 1's cases entry, minus the 46 code point lists (now
367). Per-case classification:
[classify.tsv](2026-11-24-exp-06-m2-run2-raw/classify.tsv),
[in-s2.tsv](2026-11-24-exp-06-m2-run2-raw/in-s2.tsv). The tables are
unchanged from run 1 (`tables.txt` sha256 `653b65f7...`; 24 ctypes
used, now with 163 property-heavy cases).

## Agreement (criterion 2)

| Row | x2 (900) | x3 (82) | n (198) | e (63) | Out of S2 |
|-----|---------:|--------:|--------:|-------:|----------:|
| stack G | 900 pass | 81 pass, 1 deviation | 198 pass | 59 pass, 4 deviation | 367 |
| Why3 | 900 pass | 81 pass, 1 deviation | 198 pass | 59 inherited, 4 deviation | 367 |
| F\* | 900 pass | 81 pass, 1 deviation | 198 pass | 59 inherited, 4 deviation | 367 |
| Rocq | 900 pass | 81 pass, 1 deviation | 198 pass | 59 inherited, 4 deviation | 367 |
| Lean 4 | 900 pass | 81 pass, 1 deviation | 198 pass | 59 inherited, 4 deviation | 367 |

No disagreement is left. The four provers give the same full verdict
(every group) as stack G on all 1,184 emitted cases. Deviations logged,
with the C verdict recorded:

| Case | C (f95747b) | Spec | Entry |
|------|-------------|------|-------|
| test_utf8:742 (x3) `(?:\1a|())*` on `a` | `MATCH 0 0`, group 1 `0 0` | `MATCH 0 1`, group 1 `1 1` | DEV-008 (as DEV-003) |
| test_utf8:1194, 1196, 1200, 1201 (e) | -223 | compile | DEV-004 |

Whole verdicts (every group), stack G against C: identical on every S2
case except the five deviations and two `e` cases rejected with another
code (test_utf8:1195, C -223, spec -117; test_utf8:1762, C -400, spec
-206; both as in run 1). test_utf8:797 now agrees with C on every group
(`MATCH 2 11`, group 1 `11 11`, group 2 `8 11`). In run 1 it differed
on group 1. test_utf8:1461 now gives C's code, -122 (run 1: -201).

### DEV-003's literal form (evidence for DEV-008)

Stack G with `G2_EMPTY_ALL_GROUPS=1` on the 1,243 cases, compared with
the default (DEV-008) on whole verdicts:
[g-verdicts-literal-dev003.txt](2026-11-24-exp-06-m2-run2-raw/g/g-verdicts-literal-dev003.txt).

| Case | DEV-008 (= C) | Literal form |
|------|---------------|--------------|
| test_utf8:745 `(?:()|()|()|()|()|())*\2\5` on `""` | groups 3, 4 unset | groups 3, 4 `0 0` |
| test_utf8:746 `(?:()|()|()|(x)|()|())*\2b\5` on `b` | group 3 unset | group 3 `0 0` |
| test_utf8:793 `(?:()|()|())*\3\1` on `abc` | group 2 unset | group 2 `0 0` |
| test_utf8:797 | group 1 `11 11` | group 1 `8 11` |
| test_utf8:1757 `a(b|)+d` on `a`, 30 `b`, `cd` | no match | fuel exhausted (`LIMIT`) |

The other 1,238 cases give identical verdicts. All five cases still
pass their checked group or kind, except 1757, so run 1's agreement
counts could not show the differences. DEV-003's claim that the two
forms are observably equal therefore does not hold: in the four capture
cases the literal form keeps a value of an unreferenced group that the
backreferenced form discards. DEV-008 records this. It is test evidence
over S2, not a proof in either direction.

Raw data: [run 2 raw directory](2026-11-24-exp-06-m2-run2-raw/):
`g/oracle-verdicts.txt` (C), `g/g-verdicts.txt`, the decoded verdicts
and `agreement.txt` of each prover under `why3/`, `fstar/`, `rocq/`
and `lean/`, plus the Rocq and Lean build logs.

## Analysis and open points

- All five rows pass criterion 2 on the updated S2. Rocq and Lean agree
  with stack G on every emitted case at their first build, as Why3 and
  F\* did in run 1: one shared machine transcribed four times.
- For review: nested fixed intervals. The maintainer's decision says
  the rule is removed. This run keeps a rule, upstream's
  `onig_reduce_nested_quantifier` overflow test, because removing it
  outright fails test_utf8:1770-1772. That rule rejects a pattern
  because a product overflows a C `int`, an implementation limit rather
  than a property of the pattern. Whether the specification keeps it,
  states another limit, or logs a deviation (accepting these three
  patterns) is the maintainer's call.
- DEV-008 checks every iteration, including the copies that upstream
  unrolls without a check (the first `lower` copies of an infinite loop,
  and small greedy bounded loops). No S2 case shows a difference.
