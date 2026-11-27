# Experiment #8 follow-up: the shared design of the two lemmas

Issue #34, plan `plans/08-discriminating-lemmas.md`, run 1. This file
fixes, once for Rocq and Verus, what both tools formalise and prove:
the two statements, the desugaring, the state-threaded matcher and the
lemma plan. Rocq transcribes it in `rocq/`, Verus in `verus/` (run 3).
References to the C sources are `upstream/<path>:<line>` at `f95747b`.
The semantics is experiment #8's (`lab/08-hard-features/SEMANTICS.md`,
sections 2 and 4), with the changes listed in the last section.

## Lemma 1: lemma F over a symbolic subject

On `m` of `rocq/Fold.v` (experiment #8's file, unchanged) and of
`verus/fold.rs`, under IGNORECASE (the expansion `unravel` of
`upstream/src/regcomp.c:4963-5045` with the ISO-8859-1 items of
`upstream/src/iso8859_1.c:116-215`). Write `SS = {ss, SS, sS, Ss}`
(bytes `115 115`, `83 83`, `115 83`, `83 115`). For every subject `s`,
position `i` and fuel `f >= 7`:

- **(F1)** `In (i + 2) (m s f [R (ILit [223])] i)` iff
  `s[i..i+2)` is in `SS`;
- **(F2)** for every `w` in `SS`, `In (i + 1) (m s f [R (ILit w)] i)`
  iff `nth_error s i = Some 223`.

In Rocq the bound is written `m s (7 + f) ...` (or `f >= 7`); in Verus
the fuel stays a variable with `f >= 7` in `requires`, and
`reveal_with_fuel(m, k)` takes a literal unfolding depth `k`. The
constant `fuel := 1000` of `Fold.v` appears in no statement or proof.

**The bound 7.** `unravel [223]` and `unravel w` for `w` in `SS` are one
segment of five alternatives (checked by `vm_compute` in run 1); `m`
spends one step on `ILit`, one per alternative tried and one on the
final empty segment or the empty stack, so the last alternative needs
seven steps. The bound is tight for (F1): at fuel 6, `m [83;115] 6
[R (ILit [223])] 0 = []` (the spelling `Ss`, last in the segment, is
missed), at fuel 7 it is `[2]` (run 1, `Kcheck.v` in the raw data).

The proof unfolds `unravel` on the concrete literal and seven steps of
`m`, then splits on `nth_error s i` and `nth_error s (i + 1)`;
`prefix_at` is related to `nth_error` by a small lemma.

**Stretch (decision 6).** The one-level fold statement for every literal
`w`, with a declarative relation:

    fold_rel s i [] i
    fold_rel s i (alts :: segs) e   if  In u alts, prefix_at s i u = true
                                        and fold_rel s (i + |u|) segs e

For every `w`, `s`, `i`, `e` and `f` above a bound in `w` (the total
number of alternatives of `unravel w` plus its number of segments plus
2): `In e (m s f [R (ILit w)] i)` iff `fold_rel s i (unravel w) e`, by
induction on `w` through `unr`. Attempted only after (F1), (F2) and
lemma 2 are closed in that tool.

**Run 2 (Rocq): closed** (`FoldProof.v`, `fold_lit`). The induction is
on the list of segments and on each segment's alternatives, for any
segment list, not on `w`, so it needs no lemma about `unr`; the bound
is the number of alternatives of `unravel w` plus 2 (`cost`), which is 7
for `[0xDF]`, the bound of (F1).

**Run 3 (Verus): closed** (`verus/fold_proof.rs`, `sharp_s_sym` at
`f >= 7` in `requires`, and `fold_lit` with the same bound). The
unfolding of `unravel` on the concrete literals is a `compute_only`
assertion; `fold_rel` is a recursive spec fn with an existential.

## Lemma 2: absent desugaring equivalence

### The desugaring

`rocq/Desugar.v`. The desugared AST `dre` is experiment #8's
absent-free core (`DEps`, `DChr`, `DAny`, `DAnyO`, `DSeq`, `DAlt`,
`DStar`) plus the nodes the C parser emits:

| Node | C node | Source |
|------|--------|--------|
| `DAtomic a` | `BAG_STOP_BACKTRACK` | `upstream/src/regparse.c:3041-3047` |
| `DFail` | `node_new_fail` | `upstream/src/regparse.c:3020`, `:3053`, `:3098`, `:3146` |
| `DSaveRR id` | `SAVE_RIGHT_RANGE` gimmick | `upstream/src/regparse.c:3090`, `:3138`, `:3270`, `:3347` |
| `DSaveS id` | `SAVE_S` gimmick | `upstream/src/regparse.c:3009`, `:3352` |
| `DUpdRRFromStack id` | `UPDATE_VAR_RIGHT_RANGE_FROM_STACK` | `upstream/src/regparse.c:3049`, `:3094`, `:3106`, `:3142`, `:3281` |
| `DUpdRRFromS id` | `UPDATE_VAR_RIGHT_RANGE_FROM_S_STACK` | `upstream/src/regparse.c:3013` |
| `DUpdSFromStack id` | `UPDATE_VAR_S_FROM_STACK` | `upstream/src/regparse.c:3368` |
| `DRRInit` | `UPDATE_VAR_RIGHT_RANGE_INIT` | `upstream/src/regparse.c:3156` |

`desugar : re -> nat -> dre * nat` (the `nat` is the next free gimmick
id) follows `make_absent_tree`'s dispatch:

- `AbsRep a`, i.e. `(?~absent)`: `make_absent_tree` builds `\O*` and
  enters the simple path (`upstream/src/regparse.c:3317-3328`);
  `make_absent_tree_for_simple_one_char_repeat`
  (`upstream/src/regparse.c:3252-3296`) gives
  `SaveRR id1; Engine(id1, j, a, AnyO, non-possessive); UpdRRFromStack id1`.
- `AbsExp a e`, i.e. `(?~|absent|exp)`: `make_absent_tree` calls
  `is_simple_one_char_repeat` on `exp` (`upstream/src/regparse.c:3331`),
  which accepts a greedy `ND_QUANT` (or a `BAG_STOP_BACKTRACK` around
  one, then possessive) whose body is a one-character `ND_STRING` or an
  `ND_CCLASS` (`upstream/src/regparse.c:3184-3249`, the test at
  `:3194-3236`). The AST has no classes, other quantifiers or possessive
  groups, so its only simple case is `Star (Chr c)`:
  - simple path, `e = Star (Chr c)`:
    `SaveRR id1; Engine(id1, j, a, Chr c, non-possessive); UpdRRFromStack id1`
    (no `SaveS`, no tail; the quantifier's bounds are `*`'s, 0 and
    infinite);
  - general path, every other `e`, `\O*` included (`\O` is an
    `ND_CTYPE` any-char node, not a class, so `\O*` is rejected;
    `upstream/src/regparse.c:3347-3384`):
    `SaveRR id1; SaveS id2; Engine(id1, j, a, AnyO, possessive); UpdSFromStack id2; e; Tail(id1, id3)`.
- `Stopper a`, i.e. `(?~|absent)`: the general path without the tail, the
  four-node list (`upstream/src/regparse.c:3371-3373`); the engine's outer
  alternation is flagged `SUPER` and its `UpdRRFromS` node
  `ABSENT_WITH_SIDE_EFFECTS` (`upstream/src/regparse.c:3064-3065`,
  `:3017-3018`).
- `RClear`, i.e. `(?~|)`: `make_range_clear`
  (`upstream/src/regparse.c:3127-3183`):
  `SaveRR id; Alt (RRInit) (UpdRRFromStack id; Fail)`, the alternation
  flagged `SUPER`.
- `Engine(id, j, a, step, poss)` = `make_absent_engine`
  (`upstream/src/regparse.c:2995-3075`):
  `Alt (Star (Alt (SaveS j; a; UpdRRFromS j; Fail) step) [inside Atomic if poss]) (UpdRRFromStack id; Fail)`.
- `Tail(id1, id3)` = `make_absent_tail`
  (`upstream/src/regparse.c:3078-3124`):
  `SaveRR id3; Alt (UpdRRFromStack id1) (UpdRRFromStack id3; Fail)`.

**Ids.** Gimmick ids come from one counter (`ID_ENTRY` in
`node_new_save_gimmick`, `upstream/src/regparse.c:2785-2799`) and the
model allocates them in the C's order (simple path: `id1`, then the
engine's `j`; general path and stopper: `id1`, `id2`, the engine's `j`,
then the tail's `id3`). The model only needs them distinct per
construct. Inside a loop the same ids are reused at every iteration;
the lookup takes the newest entry (below), as the C does.

### The state-threaded matcher

`md s f ks i rr sv` in `rocq/Desugar.v` mirrors `match_at`
(`upstream/src/regexec.c`) on these nodes:

- **Register.** `rr` is `right_range`, a local of `match_at`
  (`upstream/src/regexec.c:3189`), initialised to the subject end at each
  start (`INIT_RIGHT_RANGE`, `:2729`, called at `:3278`; the subject end
  is `data_range`, `end` for a forward search of the whole subject,
  `:5660-5663`),
  written only by `OP_UPDATE_VAR` (`:4548-4580`) and read by
  `DATA_ENSURE*` (`:2725-2727`): every consuming node checks `i < rr`.
  Outside this scope it is also read by
  `CHECK_POSITION_CURRENT_RIGHT_RANGE` (`:3994-3995`, look-behind) and by
  callout arguments (`:1188`, `:1207`).
  Backtracking does not restore it: `md` returns the ordered list of
  results together with the register at final failure, and the
  alternative tried next starts from the register the previous one
  failed with.
- **Save store.** `sv`, newest first, is the list of `STK_SAVE_VAL`
  entries of the backtrack stack; `STACK_GET_SAVE_VAL_TYPE_LAST_ID`
  (`upstream/src/regexec.c:2211-2230`) takes the last entry of the id,
  and `clear` is `FALSE` for every absent gimmick, so the entry stays.
  Being on the stack, the store is per branch: each alternative starts
  from the store of its choice point. A lookup of an id with no entry
  makes `md` return `None` (it never happens on a desugared tree).
- **Results.** A result is `(end, rr, sv)` at success; the projection to
  `end` is what the lemma compares.
- **Atomic.** `DAtomic a` keeps the first result of `a` with its register
  and its saves, and drops `a`'s other branches. The saves survive the
  cut: `STK_SAVE_VAL` is `0x0600` (`upstream/src/regexec.c:1269`), and
  `STACK_TO_VOID_TO_MARK` (`:2391-2407`) voids only the entries whose
  type meets `STK_MASK_TO_VOID_TARGET`, `0x100e` (`:1276`, tested by
  `IS_TO_VOID_TARGET`, `:2008`);
  `0x0600 & 0x100e = 0`. Re-checked in run 1.
- **SUPER.** Not modelled. It changes only which stack entries a cut
  voids (`STK_SUPER_ALT`, `0x0001`, is outside the void mask, `STK_ALT`,
  `0x0003`, inside: `upstream/src/regexec.c:1239-1244`).
  **Scope condition:** the AST has no atomic group and no lookaround,
  so no cut encloses an absent construct and `SUPER` has no effect on
  the patterns of the lemma; `ABSENT_WITH_SIDE_EFFECTS` only rejects a
  stopper inside a lookbehind (`upstream/src/regcomp.c:3481`, `:3578`).
- **Fuel.** `md` takes a fuel `f`; every step costs one unit; `None` is
  out of fuel. `md` runs the absent pattern inside the engine with its
  own fuel, the direct `m` with `occ`'s inner fuel `g`.

**Faithfulness.** `md (desugar r)` is a new definition. Its faithfulness
to the C library is established only on the case corpus below, by
agreement of the first match; nothing else ties it to `match_at`.

### Validation (run 1, before any proof)

`rocq/Cases.v`: for each of the 29 cases (experiment #8's ab01-ab11 in
`lab/08-hard-features/cases/absent.tsv`; ab12-ab29 in
`cases/absent-restore.tsv`), `search G F p s` (direct `m`) and
`dsearch F p s` (`md` on `desugar p`) both equal the C result (Debug and
ASan/UBSan builds agree), and `m` and `md` give the same complete list
of ends at every start, at `G = F = 1000`, by `vm_compute`. Results:
`lab/results/2026-11-26-exp-08-lemmas-cases.md`.

A mutation check (raw data of that entry) removed one restore at a time
from `desugar` and found, for each restore, which cases detect it. It
ran on the first 27 cases (ab01-ab27), before ab28-ab29 (the loops
around an absent construct) were added; the detections below hold on
29, but the two no-effect statements (the atomic group changes no first
match; the two removals that change nothing) were not checked on the
loop cases, and ab29 is the only stopper inside a loop. Run 2 reran the
eight mutants on the 29 cases (`lab/results/2026-11-26-exp-08-lemmas-rocq.md`):
the two no-effect statements hold on all 29, and ab29 also detects the
engine restore. Detections on 29 cases:
the engine restore `UpdRRFromStack id; Fail` (ab13, ab14, ab15, ab29), the
tail's re-install through `id3` (ab20), the tail's restore through `id1`
(ab21, ab22, ab25, ab27), the range clear's restore (ab23), the simple
path's final `UpdRRFromStack id1` (ab16, ab26), the rewind
`UpdSFromStack id2` (ab09, ab20, ab21, ab27). Dropping the atomic group
of the general path changes no first match but changes the lists of
ends (seven cases), so only the list comparison sees it. Two removals
change nothing: sending every `AbsExp` through the general path (the
two paths agree, as CB-001 says) and, in the simple path only, the
engine restore (with a lower bound of 0 the loop always reaches the
zero-iteration end, whose final `UpdRRFromStack id1` already restores
the register).

### The statement

`in_scope r`: `r` is built from the core, `AbsRep a`, `AbsExp a e`,
`Stopper a` and `RClear`, where `a` and `e` are absent-free (nested
absent is out of scope, as in experiment #8: `upstream/doc/RE:385` calls
it undefined). For every `r` with `in_scope r`, every subject `s`,
position `i` and register `rr` with `i <= rr <= length s` (run 2, see
below), writing `d = fst (desugar r 0)` and
`ends rs = map (fun '(e, _, _) => e) rs`:

- **(2a)** for all `g f l`, if `m s g f [R r] i rr = Some l` then there
  is `f'` with `md s f' [DR d] i rr [] = Some (rs, rr)` and `ends rs = l`
  (the register at final failure is the starting one);
- **(2b)** for all `f' rs x`, if `md s f' [DR d] i rr [] = Some (rs, x)`
  then `x = rr` and there are `g f` with
  `m s g f [R r] i rr = Some (ends rs)`.

**Run 2: the hypothesis `i <= rr <= length s`.** Run 1 wrote "every
register `rr`"; the statement is false without `rr <= length s`. On the
empty subject at `i = 0`, `rr = 2`, `m` on `AbsRep (Chr 7)` returns the
ends `[2; 1; 0]` (the cut scans up to the register), and `md` on its
desugaring returns `[0]` (the engine's `\O` step stops at the subject
end): `Rcheck.v` in run 2's raw data. For a forward search of the whole
subject (`onig_search` with `range = end`) and for `onig_match`, every
start has `rr = length s` and `i <= length s`, and both matchers preserve
the hypothesis (a consuming step needs `i < rr`; a cut lies between the
position and the register; `RClear` sets the register to `length s`), so
the theorem applies at every start. It is stated per start, with fuels
chosen per start; no corollary relating `search` and `dsearch` is proved,
and `dsearch` does not model `search_in_range`'s choice of starts
(`regexec.c:5730-5930`). When the caller passes `range < end`, or searches
backward, the C starts the register at `in_right_range` and the range
clear resets it there (`regexec.c:5660-5663`, `:5972`, `:5987`,
`:4576-4577`), not at the subject end: those calls are not modelled, and
the comments of `Desugar.v` and `desugar.rs` on `INIT_RIGHT_RANGE` mean
the subject end of a forward search of the whole subject. The change is
to the statement written in run 1, not to a decision.

Rocq name `absent_desugar_eq` (the conjunction), in `AbsentProof.v`.
A continuation is a pattern too (`Seq r k`), so the statement covers the
continuations of the corpus; the induction generalises it to item
stacks (below).

**Fuel (decision 3).** Both directions are existential in the other
side's fuel. They rest on monotonicity and determinism for both matchers
(`AbsentMono.v`, after experiment #9's `ct_mono`/`ct_det` in
`lab/09-representative-proof/rocq/ProofSem.v`): if a matcher returns
`Some` at some fuel, it returns the same value at every larger fuel
(and for `m`, at every larger `g` too). `mb` returns `option bool`
(`None` for out of fuel) and the `None` propagates through `occ`,
`scan`, `cut` and `m`, so a complete list on either side implies that
every `occ` it evaluated was complete. Fuel adequacy (fuel as a function
of the input) is later work.

**Termination (decision 8, run 5).** Both tools prove that the direct
matcher terminates on every in-scope pattern: for every `s`, `i`, `rr`
with `i <= rr <= length s` and `in_scope r`, there are fuels `g`, `f`
and a list `l` with `m s g f [R r] i rr = Some l` (`m_term`). With
direction (2a) of `absent_desugar_eq`, `md` on `desugar r` then returns
`Some (rs, rr)` at some fuel, with `ends rs = l`
(`absent_desugar_total`, stated identically in both tools), so lemma 2
holds without assuming that either side is complete: at every such
start, both matchers terminate and agree. `absent_desugar_eq` is
unchanged.

The induction (`m_term_stack`) generalises to item stacks made of
in-scope `R` and `Chk` items and of `SetRR k` items with
`k <= max q (length s)` (the restore at the end of `AbsExp`'s `exp`),
with the register also at most `max q (length s)`. Its measure is
`(length s - q, tmu ks q)` lexicographically: `term_core`'s, with an
`AbsExp a e` weighed by its `exp` (`2 + size e`), since `exp` and the
restore replace it at the same position. A consuming step moves forward
below `length s` (`at_` reads the subject). The cut of `AbsRep`, `AbsExp`
and the stopper exists at some inner fuel (`cut_term`) and lies between
the position and the register (`scan_ge`, `scan_le`). An `AbsRep`'s
`Ends` branches either stay at `q`, on the rest of the stack (a smaller
`tmu`), or move forward to an end at most the cut, hence at most the
register and the subject length. The per-branch fuels are merged by
monotonicity (`m_mono`, `cut_mono`). Fuel adequacy, a fuel bound as a
function of the input, is still later work: the proofs give fuels that
exist, not a formula.

**The invariant.** The core of the proof relates a direct item stack and
register to a desugared item stack, register and save store: after a
desugared absent construct, the register equals the direct semantics'
`rr` for that branch, and the save store's newest entries for the
construct's ids hold the register from before the construct (`id1`) and,
on the general path, the start position (`id2`) and the cut (`id3`).
The register at final failure of a desugared construct equals the
register it started with (every exit path restores `id1`); that is what
makes the global register behave like experiment #8's per-branch `rr`.

### Lemma plan (shared by both tools)

- (a) Core: on absent-free item stacks, `m` and `md` agree and `md`
  never writes the register or the store (`md` returns the starting
  register at final failure).
- (b) Fuel monotonicity and determinism of `mb`, `scan`/`cut`, `m` and
  `md` (after `ProofSem`).
- (c) The scan: `Star (Alt (SaveS j; a; UpdRRFromS j; Fail) step)` from
  `i` with register `rr` reaches the cut `cut a i rr` (`occ` at the
  inner fuel) and sets the register to it, and the attempts at the
  positions before it leave the register unchanged.
- (d) The simple path for a general step (`AnyO` for `AbsRep`, `Chr c`
  for `AbsExp a (Star (Chr c))`; `step` is a parameter of the engine
  model): the non-possessive scan yields the ends of the step's
  repetitions under the cut, longest first, each followed by the
  restore through `id1`; the engine restore runs last.
- (e) `AbsExp` on the general path: the atomic scan gives the cut, the
  rewind, `e` under the cut, then the tail's two branches (restore
  through `id1` for the continuation, re-install through `id3` when
  backtracking into `e`).
- (f) Stopper: the general path without the tail; the cut stays for the
  continuation; the engine restore on final failure.
- (g) The main theorem, by induction on the fuel with the invariant over
  the item stacks.
- (h) Range clear, as one more case of (g) if it closes in a few lines in
  each tool; otherwise named out of scope with the reason.
- (i) Termination of `m` on in-scope patterns (`m_term_stack`, `m_term`)
  and lemma 2 without its condition (`absent_desugar_total`), added in
  run 5 by decision 8; see "Termination" above.

**Run 2 (Rocq), how the plan was carried out.** `AbsentMono.v` proves
(b). `AbsentProof.v` proves (a) and (c) together for an absent-free
stack followed by the engine's continuation `UpdRRFromS j; Fail`
(`core_K`: `md` ends with `p` if `mb` finds a result, with the starting
register otherwise), and its termination (`term_core`, by induction on
`(rr - i, size)`; it also gives the termination of `mb` on absent-free
patterns, which the simple path needs because its scan can stop before
the cut, at the first position that is not `c`). (d) is `scan_a`/`scan_b`
for a general step, `AnyO` or `Chr c`, followed by a continuation whose
final register is a function `h` of the register it is entered with
(constant on the simple path, the identity for the atomic scan of the
general path and the stopper, where the continuation is empty). (g) is
`sim_a`/`sim_b`, by strong induction on the fuel of `m` (for (2a)) or
of `md` (for (2b)), over a relation `rel` between the two item stacks:
items related one by one (each with its own id base, since every lookup
of a desugared construct reads an id that the construct saved itself),
a `SetRR k` (the end of `AbsExp`'s `exp`) related to the tail with the
store holding `k` under `id1`, and only absent-free items above it. The
invariant of the design note holds as stated: `md` on a related stack
ends with the register it started with, so the next alternative starts
from the register of its choice point, as in the direct semantics.
(e), (f) and (h) are cases of (g): the range clear closes in the same
induction (one case of 5 to 6 lines in each direction, plus four
unfolding and inversion lemmas of about 35 lines), so it is in scope,
not named out.

**Run 3 (Verus), the same plan with a different encoding.** `verus/`
transcribes the definitions (`absent.rs` with C1-C6, `desugar.rs`,
`cases.rs`, whose 29 cases agree by `compute_only`) and the lemma plan
lemma by lemma: `absent_mono.rs` for (b); `core_k`, `term_core`,
`attempt` for (a)/(c); `scan_a`/`scan_b` for (d); `sim_a`/`sim_b` for
(g). The encoding differs where Verus has no inductive predicates:
- Rocq's `Forall2` over the ends of a scan is replaced by one fuel for
  every end (monotonicity) and the concatenation of the results at that
  fuel (`dcat`, `mcat`).
- The per-end fuels of the induction hypothesis are merged by `choose`
  and a maximum over the range.
- `rel` is a recursive spec fn that takes the ids of each item as a
  list.
- The absent cases of `sim_a`/`sim_b` are functions of their own,
  mutually recursive with the main induction (`decreases f, 0/1`).
- (2b)'s `Alt` and `Star` cases were split off after the unsplit
  `sim_b` exceeded the default rlimit.

The range clear closes in Verus too, in about 90 lines (four helper
lemmas, one case per direction), so it stays in scope in both tools.
Results: `lab/results/2026-11-26-exp-08-lemmas-verus.md`.

## Changes to experiment #8's definitions

`rocq/Fold.v` is experiment #8's file unchanged. `rocq/Absent.v` is
experiment #8's file (main at `6630262`) with these changes, also listed
in its header:

- **C1** `mb` returns `option bool`, `None` for out of fuel
  (`Alt` and `Star` through `oor`: a true left branch decides).
- **C2** `occ` takes its fuel `g` as a parameter (a section variable),
  instead of the constant `fuel := 1000` (removed).
- **C3** `scan`, `cut` and `rep_ends` return options and propagate
  `None`.
- **C4** `m` returns `option (list nat)`, `None` for out of fuel or an
  `occ` out of fuel, and takes `g`.
- **C5** `search` takes both fuels and returns `Match st e`, `NoMatch`
  or `OutOfFuel`; experiment #8's case lemmas ab01-ab11 moved to
  `Cases.v`, at explicit fuels, with the desugared model beside them.
- **C6** Lemma A (`absent_not_inside`) restated for the option `cut`:
  below every end of the repeater, `occ` is `Some false`.

The equations are otherwise experiment #8's, and ab01-ab11 give the
same results as in experiment #8.
