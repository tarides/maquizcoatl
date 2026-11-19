# Plan: experiment #6, executable spec speed

Issue: [#1](https://github.com/tarides/maquizcoatl/issues/1) (the issue
body is the reference for scope, inputs, measurement protocol and
done-criteria; this plan says how).
Source: maintainer's state-of-the-art report, "Experiments before
deciding", row of experiment #6, and stacks A to G in "Option matrix and
open questions" (https://claude.ai/artifact/8w6PVuiTsLCKpugpCowMHc).

## Objective

Write an executable semantics of a matching subset of Oniguruma
`f95747b` in each prover still standing after experiments #4 and #5,
plus a plain OCaml reference interpreter (stack G); run each on the
upstream test cases inside the subset, check agreement with the C
library, and measure throughput in every execution mode the tool
offers. From the throughput, extrapolate the wall-clock time of 10⁶
differential cases and judge it against the 8-hour, one-core bar. Along
the way, record each prover's spec build time `T_spec` with experiment
#7's protocol and settle experiment #7's provisional table verdicts.

## Decisions folded in

From the maintainer's
[comment](https://github.com/tarides/maquizcoatl/issues/1#issuecomment-7022328211):

1. **Fast enough: (b).** 10⁶ cases in at most 8 hours on one core, that
   is at least 34.7 cases/s, single-threaded, measured end to end (parse
   plus search per case).
2. **Subset: experiment #9's subset first, then S2.** Milestone 1 uses
   experiment #9's fragment: concatenation, alternation, star, capture
   groups, character classes; UTF-8; Oniguruma syntax
   (`ONIG_SYNTAX_ONIGURUMA`); forward search. Milestone 2 extends the
   same semantics to S2 of experiment #1
   (`lab/results/2026-11-19-exp-01-compile-and-classify.md`), if time
   allows.
3. **Stack G included.** A plain OCaml reference interpreter is the
   seventh row. It reuses the parser and subset classifier of
   experiment #12's VM (`lab/12-ffi-vs-native/vm/vm.ml`), restricted to
   the milestone's subset.
4. **Requirement from experiment #7.** `T_spec` per prover and per
   extraction target, check, extraction and compile reported
   separately, median of three clean runs, load average recorded per
   run, same tool versions and host as experiment #7; comparable load
   or both rerun idle (see Machine budget); a new notebook entry
   settles experiment #7's verdicts.

## Gate: execution waits for experiment #5

Nothing in steps 4 onwards runs until experiment #5 (issue #13, owned
by Vincent Balat) has reported and experiment #4 (issue #7) has
finished its last mechanism. Their results say which of stacks A to F
are still standing; only those provers get a row. Stack G stands in
any case. Steps 1-3 (case extraction, C reference, stack G) do not
depend on the gate and may run before it, since they need no prover.

## Where things live

- **Bench host** (all timed runs). `<bench-workdir>/cache/` (written
  `<cache>`) is experiment #7's shared toolchain cache: opam root with
  switch `provers` (OCaml 5.4.1, Rocq 9.3.0, Why3 1.9.0, Alt-Ergo
  2.6.5), F\* 2026.11.15 binary release with Z3 and `krml`, elan with
  Lean 4.36.0, and `<cache>/env.sh`. Every command runs through
  `env.sh`. `<bench-workdir>/exp/06-spec-speed/` (written `<exp>`):
  a clone of the branch with `upstream/` at `f95747b` (read only),
  the out-of-tree C build (`<exp>/build/onig/`), per-tool build
  directories (`<exp>/build/<tool>/`), and raw outputs
  (`<exp>/out/<run-id>/`).
- **Workstation.** `<workdir>` is the work directory outside the
  repository; the branch's worktree is under `<workdir>/wt/`. Raw
  outputs are copied back to `<workdir>/e06/out/` before selection.
- **Repository** (branch `exp/06-spec-speed`), `lab/06-spec-speed/`:
  - `cases/extract.py`: per-suite extractor of the seven suites;
    `cases/classify` (OCaml, from experiment #12's parser): marks each
    case in or out of the milestone's subset, with the reason;
  - `oracle/` (C): runs each in-subset case through the library and
    times it (reference results and C throughput);
  - `g/` (stack G), `rocq/`, `lean/`, `why3/`, `fstar/` (and
    `verus/`, `isabelle/` if those stacks stand): the semantics, a
    generated module holding the cases for in-prover evaluation, and a
    driver for the extracted or compiled code;
  - `timed.sh` (adapted from experiment #7's `timed.sh`: lock,
    `taskset`, `/usr/bin/time -v`, `uptime` per run), `provenance.sh`,
    `summarise.py`, `pins.json`;
  - build output is gitignored (`_build`, `.lake`, `target`, caches).
  Generated case modules are not committed (reproducible from
  `extract.py`); their sizes and sha256 are recorded.

Scripts take `<cache>` and `<exp>` from environment variables and never
print absolute paths, hostnames or addresses into their output.

## Tools and versions

All actively maintained, and identical to experiment #7's so that
`T_spec` and `T_table` are comparable (versions from
`lab/results/2026-11-19-exp-07-toolchains.md`):

| Tool | Version | Role |
|------|---------|------|
| OCaml | 5.4.1, switch `provers` | stack G, extracted OCaml, drivers |
| Rocq | rocq-core 9.3.0, rocq-stdlib 9.2.0, rocq-native | spec; `vm_compute`, `native_compute`, extraction |
| Lean 4 | 4.36.0 (elan 4.4.0) | spec; `#eval`, native via `lake build` |
| Why3 | 1.9.0 (Alt-Ergo 2.6.5) | spec; `why3 execute`, `why3 extract -D ocaml64` |
| F\* | 2026.11.15 (Z3 5.3.0) | spec; `--codegen OCaml` (Custard) |
| GCC, CMake | 13.3.0, 3.28.3 (system) | C library and oracle |
| Python | 3.12 (system, stdlib, `-I`) | extraction, summaries |

Verus and Isabelle/HOL: only if still standing after experiment #5;
their latest releases on the day are then pinned in `pins.json` and
installed into `<cache>` (follow-up, see Machine budget). If a pinned
version above has been superseded when the run starts, the pin is kept
for comparability with experiment #7 and the newer release is noted.

## Approach

1. **Case extraction** (workstation, no timing). Extend experiment
   #12's `select_tests.py` into `extract.py` covering the seven suites:
   macro and function forms, `test_options`' options argument,
   `test_back`'s backward direction, `testc`'s EUC-JP and `testcu`'s
   UTF-16BE bytes, `test_syntax`'s global `Syntax` tracked through its
   helper functions, `test_regset` emitted as regset cases. One line per
   case: suite, line, kind, encoding, syntax, options, direction,
   pattern and subject in hex, expected values. The total is checked
   against 4,565, and per suite against the counts in the issue.
2. **Classification** (workstation). `classify` runs experiment #12's
   strict parser, narrowed to experiment #9's subset, on each case;
   anything with another encoding, syntax, options or direction, or a
   construct outside the subset (`+`, `?`, intervals, anchors,
   non-capturing groups, lookaround, backreferences, properties, and
   so on), is out, with the reason. Output: the in-subset case file
   and a table of out-of-subset reasons. Informational only: how many
   more cases `+`, `?` and `(?:...)` would add.
3. **C reference and stack G** (bench host, before the gate).
   Out-of-tree Release build of `upstream/`, `test_utf8` as a sanity
   check. `oracle/` runs every in-subset case, records the C result
   (region, group region, no match, or error code) and times the set
   (C throughput). Stack G: a reference interpreter in direct style
   (backtracking in priority order: greedy star, left alternative
   first; captures with the last iteration kept; Oniguruma's
   empty-iteration rule as found by experiment #2; explicit fuel set
   to the C retry limit of 10,000,000), compiled with `ocamlopt`, run
   on the cases, agreement counted per kind (done-criterion 2), and
   timed with parse and search separated.
4. **Prover semantics** (session work, after the gate). For each
   standing prover, transcribe stack G's definitions: the regex AST,
   character classes as sorted range lists, the interpreter with
   explicit fuel, no type indices or proof terms in executable
   definitions. The parser is not re-specified in the prover for
   milestone 1: cases are fed as ASTs produced by stack G's parser
   (printed by `classify`), so the measured time is search time, and
   the parse time of stack G and of the extracted code is reported
   separately. Line counts per file (done-criterion 1).
5. **Agreement** (done-criterion 2). Each extracted or compiled
   artefact reads the case file and prints one verdict per case;
   `summarise.py` compares with the C oracle and counts `x2`, `x3`,
   `n`, `e` separately, plus out-of-subset cases. Every disagreement
   is either fixed in the spec, or logged as a deviation with its
   reason (in the deviation log started by experiments #2 and #3, not
   a per-experiment one).
6. **In-prover throughput** (done-criterion 3, in-prover modes). A
   generated module holds the in-subset cases as a list and a fold that
   returns the number of agreements; timed as the evaluation command
   minus an import-only baseline (experiment #7's Q0 method): Rocq
   `Eval vm_compute` and `Eval native_compute`, Lean `#eval`, Why3
   `why3 execute` (with a raised `--rac-timelimit`), F\* not applicable
   (extracted only). Isabelle `value`, if standing. Each mode is
   capped at 20 minutes; a mode that times out is recorded with the
   number of cases reached.
7. **Extracted and compiled throughput** (done-criterion 3). Rocq
   `Extraction` to OCaml (`ExtrOcamlNativeString`, `ExtrOcamlZInt`,
   as in experiment #7), Lean `lake build` native executable, Why3
   `why3 extract -D ocaml64`, F\* `--codegen OCaml` with `Prims.ml`
   compiled in the switch (experiment #7's method), stack G `ocamlopt`
   (and Verus compiled Rust, Isabelle `export_code`, if standing).
   Each driver loops over the case set enough times for one run to
   last at least 10 s, single-threaded; median of three runs; cases/s,
   and parse and search separately where visible.
8. **Extrapolation and verdict** (done-criterion 4). 10⁶ / (cases/s)
   per tool and mode, compared with 28,800 s; verdict "fast enough" if
   at most 8 h. The C library's figure from step 3 is the reference
   point; experiments #11 and #12 figures are quoted for context.
9. **`T_spec`** (done-criterion 5). For each prover and extraction
   target, clean build, check, extraction and compile timed
   separately with `/usr/bin/time -v` (wall-clock, peak RSS), median of
   three, `uptime` before each run, through experiment #7's `timed.sh`
   method (serialised by a lock, pinned with `taskset`). The case module
   is excluded: `T_spec` is the semantics alone. Experiment #7's C
   targets (Why3 C, F\* KaRaMeL and direct C) have no spec counterpart
   if the semantics does not extract to C (lists, unbounded integers);
   the verdict entry then compares them with the same tool's spec
   check time plus its OCaml-target time, and says so.
10. **Load comparability.** Experiment #7's timings were taken at a
    1-minute load average of 41.7-45.2. If the load at step 9 lies in
    a comparable band (32-55), the `T_spec` figures are compared with
    experiment #7's directly. Otherwise, when the host is idle (load
    below 8), experiment #7's `timed.sh` is rerun for its targets in
    the same session, and both sets are compared at idle; the rerun is
    recorded with experiment #7's scripts and commit.
11. **Settle experiment #7** (new notebook entry). Per tool and
    target, `T_table` against `T_spec`: in-prover if `T_table <=
    T_spec`, else unverified runtime data checked by the generator.
    The entry states that `T_spec` is milestone 1's (the smallest
    subset), so the verdicts are revisited at milestone 2.
12. **Fetch back and report.** `rsync` raw outputs to
    `<workdir>/e06/out/`, redaction check (paths, hostnames,
    addresses), copy the files that back notebook entries into
    `lab/results/`, commit, push, open the PR, post the comparison
    table on issue #1 and a pointer to the settled verdicts on issue
    #11.
13. **Milestone 2 (S2), if time allows.** Extend stack G's parser
    acceptance and interpreter to S2 (named groups, lookaround, atomic
    groups and possessive quantifiers, bounded repetition, Unicode
    properties, case folding, backreferences; Oniguruma, Perl_NG and
    Ruby syntaxes), then each prover's semantics; rerun steps 2-9 on
    the S2 cases. Unicode properties and case folding reuse the table
    representations chosen in experiment #7.

## Machine budget

Bench host, shared with other experiments. At most 4 parallel jobs,
never on CPUs pinned by another experiment (checked with `lscpu -e`
and the other plans at run time). Timed runs (throughput and `T_spec`)
run one at a time, pinned with `taskset` to one L3 complex kept for
timing, with the load average recorded per run. At most 3 hours of
wall-clock for one run of the pipeline (steps 3 and 5-12); session time
spent writing the semantics (step 4) is engineering effort, recorded
per tool, not machine time.

**Milestone 1** (fits in 3 hours of machine time): experiment #9's
subset; stack G and the standing provers among those already in
`<cache>` (Rocq, Lean 4, Why3, F\*); done-criteria 1-5. Expected
schedule:

| Phase | Steps | Time |
|-------|-------|------|
| C build, oracle, stack G | 3 | 15 min |
| Agreement, all tools | 5 | 15 min |
| In-prover throughput (serial, 20 min cap each) | 6 | 60 min |
| Extracted throughput (serial) | 7 | 30 min |
| `T_spec` (serial) and, if needed, experiment #7's idle rerun | 9-10 | 45 min |
| Fetch, summarise | 8, 11, 12 | 15 min |

**Follow-up**, outside this budget: Verus and Isabelle/HOL rows if
those stacks stand after experiment #5 (toolchain install plus their
own run); milestone 2 (S2); throughput on the S2 cases and re-settling
experiment #7's verdicts with milestone 2's `T_spec`.

## Lab notebook

With the lab-notebook skill: `lab/notebook.md` (index, one line per
recorded run) and `lab/results/<date>-exp-06-<topic>.md`
(append-only), raw data beside it under
`lab/results/<date>-exp-06-raw/`. Planned entries:

1. `provenance`: host (CPU model, kernel), tool versions, pinning,
   commits.
2. `cases`: extraction counts per suite, in-subset counts per kind,
   out-of-subset reasons.
3. `agreement`: per tool, the four counts and every deviation.
4. `throughput`: per tool and mode, cases/s (median of three, load
   average per run), parse and search split, C reference, the 10⁶
   extrapolation and verdicts.
5. `t-spec`: per prover and target, check, extraction and compile
   times and peak RSS, line counts.
6. `exp-07-verdicts-settled` (named
   `<date>-exp-07-verdicts-settled.md`): experiment #7's verdicts
   settled against `T_spec`, with the load comparison or idle rerun.

Exploratory runs are recorded only inside the entry they explain. The
maintainer decides on any further entry.

## Outputs

- `lab/06-spec-speed/` (extractor, classifier, oracle, stack G,
  per-prover semantics and drivers, scripts, pins).
- The notebook entries above.
- A comparison table on issue #1 and the settled verdicts linked from
  issue #11.

## Done-criteria (from the issue)

For each surviving tool and for stack G:

1. A semantics of the chosen subset, with its line count, committed under the experiment branch.
2. The number of upstream cases in the subset, and how many the spec passes, or a deviation is logged with its reason. Agreement is defined per case kind:
   - `x2`: the group 0 region equals the C library's;
   - `x3`: the region of group `mem` equals the C library's;
   - `n`: no match;
   - `e`: the spec rejects the pattern; whether the error code also matches the C library's is reported separately.

   The four counts are reported separately, plus the count of cases outside the subset.
3. Measured throughput in cases per second, in each execution mode the tool offers, on a stated machine (hardware and OS recorded in the lab notebook):
   - Rocq: `vm_compute` / `native_compute`, and extracted OCaml;
   - Lean 4: `#eval`, and `lake` native build;
   - Isabelle/HOL: `value`, and `export_code`;
   - Why3: `execute`, and extracted OCaml;
   - F\*: extracted OCaml;
   - Verus: compiled Rust (spec fns are ghost, so only compiled exec code is measurable). The proof that the exec fns refine the spec fns is not required here; it belongs to experiment #9;
   - stack G: native OCaml (`ocamlopt`).
4. An extrapolated wall-clock time for 10⁶ differential cases, and a verdict against Decision 1: fast enough if 10⁶ cases take at most 8 hours on one core (at least about 35 cases/s). The extrapolation assumes fuzz cases of size comparable to the upstream cases. Compile (parse) and search throughput are reported separately where the tool makes the split visible.
5. For each prover and extraction target, `T_spec` = check + extraction + compile time of the spec (each reported separately, median of 3 clean runs, load average per run), with experiment #7's protocol and tool versions; and a new notebook entry that settles experiment #7's provisional verdicts (in-prover if `T_table <= T_spec`), stating which milestone's spec the `T_spec` comes from.

Milestone 1 meets criteria 1-5 on experiment #9's subset; milestone 2 repeats criteria 1-4 (and updates criterion 5) on S2.

Results recorded in the lab notebook; a summary comment on issue #1 compares the tools.

## Risks

- **Gate.** Experiment #5 has an open decision; the prover rows wait
  for it. Steps 1-3 proceed meanwhile, so stack G and the C reference
  are ready when the gate opens.
- **Small subset, few cases.** Experiment #12 found 531 of
  `test_utf8`'s cases in its regular subset; experiment #9's narrower
  fragment (no `+`, `?`, anchors, non-capturing groups) may leave a
  few hundred or fewer, and the other suites add little (other
  encodings, syntaxes, directions). Throughput is still measurable by
  looping; the case count is reported as a limit, and the informational
  count of step 2 shows what desugaring would add.
- **In-prover evaluation is slow.** Why3 `execute` spent 2 minutes and
  14 GB loading experiment #7's table; a case list may behave alike.
  The 20-minute cap bounds it, and a timeout is a result.
- **`T_spec` is small for milestone 1.** A fragment this size will
  likely build in seconds, so most of experiment #7's verdicts would
  come out "unverified runtime data". The settled entry says the
  `T_spec` is milestone 1's and the verdicts are revisited with S2.
- **Load not comparable.** If the bench host is neither at experiment
  #7's load nor idle when step 9 runs, `T_spec` is recorded but the
  settling entry waits for an idle window (both rerun), rather than
  comparing figures taken at different loads.
- **No C extraction of the spec.** See step 9: the comparison basis for
  experiment #7's C targets is stated explicitly.
- **OCaml 5.4.1 and `fstar.lib`.** As in experiment #7, extracted F\*
  code is compiled with `Prims.ml` in the switch; anything needing more
  of `fstar.lib` needs a 5.3.0 switch, recorded if it happens.
- **Stack G copying the VM.** Reusing experiment #12's parser is
  allowed; the interpreter is written as a semantics so that agreement
  with the VM is evidence, not tautology.
- **Leaking host details.** Raw outputs pass a redaction check before
  they are committed; the host is named only as the bench host.
