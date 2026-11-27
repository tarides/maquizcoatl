# Plan: experiment #10, proved C VM, stack A vs stack C

Issue: [#8](https://github.com/tarides/maquizcoatl/issues/8). The issue
body is the reference for scope, inputs, measurement protocol and
done-criteria; this plan says how. The issue was re-scoped on 2026-11-27
([comment](https://github.com/tarides/maquizcoatl/issues/8#issuecomment-7223979785)).
This plan replaces the plan of 2026-11-19, which timed the code generated
from experiment #9's VM and is kept in this branch's history. Source:
maintainer's state-of-the-art report, "Experiments before deciding", row
of experiment #10 (https://claude.ai/artifact/8w6PVuiTsLCKpugpCowMHc).

## Objective

Settle the choice between the two finalist stacks, A (Rocq) and C
(F\* + Pulse). Each finalist proves the same imperative VM design as C;
then four things are measured:

1. proof cost, in experiment #9's units;
2. speed against Oniguruma `f95747b`'s `match_at` on the same bytecode,
   subjects and retry budget;
3. SMT brittleness, for Pulse;
4. readability of the shipped C.

The figures feed the stack decision. No pass/fail verdict is given here
(decision B).

## Decisions folded in

From the maintainer's answer of 2026-11-19
([comment](https://github.com/tarides/maquizcoatl/issues/8#issuecomment-7023136027)):

- **A. Identical bytecode: (a).** Patterns are compiled by Oniguruma
  through the public `onig_new`, and the *strict tier* times only those
  whose compiled code stays inside experiment #9's opcode subset.
- **B. Ratios only.** The verdict is taken at the stack decision,
  against experiment #11's reference points: the switch-dispatch build
  (primary, since the design uses `switch`) and the direct-threaded build
  (second). Reference values are read from
  experiment #11's latest notebook entry, not hard-coded.
- **C. Native routes:** superseded by E-H.
- **D. Bench host**, pinned to a free and idle cache complex, with the
  protocol of experiments #11 and #12.

From the maintainer, 2026-11-27 (stack decision and re-scope):

- **E. Drop-in from C source without a Rust toolchain.** All Rust
  routes are out (Verus, Aeneas, hax, RefinedRust, Creusot).
- **F. OCaml library through bindings.** The generated-OCaml rows are
  dropped; issue #22 covers them.
- **G. Stack A: a staged pilot.** VST and RefinedC each prove the same
  slice, then the cheaper one finishes. Bedrock2 is the fallback.
- **H. Re-scope.** The experiment settles between stacks A and C.
- **A′. Translated tier: (ii).** A second, separately labelled tier.
  For the VMs only, `OP_PUSH_OR_JUMP_EXACT1` and `OP_PUSH_IF_PEEK_NEXT`
  are rewritten to `OP_PUSH`. Oniguruma does strictly less work per
  iteration, so the ratio is a lower bound on the VM's relative speed.
- **B′. Reference loop: (ii).** Besides `onig_match_with_param` per start
  position, two builds without the optimiser (`-DONIG_DONT_OPTIMIZE`,
  experiment #12's `onig-noopt` recipe, threaded and switch) are driven
  through `onig_search` as extra reference columns.

## Where things live

- **Workstation.** `<workdir>` is the work directory outside the
  repository; this branch's worktree is `<workdir>/wt/10-generated-code`.
  Engineering for the shared part (driver, classifier, translator,
  adapters) happens here, with a Debug build of `upstream/` out of tree
  under `<workdir>/e10/build/`. It needs only GCC, CMake and Python. No
  prover is installed on the workstation.
- **Bench host** (never named in public text). Proof development and
  checking, extraction, builds and timing all run here.
  - `<cache>` is the shared toolchain cache of earlier experiments.
    Checked on 2026-11-27, it holds:
    - the opam root, with the `provers` switch (Rocq 9.3.0), the `vst`
      switch (VST 2.17, CompCert 3.18, Rocq 9.2.0) and the `refinedc`
      switch (RefinedC `d0575839` with `coq-lithium`, Rocq 9.1.0, OCaml
      4.14.2); `provers` was installed by experiment #7, `vst` and
      `refinedc` by experiment #5;
    - the F\* 2026.11.15 binary release in `<cache>/fstar` (Pulse
      included, `krml`, and Z3 4.8.5, 4.13.3, 4.15.3 and 5.3.0 under
      `lib/fstar/`);
    - Bedrock2 `67b682a5` with coqutil `4c399b7`, built in place against
      `provers`.

    The opam root's default switch is shared and was `compcert` on that
    date, so every script names its switch explicitly
    (`opam exec --root <cache>/opam --switch <name> --`) and never runs
    `opam switch`.
  - The CompCert column uses the `ccomp` of the `vst` switch, the
    version VST's proofs target.
  - Free disk was 40 GB on 2026-11-27. `setup.sh` checks for at least
    20 GB free before building, as experiment #5's scripts did, and
    stops if less is left.
  - `<exp>` is `<bench-workdir>/exp/10-generated-code/`. It holds a
    clone of this branch with `upstream/` at `f95747b` (read only), the
    out-of-tree builds (`<exp>/build/`), the proof and route builds
    (`<exp>/routes/<route>/`) and raw outputs (`<exp>/out/<run-id>/`).
  - Nothing is installed system-wide, and nothing needs root.
- **Repository** (branch `exp/10-generated-code`), under
  `lab/10-generated-code/`:
  - `setup.sh` (clone check, the five Oniguruma builds), `pins.json`,
    `provenance.sh`;
  - `driver/`: the C driver and the common work-file reader;
  - `classify/`: the bytecode classifier and the dump-to-subset
    translator, with both tiers;
  - `vm/DESIGN.md`: the fixed VM design (step P0);
  - `routes/vst/`, `routes/refinedc/`, `routes/pulse/` (and
    `routes/bedrock2/` only if it is needed): the C VM or the Pulse
    source, its proofs, the build and check scripts, the generated C
    for Pulse (committed, with the extraction command and tool
    versions), and a thin adapter to the harness protocol;
  - `effort.tsv` and `invocations.tsv`, with experiment #9's columns;
  - `run.py`, `summarise.py`, and `brittle.sh` (adapted from experiment
    #9's);
  - `lab/notebook.md` and `lab/results/`.

Scripts take `<cache>` and `<exp>` from environment variables and never
print absolute paths, hostnames or addresses.

## Approach

### Shared part (route-free; can start at once)

1. **Inputs.** Read, without modifying them:
   - experiment #1's workloads
     (`experiments/01-pattern-inventory/workloads/data/` on `main`);
   - experiment #12's work-file format, `prep.py`, classifier and
     harness protocol (`lab/12-ffi-vs-native/`), and its `onig-noopt`
     recipe;
   - experiment #11's build recipe, dispatch probe,
     catastrophic-pattern set and baselines
     (`experiments/11-perf-baselines/` on `main`: `build.sh`, with
     `CFLAGS_E11` at line 12, `dispatch_probe.c` and `worst.sh`);
   - experiment #9's opcode subset, taken from
     `lab/09-representative-proof/FRAGMENT.md` (instruction table):
     `OP_STR_*`, `OP_PUSH`, `OP_JUMP`, `OP_FAIL`, `OP_MEM_START`,
     `OP_MEM_START_PUSH`, `OP_MEM_END`, `OP_EMPTY_CHECK_START`,
     `OP_EMPTY_CHECK_END`, `OP_END`. `OP_FINISH` is the backtrack-stack
     sentinel (`upstream/src/regexec.c:3074`), is never stored in
     `reg->ops`, and so is never seen by the classifier.

2. **Five out-of-tree Oniguruma builds**, using experiment #11's recipe
   (static, `Release`, identical flags apart from the macros named
   here):
   - `onig-threaded` (default);
   - `onig-switch` (`-DONIG_DISABLE_DIRECT_THREADING`);
   - `onig-noopt-threaded` and `onig-noopt-switch`, the same two with
     `-DONIG_DONT_OPTIMIZE` added (decision B′);
   - `onig-dump` (`Debug`, `-DONIG_DEBUG_COMPILE`), for classification
     only. It makes `onig_compile` print the compiled bytecode list
     (call site `upstream/src/regcomp.c:7636-7639`; printers
     `print_compiled_byte_code` and `onig_print_compiled_byte_code_list`,
     `upstream/src/regexec.c:510-890`).

   The dispatch style of each timing build is checked with experiment
   #11's dispatch probe and by comparing the `regexec.c.o` hashes, which
   must differ. `test_utf8` (1554 cases) is run on each build as a
   sanity check.

3. **Bytecode classifier and translator.** The C driver compiles each
   (pattern, syntax, options) triple with `onig_new` on `onig-dump`,
   captures the printed opcode list, and classifies the triple:
   - *strict*: every opcode is in the subset;
   - *translated*: every opcode is in the subset, or is
     `OP_PUSH_OR_JUMP_EXACT1` or `OP_PUSH_IF_PEEK_NEXT` (decision A′);
   - *out*: anything else, with the first offending opcode logged.

   Only the public API and the debug output are used: no internal
   symbol and no `regint.h` structure (DEV-005, from experiment #4). The
   translator turns the dump into the VM's bytecode format: jump targets
   resolved, string operands decoded, and, in the translated tier, the
   two push variants rewritten to `OP_PUSH` with the same alternative
   target. That rewrite preserves match results
   (`upstream/src/regexec.c:4333-4360`):
   - `OP_PUSH_OR_JUMP_EXACT1` enters the loop body only when the next
     byte is the body's first literal, and otherwise jumps straight to
     the exit. As a plain `OP_PUSH`, the VM enters the body anyway, fails
     at its first byte, and backtracks to the exit.
   - `OP_PUSH_IF_PEEK_NEXT` pushes the exit only when the next byte is
     the exit's first literal. As a plain `OP_PUSH`, the VM always
     pushes it, and an exit restored on any other byte fails at once.

   In both cases the VM restores more choice points than Oniguruma, so
   its retry count is higher. A translated-tier case that hits the
   retry limit on one side only is recorded as a limit difference, not
   as a disagreement, and the catastrophic analogues run in the strict
   tier only. The equal-results criterion (step T2) is the check for
   everything else.

   **The dump is parsed as bytes, not lines.**
   - `p_string` writes the operand's raw bytes
     (`upstream/src/regexec.c:456-459`), so a literal containing a
     newline splits its line.
   - `OP_STR_N` prints no length (`:556-558`).
   - Text printed before the list also holds raw bytes. `onig_compile`
     prints `PATTERN: /…/` and `OPTIONS:` (`upstream/src/regcomp.c:7504-7510`).
     The optimiser prints `optimize:` and `exact: [raw bytes]`
     (`:7226-7282`). `onig_print_names` comes before the list too
     (`upstream/src/regparse.c:970`).

   The parser anchors on the `code-length: N` line
   (`upstream/src/regexec.c:877`) and must parse exactly N `\n%4d: `
   entries, ending at the end of the dump; anything before that line is
   skipped. It takes the length of `str_1`..`str_5` from the opcode, and
   ends a `str_n` at the next `\n%4d: ` prefix carrying the expected
   index. A dump where that parse is not unique marks the triple out
   ("ambiguous dump"). Each `onig_new` writes its dump to its own
   file. The parser is unit-tested on hand-picked patterns: one per
   opcode in the subset, one per push variant, a newline-bearing literal
   and a `str_n` longer than 5 bytes.

4. **Coverage table.** For each workload (jq, PHP, VS Code, with VS Code
   also weighted by experiment #1's frequency profile) and each tier:
   - triples and calls classified, out of the total;
   - the most frequent offending opcodes;
   - a comparison with experiment #12's pattern-level subset.

   A workload whose coverage in a tier is below about 5% of calls is
   still reported, but its timing rows in that tier are labelled as not
   representative.

5. **Workloads.** Cases in each tier are written in experiment #12's
   flat format, in three shapes:
   - **short subjects**, as recorded by experiment #1;
   - **large subjects**: experiment #12's 1 MiB cuts of the OCaml source
     and the Loghub SSH log, with a find-all loop. The top 16 patterns
     per source and tier are re-picked among the classified ones with
     `pick_large.py`; if there are fewer than 16, the count is stated;
   - **catastrophic analogues**. Experiment #11's set is entirely out of
     subset, so subset-shaped analogues are used, one per family's
     syntax and options: `(a|aa)+(b|c)` and `(?:a|aa)+(?:b|c)`, on
     `"a"*n "!"` for n = 16 to 4096. They are labelled as analogues.

   **Limits.** Every call runs with a retry limit of 10,000,000 in match
   and 0 in search, on both sides, through `OnigMatchParam`. This
   overrides the limits that PHP calls recorded (the `prep.py` columns
   `retry_limit_in_match` and `match_stack_limit`), so on PHP's limit
   cases C may differ from experiment #1's expected results; those
   cases are listed.

   Retries are counted once per restored choice point
   (`CHECK_RETRY_LIMIT_IN_MATCH` after `STACK_POP`,
   `upstream/src/regexec.c:4674-4677`, macro at `:1558-1563`). The
   counter resets per `onig_match_with_param` call, that is, per start
   position.

   The VM's stack capacity is the call's recorded `match_stack_limit`
   when that is non-zero, and 2^20 entries otherwise, recorded per run. A
   -15 on either side goes in T2's limit-difference list.

6. **C reference columns.** The driver times `onig_match_with_param` at
   each start position on `onig-threaded` and `onig-switch`. It times
   `onig_search_with_param` on `onig-noopt-threaded` and
   `onig-noopt-switch` (decision B′).
   - **Per-call overhead** of `onig_match_with_param`: setup grows with
     the group count (`regexec.c:5402`, `:3265-3267`). It is measured on
     an empty pattern and on a pattern of k empty groups that fails at
     its first byte, for k = the tier's maximum group count, and
     reported as a range.
   - **Start positions** advance by the encoding's character length, as
     `search_in_range` does (`regexec.c:5921-5923`). The find-all loop
     uses experiment #12's rule (`lab/12-ffi-vs-native/bench/cdriver.c:137-141`):
     after a match `[r, fin)`, the next start is `fin` if `fin > r`,
     otherwise `r` plus one character. The VM adapters use the same two
     rules (P0's trusted list).
   - An `onig_search_with_param` column on the optimising builds is timed
     too, labelled "whole search, not comparable".

Milestone 1 is steps 1-6 alone: the coverage table and the C reference
columns. It is useful before any proof exists.

### Proof part

**P0. Fixed VM design** (`vm/DESIGN.md`, written before any proof,
identical for every route):
- C entry point `vm_match(code, ncode, strs, nstrs, subject, len, start,
  regs, nregs, stack, stack_cap, retry_limit)`. It returns:
  - the match length, as `onig_match_with_param` does
    (`upstream/src/regexec.c:5413`; experiment #9's `Match e` is
    `e - start`);
  - `ONIG_MISMATCH`;
  - `ONIGERR_RETRY_LIMIT_IN_MATCH_OVER` (-17);
  - `ONIGERR_MATCH_STACK_LIMIT_OVER` (-15).
- **Bytecode format:** an array of fixed-size operations
  `{int opcode; int a; int b;}`, indexed like `reg->ops`, with jump and
  push targets absolute, as in experiment #9. String operands live in a
  byte pool `strs`, addressed by `(offset, length)`. `decode` is the pure
  function from that array to experiment #9's `list instr`, written in
  both tools.
- One `switch` over the opcode, inside one loop.
- **Backtrack stack:** the caller-provided array `stack` of `stack_cap`
  fixed-size entries, each an alternative, a capture save or an
  empty-check start. A push that would exceed `stack_cap` entries
  returns -15, as upstream does at `match_stack_limit` entries
  (`regexec.c:1966-1970`).
- **Captures:** a mutable array of `int` pairs.
- **Integers:** machine integers, with `len` and `stack_cap` below
  `INT_MAX`.
- **Retry counter:** inside the VM, counted as upstream counts it.
- **One C source:** the pilot slice is one file, `vm/vm.c`, written in
  the intersection of the tools' subsets: one call or memory access per
  expression, and no `&&` or `||`. Before P2, the driver checks it
  against `onig-threaded` on the pilot's cases, and it is then frozen,
  with its sha256 recorded in `effort.tsv`.
  - RefinedC's copy, `routes/refinedc/vm_rc.c`, is `vm.c` plus
    `[[rc::…]]` attributes and `//@` lines. Its build checks that
    stripping them gives back `vm.c`, as step 1 of experiment #5's
    `refinedc/build.sh` does for `vu_rc.h`.
  - A pilot that must change `vm.c` records the change, and the other
    pilot re-checks on the changed file.

**Correctness statement.** It is written once in `vm/DESIGN.md` and
transcribed in Rocq (for VST, RefinedC and Bedrock2) and in F\* (for
Pulse). Take code `c` that `decode` accepts, a subject `s`,
`start <= len`, a retry limit `L` and a stack capacity `K`. If
`vm_match` returns `r`, then:
1. if `r` is neither -17 nor -15, there is a fuel `f` such that
   `vm f (decode c) nregs s start` returns:
   - `Match (start + r) regs'` when `r` is a length, where `regs'`
     reports a group only when its end is set (`regexec.c:3347-3357`);
   - `NoMatch` when `r = ONIG_MISMATCH`;
2. `r = -17` only if `retries (decode c) s start` reaches `L`. Here
   `retries` counts the backtracks of experiment #9's `run`, including
   the final pop that reaches `EFinish`: upstream runs
   `CHECK_RETRY_LIMIT_IN_MATCH` after that pop (`regexec.c:4674-4677`),
   and its test is `>=` (`:1559`);
3. `r = -15` only if some state of that run has a stack longer than
   `K`.

`rocq/Vm.v` and `fstar/Vm.fst` are under
`lab/09-representative-proof/`, and the fuel exists because experiment
#9 proved `run_mono`, `run_det` and `vm_det`. `retries` and the stack
depth are defined by recursion on the fuel beside `run`, in
`lab/10-generated-code/vm/`, as Rocq and F\* transcriptions of each
other; experiment #9's files are not edited. For code produced by
experiment #9's `compile`, its main theorem carries item 1 to the
semantics. For Oniguruma-compiled code, the proved property is items
1-3 against experiment #9's VM.

**Left to trusted code:** the translator (dump to this format), `decode`
as a definition, the work-file reader, the outer loop over start
positions, and the adapter's capture-array conventions.

**P1. Toolchain checks.** Experiment #9's Rocq files (`rocq/`) were
checked on Rocq 9.3.0. They are now checked on the `vst` switch (Rocq
9.2.0) and the `refinedc` switch (Rocq 9.1.0). Any change needed is
recorded and kept minimal; if a file cannot be ported, that is recorded
as a pilot cost. VST's `forward_switch` is checked on VST 2.17 with a
one-function `switch` probe. RefinedC's handling of `switch` is checked
with the same probe. The RefinedC probe's specification refers to a
definition of `rocq/Vm.v` compiled in the `refinedc` switch, so the
project wiring for experiment #9's files is settled before P2; VST's
probe does the same with a `funspec` that mentions `Vm.vm`.

**P2. Stack A pilot.** VST and RefinedC each prove the same slice of
the design:
- the `switch` dispatch loop;
- the array backtrack stack, with its exhaustion case;
- `OP_STR_*`, `OP_PUSH` and `OP_FAIL` (with `OP_JUMP` and `OP_END`, which
  the loop needs to run).

The pilot's statement is P0's, under the hypothesis that `decode c`
contains only `IStr`, `IPush`, `IJump`, `IFail` and `IEnd`; `regs` is
then unchanged, and the reported region is all unset. Closing the slice
means this statement is proved, with a clean axiom/admit report.

Each pilot records proof cost in experiment #9's units (sessions, failed
checks, failing invocations, proof lines and automatic share) in
`effort.tsv` and `invocations.tsv`, with source digests. It also
records trusted lines, using experiment #5's `TRUSTED` convention, and
whether `switch` was provable as written.

**Cap:** each pilot gets at most N hours of session wall-clock, summed
over its `effort.tsv` `session` rows, with N = 6 (two 3-hour runs). The
report's one third of 2-4 weeks is the scale, not the unit. A pilot
whose sessions reach N without closing the slice counts as failed, and
what remains open is recorded.

Both pilots prove the frozen `vm.c` of P0. They run one after the other,
VST first, so that each session's figures are its own; the order is
recorded as a possible bias.

**P3. Choice of the stack A tool.** The tool whose pilot closed with
fewer failed checks finishes; if those are equal, the shorter total
session time wins, and then the fewer trusted lines. (This rule is under
review: a failed check measures how often the prover is run as well as
how hard the proof is, so a slow checker scores better on it.) If both pilots
fail, Bedrock2 proves the same slice under the same cap. Its language
has no `switch`, so it dispatches with an if-chain, and that is
recorded. If Bedrock2 fails too, stack A has no C VM, and that is the
result. The choice and the rule applied are recorded before P4 starts.

**P4. Finish.**
- **Stack A:** the chosen tool proves the rest of the opcode subset
  against the full refinement statement.
- **Stack C:** a Pulse VM implements the same design and is proved
  against F\*'s `Vm.fst`, reusing experiment #9's invariants where they
  carry over. It is extracted to C twice, through KaRaMeL
  (`--codegen KrmlC`, bundled krml) and through F\*'s direct C back end
  (`--codegen C`). Both back ends start from one proof.

  The generated C is compiled with its generated header included, so
  that FStar#4932 (a dropped parameter, silent only without the header)
  shows up as a compile error.

  Every proof ends with experiment #9's axiom/admit report: `Print
  Assumptions` for Rocq, and for F\* the `--admit_smt_queries false`
  check plus the scan.

### Timing and review (per finished route)

The routes timed are:
- stack A's chosen tool, as a GCC column, plus a CompCert column for
  VST;
- Pulse through KaRaMeL;
- Pulse through the direct back end.

For each one:

- **T1. Build.** Compile with the reference's flags, `-O3 -DNDEBUG`
  (experiment #11's `CFLAGS_E11`). GCC `-O2` is only an optional extra
  column. The stack A column compiles the frozen `vm.c` (for RefinedC,
  the stripped file, byte-identical to the proved copy minus its
  annotations). The annotated RefinedC copy is also compiled with
  experiment #5's flags (`refinedc/build.sh:101-103`), untimed, to check
  that it builds. The CompCert column applies to VST only: CompCert is the
  compiler VST's end-to-end guarantee covers. It is used here for
  research and evaluation, which the INRIA non-commercial licence
  allows.
- **T2. Agreement** on every case in both tiers: return code, match span
  and all capture positions, against `onig-threaded`. Every difference is
  recorded, and goes to `spec/deviations.md` if Oniguruma is the one
  wrong.
- **T3. Dispatch inspection.** Check whether the compiler turns the
  `switch` into a jump table at the level used (disassembly), and
  whether threaded dispatch could be expressed inside the proof.
- **T4. Timed series**, interleaved with the four C reference columns in
  the same series, so ratios are same-session.
- **T5. Brittleness** (Pulse only). Experiment #9's matrix: Z3 5.3.0
  (the baseline), 4.15.3 and 4.13.3, each with the default seed and
  seeds 1-10, the rlimits as written, run with `brittle.sh` adapted from
  experiment #9's.
- **T6. Readability review.** A reader who did not write the proof
  reviews each shipped C VM against a fixed checklist:
  - do names match Oniguruma's opcodes;
  - is there one `case` per opcode;
  - are there generated temporaries, and how many;
  - how many lines and functions does it have;
  - can a crash at a given line be mapped back to the source (for
    Pulse, back to the `.fst` line): for five lines chosen by a fixed
    rule (every ⌊n/5⌋-th line of `vm_match`), the source construct each
    maps to, and the time taken;
  - which annotations are left in the source (for RefinedC);
  - which file is shipped, and whether it is byte-identical to what was
    proved, or what differs (stripped annotations, krml's rename layer,
    `custard_init_globals`).

  Findings are recorded, not scored.

### Close-out

**S. Summary.** One table across the finalists' routes, with, for each:
- proof cost (pilot and finish separately);
- trusted lines;
- coverage per tier;
- time per match and throughput (median, min/max and IQR over at least
  10 runs; the done-criterion's minimum is 5);
- ratios to the four C reference columns, the switch build first, and
  to experiment #11's baselines;
- agreement, dispatch findings, brittleness and readability findings.

It is recorded in the lab notebook and posted on issue #8 after the
maintainer's review, with no verdict.

## Tools and versions

All actively maintained (report, "active" rows). Every prover was
installed by experiments #5 and #7; nothing new is installed. Experiment
#5 installed F\* 2026.11.15 into this account's cache, because the
shared copy's `.checked` files are owner-only
(`2026-11-19-exp-05-toolchains-m1`). Pins
go in `pins.json`, and the versions actually used are recorded in the
notebook.

| Tool | Version |
|------|---------|
| Oniguruma | `f95747b` (`upstream/` submodule) |
| VST, CompCert | 2.17, 3.18 (`clightgen` prints 3.17), Rocq 9.2.0, switch `vst` |
| RefinedC | `d0575839` with `coq-lithium` at the same commit, Rocq 9.1.0, OCaml 4.14.2, switch `refinedc` |
| Bedrock2 (fallback) | `67b682a5`, coqutil `4c399b76`, Rocq 9.3.0 |
| Rocq (experiment #9's files) | 9.3.0 (`provers`), then checked on 9.2.0 and 9.1.0 (P1) |
| F\*, Pulse, KaRaMeL | 2026.11.15 (`b92b0f87`), bundled Pulse, krml `3384ecaf` |
| Z3 | 5.3.0, 4.15.3, 4.13.3, as in experiment #9 |
| GCC | Ubuntu 24.04 package (13.3.0) |
| CMake | system (3.28.3) |
| Python | 3.12, stdlib only, run with `-I` |

## Budget

- **Engineering time**, on the report's scale of 2-4 weeks per proof
  tool and 1-2 weeks per timed route:

  | Item | Weeks |
  |------|------:|
  | Stack A pilots (P2), about one week each | 2 |
  | Finishing stack A's chosen tool (P4), a tool's budget less its pilot week | 1-3 |
  | The Pulse VM (P4) | 2-4 |
  | Timing stack A, then stack C (the two back ends share one adapter) | 2-4 |
  | **Total** | **7-13** |
  | Bedrock2 fallback pilot (P3), only if both pilots fail | +1 |
  | **Total with the fallback** | **8-14** |

  P0 and P1 add a few days on top.
- **Bench host time** for builds and timing: one free and idle L3 cache
  complex chosen at the start of each run (recorded by CPU numbers
  only), with all jobs under `taskset` on that complex and at most 4
  parallel jobs. Timed runs use one core of that complex, one process
  at a time, with nothing else of this experiment running. Load average
  and other running experiments (by number) are recorded before and
  after each series, along with the governor, and each cell gets a
  warm-up pass.

| Phase | Steps | Bench time |
|-------|-------|------------|
| Clone, five Oniguruma builds, sanity tests | 2 | 25 min |
| Classification, coverage, workload preparation | 3-5 | 15 min |
| C reference columns | 6 | 15 min |
| Per timed column: build, agreement, dispatch check, timed series | T1-T4 | about 30 min each, 4 columns (3 routes, plus CompCert for VST) |
| Pulse brittleness matrix | T5 | about 33 full checks of the Pulse proof |
| Summary, redaction check, record | S | 20 min |

**Milestones:**
1. Steps 1-6: the route-free part.
2. P0-P3: the design, toolchain checks, both pilots and the choice.
3. P4: finishing both finalists.
4. T1-T6 and S.

Each milestone is recorded as it closes.

## Recorded with the lab-notebook skill

In `lab/notebook.md` (section "Experiment #10") and `lab/results/`, one
entry each, nothing overwritten:
- provenance: builds, dispatch probe, `regexec.c.o` hashes, compiler and
  toolchain versions, cache complex and protocol;
- the coverage table, for both tiers;
- the C reference columns;
- the toolchain checks (P1);
- each pilot, and the choice (P2, P3);
- each finished proof (P4);
- for each timed route: agreement, dispatch inspection, timing and
  ratios;
- the brittleness matrix;
- the readability review;
- the summary.

Deterministic re-runs are not logged twice; repeated timing series are
kept as data. The maintainer decides what is worth recording.

## Outputs

- `lab/10-generated-code/`: driver, classifier, translator, VM design,
  route sources and proofs, generated C, scripts.
- The notebook entries and result files above.
- Any match-result difference in `spec/deviations.md`, when it reveals
  an Oniguruma bug.
- A summary comment on issue #8, then a PR from this branch.

## Done-criteria (from the issue)

- **Stack A pilot:** the slice proved in VST and in RefinedC, each with its proof cost, trusted lines, `switch` verdict and a clean axiom/admit report, plus the choice of the tool to finish, with the rule applied.
- **Finished routes** (stack A's chosen tool, and Pulse through both back ends): the VM proved against experiment #9's semantics, with a clean axiom/admit report, as in experiment #9.
- **Coverage:** for each workload and each tier, the share of patterns (and of calls, where weighted) whose compiled code is timed.
- **Speed:** for each finished route and each upstream build, throughput (bytes/s) and time per match on each workload, as the median of at least 5 runs with the spread recorded, on one pinned machine with its configuration recorded.
- **Ratios:** each route's speed relative to switch-dispatch `match_at`, direct-threaded `match_at`, and the two builds without the optimiser.
- **Equal results:** every VM gives the same match results as `match_at` on all benchmark inputs (positions and captures); any difference is recorded.
- **Dispatch:** for each route, whether it can express threaded dispatch, and whether that dispatch stays inside the proof.
- **Brittleness:** Pulse's matrix, as experiment #9's (three Z3 versions × default seed + 10 seeds).
- **Readability:** one reader reviews each shipped C VM for naming, structure, and how well a crash report maps back to the source.
- **Report:** results in the lab notebook, plus a comparison table across the finalists' routes posted on issue #8 after the maintainer's review, with no pass/fail verdict.

## Risks

- **Experiment #9's Rocq files on older Rocq versions.** VST pins Rocq
  9.2.0 and RefinedC pins 9.1.0, while experiment #9 used 9.3.0. P1
  checks this first; a port cost counts against that tool's pilot.
- **`switch` not provable as written.** VST's `forward_switch` has not
  been checked at 2.17, and RefinedC's support is unknown. If a tool
  cannot prove `switch`, its pilot records that and falls back to an
  if-chain. The dispatch difference then shows up in timing (T3, T4).
- **The pilot is small.** The slice may understate the cost of the whole
  VM, and experiment #9's fragment understates the cost of the whole of
  Oniguruma: effort diverged between tools only on experiment #8's
  larger follow-up proof. The summary states this. The pilot does
  measure what imperative code adds (memory, aliasing, array bounds),
  which experiment #9 did not.
- **Pulse refinement cost.** The Pulse VM is proved against a total-F\*
  VM over lists, so the gap from arrays to lists is part of stack C's
  cost. It is counted, not avoided.
- **FStar#4932** affects both C back ends. Compiling with the generated
  header (P4) turns it into a compile error. Any workaround in the
  Pulse source is recorded.
- **Low coverage in the strict tier.** Three unconditional rewrites push
  most star patterns out of subset (`get_tree_head_literal`,
  `upstream/src/regcomp.c:3237-3314`, and `tune_next`, `:4703-4728`):
  - `OP_PUSH_OR_JUMP_EXACT1`, when the body begins with a literal;
  - `OP_PUSH_IF_PEEK_NEXT`, when the node after the loop begins with a
    literal;
  - `OP_POP` (automatic possessivation), when both do and are exclusive.

  The translated tier recovers the first two; `OP_POP` stays out.
  Coverage is a criterion in itself, and low rows are labelled.
- **Translated-tier bias.** Oniguruma does strictly less work per
  iteration than the VM in this tier, so ratios there are lower bounds,
  labelled as such. The VM's extra backtracks also raise its retry
  count, so limit outcomes can differ there (step 3).
- **`onig_match` per start position** pays per-call setup, which grows
  with the group count. It is measured as a range (step 6), and the
  builds without the optimiser give a loop without it (decision B′).
- **Debug-print parsing.** The dump format is not an API. An ambiguous
  dump marks the triple out, with the reason logged.
- **CompCert licence.** CompCert is non-commercial unless licensed from
  AbsInt. Its column here is research use. A shipped Maquizcoatl built
  with GCC keeps VST's guarantee at the level of the C source only.
- **Bench host contention.** If no cache complex is idle, the run waits.
  A series started with load above experiment #12's threshold is
  flagged.
- **Reference ratios drift between sessions** (experiment #11 saw
  3-7%), so ratios are taken within the same interleaved series only.
