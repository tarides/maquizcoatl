# Experiment #8: shared semantics of the four hard features

This file fixes, once for all four tools (Rocq, Lean 4, F\* with Pulse,
Verus), what each tool formalises, so that the size, time and automation
columns compare the same definitions and the same lemma statements. It is
step 3 of `plans/08-hard-features.md`. References to the C sources are
`upstream/<path>:<line>` at `f95747b`.

## Common design

**Style.** Linden's backtracking-tree style (style only): a match
function returns the priority-ordered list of results; the first match is
the head of that list. The semantics of empty loops follows
`spec/deviations.md` (DEV-003: an empty iteration exits the loop, here by
a loop-check item). Lookbehind and captures are not needed by any case
and are not modelled.

**Matcher shape.** All four tools use the same first-order matcher: a
*stack of pending items* (a defunctionalised continuation) instead of a
higher-order continuation. Higher-order continuations need closures inside
recursive definitions, which Verus spec functions do not support well and
which make kernel reduction and SMT encodings heavier; the stack keeps the
four encodings line-for-line comparable.

    item ::= R r          run regex r
           | Chk i a      loop check after one iteration of Star a entered at i
           | Ret          return from a call frame          (calls only)
           | SetRR n      restore the right range to n      (absent only)

`m f ks i ... : list result` runs the items `ks` at position `i`. Every
step consumes one unit of fuel `f`; `m 0 ... = []`. The fuel exists so
that Rocq and Lean can compute with the definition by kernel reduction and
so that every tool accepts the definition with a plain `decreases f`; it is
*computability help*, recorded as such in the notebook, not an automation
failure. Fuel 1000 is used for every case (far above what any case needs;
a case that ran out of fuel would show up as a wrong `N`).

Characters are byte values (natural numbers). Search is forward,
unanchored: `search` tries starts `0, 1, …, |s|` and returns
`Some (start, end)` for the first start with a non-empty result list,
`None` otherwise. Captures are not reported; the cases compare the
whole-match range only (the `M a-b` part of the harness result).

Common regex constructors: `Eps`, `Chr c`, `Any` (any byte but `\n`),
`Seq a b`, `Alt a b` (left first), `Star a` (greedy):

    m (f+1) []                 i = [result at i]
    m (f+1) (R Eps     :: ks)  i = m f ks i
    m (f+1) (R (Chr c) :: ks)  i = if s[i] = c then m f ks (i+1) else []
    m (f+1) (R (Seq a b) :: ks) i = m f (R a :: R b :: ks) i
    m (f+1) (R (Alt a b) :: ks) i = m f (R a :: ks) i ++ m f (R b :: ks) i
    m (f+1) (R (Star a) :: ks) i  = m f (R a :: Chk i a :: ks) i ++ m f ks i
    m (f+1) (Chk i0 a :: ks)    i = if i = i0 then m f ks i            (empty iteration: exit)
                                    else m f (R (Star a) :: ks) i

Each feature file is self-contained: it repeats the part of this core it
needs, so that its line counts stand alone.

## 1. Subexpression calls with the nest limit (`Calls`)

**C mechanism.** `OP_CALL` fails when `subexp_call_nest_counter ==
SubexpCallMaxNestLevel` (`upstream/src/regexec.c:4426-4427`), otherwise
increments it and pushes a call frame; `OP_RETURN` decrements it
(`regexec.c:4453-4457`) and backtracking over a frame restores the count
(`POP_CALL`, `regexec.c:1419`). The default limit is 20
(`upstream/src/regint.h:115`), set by `onig_set_subexp_call_max_nest_level`.
A group that is the target of some call is compiled as a subroutine, and
its *definition site is itself an `OP_CALL`* (`upstream/src/regcomp.c:1704-1713`),
so it takes a frame too. The corpus confirms this count: `\A(?<n>a\g<n>|b)\z`
on `aaab` needs 4 frames (1 for the definition site, 3 recursive) and
fails at limits 0-3, matches from 4 (`cases/nest.tsv` ns01); on
`((((((a))))))`, limit k gives the match nested k-1 deep (ns02).

**Formal model.** `Call n` with a table `defs` of called-group bodies;
the definition site is written `Call n` in the main regex. The state adds
the depth `d` (live frames) and, for the lemma, the running maximum `mx`.
The limit `lim` is a parameter of `m` and of `search`; `default_limit = 20`.

    m (f+1) (R (Call n) :: ks) i d mx =
        if lim <= d then []
        else m f (R defs[n] :: Ret :: ks) i (d+1) (max mx (d+1))   ([] if n is unbound)
    m (f+1) (Ret :: ks) i d mx = m f ks i (d-1) mx

Results are pairs `(end, mx)`. Anchors `Bos` (`\A`) and `Eos` (`\z`) are
added for the cases. Only patterns accepted by upstream's never-ending
recursion check are in scope; that check is a precondition, not modelled.
The termination measure is the fuel (computability help, see above); the
lexicographic measure of the plan is not needed because every tool
accepts `decreases f`.

**Lemma C (main).** For all `f ks i d mx` and every result `(e, x)` of
`m f ks i d mx`: if `d <= lim` and `mx <= lim` then `x <= lim`. That is,
every result is produced with nest depth at most the limit at every step.
Corollary at the top level: `d = mx = 0`.

**Cases.** `cases/calls.tsv` (ca01-ca06, four from `test_utf8.c`) and
`cases/nest.tsv` (ca06 is in calls.tsv; nc01-nc04 and the scan points ns01@3, ns01@4, ns02@1,
ns02@6, ns02@7).

## 2. Absent operator (`Absent`)

**C mechanism.** `make_absent_tree` (`upstream/src/regparse.c:3299-3380`).
`(?~absent)` has no expression: it jumps straight to
`make_absent_tree_for_simple_one_char_repeat` with body `\O` and
quantifier `*` (`regparse.c:3317-3328`), the step-wise engine with a
non-possessive loop. `(?~|absent|exp)` takes that path only when `exp`
is a greedy repeat of a one-character string or a character class
(`is_simple_one_char_repeat`, `regparse.c:3185-3240`); `\O` is an
`ND_CTYPE` any-char node (`node_new_true_anychar`, `regparse.c:2424-2432`),
not a class, so `(?~|abc|\O*)` is *not* simple and goes through the
general engine although `upstream/doc/RE:367` calls `(?~absent)` "a
written abbreviation of `(?~|(?:absent)|\O*)`". The two spellings
therefore compile through different code paths, and their agreement on
the cases is a finding (ab02/ab05, ab06/ab07, ab08/ab09 agree).
Other expressions go through the general engine, `make_absent_engine`
(`regparse.c:2995-3076`): save the right range, save `s`, a possessive scan
`((SAVE_S absent UPDATE_VAR_RIGHT_RANGE_FROM_S_STACK FAIL) | \O)*`, rewind
`s`, then `exp`; `make_absent_tail` (`regparse.c:3078-3127`) restores the
right range on exit and re-installs the cut when backtracking into `exp`.
The cut is the position where the absent match *starts*
(`UPDATE_VAR_RIGHT_RANGE_FROM_S_STACK`, `upstream/src/regexec.c:4563-4568`)
and every consumption is bounded by the right range (`DATA_ENSURE`,
`regexec.c:2725-2727`). The stopper `(?~|absent)` is the engine without
the tail (the four-node list at `regparse.c:3371-3373`), so the cut stays for the rest of the
pattern; the range clear `(?~|)` sets the right range back to the subject
end (`UPDATE_VAR_RIGHT_RANGE_INIT`).

**Formal model.** The state adds the right range `rr` (initially `|s|`);
every consuming step checks `i < rr`. A base matcher `mb` (the common core
plus `AnyO` = `\O`, any byte) decides absent matches, so the absent
pattern must be absent-free (nested absent functions are out of scope:
`upstream/doc/RE:385` calls them undefined, and `test_utf8.c:850` is
excluded). `occ a p rr` holds when `mb` has a result for `a` at `p`.

    cut a i rr = the first p in [i, rr] with occ a p rr, else rr
    m (f+1) (R (AbsRep a)   :: ks) i rr = concat [m f ks e rr | e <- [c, c-1, ..., i]]   where c = cut a i rr
    m (f+1) (R (AbsExp a e) :: ks) i rr = m f (R e :: SetRR rr :: ks) i (cut a i rr)
    m (f+1) (R (Stopper a)  :: ks) i rr = m f ks i (cut a i rr)
    m (f+1) (R RangeClear   :: ks) i rr = m f ks i |s|
    m (f+1) (SetRR n        :: ks) i rr = m f ks i n

`AbsRep` is the direct semantics of the repeater (the list of its ends,
longest first, as the greedy `\O*` gives them); `AbsExp` is the general
form. `(?~abc)` is written `AbsRep abc` and `(?~|abc|\O*)` is written
`AbsExp abc (Star AnyO)`, so the agreement of the two spellings on the
cases is checked, not assumed. Since every branch carries its own `rr`,
the explicit restores the C performs on backtracking are implicit.

**Lemma A (main).** For every end `e` of the repeater (`e` in the list
`[c, …, i]` above): no position `p` with `i <= p < e` starts an absent
match, `occ a p rr` is false. Hence no non-empty substring of the result
`[i, e)` matches the absent pattern.

**Cases.** `cases/absent.tsv` ab01-ab11.

## 3. `ONIG_OPTION_FIND_LONGEST` (`Longest`)

**C mechanism.** With the option, `OP_END` records the match only if it is
strictly longer than the best so far (`upstream/src/regexec.c:3297-3299`)
and then fails (`regexec.c:3404`) to explore the remaining alternatives;
`OP_FINISH` returns `ONIG_MISMATCH` (`regexec.c:4655-4660`), so
`search_in_range` visits every start and reports `msa.best_s`/`best_len`
at the end (`regexec.c:5993-5999`). The only short cut,
`regexec.c:3305-3307`, stops when a match reaching the range end is not
longer than the best of the same start; no later start can then be
strictly longer, so it does not change the result.

**Formal model.** `longest` folds over starts `0..|s|` ascending and,
within a start, over the results of `m` in priority order, keeping the
first result of strictly greater length: the first result of maximal
length in (start ascending, then priority) order. Forward search only.
The regex core adds `Word` (`\w`, ASCII: `[0-9A-Za-z_]`), enough for the
cases.

**Lemma L (main).** If the first-match `search` returns `Some (s1, e1)`,
then `longest` returns some `Some (s2, e2)` with `e2 - s2 >= e1 - s1`.

**Cases.** `cases/find-longest.tsv` fl01-fl06 (fl05 and fl06 are the
first-match companions of fl03 and fl04).

## 4. ISO-8859-1 multi-character case folding (`Fold`)

**C mechanism.** Under `IGNORECASE`, a string node is expanded by
`unravel_case_fold_string` (`upstream/src/regcomp.c:4963-5045`): at each
pattern position `p` it asks `get_case_fold_codes_by_str`
(`upstream/src/iso8859_1.c:116-215`) for the fold items, consumes the
items' byte length, and emits the alternation of the original bytes and
each item (`unravel_cf_string_alt_or_cc_add`). For ISO-8859-1 the items
are: `0xDF` gives `ss`, `SS`, `sS`, `Ss` (`iso8859_1.c:173-197`); a
two-byte spelling of `ss` (`s`/`S` followed by `s`/`S`) gives `0xDF`
and the three other spellings (`iso8859_1.c:126-150`, `157-160`); other
ASCII letters, `0xC0-0xDE` except `0xD7`, and `0xE0-0xFE` except `0xF7`
give their one-byte case partner. This is one level of expansion, not a
transitive closure. The subject is not folded. Character classes
(`[\xDF]`, `apply_all_case_fold`) are a separate path, out of scope.

**Formal model.** `unravel : list byte -> list (list (list byte))` (one
segment per pattern position, each the list of alternatives, original
first); `ILit w` matches the sequence of segments, each as an
alternation of byte strings in that order. `Chr`, `Seq`, `Alt` and `Eps`
are kept for the cases.

**Lemma F (main).** `0xDF` matches each of `ss`, `SS`, `sS`, `Ss`, and
back: for each such `w`, `search (ILit [0xDF]) w = Some (0, 2)` and
`search (ILit w) [0xDF] = Some (0, 1)`; eight equalities checked by
computation (kernel reduction in Rocq and Lean).

**Cases.** `cases/iso-fold.tsv` cf21, cf22, if01-if08.

## Assumptions and checks

No axioms, admits, `sorry`, `assume` or `external_body` in any file; the
check is in `check.sh`. Native computation (`native_decide`,
`native_compute`) is not used anywhere so far: every case and every main
lemma is checked by the kernel (Rocq `vm_compute`, Lean `decide +kernel`),
by F\*'s normaliser (`assert_norm`) or by Verus's interpreter
(`by (compute_only)`).
