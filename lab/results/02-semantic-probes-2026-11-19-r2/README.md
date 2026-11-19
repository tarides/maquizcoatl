# Experiment #2, run 2: separating probes and opcode dump (2026-11-19)

Issue: [#6](https://github.com/tarides/maquizcoatl/issues/6). Plan:
[`plans/02-semantic-probes.md`](../../../plans/02-semantic-probes.md).
Previous run (kept unchanged):
[`02-semantic-probes-2026-11-19/`](../02-semantic-probes-2026-11-19/README.md).
This entry **supersedes the area-3 verdict and deviation candidate D3**
of the previous run, and closes its first open question.

## What

The independent review of run 1 (issue #6) showed, from a bytecode dump,
that the capture-status empty check (`OP_EMPTY_CHECK_END_MEMST`) is
emitted for fewer loops than the run-1 verdict said. This run:

- adds 4 empty-iteration probes (ei17-ei20) that separate the two
  candidate rules, and 6 lookbehind probes (lb24, lb25 under the
  Oniguruma, Ruby and Perl syntaxes) for `LOOK_BEHIND_MAX_CHAR_LEN`;
- re-runs every area on the Debug and ASan/UBSan builds and Node.js;
- adds a third build with `ONIG_DEBUG_COMPILE` and records, per probe,
  the empty-check and lookbehind opcodes actually emitted
  (`raw/<area>.opcodes.tsv`, extracted from `raw/<area>.dbgc.stderr`).

## Why

Run 1 stated the empty-iteration rule and the opcode behind ei14/ei15
from a reading of the source. The review found that the reading was
wrong for ei04, ei11 and ei16, which changes the spec's rule for area 3
and the explanation of D3. The new probes pin the rule by data, the
dump turns the opcode claims into observations, and lb24/lb25 exercise
a compile-time limit the lookbehind verdict names but no probe reached.

## Provenance

- Branch `exp/02-semantic-probes`, probes at `1c8ae99`; this results
  directory is the next commit.
- Upstream `f95747b` (`onig_version()` = `6.9.10`); `git -C upstream
  status` clean before and after.
- Machine, toolchain, sanitizer options and V8 flags: as in run 1
  (i7-1260P, 15 GB RAM, Ubuntu 26.04.1, Linux 7.0.0-43-generic; GCC
  15.2.0, CMake 4.2.3, Node.js v22.22.1).
- **Build layout** (the one `probes/README.md` replays; the plan now
  uses it too). All under one work directory `<workdir>` outside the
  repository, `make -j4`:
  - `<workdir>/build`: Debug (`-DCMAKE_BUILD_TYPE=Debug`), reused from
    run 1;
  - `<workdir>/build-asan`: Debug + `-fsanitize=address,undefined
    -fno-omit-frame-pointer` (compile and link), reused from run 1;
  - `<workdir>/probes-build`: `harness-debug`, `harness-asan`, reused
    (harness source unchanged since run 1);
  - new: `<workdir>/build-dbgc`: `cmake -S upstream -B <workdir>/build-dbgc
    -DCMAKE_BUILD_TYPE=Debug -DCMAKE_C_FLAGS=-DONIG_DEBUG_COMPILE`,
    `make -C <workdir>/build-dbgc -j4 onig`; harness in
    `<workdir>/probes-build-dbgc` (`make -C probes
    BUILD=<workdir>/build-dbgc OUT=<workdir>/probes-build-dbgc harness`,
    `ldd` checked: it loads the `build-dbgc` library).
- Run: `probes/run.sh <workdir>/probes-build <out>` (exit 0, about
  1.5 s), then `probes/opcodes.sh <workdir>/probes-build-dbgc/harness-debug
  <out> empty-iterations lookbehind` (exit 0). Run twice from the
  committed probes; both runs byte-identical. Deterministic.
- Kept here: the two changed areas only. The three unchanged areas
  (captures in loops, backref to unset group, case folding) gave joined
  TSVs byte-identical (`cmp`) to run 1's, so they are not duplicated.

## Raw data

| Area | Probes | same | different | n/a (extra) | Sanitizer reports | Debug = ASan |
|------|-------:|-----:|----------:|------------:|------------------:|:------------:|
| [empty iterations](raw/empty-iterations.joined.tsv) | 20 (+4) | 3 | 13 | 4 | 0 | all |
| [lookbehind](raw/lookbehind.joined.tsv) | 75 (+6) | 35 | 40 | 0 | 0 | all |

Results of the old probes are unchanged (sorted joined rows identical to
run 1 apart from the added ones). Opcodes: [empty
iterations](raw/empty-iterations.opcodes.tsv),
[lookbehind](raw/lookbehind.opcodes.tsv); raw dumps in
`raw/<area>.dbgc.stderr`.

### Empty iterations: results and emitted empty check

| Probe | Pattern / subject | Oniguruma | JavaScript (`u`) | Empty check emitted |
|-------|-------------------|-----------|------------------|---------------------|
| ei01 | `()*\1` / `a` | `M 0-0 \| 1=0-0` | `M 0-0 \| 1=-` | `empty-check-end-memst` |
| ei02 | `(?:()\|())*\1\2` / `a` | `M 0-0 \| 1=0-0 2=0-0` | `M 0-0 \| 1=- 2=-` | `empty-check-end-memst` |
| ei03 | `(?:()\|()\|()\|(x)\|()\|())*\2b\5` / `b` | `M 0-1 \| 1=0-0 2=0-0 5=0-0 …` | `M 0-1 \| all unset` | `empty-check-end-memst` |
| ei04 | `(a\|)*` / `aa` | `M 0-2 \| 1=2-2` | `M 0-2 \| 1=1-2` | `empty-check-end` |
| ei05 | `(a\|)*` / `b` | `M 0-0 \| 1=0-0` | `M 0-0 \| 1=-` | `empty-check-end` |
| ei06 | `(?:a?)*?b` / `aab` | `M 0-3` | same | none |
| ei07-ei09 | `(a*)*`, `(a*)+`, `(a?)*?b` | see joined TSV | see joined TSV | `empty-check-end` |
| ei10 | `(?:a\|())*\1` / `aa` | `M 0-2 \| 1=2-2` | `M 0-2 \| 1=-` | `empty-check-end-memst` |
| ei11 | `(?:(a)\|())*` / `ab` | `M 0-1 \| 1=0-1 2=1-1` | `M 0-1 \| 1=0-1 2=-` | `empty-check-end` |
| **ei17** | `(?:(a)\|())*\1` / `ab` | `N` | `M 0-0 \| 1=- 2=-` | `empty-check-end-memst` |
| **ei18** | `(?:(a)\|())*\1` / `aa` | `M 0-2 \| 1=0-1 2=1-1` | `M 0-2 \| 1=0-1 2=-` | `empty-check-end-memst` |
| ei12 | `(?<r>a?\g<r>?)*b` | `E -221` (left-most recursion control) | n/a | none (compile error) |
| ei13 | `(?<r>a\|\(\g<r>?\))*b` / `(a)b` | `M 0-4 \| 1=0-3` | n/a | none (body never empty) |
| ei14 | `(?<r>a\g<r>?b\|)*c` / `abaabbc` | `M 0-7 \| 1=6-6` | n/a | `empty-check-end-memst-push` |
| ei15 | `(?<r>a\g<r>?b\|)*c` / `c` | `M 0-1 \| 1=0-0` | n/a | `empty-check-end-memst-push` |
| ei16 | `(?:\1a\|())*` / `a` | `M 0-0 \| 1=0-0` | `M 0-1 \| 1=-` | `empty-check-end` |
| **ei19** | `(?:\1a\|())*\1` / `a` | `M 0-1 \| 1=1-1` | `M 0-1 \| 1=-` | `empty-check-end-memst` |
| **ei20** | `(?:a\|())*\1` / `a` | `M 0-1 \| 1=1-1` | `M 0-1 \| 1=-` | `empty-check-end-memst` |

### Lookbehind: emitted opcodes and the length limit

Every compiled lookbehind uses `mark` ... `cut-to-mark` (positive) or
`mark` ... `pop-to-mark` (negative). The variable-length ones
(lb01o-lb03o, lb08o-lb15o, lb20o-lb22o) add `step-back-next` and
`check-position`; the fixed-length or reduced ones (lb04, lb07, lb16-lb19,
lb23, lb25) use `step-back-start` alone. In particular lb08o, lb09o,
lb21o and lb22o compile to `mark` / `step-back-start` /
`step-back-next` / `check-position` / `cut-to-mark`, as run 1 described
from the source (`upstream/src/regexec.c:4481-4504`).

| Probe | Pattern | Oniguruma / Ruby / Perl | JavaScript |
|-------|---------|-------------------------|------------|
| lb24o/r/p | `(?<=a{65536})x` / `x` | `E -122 invalid pattern in look-behind` (all three) | `N` |
| lb25o/r/p | `(?<=a{65535})x` / `x` | `N` (compiles; `step-back-start` only) | `N` |

The limit is `LOOK_BEHIND_MAX_CHAR_LEN` = `STEP_BACK_MAX_CHAR_LEN` =
65535 (`upstream/src/regint.h:227-228`), checked on the body's minimum
and finite maximum length at `upstream/src/regcomp.c:4633-4636` (comment
"#177: overflow in onigenc_step_back()"). It is independent of the
syntax and reuses error -122, the code of the syntax-driven lookbehind
restrictions.

## Analysis

### Area 3, corrected verdict (supersedes run 1)

Run 1 said that, for capture-bearing bodies, Oniguruma continues the
loop after an empty iteration when the capture status changed. The dump
shows the rule is narrower. When the body may be empty and contains
captures (`BODY_MAY_BE_EMPTY_MEM`), the compiler emits
`OP_EMPTY_CHECK_END_MEMST` only if the quantifier carries
`EMPTY_STATUS_CHECK` and a non-empty `empty_status_mem`
(`upstream/src/regcomp.c:980-990`, decision at `:984`); otherwise it
emits the plain `OP_EMPTY_CHECK_END`. `set_empty_status_check_trav`
sets that flag, for a group, only when a **backreference to the group
lies outside the loop** (`upstream/src/regcomp.c:3941-3957`, the
`! is_ancestor_node(ernode, node)` test), and then only for the
referenced groups. Recursive bodies (`BODY_MAY_BE_EMPTY_REC`) always get
`OP_EMPTY_CHECK_END_MEMST_PUSH` (`:992-997`).

The new probes show the observable difference:

- ei16 `(?:\1a|())*` on `a`: the backreference is inside the loop only,
  so the check is plain; the loop exits after the first (empty)
  iteration, which set group 1: `M 0-0 | 1=0-0`.
- ei19 `(?:\1a|())*\1` on `a`: the same loop plus a backreference after
  it. Group 1 now gets the status check; the first empty iteration
  changes it (unset to `0-0`), so the loop continues, `\1a` matches `a`,
  a further empty iteration moves group 1 to `1-1` (changed again), the
  next one leaves it unchanged and the loop exits: `M 0-1 | 1=1-1`.
  Adding a backreference *after* the loop changes how much the loop
  consumes.
- ei17/ei18 `(?:(a)|())*\1` (ei11 plus a backreference outside) and ei20
  `(?:a|())*\1` get `memst`; ei04 and ei11 (no backreference) get the
  plain check, with the same observable result either way.

**Verdict: adapts** (unchanged), with the rule restated. Replace the
RepeatMatcher's empty-iteration failure (ES2025 22.2.2.3.1 step 2.b) by
Oniguruma's empty check: after an empty iteration, leave the loop and
keep the iteration's captures, except that the loop continues if a
*selected* group changed its capture during the iteration; the selected
groups are chosen at compile time (groups of the body referenced by a
backreference outside the loop; for recursive bodies, the push variant).
The selection rule lives in `regcomp.c`, not `regexec.c`. Whether
Maquizcoatl keeps that selection rule is deviation DEV-003 in
[`spec/deviations.md`](../../../spec/deviations.md).

### D3, refined

`doc/RE:592-595` states the rule without the selection ("Zero-width
match in an infinite loop stops the repeat, then changes of the capture
group status are checked as stop condition") and gives `/(?:\1a|())*/ =~
"a"` as an example. That example is exactly a loop the implemented
selection excludes, since its only backreference is inside the loop: the
doc's own example is one its stated rule does not apply to.
`upstream/test/test_utf8.c:742` pins the implemented result (`[0,0)`,
group 1 `[0,0)`); the doc rule, applied to it, gives ei19's behaviour
(`[0,1)`). D1 and D2 are unchanged.

### Lookbehind

The opcode claims of run 1 are confirmed by the dump. lb24/lb25 add the
length limit to the per-syntax compile restrictions: a body whose
minimum or finite maximum exceeds 65535 characters is rejected under
every syntax with -122.

## Open questions

- Run 1's first open question (opcode behind ei14/ei15) is **closed**:
  the dump shows `empty-check-end-memst-push` for both.
- Termination of a loop that continues on capture-status changes is
  argued, not proved: each continued empty iteration must change a
  selected capture, and the spec will need a measure for it.
- Corpus widening from `upstream/test/*.c` and the swap of Node.js for
  Warblre (#13) remain follow-up, as planned.
