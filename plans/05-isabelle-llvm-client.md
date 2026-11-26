# Plan: experiment #5 follow-up, Isabelle-LLVM model of the `caller.c` client

Issue: https://github.com/tarides/maquizcoatl/issues/30 (the issue body
is the reference for scope, decisions and done-criteria; this plan says
how).
Parent: experiment #5, issue #13, plan `plans/05-unverified-calls.md`,
merged in PR #21; files on `main` under `experiments/05-unverified-calls/`,
results `lab/results/2026-11-*-exp-05-*`.
Source: maintainer's state-of-the-art report, section "Experiments before
deciding", row 5: https://claude.ai/artifact/8w6PVuiTsLCKpugpCowMHc

## Objective

Close, as far as a proof can, the gap that run B of experiment #5 left in
the Isabelle-LLVM prototype: `vu_fold_all_composed`
(`isabelle-llvm/VU.thy:374`) rests on the client contract
`respects_i_apply` (`VU.thy:349-356`), and nothing shows that the client
in `caller/caller.c` meets it. Write an Isabelle model of `caller.c`'s two
apply-all clients and prove that each meets the contract, as Aeneas's
`tableClient_respects` does (`aeneas/proofs/Proofs.lean:204`). Then
reword the trusted entry (it stays trusted: the model is a hand-written
restatement of C that nothing checks) and update experiment #5's
`table.md`.

All paths below are relative to `experiments/05-unverified-calls/` unless
they start with `lab/`, `plans/` or `docs/`.

## Decisions folded in

From the issue's Decisions section (maintainer, 2026-11-26, each the
recommended option of the review,
https://github.com/tarides/maquizcoatl/issues/30#issuecomment-7192949435):

1. **Contract shape: (a), restate.** `VU.thy` gets a definition
   `respects_at ai apply_all rc`: today's body of `respects_i_apply`,
   with `vu_i_apply` replaced by the parameter `ai` and
   `vu_call_apply_all g` by the parameter `apply_all`. `respects_i_apply
   g rc` becomes `respects_at vu_i_apply (vu_call_apply_all g) rc`.
   `vu_fold_all_composed` keeps its statement; its proof unfolds both
   definitions. The client lemmas are proved for every `ai`.
2. **Trusted line: (a), kept and reworded.** The entry in
   `isabelle-llvm/TRUSTED` stays, its comment reworded as Aeneas's
   (`aeneas/TRUSTED:22-27`: "Assumed of the C client, checked nowhere
   (... shows a model of caller.c's client meets it)"). The table's
   callee-assumption and re-entrancy (a) columns get Aeneas's wording.
   The count is not changed by hand; see "Open point" below.
3. **Scope: (a), both clients.** The table walker `client_apply_all`
   (`caller/caller.c:293-303`) and `client_apply_all_stop`
   (`caller/caller.c:305-309`).

### Open point (raised on issue #30, not decided here)

The review expected the trusted count to stay 108 because the range
"moves, its content and count do not". With decision 1 the contract is
spread over two definitions: `respects_at` (laid out line for line as
today's 8 counted lines, `VU.thy:349-356`) and the new one-line
definition of `respects_i_apply`, which is what ties the contract to
`vu_i_apply` and to the shim. Counting that line too gives 109;
leaving it out (by analogy with Aeneas, whose instantiation
`Respects ApplyAllInst g` sits in the hypothesis of `fold_all_rec_ok`
and is not counted) keeps 108. This plan does not choose: the question
is put on issue #30 with the label `needs-decision`. The proof work does
not depend on it; only the TRUSTED range and the count in `table.md` do.
Both candidate TRUSTED entries are written now ("Updates to the
record"), so that after the answer the change is a one-line edit.
Whatever the answer, the number written is the output of
`./count-trusted.sh isabelle-llvm`, never a hand computation.

## The model and the lemmas

A new theory `isabelle-llvm/VU_Client.thy`, `imports VU`, added to the
`theories` of `isabelle-llvm/ROOT` (`theories VU VU_Client`). `VU.thy`
changes only for decision 1, so `export_llvm` (`VU.thy:541`) still
writes the same `vu.ll`: `abi.expected` and steps 3-4 of `build.sh` are
unchanged. The model is higher-order in the apply function and is never
exported (`export_llvm` has no function-pointer type, `VU.thy:4-7`).

Types are those of `VU.thy`: the apply function has the type of
`vu_i_apply` (`VU.thy:271`), `32 word ⇒ 32 word ptr ⇒ 32 word ⇒
fold_rec ptr ⇒ 32 word llM`; `from` and `to_len` are `32 word`
(`to_len = -1` of `caller.c:282` is the word `-1`).

- **`fold_table`**: the 13 `(from, to_len)` pairs of `caller.c:275-289`,
  as a HOL list constant, in the C order.
- **`table_client ai to tbl rc`**: a `fun` in `llM`, by recursion on the
  list, after Aeneas's `walk` (`Proofs.lean:192-200`): `[]` returns 0; on
  `(fr, tl) # t` it binds `ai fr to tl rc` and returns the result when it
  is non-zero (`caller.c:299-300`), recurses on `t` otherwise. The list
  is a HOL value: no `partial_function (M)`, no `llc_while`, no
  termination argument. HOL `if` on the result is used (the theory is
  not exported); `llc_if` and `ll_icmp_eq` are the fallback if the VCG
  handles them better.
- **`stop_client ai to rc`**: binds `ai 0x41 to 1 rc`, ignores its
  result and returns `-7` (`caller.c:305-309`).
- **Not modelled**, as in Aeneas: the content of `to` (the model takes
  any pointer `to`, passed unchanged; `vu_i_apply` never reads it,
  `VU.thy:298`, and the contract quantifies over every `to`), the
  `memcpy` into the stack array, and the counter `apply_all_calls`
  (`caller.c:291,294`), which is client-private state.

Lemmas (names fixed now so that the results can cite them):

1. `table_client_respects`: `respects_at ai (table_client ai to tbl) rc`
   for every `ai`, `to`, `tbl`, `rc`. Proof: unfold `respects_at`, fix
   `P` and its hypothesis, then induction on `tbl` generalising the
   record value `r`; the hypothesis on `ai`, restated as a rule with
   `P r` as premise and `↑(P r)` folded into the precondition, is a
   `vcg_rules` fact, as `vu_fold_all_correct` uses its own
   (`VU.thy:329-339`). `Nil` is one `vcg'`; `Cons` is `vcg'` with the
   induction hypothesis as a further `vcg_rules` fact and a split on the
   `if`.
2. `stop_client_respects`: same statement for `stop_client`, one
   `vcg'`.
3. Instances at `vu_i_apply`, the form the contract takes in
   `vu_fold_all_composed`: `table_client_rec_wf` and
   `stop_client_rec_wf`, the `rec_wf` preservation triples for
   `table_client vu_i_apply to fold_table rc` and
   `stop_client vu_i_apply to rc`, derived from lemmas 1-2 and
   `vu_i_apply_rec_wf` (`VU.thy:360-369`). They show the restated
   contract is usable on the model, not only provable.

### Sanity check (untimed, not a negative control)

The new lemmas must not be vacuous. During development, once, a copy of
`VU_Client.thy` whose walker also writes the record directly
(`ll_store` of a fixed value into `rc` before calling `ai`) must make
`table_client_respects` fail. It is a one-off check on the untimed CPUs,
recorded in the results (outcome and failing lemma), not added to
`run.sh` or `build.sh`: the issue keeps the two existing controls only.

## Harness changes

- **`isabelle-llvm/build.sh`**, step 1 copies `ROOT` and `VU.thy` only:
  it also copies `VU_Client.thy` into `$src`, and the proof-escape check
  (`sorry`, `axiomatization`, `oracle`, `quick_and_dirty`,
  `skip_proofs`) also reads `VU_Client.thy`. The negative controls edit
  `VU.thy` only, as today. With a rejected `VU`, `VU_Client` is not
  checked, but Isabelle reports it as an error of its own,
  `Failed to load theory "VU.VU_Client" (unresolved "VU.VU")`
  (`src/Pure/Build/build.ML`, `join_parents`), which reaches
  `errors.log`. As `build.sh` stands, that head lands in `others`
  (`build.sh:99-109`), the build exits 1 instead of
  `VU_PROOF_REJECTED`, and `run.sh:175-177` records `control=error`.
  So the `others` filter (`build.sh:102-103`) also drops heads matching
  `^\*\*\* Failed to load theory .* \(unresolved `: such a head only
  follows another error. The requirement that at least one failed-proof
  head exists is kept: the test becomes `[ -n "$proofs" ] && [ -z
  "$others" ]`, with `proofs` the failed-proof heads, so a build whose
  only heads are unresolved-theory ones is still an error (exit 1).
  The rename's TRUSTED range moves by the lines added. Phase 3 ends
  with one `-n` and one `-r` development run that check this before the
  recorded run.
- **`isabelle-llvm/TRUSTED`**: the line range of the symbol rename,
  `build.sh:138-143`, moves by the lines added above (same 6 lines, same
  content); the contract's range moves with decision 1; its comment is
  reworded (decision 2). Both ranges are checked by reading them, then
  by `count-trusted.sh`.
- `run.sh` is unchanged: its `sources()` already hashes every file of
  the tool directory, so `VU_Client.thy` is tied to the run in
  `build.log`.

## Tools and versions

Checked read-only in the shared cache on the bench host on 2026-11-26;
nothing is installed or upgraded:

| Component | Version | Where |
| --- | --- | --- |
| Isabelle | Isabelle2026 (`isabelle version`) | `<cache>/isabelle/dist/Isabelle2026`, `<cache>/isabelle/bin/isabelle` |
| AFP | `afp-2026-11-19` | `<cache>/isabelle/afp-2026-11-19` |
| Isabelle-LLVM | `e42f478118988ff38676ff01215be26f3018f015` (branch `2026`, 2026-10-19) | `<cache>/isabelle/isabelle_llvm`, checked out at that commit |
| `Isabelle_LLVM` heap | built in experiment #5 (with `Refine_Monadic`, `Automatic_Refinement`) | `<cache>/isabelle/home` (`ISABELLE_HOME_USER`) |
| clang/LLVM | 23.1.5 | `<cache>/llvm/23.1.5` |
| C compiler | system `cc`, as in experiment #5 | |

The upstream branch `2026` of Isabelle-LLVM has moved since
(`9b6b3c0`, 2026-11-25); it is not fetched. The record names
`e42f4781`. `build.sh` prints the versions at the head of every
`build.log` (step "versions"), so the recorded run carries them.

opam is not used by this plan.

## Where things live

- **Bench host.** `<bench-workdir>/cache/` (written `<cache>`), read only.
  The `VU` session's build writes its log (and its small heap) under
  `ISABELLE_HOME_USER` in `<cache>/isabelle/home`, as runs A and B did;
  that is a build product, not an install. `<bench-workdir>/exp/05-isabelle-llvm-client/`
  (written `<exp>`, `VU_EXP`): a clone of the branch at `<exp>/repo`
  (`upstream/` not needed and not initialised), build directories
  `<exp>/build/<run-id>/` and outputs `<exp>/out/<run-id>/`, written by
  `run.sh`.
- **Workstation.** The branch's worktree under `<workdir>/wt/`; no
  Isabelle is installed locally, so every check is a session build on
  the bench host. Raw outputs are copied back to `<workdir>/tmp/` before
  selection.
- **Repository**, branch `exp/05-isabelle-llvm-client`:
  `experiments/05-unverified-calls/isabelle-llvm/` (`VU.thy`,
  `VU_Client.thy`, `ROOT`, `build.sh`, `TRUSTED`),
  `experiments/05-unverified-calls/table.md`, `docs/experiments.md`
  (row of issue #30: stage "pipeline"), `lab/notebook.md` (section
  "Experiment #5") and `lab/results/`.

## Method

### Development loop (untimed)

Each proof round trip: commit on the branch, push, `git -C <exp>/repo
pull --ff-only` on the bench host, then

    VU_EXP=<exp> VU_CACHE=<cache> VU_CPUS=20-23,52-55 VU_JOBS=4 \
      <exp>/repo/experiments/05-unverified-calls/run.sh isabelle-llvm dev-<n>

(about one minute: a clean `isabelle build -c` of `VU`, 42 s in run B,
`out/runB/isabelle-llvm/result.txt`, plus the new theory, clang and the
link). The proof errors are read from `errors.log` in the build
directory. Development outputs (`dev-<n>`) are not recorded, except the
number of round trips. At the end of phase 3, after the last normal
`dev-<n>` run passes, one `run.sh -n isabelle-llvm dev-<n>` and one
`run.sh -r isabelle-llvm dev-<n>` (same run ID, same CPUs, about two
minutes) check that both controls end with `VU_PROOF_REJECTED` now
that `VU_Client` is in `ROOT`; the development loop otherwise runs
normal builds only. CPUs 20-23,52-55: outside 28-31,60-63 and outside
`lib.sh`'s reserved `4-7,36-39`; `run.sh` refuses the set if another
process is pinned there (`vu_check_cpus`).

### Recorded run (timed set)

From a fresh `git pull` of the final commit, with run ID `i30-run1`:

    VU_CPUS=24-27,56-59 VU_JOBS=4 run.sh    isabelle-llvm i30-run1
    VU_CPUS=24-27,56-59 VU_JOBS=4 run.sh -n isabelle-llvm i30-run1
    VU_CPUS=24-27,56-59 VU_JOBS=4 run.sh -r isabelle-llvm i30-run1

(`VU_EXP` and `VU_CACHE` as above). `run.sh` runs each build under
`nice -n 10 taskset -c 24-27,56-59`, `timeout` 1200 s (default; no
`ulimit -v` for Isabelle-LLVM, `run.sh:146`), and `/usr/bin/time -v`.
Expected: the normal run builds, links with `caller.c` and prints
`caller/expected.txt` (`caller_output=same`); both controls end with
`VU_PROOF_REJECTED` (status 3) on the same lemmas as in run B
(`VU.thy:127` for `-n`; for `-r`, the lemma of run B's `VU.thy:526`,
whose line moves with the restatement: the results name the new line).
Before and
after the three builds: load average, and `ps -eLo user,psr,pcpu,comm`
restricted to the timed set, recorded. Then, locally on the committed
tree, `./count-trusted.sh isabelle-llvm` and `./count-trusted.sh aeneas`
(the latter unchanged at 122, as a check of the tool).

## Measurements and lab-notebook recording

Recorded in `lab/results/<date>-exp-05-isabelle-client.md` with its raw
directory `lab/results/<date>-exp-05-isabelle-client-raw/` (redacted by
`lib.sh`, checked for host, user and home names before commit), and one
row in `lab/notebook.md`, section "Experiment #5":

- the repository commit, the run ID, the commands, the machine (CPU
  model, `nproc`, CPUs used, load before and after);
- the raw `build.log`, `build.time` and `result.txt` of the normal run
  and of both controls (proofs accepted; controls rejected and on which
  lemma);
- the "generated vu.ll" line of the normal run's `build.log`: its
  sha256 must equal run B's,
  `0a963ae345731c4765236ab15030e8d144fd35e62a5c423b7894d27fbf0148cb`
  (`lab/results/2026-11-21-exp-05-runB-raw/isabelle-llvm/build.log`),
  next to the ABI diff, as the check that the export is unchanged;
- the controls' failing lines: `-n` at `VU.thy:127`, `-r` at the new
  line of run B's `VU.thy:526` lemma (named, not only "the same
  lemmas");
- `build_seconds` against run B's 42 s on CPUs 20-23,52-55 (not a
  like-for-like comparison: different CPU set; stated as such);
- size of the work: counted lines of `VU_Client.thy` (`count-trusted.sh`'s
  comment rule, by hand-listing the file in a scratch TRUSTED copy, not
  committed) and the `VU.thy` diff (`git diff --stat`);
- effort: number of development round trips, hands-on time, and the
  proof-method changes that a round trip needed (for example `if` versus
  `llc_if`);
- the sanity check's outcome;
- the output of `count-trusted.sh isabelle-llvm` (and `aeneas`).

## Runs (launched one by one by the maintainer)

**Run 1** (at most 4 hours of wall clock; expected under one hour):

| Phase | CPUs | Worst case |
| --- | --- | --- |
| 1. `df` check, clone of the branch in `<exp>` | none | 0:05 |
| 2. `VU.thy` restatement (decision 1); `vu_fold_all_composed` builds unchanged | 20-23,52-55 | 0:20 |
| 3. `VU_Client.thy`, lemmas 1-3, `build.sh` and `ROOT` changes, sanity check; one `-n` and one `-r` dev run | 20-23,52-55 | 2:30 |
| 4. Recorded run: normal, `-n`, `-r` | 24-27,56-59 | 0:10 |
| 5. Copy back, count, results and notebook row; `TRUSTED` and `table.md` if the open point is answered | local | 0:30 |

At 3:30 a proof still failing stops the run where it is: the results
record it as interrupted (lemmas proved, the failing goal, round trips,
hands-on time), and a second run of at most 4 hours continues it, ending
with the recorded run. If the open point is not answered at the end of
run 1, `TRUSTED` and `table.md` are written after the answer, with no
bench-host run (the count is local).

**Disk.** 41 GB free on the bench host on 2026-11-26; floor 20 GB. The
run writes a clone of the repository without `upstream/` (under
100 MB) and a few build directories of a few MB each: budget 1 GB.
`df` is checked at the start of the run; the run stops as blocked if
free space is below 21 GB.

## Updates to the record

After the recorded run (and, for the count, the answer to the open
point):

- `isabelle-llvm/TRUSTED`: the contract's new range and reworded comment;
  the rename range of `build.sh`. Both candidate entries are written
  here now, so that phase 5 is a one-line edit whichever way the open
  point goes. Same comment text for both:

      # Contract of the client's apply_all_case_fold (hypothesis of
      # vu_fold_all_composed): assumed of the C client, checked nowhere
      # (table_client_respects and stop_client_respects in VU_Client.thy
      # show that models of both of caller.c's apply-all clients meet
      # it). The client reaches the record only through the vu_i_apply
      # it is given, so it preserves every property that vu_i_apply
      # preserves.

  followed by, for answer (b), 108: the `respects_at` range alone,

      VU.thy:<respects_at, 8 lines>

  and for answer (a), 109: that range plus the one-line definition of
  `respects_i_apply`,

      VU.thy:<respects_at, 8 lines>
      VU.thy:<respects_i_apply definition line>

  The placeholders become the line numbers of the final `VU.thy`, read
  in the file and then checked by `count-trusted.sh`.
- `table.md`, Isabelle-LLVM row: trusted count (from
  `count-trusted.sh`), and the breakdown in its parenthesis "(C shim 8
  and its declaration 7, callee hypotheses and their predicates 20,
  hand-written ABI mapping 67, symbol rename 6)" following it, each
  figure taken from `count-trusted.sh`'s per-range lines: callee
  hypotheses and predicates 21 under answer (a), 20 under (b);
  callee-assumption column ending "... for (a),
  reaches the record only through the `vu_i_apply` it is given; models
  of both of `caller.c`'s apply-all clients meet it"; re-entrancy (a)
  column: "... proved under a client contract (`respects_i_apply`),
  composed with `vu_i_apply_correct` in `vu_fold_all_composed`; models
  of both of `caller.c`'s apply-all clients meet it", as Aeneas's row
  says of its Lean model. The "Last update" paragraph gets a new head
  sentence for this follow-up (issue #30, the results entry); the
  earlier paragraphs stay.
- `docs/experiments.md`: the row of issue #30 says "pipeline" and has
  PR #41 in its PR column, as the other follow-up rows with a PR (done in
  this plan's PR, since the work has started).
- The Bedrock2 row also states its contract as `respects_i_apply` "as
  Isabelle-LLVM"; it has no client model and is not changed (out of
  scope of issue #30).

## Done-criteria mapping

| Done when (issue #30, as amended by decision 2) | Where it is met |
| --- | --- |
| The lemma is checked by the `VU` session build of `run.sh isabelle-llvm` on the bench host, proofs accepted, `-n` and read controls still rejected | Recorded run `i30-run1` (phase 4): `result.txt` of the normal run and of both controls |
| A `lab/results/<date>-exp-05-<name>.md` records the raw `build.log` and `build.time`, with one `lab/notebook.md` row | `<date>-exp-05-isabelle-client.md` and its raw directory; one row in section "Experiment #5" |
| `table.md`: Isabelle-LLVM row (trusted count; callee-assumption and re-entrancy (a) columns) and its "Last update" paragraph updated | "Updates to the record" above; count from `count-trusted.sh` once the open point is answered |
| `isabelle-llvm/TRUSTED` changed as decision 2 settles: line kept, comment reworded | "Updates to the record" above |

## Steps

1. This plan, the `docs/experiments.md` stage; issue #30 moves to
   `stage:plan`; the open point is put on the issue.
2. Run 1 (phases 1-5), launched by the maintainer.
3. Results entry, notebook row, `TRUSTED` and `table.md`; results comment
   on issue #30.

## Risks

- **VCG and HOL `if`** (confirmed behaviour, no longer a risk). HOL
  `if` is a VCG decomposition rule in Isabelle-LLVM `e42f4781`:
  `wpa_ifI[vcg_decomp_rules]` (`thys/vcg/Sep_Generic_Wp.thy:357-360`),
  with `if_split` removed from the normaliser's splits
  (`thys/lib/Basic_VCG.thy:152`). The fallback stays: `llc_if`
  (`thys/basic/kernel/LLVM_Shallow.thy:612`, `llc_if_simp` in
  `vcg_normalize_simps`, `thys/vcg/LLVM_Shallow_RS.thy:898`) with
  `ll_icmp_eq` in the model.
- **Hypothesis shape.** The contract's hypothesis on `ai` has `P r`
  outside the precondition; `vcg'` needs it as a rule with a pure
  precondition. A local restatement lemma (one consequence rule, as `vu_i_apply_rec_wf` uses `cons_post_rule`) is planned;
  if the frame inference still fails, the `Cons` step is done by hand.
  Bind is handled by the normaliser's `wp_bind[vcg_normalize_simps]`
  (`thys/vcg/Sep_Generic_Wp.thy:87`); the manual fallback is single
  steps with `vcg_step'` (`thys/lib/Basic_VCG.thy:594`) and
  `cons_post_rule` (`Sep_Generic_Wp.thy:450`, already used at
  `VU.thy:365`). Cost: more round trips, not a change of method.
- **Generalisation.** The induction must generalise the record value
  `r` (and `P`'s witness), as Aeneas's `generalizing rec`; forgetting it
  gives an unprovable `Cons` goal, recognisable on the first round trip.
- **Restating `respects_i_apply` breaks `vu_fold_all_composed`'s
  `blast`.** Fixed by unfolding `respects_at_def` with
  `respects_i_apply_def`; phase 2 checks it before any client work.
- **No local Isabelle.** Each round trip is about a minute on the bench
  host; a long proof search is bounded by `run.sh`'s 1200 s timeout.
- **Shared bench host.** A pinned process on a planned CPU set makes
  `run.sh` refuse it; the recorded run then waits, and development moves
  to another set outside 28-31,60-63 and 4-7,36-39, said in the results.
- **The open point stays unanswered.** The proof work and the recorded
  run do not depend on it; only `TRUSTED`'s range and the count do, and
  they wait.

_Drafted by Claude Code (Opus 5.5) as part of the experiment pipeline._
