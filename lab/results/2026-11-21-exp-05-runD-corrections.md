# exp-05 runD-corrections: fixes after the review of run D

## What

Corrections to the [run D entry](2026-11-21-exp-05-runD.md) of
experiment #5, after the independent review of run D on issue #13
([comment](https://github.com/tarides/maquizcoatl/issues/13#issuecomment-7062318250)).
The run D entry and its index row are kept as they are; the passages
named below are superseded by this entry. The five decision-free
problems of the review are fixed. Nothing was installed, built or run on
the bench host; the only checks are three read-only queries of upstream
repositories, whose output is in
[`2026-11-21-exp-05-runD-corrections-raw/pin-checks.txt`](2026-11-21-exp-05-runD-corrections-raw/pin-checks.txt).
No verdict, trusted-line count or done-criterion changes.

## Why

Two pins were wrong or missing (CN's Cerberus commit, RefinedRust's
commit), the floor check acts on three disk sizes the record did not
justify, and two sentences were inaccurate.

## Provenance

- Repository: `exp/05-unverified-calls`, fixes on top of `990ffc7`.
- Checks run from the local worktree on 2026-11-21 (12:06 UTC) with
  `gh` 2.104.0 (GitHub API), `git` 2.53.0 (`git ls-remote`) and the
  GitLab API of `gitlab.mpi-sws.org`. No bench host step, no disk used.

## Corrections

1. **CN's Cerberus commit** (supersedes the run D entry's Provenance
   bullet "CN: ... `cerberus-lib` from `rems-project/cerberus` master
   `e29a8ec9`", the index row's "Cerberus `e29a8ec9`" and the Analysis
   sentence "Its install will be two pins"). At the pinned CN commit
   `f2e8eeb4`, `cn.opam` has

       pin-depends: [
         ["cerberus-lib.dev" "git+https://github.com/rems-project/cerberus.git#a0f7071"]
       ]

   Cerberus `a0f7071dbfe0d3a204d7a6257b8de8bc4b0a202a` is dated
   2026-11-13; master `e29a8ec9` is 28 commits ahead of it. `a0f7071` is
   the commit CN's own build uses, and an `opam pin` of the CN checkout
   applies that `pin-depends` itself. CN's Cerberus commit is therefore
   `a0f7071`, and the install will be one pin (the CN checkout), with no
   separate `cerberus-lib` pin. Updated: `pins.json`
   (`cn.cerberus_commit`, new `cerberus_commit_date` and
   `cerberus_note`, `repository_note`), the CN row of `table.md`, and
   the plan section "Deviations found during run D".
2. **RefinedRust's commit** (supersedes the runC-corrections entry's
   "RefinedRust's commit not pinned: work for the next run"). `git
   ls-remote` gives `main` = `HEAD` =
   `2862b1d8044919d22330a9c8d5778fef85a47936`, committed 2026-11-16
   (GitLab API). Pinned in `pins.json` (`commit`, `commit_date`,
   `commit_note`); the top-level note's "Empty commit fields belong to
   installs not written yet (RefinedRust)" and the table's "commit not
   pinned yet" are gone. The install is still not written.
3. **Disk sizes of the milestone 4 tools** (supersedes the run D
   entry's "The estimates come from the measured sizes of the `hax`
   switch (2.2 GB) and the `vst` switch, and from RefinedRust's
   estimate"). They are guesses, not measurements, and each is replaced
   by the `du -sL` of the install once it runs. What each adds up from
   (now in each `disk_note`):

   | Tool | `disk_gb` | Basis |
   |---|---|---|
   | Bedrock2 | 3 | the source with three submodules (size not measured) and the compiled coqutil and bedrock2 theories on Rocq 9.3; the only compiled Rocq library measured so far is the `vst` switch (1.2-1.3 GB); the compiler and kami are not built |
   | CN | 3 | an opam switch on OCaml 5.4.1 with `cn` and `cerberus-lib` (about 2 GB, by analogy with the `hax` switch, 2.2 GB measured on the same OCaml) plus Z3 or cvc5 (about 1 GB, not measured) |
   | RefinedC | 5 | an opam switch on Coq 9.1.0 with Iris, std++, Lithium and RefinedC (about 4 GB, as RefinedRust's switch, itself an estimate) plus its own `cerberus-lib` at `f11e6b3` (about 1 GB, not measured) |

   The 35 GB total of the pending rows (25 GB without hax Lean) is
   therefore partly guessed.
4. **CPU rule** (supersedes the run D entry's "CPUs 20-23,52-55
   (outside 28-31 and 60-63)"). The rule is: outside 4-7, 36-39, 28-31
   and 60-63. The set used, 20-23,52-55, is outside all four, so no
   step ran on a reserved CPU.
5. **hax F\* row of `table.md`** (run C's `1e78df4`): "the F\* hax pins
   was refused" now reads "the F\* that hax pins was refused".

## Open

Unchanged by these fixes: the disk floor (options a-d), the 6.2 GB of
removals, keeping the hax Rocq verdict final at v0.5.0, whether to run
hax Lean (10 GB), and from run B the upstream F\* report (issue #29)
and the Isabelle-LLVM model client.
