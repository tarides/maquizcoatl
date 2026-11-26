# Experiment #8 follow-up (issue #34): PR review fixes, corrections to entries 4, 6 and 9

Date: 2026-11-26. Kind: correction entry; no prover run. The lab notebook
is append-only, so entries 4 (Rocq), 6 (Verus) and 9 (comparison) stand
as written and are corrected here.

The review of PR #40 read the final theorems of both tools against the
C sources at `f95747b`. It found the theorems to be what the entries say
they are:
- no admits or axioms;
- the Rocq and Verus statements are equivalent;
- the model of the C desugaring follows `upstream/src/regparse.c` node
  for node.

It also found that the "Limits" of entry 9, repeated in entries 4 and 6,
leave out three things, and that two fuel bounds are worded off by one.
It settled one limit by observation.

## Provenance

- Branch commit `c48e9b9`. The Rocq and Verus sources are unchanged
  since entries 4 and 6, and their `sha256.txt` files hold.
- One local C build, made for problem 4 only, in a scratch directory
  outside the repository:
  - upstream `f95747b`, Debug, with `-DONIG_DEBUG_COMPILE`, which
    `upstream/src/regint.h:34` leaves commented out;
  - `probes/harness.c`, built against that copy as the probe README
    describes;
  - gcc 15.2.0, Linux 7.0.0-43-generic, 12th Gen Intel Core i7-1260P;
  - untimed.

Raw data are in [`2026-11-26-exp-08-lemmas-pr-review-raw/`](2026-11-26-exp-08-lemmas-pr-review-raw/):
- `cases.tsv`: cases ab13-ab19, taken from experiment #8's corpus and
  from `cases/absent-restore.tsv`;
- `harness.tsv`: the harness output;
- `dbgc.stderr`: the bytecode dumps, one block after each `@@probe <id>`
  line;
- `gimmicks.tsv`: the `save-val` and `update-var` opcodes of each dump,
  in code order.

## Corrections

### 1. Termination is not proved (entries 4, 6, 9, "Limits")

**What the Limits omitted.** The Limits say "Fuel adequacy is not
covered", which reads as if only the size of the fuel were open.
Termination is open too:
- No lemma shows that `m` or `md` returns a complete result at some fuel
  on an in-scope pattern. `mb_term`, `cut_term` and `term_core` cover
  only the absent-free parts.
- Both directions of lemma 2 assume that one side has returned `Some`.

**What this means.** The theorem is conditional. At a start where `m`
and `md` both run out of fuel at every fuel, it holds vacuously.
Direction (2a) does give `md`'s termination wherever `m` terminates.
Only the 29 cases, at fuel 1000 (`Cases.v`, `cases.rs`), show that the
theorem is not vacuous.

**Decision raised on issue #34:** whether to prove termination of `m`
on in-scope patterns.

Add to the Limits: "Termination is not proved. Lemma 2 is conditional
on one side returning a complete result, and non-vacuity is shown only
on the 29 cases."

### 2. Lemma 2 covers experiment #8's AST only (entries 4, 6, 9, "Limits")

**What the Limits omitted.** They name only nested absent constructs and
registers above the subject length. But `core` and `in_scope`
(`AbsentProof.v:15-30`, `absent_proof.rs:29-49`) admit only `Eps`,
`Chr`, `Any`, `AnyO`, `Seq`, `Alt` and greedy `Star`, with absent-free
`a` and `e`.

**Out of scope:**
- classes;
- bounded, lazy and possessive quantifiers;
- captures;
- anchors;
- atomic groups;
- lookarounds;
- nested absent constructs.

**Consequences:**
- **Simple path:** it is proved only for `Star (Chr c)`, lower bound 0.
  There the engine's restore has no observable effect (`LEMMAS.md`,
  mutant M1 of entry 2). So the restore that bounded or `{n,}` repeats
  rely on is not exercised by the proof.
- **SUPER flag:** not modelled (`regparse.c:3065`, `:3164`). This is
  sound only because nothing in scope places an absent construct inside
  an atomic group or a lookaround.
- **Look-behind's right-range save and restore:** not modelled
  (`regcomp.c:2056-2090`, `:2192-2249`, emitted under
  `PE_FLAG_HAS_ABSENT_STOPPER`).

### 3. The model's register fits a forward search of the whole subject (entries 4, 6, 9)

**What it misstates.** `md`'s starting register, `DRRInit` and `RClear`
use the subject length. The C initialises the register, and resets it
on a range clear, to `in_right_range` (`regexec.c:2729`, `:4576-4577`):
- `range` for a forward `onig_search`, where `range > start`
  (`:5660-5663`);
- one character past `orig_start` for a backward search (`:5972`,
  `:5987`);
- `end` for `onig_match` (`:5413`).

**What this means:**
- The theorem applies at every start of `onig_match` and of a forward
  `onig_search` with `range = end`.
- It is stated per start, with fuels chosen per start.
- No corollary relating `search` and `dsearch` is proved.
- `dsearch` does not model `search_in_range`'s choice of starts
  (`regexec.c:5730-5930`).
- With `range < end`, or a backward search, the C's range clear differs
  from the model's: those calls are not modelled.

**Sentences corrected:**
- Entry 9's "Its faithfulness to `match_at` is checked only on the 29
  cases" now reads: "Its faithfulness to `match_at` (not to
  `search_in_range`) is checked only on the 29 cases, for a forward
  search of the whole subject."
- `LEMMAS.md`'s "the theorem covers every pattern a search runs" is
  corrected in place. The comments of `Desugar.v` (line 160) and
  `desugar.rs` (line 182) on `INIT_RIGHT_RANGE` are not edited, to keep
  the recorded source hashes. They mean the subject end of a forward
  search of the whole subject.

### 4. The simple-path dispatch, observed (entries 4, 6, 9)

The entries say the simple-path dispatch "rests on the reading of
`upstream/src/regparse.c:3194-3236`, not on a C case". It is now
observed in the bytecode (`gimmicks.tsv`):

| Case | Construct | `save-val S` | `update-var S_FROM_STACK` | tail (`RIGHT_RANGE id:3`) |
|------|-----------|-------------:|--------------------------:|:-------------------------:|
| ab13 | expression `(?~\|abc\|\O*)` | 2 | 1 | yes |
| ab14, ab15 | stopper `(?~\|abc)` | 2 | 1 | no |
| ab17, ab18, ab19 | expression `(?~\|abc\|x*)` | 1 | 0 | no |
| ab16 | repeater `(?~abc)` | 1 | 0 | no |

`(?~|abc|x*)` compiles to the simple path: the engine alone, with no
second save of the position and no tail. `(?~|abc|\O*)` takes the
general path. This is what `desugar` builds in both tools. All seven
cases also match as in entry 2 (`harness.tsv`).

The limit is replaced by: "The simple-path dispatch is observed in an
`ONIG_DEBUG_COMPILE` bytecode dump of ab13-ab19, not only read from
`regparse.c`."

### 5. Fuel bounds: "at least", not "above" (entry 9; `FoldProof.v:87`, `fold_proof.rs:205`)

**Lemma F.** Both tools prove it at fuel `7 + f` (Rocq) or `f >= 7`
(Verus). That is every fuel of at least 7, the tight bound. Entry 9's
"for every fuel above the tight bound 7" now reads "for every fuel of
at least 7 (the tight bound)".

**`fold_lit`.** It is proved at fuel `S f` with `cost <= f`, where
`cost` is the number of alternatives plus 1. That is every fuel of at
least the number of alternatives plus 2.
- Entry 9's "at fuel equal to the number of alternatives plus 2" now
  reads "at every fuel of at least the number of alternatives plus 2".
- The comment in `FoldProof.v:87` and `fold_proof.rs:205` ("at every
  fuel above the number of alternatives plus 2") should say "of at
  least". It is not edited, to keep the recorded source hashes.

### 6. Where the register is read (`LEMMAS.md`)

**What it omitted.** `LEMMAS.md` said the register is read only by
`DATA_ENSURE`. It is also read by:
- `CHECK_POSITION_CURRENT_RIGHT_RANGE` (`regexec.c:3994-3995`,
  look-behind);
- callout arguments (`:1188`, `:1207`).

Both are out of scope. This is corrected in place.

### 7. Scripts (`lab/08-discriminating-lemmas/`)

**`lemmas.py`.** Its Verus body rule now skips a brace block that is
followed by `,`, `else`, a clause keyword or another block. That is the
rule `realbody.py` checked in entry 7.
- On the eight Verus files, it changes exactly the seven lemmas entry 7
  lists, and gives 4 automatic lemmas, as corrected by hand there.
  `realbody.py` now reports no difference.
- Its Rocq output is unchanged.

**`timed.sh`, `axioms.sh`, `brittle.sh`.** Their F\* cases are dropped:
they copied files from a `fstar/` directory that this experiment does
not have.

**Headers.** The headers of these three scripts, of `provenance.sh` and
of `brittle_verus.py` described experiment #9: its CPU sets, its file
lists, a sampler on CPU 4. They now describe this experiment: timed CPUs
24-27,56-59, untimed CPUs 8-11, the sampler on CPU 8, the eight Verus
files.

No command or output of a recorded run depends on these changes.

## Dropped

**Out-of-range search starts.** The review also suspected that a
forward search with `range < end` may try starts beyond
`in_right_range` (`regexec.c:5862-5888`). That would mean `i > rr`. It
is not checked here: calls with `range < end` are outside the model
(problem 3), so the outcome would change no claim of these entries.

## Draft comment

The comparison comment was posted on issue #34 before this review.
Problems 1-5 go into a follow-up comment there, once the maintainer
approves it.

_Drafted by Claude Code (Opus 5.5) as part of the experiment pipeline._
