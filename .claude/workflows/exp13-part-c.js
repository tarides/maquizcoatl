export const meta = {
  name: 'exp13-part-c',
  whenToUse: 'Experiment #13 Part C batch; pass args {repo, work} (absolute paths)',
  description: 'Experiment #13: review+commit mining tool, recorded Part C run, classification, Part A driver, synthesis',
  phases: [
    { title: 'Review', detail: 'context-free review of upgrade_mining, then fixes and commits' },
    { title: 'Run', detail: 'recorded Part C run into lab/results' },
    { title: 'Classify', detail: 'one agent per project + Part A driver' },
    { title: 'Synthesis', detail: 'commits, issue comment, dashboard, session log, push' },
    { title: 'Gate', detail: 'check CPU-set answer for Part A' },
  ],
}

// args: { repo: absolute path of the maquizcoatl checkout,
//         work: absolute path of the experiment's work directory (clones, logs) }
if (!args || !args.repo || !args.work) throw new Error('args.repo and args.work are required')
const REPO = args.repo
const EXP = `${REPO}/experiments/13-upgrade-cost`
const WORK = args.work
const CTX = `Repository: ${REPO}, branch exp/13-upgrade-cost (do not switch branches). Experiment #13 "upgrade cost", issue https://github.com/tarides/maquizcoatl/issues/3, draft PR https://github.com/tarides/maquizcoatl/pull/20. Plan: ${REPO}/plans/13-upgrade-cost.md. Handoff note from the previous session (read it first, it is the authoritative state): ${EXP}/HANDOFF.md. Work directory outside the repo: ${WORK} (clones in ${WORK}/clones). The OCaml tool lives in ${EXP}/mining; build/test it with \`opam exec --switch 5.4.0 -- dune ...\` from that directory. Never touch upstream/ and never stage the untracked file prompt-initial. Never use \`git add -A\`; stage explicit paths. Do not push unless your task says so. You cannot ask the user questions: if something needs a human decision, say so in your output instead of guessing.`

// ---------- Phase 1: review + fix + commits
phase('Review')
const review = await agent(
  `You are a code reviewer with no prior context. Review the OCaml project in ${EXP}/mining (library src/, executable bin/, tests test/). It mines git histories of verified projects for prover-version bumps (see "Part C" in ${REPO}/plans/13-upgrade-cost.md for what it must do, and the "Decisions taken along the way" section of ${EXP}/HANDOFF.md for intended deviations from the plan). Look for: correctness bugs (version parsing, bump detection, grouping, numstat filtering, release spans, commit-to-release mapping), swallowed errors, unhandled git failures, missing or wrong .mli docs, code duplication, non-idiomatic OCaml, missing tests for a feature. Run \`opam exec --switch 5.4.0 -- dune build @check\` and \`dune test\` to confirm the baseline. Do not modify any file. Return a numbered list of findings, each with file:line, severity (bug / quality / nit), the concrete failure scenario, and a suggested fix. Do not report style preferences that ocamlformat handles.`,
  { label: 'review:upgrade_mining', phase: 'Review' })

const fixes = await agent(
  `${CTX}

A context-free code review of ${EXP}/mining produced these findings:

${review}

Tasks:
1. Fix every finding of severity bug or quality that is real (check each one; skip and explain any you judge wrong). Add or update tests where a bug is fixed. Keep .mli docs up to date.
2. \`opam exec --switch 5.4.0 -- dune build @check\`, \`dune test\` and \`dune fmt\` must pass in ${EXP}/mining.
3. Update ${REPO}/plans/13-upgrade-cost.md for the deviations listed in HANDOFF.md "Decisions taken along the way" (project configurations are typed OCaml values in mining/src/projects.ml, dune-project is not a Rocq pin file, the stricter grouping rule, keyword rows without pin values, AFP author alignment caveat). Short, factual wording; no em dashes.
4. Make exactly three commits on exp/13-upgrade-cost, in this order, each staging explicit paths only:
   a. "Release lists for experiment #13" : experiments/13-upgrade-cost/releases/ (message body: the commands used to fetch them, from HANDOFF.md).
   b. "Add upgrade_mining for experiment #13 (Part C)" : experiments/13-upgrade-cost/mining/ (source, tests, dune files, .gitignore, .ocamlformat; never _build).
   c. "Plan #13: record deviations from the first implementation" : plans/13-upgrade-cost.md.
   Do NOT commit HANDOFF.md. Commit messages: short, plain English, end with a blank line then "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>".
Return: the list of findings with what you did for each (fixed / skipped + reason), the three commit hashes, and the test count.`,
  { label: 'fix+commit', phase: 'Review' })

// ---------- Phase 2: recorded run
phase('Run')
const run = await agent(
  `${CTX}

Do the recorded Part C run (step 2 of "Remaining, per the plan" in HANDOFF.md).
1. Look at the lab notebook format used by other experiments: \`git show origin/exp/11-perf-baselines:lab/notebook.md\` and \`git show origin/exp/01-pattern-inventory:lab/notebook.md\`. This branch has no lab/ yet: create ${REPO}/lab/notebook.md in the same format (only #13 entries) and ${REPO}/lab/results/.
2. Run upgrade_mining on all projects with --until 2026-11-19, output into ${REPO}/lab/results/ (file names 2026-11-19-exp-13-<project>-bumps.csv, -per-release.csv, -mining-summary.md). Keep the run log in ${WORK}/logs/.
3. Write the notebook entry: repository commit (git rev-parse HEAD), exact command, machine (CPU model, nproc, load before/after), clones' revisions (commit at D for each project, AFP mirror refs), window, configuration (mining/src/projects.ml), and the limits listed in the plan's "What Part C cannot measure".
4. Do not commit.
Return: list of result files with their row counts, and a JSON-like list of the rows that need manual classification per the plan (every bump row > 100 changed lines or > 10 files, every keyword/pattern-selected row, every non-empty snapshot row), grouped by project, with commit/unit id and size.`,
  { label: 'part-c-run', phase: 'Run' })

// ---------- Phase 3: classification in parallel with the driver
phase('Classify')
const GROUPS = [
  { key: 'rocq', files: 'warblre and linden', note: 'Rocq projects; includes pattern-selected rows (Rocq 9 migration: Warblre a5a3120, Linden 4312028).' },
  { key: 'lean-regex', files: 'lean-regex', note: 'Known large bumps: e2e33d6, 153ed60, e1600a1, cdfe4c8. Separate Lean adaptation from mathlib-driven changes and unrelated refactors.' },
  { key: 'everparse-cbor', files: 'everparse-cbor', note: 'F* pins; most rows are 0 lines under the restricted paths. Note that EverParse is maintained by the F* team.' },
  { key: 'creusot', files: 'creusot', note: 'Why3 development-commit pins later released in 1.9.0. The creusot clone has no working tree; use git show / git diff on objects.' },
  { key: 'anvil', files: 'anvil', note: 'Verus; bumps and keyword rows in the unpinned periods. Large: a65d68c, 0cd9f9f ("Migrate to cargo verus"), aa757c8.' },
  { key: 'afp', files: 'afp-regex', note: 'Isabelle AFP snapshot rows. Also check the author/period misalignment noted in HANDOFF.md (Formula_Derivatives) and either fix the attribution in the CSV or document it.' },
  { key: 'why3-gallery', files: 'why3-gallery', note: 'One snapshot row 1.8.2..1.9.0 of 735 files. Decompose it (per example directory and by file type: why3session.xml / .mlw / other; new examples vs changed existing ones), write the decomposition as an extra CSV 2026-11-19-exp-13-why3-gallery-decomposition.csv, and classify the changes to pre-existing examples. If a meaningful adaptation figure cannot be extracted, say why.' },
]

const classifyThunks = GROUPS.map(g => () => agent(
  `${CTX}

Manual classification for experiment #13, Part C, project(s): ${g.files}. ${g.note}

The recorded run wrote its CSVs in ${REPO}/lab/results/ (2026-11-19-exp-13-<project>-bumps.csv). The run agent reported these rows to classify (all projects; handle only yours):
${run}

For each row of your project(s) that the plan's "Manual classification" section requires (bump rows > 100 changed lines or > 10 files, every pattern/keyword-selected row, every non-empty snapshot row), read the actual diff in the clone under ${WORK}/clones (git show / git diff restricted to the configured paths) and fill the \`class\` column: adaptation, mixed (with an estimated adaptation share and the reason), or unrelated. Add or fill a short \`reason\` column if the CSV has one; if it does not, add \`adaptation_share\` and \`reason\` columns consistently to your project's CSV only. Edit only your project's files in lab/results/ (and the extra file named above, if any). Do not touch lab/notebook.md, do not run dune, do not commit.
Return: per row: id, class, share, one-line reason; then a 3-5 sentence summary of the observed adaptation cost per tool release for your project(s), with numbers.`,
  { label: `classify:${g.key}`, phase: 'Classify' }))

const driverThunk = () => agent(
  `${CTX}

Write the Part A driver \`upgrade_builds\` described in the plan ("Part A: builds" and "Where things live"): a second executable in ${EXP}/mining (reuse the existing library where it makes sense, new modules each with a documented .mli). It installs the toolchains (opam switches for Rocq 9.2.0/9.3.0, elan toolchains for Lean v4.34.0-rc1/v4.36.0 with mathlib cache, F* v2026.10.25/v2026.11.15 with Pulse examples of v2026.10.25, Why3 1.8.2/1.9.0 with provers), runs each project's build/check with a given -j, CPU set (taskset), nice and timeout, times it, and writes build rows (CSV 2026-11-19-exp-13-builds.csv) and logs. Commands must be built as argument lists, never through a shell string with interpolated values. Configuration (CPU set, -j, workdir) comes from the command line (cmdliner if available in switch 5.4.0, else Stdlib Arg; stay consistent with bin/upgrade_mining.ml). Test command construction and result parsing on fixtures in the alcotest suite; the builds themselves are never run by dune test. DO NOT run any build, install any toolchain, or connect to the bench host.
Another agent may be reading lab/results/ meanwhile; you only touch ${EXP}/mining. When done: \`opam exec --switch 5.4.0 -- dune build @check\`, \`dune test\`, \`dune fmt\` pass. Do not commit.
Return: files added/changed, CLI synopsis, test count, and anything you could not decide.`,
  { label: 'driver:upgrade_builds', phase: 'Classify' })

const [driver, ...classified] = await parallel([driverThunk, ...classifyThunks])

const driverReview = await agent(
  `You are a code reviewer with no prior context. Review the uncommitted changes in ${EXP}/mining (\`git -C ${REPO} diff\` and untracked files under that directory): a new executable upgrade_builds that will drive builds of verified projects on a shared bench host. Look for correctness bugs, shell-injection risks, swallowed errors, missing .mli docs, duplication with the existing library, untested features. Do not modify files. Return a numbered list of findings with file:line, severity, failure scenario, suggested fix.`,
  { label: 'review:upgrade_builds', phase: 'Classify' })

// ---------- Phase 4: synthesis
phase('Synthesis')
const synth = await agent(
  `${CTX}

Finish this batch of experiment #13 work.

Driver author's report:
${driver}

Context-free review of the driver:
${driverReview}

Classification reports (per project):
${classified.map((c, i) => `--- ${GROUPS[i].key}\n${c ?? '(agent failed: classification missing for this group; record it as pending)'}`).join('\n')}

Tasks:
1. Fix the real bug/quality findings of the driver review; dune build @check, dune test, dune fmt pass in ${EXP}/mining.
2. Check the classified CSVs in ${REPO}/lab/results/ for consistency (same columns across projects, every required row has a class). Add a classification entry to ${REPO}/lab/notebook.md (who/what classified, decisions, summary per tool with numbers, Why3 gallery decomposition, limits). Write ${REPO}/lab/results/2026-11-19-exp-13-part-c-summary.md: one line per tool on the observed per-release adaptation cost (Rocq, Lean, F*, Why3 incl. Creusot, Verus, Isabelle), stating clearly that Part A is still to come.
3. Commits (explicit paths, short plain-English messages ending with "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"), in order:
   a. "Experiment #13: Part C run and classification": lab/notebook.md, lab/results/ files of exp 13.
   b. "Add upgrade_builds, the Part A driver for experiment #13": experiments/13-upgrade-cost/mining/.
   Do not commit HANDOFF.md.
4. Post a comment on issue #3 (gh issue comment) with the Part C results: short, plain, friendly English, the summary table, links to the result files on the branch (https://github.com/tarides/maquizcoatl/blob/exp/13-upgrade-cost/...), and what remains (Part A, waiting for the CPU set on the bench host). No em dashes.
5. Append a dated entry (2026-11-19) to docs/session-log.md: #13 handed over from an interactive session to a background workflow; Part C done. Public-content redaction: no local paths, no private names other than those already in the log. Commit it as "Session log: experiment #13 Part C done" (this file only).
6. Update the dashboard row: artifact https://claude.ai/artifact/75qJzdKrn8cdFWmYAh72VG, collection data/team/experiments, document e13. Use the ArtifactData tool (load it with ToolSearch "select:ArtifactData"); read the document first, then "update" it keeping its schema: note = Part C done + link to the issue comment, pending question = CPU set for Part A, updated = current UTC time (from \`date -u +%FT%TZ\`). Stage stays "run".
7. \`git push origin exp/13-upgrade-cost\` (branch already exists on origin; plain push, never --force).
Return: commit hashes, the issue comment URL, dashboard update result, push result, and anything left undone.`,
  { label: 'synthesis', phase: 'Synthesis' })

// ---------- Phase 5: gate for Part A
phase('Gate')
const gate = await agent(
  `${CTX}

Check whether the CPU set for Part A on the bench host has been agreed: read the comments of PR #20 and issue #3 (gh pr view 20 --comments; gh issue view 3 --comments) after the plan was posted. 
- If a maintainer (Cuihtlauac) answered with a CPU set: return it verbatim with the comment URL. Change nothing.
- If not: add label needs-decision to issue #3 (gh issue edit 3 --add-label needs-decision), and make sure the dashboard document e13 (artifact https://claude.ai/artifact/75qJzdKrn8cdFWmYAh72VG, collection data/team/experiments, ArtifactData tool via ToolSearch "select:ArtifactData") has the pending question "Which CPUs of the bench host may Part A use (-j8, nice)?" and its labels include needs-decision if the schema has labels. Read before updating.
Return: answered (yes/no), CPU set if any, actions taken.`,
  { label: 'gate:cpu-set', phase: 'Gate' })

return { review, fixes, run, driver, driverReview, classified, synth, gate }