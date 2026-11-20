# Experiment #13: correction after two maintainer decisions

Issue: https://github.com/tarides/maquizcoatl/issues/3. This entry records
two decisions taken by the maintainer on 2026-11-19 after the results
were posted, and the wording changes they caused in earlier entries. No
figure changes and nothing was run again.

## 1. Spot check waived

Decision: https://github.com/tarides/maquizcoatl/issues/3#issuecomment-7019912682,
confirmed by Vincent Balat at
https://github.com/tarides/maquizcoatl/issues/3#issuecomment-7022469324.

The human spot check of three agent-estimated shares no longer gates the
summary. The results now state instead: the shares of lean-regex
`e2e33d6` (0.99), Anvil `cc8ab6a` (0.05) and the Why3 gallery (0.006) were
estimated by Claude agents and not checked by a human.

Every "provisional" mark, "Provisional" header and "pending human spot
check" item was replaced by that sentence, in:

- [`2026-11-19-exp-13-summary.md`](2026-11-19-exp-13-summary.md);
- [`2026-11-19-exp-13-mining-v3.md`](2026-11-19-exp-13-mining-v3.md);
- [`2026-11-19-exp-13-builds.md`](2026-11-19-exp-13-builds.md) (one
  "provisional" in its analysis);
- the rows "exp-13 mining summary v3" and "exp-13 summary" of
  [`../notebook.md`](../notebook.md);
- the Results comment on the issue
  (https://github.com/tarides/maquizcoatl/issues/3#issuecomment-7022338970).

The figures are unchanged: lean-regex 9,733 hand-written lines a year
(710 per kLOC), median / mean 70.5 / 973 per release crossed; Anvil 4,194
(49 per kLOC), 86 per release; Why3 gallery 157 (1.5 per kLOC).

## 2. Why3 prover deviation accepted

Decision: https://github.com/tarides/maquizcoatl/issues/3#issuecomment-7022409798.
Status: accepted by the maintainer on 2026-11-19, no rerun.

The plan asked for the Why3 replays to use each project's pinned prover
versions, then each prover's latest release. The builds
([`2026-11-19-exp-13-builds.md`](2026-11-19-exp-13-builds.md), section
"Why3 gallery: what the replay measures") did otherwise:

- One installed version per prover, the same on both sides (Why3 1.8.2
  and 1.9.0): Alt-Ergo 2.6.2, CVC5 1.2.1, Z3 4.13.4. The versions recorded
  in the 1.8.2 sessions (about 90) were mapped to them through a Why3
  prover upgrade policy
  ([`why3-upgrade-policy.conf`](2026-11-19-exp-13-builds-files/why3-upgrade-policy.conf));
  the five recorded CVC4 versions (1.4 to 1.8) were replayed with CVC5
  1.2.1.
- Both sides used the same provers, so the Why3-to-Why3 comparison holds:
  a session that replays on one side and not on the other shows a Why3
  difference (the two sessions broken by 1.9.0, `register_allocation` and
  `division`).
- "Fail on both" (156 of the 317 sessions replayed in the full gallery)
  mostly measures this substitution (prover versions or alternatives not
  installed, timeouts after the prover upgrade), not Why3.
- The reduced list's two failures (`dfs`, `toy_compiler`) occur on both
  sides; they are not isolated to the Why3 upgrade.

The builds entry and the summary keep their text; the summary's pending
item on the Why3 provers now says that the deviation was accepted.

## Provenance

- Branch `exp/13-upgrade-cost`, on top of `9840af4`. Text changes only,
  made by Claude Code (Opus 5.5) on the maintainer's instruction.
