# exp-05 isabelle-client: models of `caller.c`'s clients meet the Isabelle-LLVM contract

## What

Run 1 of the follow-up of experiment #5 tracked by issue #30 (plan
`plans/05-isabelle-llvm-client.md`, PR #41), with the maintainer's
decisions 1-4 of 2026-11-26 on issue #30.

- **The client contract is restated** (decision 1): `VU.thy` defines
  `respects_at ai apply_all rc` (the former body of `respects_i_apply`,
  with `vu_i_apply` and `vu_call_apply_all g` as parameters) and
  `respects_i_apply g rc ⟷ respects_at vu_i_apply (vu_call_apply_all g) rc`
  on one line. `vu_fold_all_composed` keeps its statement; its proof
  unfolds both definitions. `vu.ll` is byte for byte run B's.
- **Models of both apply-all clients of `caller.c` meet it**
  (decision 3): the new theory `isabelle-llvm/VU_Client.thy` proves
  `table_client_respects` (the table walker `client_apply_all`,
  `caller.c:293-303`, after Aeneas's `walk`) and `stop_client_respects`
  (`client_apply_all_stop`, `caller.c:305-309`) for every apply
  function, and their instances at `vu_i_apply`,
  `table_client_rec_wf` and `stop_client_rec_wf`.
- **Recorded run `i30-run1`**: proofs accepted, link with `caller.c`
  and output equal to `expected.txt`; both negative controls still
  rejected, on the same lemmas as in run B.
- **Trusted lines: 109** (`count-trusted.sh isabelle-llvm`), was 108:
  the contract stays trusted, reworded as Aeneas's (decision 2), and
  its count includes the new one-line definition of `respects_i_apply`
  (decision 4).

Raw data (redacted by `run.sh`: `<exp>`; checked for the host name,
user names, home paths, addresses and other accounts' services before
commit) in
[`2026-11-26-exp-05-isabelle-client-raw/`](2026-11-26-exp-05-isabelle-client-raw/).

## Why

Run B of experiment #5 proved Isabelle-LLVM's composition of shape (a),
`vu_fold_all_composed`, under the client contract `respects_i_apply`,
but nothing showed that the client in `caller.c` meets it, while Aeneas
showed it of a Lean model (`tableClient_respects`,
`aeneas/proofs/Proofs.lean:204`). The old contract was stated on the
shim constant `vu_call_apply_all`, which has no definition, so no model
could satisfy it as written: hence the restatement.

## Provenance

- Repository: branch `exp/05-isabelle-llvm-client` at `1bad306` for
  the recorded run (`commit:` line of `i30-run1.console`; the
  `build.log` files hash every harness source read). This entry and the
  `table.md` update are in a later commit; neither changes a file the
  run reads.
- Bench host: AMD EPYC 7502P (32 cores, `nproc` 64), Ubuntu 24.04.5
  LTS, Linux 6.8.0-100-generic. Recorded run 13:53:55-13:56:15 UTC
  (140 s for the three builds); load average 2.35 / 1.97 / 1.11 before,
  2.20 / 2.03 / 1.25 after; before and after, no thread with more than
  0.5 % CPU on 24-27,56-59 (`i30-run1.console`); 41 GB free before and
  after (floor 20 GB, plan threshold 21 GB).
- CPU sets: development, sanity check and development controls on
  20-23,52-55; recorded run on 24-27,56-59 (issue #34 had no timed check
  there: no process pinned to the set, checked before the launch);
  `run.sh` runs each build under `nice -n 10 taskset`. 28-31,60-63 and
  `lib.sh`'s reserved 4-7,36-39 not used.
- Tools (from the head of each `build.log`): Isabelle2026, AFP
  `afp-2026-11-19`, Isabelle-LLVM `e42f478118988ff38676ff01215be26f3018f015`,
  clang 23.1.5, cc 13.3.0 (Ubuntu 13.3.0-6ubuntu2~24.04.1). Nothing
  installed or upgraded; the cached `Isabelle_LLVM` heap of experiment
  #5 is used.
- `VU_CACHE` is `<cache>/exp05-view`, experiment #5's view of the
  shared cache (its `env.sh` puts Isabelle and LLVM on the `PATH`), not
  `<cache>` itself as the plan wrote: `<cache>/env.sh` is now written
  for later experiments and has no Isabelle on its `PATH`, which made
  the first development build stop at `isabelle: command not found`
  (status 127). Same toolchain, as the version lines show.
- Run driver: `i30-run1.sh` (raw directory); development driver
  `i30-dev.sh`.
- Run 1 started 13:42 UTC (labels to `stage:run`), bench-host clone
  13:46 UTC, recorded run 13:53-13:56 UTC.

## Commands

On the bench host, `<exp>` = `<bench-workdir>/exp/05-isabelle-llvm-client`,
from `<exp>/repo` after `git pull --ff-only` (`i30-run1.sh`):

```
VU_EXP=<exp> VU_CACHE=<cache>/exp05-view VU_CPUS=24-27,56-59 VU_JOBS=4 \
  run.sh    isabelle-llvm i30-run1
  run.sh -n isabelle-llvm i30-run1
  run.sh -r isabelle-llvm i30-run1
```

Locally, on the committed tree: `./count-trusted.sh isabelle-llvm` and
`./count-trusted.sh aeneas` (`count-trusted.tsv`).

## Results

### Recorded run `i30-run1`

| Build | `result.txt` | `build_seconds` | wall (`build.time`) | max RSS | Failing line |
|---|---|---|---|---|---|
| normal | `build_status=0`, `link=ok`, `caller_status=0`, `caller_output=same` | 42 | 0:41.48 | 3.78 GB | |
| `-n` (clamp removed) | `build_status=3`, `control=rejected` | 48 | 0:47.30 | 4.03 GB | `VU.thy:127`, `vu_char_len_correct` (`by`), as run B |
| `-r` (read bound removed) | `build_status=3`, `control=rejected` | 47 | 0:46.89 | 4.05 GB | `done` at line 531 of the control's `VU.thy` (`vu_get_subject_byte_correct`, lemma at its line 515), run B's line 526; line 536 of the committed `VU.thy`, whose control copy is 5 lines shorter (the READ block, 7 lines, becomes 2) |

- `Finished VU (0:00:24 elapsed time, 0:00:41 cpu time, factor 1.70)`,
  as run B's 24 s: `VU_Client` adds no visible session time.
- `build_seconds` 42, as run B's 42 s on 20-23,52-55 (different CPU
  set: not a like-for-like comparison).
- **Export unchanged**: "generated vu.ll: 709 lines, 33824 bytes,
  sha256 `0a963ae345731c4765236ab15030e8d144fd35e62a5c423b7894d27fbf0148cb`",
  equal to run B's (`2026-11-21-exp-05-runB-raw/isabelle-llvm/build.log`);
  "abi: vu.ll declares and defines what abi.expected lists", "layout:
  same".
- Each control's `build.log` ends with "proof rejected: 1 failed
  proof(s), no other error".

### The model and the lemmas (`VU_Client.thy`)

- `fold_table`: the 13 `(from, to_len)` pairs of `caller.c:275-289`
  (`to_len` -1 as the word -1).
- `table_client ai to tbl rc`: a `fun` on the list (no termination
  argument needed beyond the list); binds `ai fr to n rc`, returns a
  non-zero result, recurses otherwise; `[]` returns 0. HOL `if`, handled
  by the VCG (`wpa_ifI`), so the `llc_if` fallback was not needed.
- `stop_client ai to rc`: binds `ai 0x41 to 1 rc`, returns -7.
- Not modelled, as Aeneas: the contents of `to`, the `memcpy`, the
  counter `apply_all_calls`.
- Lemmas: `htriple_pre_pureI` (helper: a pure fact moved from the
  hypothesis into the precondition, the form `vcg'` uses),
  `table_client_rule` (induction on the table, generalising the record
  value; the hypothesis on `ai` and the induction hypothesis are
  `vcg_rules`), `stop_client_rule` (one `vcg'`),
  `table_client_respects`, `stop_client_respects` (for every `ai`, `to`,
  `tbl`, `rc`), `vu_i_apply_rec_wf_all`, `table_client_rec_wf`,
  `stop_client_rec_wf` (instances at `vu_i_apply`, `fold_table`, and
  `rec_wf`: the hypothesis of `vu_fold_all_correct`).
- Proof-escape check (`build.sh`, now also reading `VU_Client.thy`):
  "proof escapes: none".

### Sanity check (not a negative control)

A copy of the harness on the bench host whose walker first stores a
fixed record (`ll_store (0, 9, 0, ..., 0) rc`) before calling `ai`
(`sanity.txt`, one line added): the build is rejected with status 3,
"Failed to finish proof" at line 79 of the copy, the `by vcg'` of the
`Cons` case of `table_client_rule` (line 78 of the committed file), on
which `table_client_respects` rests. So the lemma is not vacuous: a
client that writes the record directly does not meet the contract.
Not added to `run.sh` or `build.sh`.

### Harness

- `build.sh` copies `VU_Client.thy` and reads it in the proof-escape
  check; its error classification also drops a head
  `*** Failed to load theory ... (unresolved ...)` and requires at least
  one failed-proof head (`proofs`), as the review of PR #41 asked.
  Observed: in Isabelle2026 neither control's session error log
  (`build_log -H Error`) nor `build.log` contains such a head when `VU`
  fails (0 matches of "unresolved" or "Failed to load" in the three
  `build.log`s), so the new filter did not fire; the controls are
  classified as rejected either way, and the filter stays as a guard.
- `ROOT`: `theories VU VU_Client`. `run.sh` unchanged.

### Trusted lines (`count-trusted.tsv`)

| Range | Lines | Group |
|---|---|---|
| `shim.c` | 8 | C shim |
| `VU.thy:93-100` | 7 | its declaration |
| `VU.thy:127-128`, `207-209`, `51-52`, `61-65` | 2 + 3 + 2 + 5 | callee hypotheses and predicates |
| `VU.thy:352-359` (`respects_at`) | 8 | callee hypotheses and predicates |
| `VU.thy:361-361` (`respects_i_apply`) | 1 | callee hypotheses and predicates |
| `abi.expected`, `layout.c:18-78` | 10 + 57 | hand-written ABI mapping |
| `build.sh:146-151` (was `138-143`) | 6 | symbol rename |
| **Total** | **109** | (C shim 8 and its declaration 7, callee hypotheses and their predicates 21, ABI mapping 67, rename 6) |

Aeneas: 122, unchanged (check of the tool). A one-line range is written
`361-361`: `count-trusted.sh` refuses `VU.thy:361` ("bad range").

### Size of the work

- `VU_Client.thy`: 131 lines, 105 counted (`count-trusted.sh`'s
  comment rule, through a scratch `TRUSTED` listing the whole file, not
  committed; `count-vu-client.tsv`).
- `VU.thy`: 11 insertions, 6 deletions (`git diff --numstat` against
  `main`). `build.sh`: 17 insertions, 9 deletions (comments included).

## Effort

- Hands-on time: about 15 minutes from the start of the run (13:42 UTC)
  to the end of the recorded run (13:56 UTC), plus the write-up.
- Development round trips (each a clean session build, about 45 s):
  - `dev-1`: harness only, `isabelle: command not found` (the
    `VU_CACHE` view, see Provenance); no proof checked;
  - `dev-2`: `VU.thy` accepted (the restatement and
    `vu_fold_all_composed`'s new `unfolding`, phase 2); in
    `VU_Client.thy` one failure, the `Nil` case of `table_client_rule`:
    the VCG splits the existential record of the postcondition into its
    ten fields and could not match the unsplit record `r` of the
    precondition. Fix: split `r` first (`obtain ... by (metis
    surj_pair)`, as `vu_i_apply_correct` does);
  - `dev-3`: everything accepted, linked, output equal.
  Then the sanity check and one `-n` and one `-r` development control
  (both rejected). Three proof-related builds in all; no change of
  proof method (HOL `if` kept, no `llc_if` fallback, no manual
  `vcg_step'`).

## Done-criteria (issue #30, as amended by decisions 2 and 4)

| Done when | Status |
|---|---|
| The lemma is checked by the `VU` session build of `run.sh isabelle-llvm` on the bench host, proofs accepted, `-n` and read controls still rejected | Met: `i30-run1`, normal run `build_status=0` and `caller_output=same`; both controls `control=rejected` |
| A results entry records the raw `build.log` and `build.time`, with one `lab/notebook.md` row | Met: this entry, its raw directory, one row in section "Experiment #5" |
| `table.md`: Isabelle-LLVM row (trusted count; callee-assumption and re-entrancy (a) columns) and its "Last update" paragraph | Met: 109 with its breakdown, both columns end "models of both of `caller.c`'s apply-all clients meet it", new head of "Last update"; the note under the table that said no model was shown is updated too |
| `isabelle-llvm/TRUSTED` changed as decided: line kept, comment reworded | Met: comment as Aeneas's, ranges `VU.thy:352-359` and `VU.thy:361-361` (decision 4) |

## Analysis and open questions

- The contract is now met by models of the actual clients in both
  tools that state it as a contract on the client (Aeneas and
  Isabelle-LLVM). In both, the model is a hand-written restatement of
  C that nothing checks against `caller.c`, which is why the line stays
  trusted.
- Bedrock2 states the same contract (`respects_i_apply`, "as
  Isabelle-LLVM") and has no client model; out of the scope of issue
  #30.
- The predicted "unresolved theory" error head did not appear; whether a
  later Isabelle reports it is not known.

_Drafted by Claude Code (Opus 5.5) as part of the experiment pipeline._
