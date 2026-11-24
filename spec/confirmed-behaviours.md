# Confirmed behaviours

This file records behaviours of Oniguruma at `f95747b` that the
specification reproduces on purpose after a question was raised about
them, typically where the documentation and the code could be read
differently. CLAUDE.md asks that each disagreement between docs and code
be recorded either as a deliberate deviation (`spec/deviations.md`) or
as a confirmed behaviour (this file). A confirmed behaviour is not a
deviation: Maquizcoatl does what upstream does.

## Entry format

Each entry is a `## CB-NNN: <title>` section with an Origin line and
these fields:

- **Upstream behaviour at `f95747b`**: what the C library does, with
  citations `upstream/<path>:<line>` (always commit `f95747b`) and the
  case or probe ids that show it.
- **Spec position**: what the specification states, and why it
  follows upstream.
- **Evidence**: links to the recorded results.
- **Limits**: what the evidence does not establish, and the open
  follow-ups.
- **Status**: who decided, and when.

---

## CB-001: `(?~absent)` behaves as its written abbreviation `(?~|(?:absent)|\O*)`

Origin: experiment #8, hard-feature spec probe (issue #12),
[corpus entry](../lab/results/2026-11-19-exp-08-corpus.md) and
maintainer decision
(https://github.com/tarides/maquizcoatl/issues/12#issuecomment-7038399798).

**Upstream behaviour at `f95747b`.** `upstream/doc/RE:368` calls the
absent repeater `(?~absent)` "a written abbreviation of
`(?~|(?:absent)|\O*)`", but the two spellings do not build the same
tree. The parser (`upstream/src/regparse.c:7983-8045`) hands both to
`make_absent_tree` (`upstream/src/regparse.c:3299-3391`):

- `(?~absent)` has no expression, so `make_absent_tree` builds the
  default `\O*` itself and jumps to the simple path
  (`upstream/src/regparse.c:3317-3328`),
  `make_absent_tree_for_simple_one_char_repeat`
  (`upstream/src/regparse.c:3252-3296`): save the right range, run
  `make_absent_engine` with step `\O` and the `*` bounds as a
  non-possessive loop, so the repeat itself is the engine's loop and
  its ends come from backtracking into it, then restore the right
  range.
- `(?~|abc|\O*)` has the expression `\O*`. The simple path is taken
  only when `is_simple_one_char_repeat`
  (`upstream/src/regparse.c:3185-3249`) accepts the expression, a
  greedy repeat of a one-character string or a character class. `\O` is
  an `ND_CTYPE` any-char node (`node_new_true_anychar`,
  `upstream/src/regparse.c:2424-2432`; `node_new_anychar`,
  `upstream/src/regparse.c:2400-2404`), so it is rejected and the
  general path runs (`upstream/src/regparse.c:3347-3384`): save the
  right range and `s`, run `make_absent_engine` with step `\O` as a
  possessive scan that cuts the right range at the start of the first
  absent match, rewind `s` (`UPDATE_VAR_S_FROM_STACK`), match the
  expression `\O*` under the cut, then `make_absent_tail`
  (`upstream/src/regparse.c:3078-3124`) restores the right range on
  exit and re-installs the cut on backtracking.

Both paths share `make_absent_engine`
(`upstream/src/regparse.c:2995-3075`), the loop
`((SAVE_S absent UPDATE_VAR_RIGHT_RANGE_FROM_S_STACK FAIL) | step)`
whose cut is the position where the absent match starts
(`upstream/src/regexec.c:4563-4568`). On experiment #8's corpus the two
spellings give the same result on all three pairs:

| Pair | Subject | `(?~abc)` | `(?~\|abc\|\O*)` |
|------|---------|-----------|------------------|
| ab02 / ab05 | `abc` | `M 0-0` | `M 0-0` |
| ab06 / ab07 | `xabcx` | `M 0-1` | `M 0-1` |
| ab08 / ab09 (followed by `z`) | `xabz` | `M 0-4` | `M 0-4` |

**Spec position.** The specification states the documented
equivalence: `(?~absent)` has the semantics of `(?~|(?:absent)|\O*)`.
Experiment #8's formal model writes the first as `AbsRep absent` and the
second as `AbsExp absent (Star AnyO)`
(`lab/08-hard-features/SEMANTICS.md`, section 2) and checks, rather
than assumes, that they agree on the cases. The two C code paths are an
implementation detail of upstream, not part of the specification.

**Evidence.** Cases ab02 and ab05-ab09
(`lab/08-hard-features/cases/absent.tsv`), run on the Debug and
ASan/UBSan builds of `f95747b`, same result on both, no sanitizer
report
([raw/corpus/absent.joined.tsv](../lab/results/2026-11-19-exp-08-raw/corpus/absent.joined.tsv),
[raw/corpus-r2/absent.joined.tsv](../lab/results/2026-11-19-exp-08-raw/corpus-r2/absent.joined.tsv)).
The direct semantics in Rocq, Lean, F\* and Verus agrees with the C
library on all 11 absent cases
([absent entry](../lab/results/2026-11-19-exp-08-absent.md)).

**Limits.** This is corpus agreement on three pairs, not a proof. No
lemma states that the direct absent semantics equals the
`make_absent_engine` desugaring, on either code path. That equivalence
stays open as a follow-up (issue #34). Nested absent functions are out
of scope: `upstream/doc/RE:385` leaves them undefined.

**Status.** Decided by the maintainer 2026-11-20
(https://github.com/tarides/maquizcoatl/issues/12#issuecomment-7038399798).
