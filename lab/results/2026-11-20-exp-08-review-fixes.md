# Experiment #8, entry 8: corrections after the results review

**What.** Corrections to entries 2 to 7 required by the automated
results review on issue #12
([comment](https://github.com/tarides/maquizcoatl/issues/12#issuecomment-7024662894)),
problems 1-4. No new run: every number below is already in the raw data
of entries 3-7. Entries 1-7 are left as recorded; this entry supersedes
the passages it names.

**Why.** The review confirmed the six done-criteria and every
conclusion, but found an off-by-one citation, two inconsistent
statements of the same Rocq timeout, a timing rerun whose command was
not recorded, and one RSS cell that does not follow the median rule of
the others.

## Provenance

Text corrections only, on the data of entries 1-7 (branch commit
`20c34be`). Two source files change only in text the tools ignore: a
citation in `lab/08-hard-features/SEMANTICS.md` and a comment in
`lab/08-hard-features/rocq/Longest.v`.

## Corrections

### 1. `doc/RE` citation (entries 2 and 7, `SEMANTICS.md`)

The sentence "This is a written abbreviation of (?~|(?:absent)|\O*)." is
`upstream/doc/RE:368`, not `:367`. Read `:368` for `:367` in entry 2
(corpus, "Confirmed behaviour") and entry 7 (comparison, last list). It
is corrected in `SEMANTICS.md` and in the results comment on issue #12;
`cases/absent.tsv` and the plan already said `:368`.

### 2. Rocq timeout at `Qed` on FIND_LONGEST (entry 5)

The comment at `rocq/Longest.v:37-39` said the kernel check "did not
finish in 5 minutes"; entry 5 says "more than 60 s, killed twice". No
log of a 5-minute run exists, so entry 5's statement is the one kept,
and the comment now reads "did not finish (killed after more than 60 s,
twice)". The fixed proof is unchanged.

### 3. Calls timings (entries 3 and 7)

The Calls rows of entries 3 and 7 come from the reruns
`timed-calls2-{1,2,3}`, made after case ca06 was added to the four tools
(commit `d66233b`, 22:51:33 UTC; the three run directories were created
at 22:51:48, 22:51:56 and 22:52:04 UTC). `timed.sh` runs all four
features, so the calls-only command was a direct loop over `check.sh`:

```
for r in 1 2 3; do
  for T in rocq lean fstar verus; do
    lab/08-hard-features/check.sh "$T" Calls "timed-calls2-$r"
  done
done
```

No log of this command was kept; it is reconstructed from the run
directories (one per run, created in order) and from the tool order in
each `summary.tsv`, which is the order of `timed.sh`. Same host, tool
versions, memory cap and CPU set (`16-23,48-55`) as entry 1.

`raw/provenance.txt` records `branch commit: 27eea1c`, taken before
ca06 was added; for the Calls rows the sources are those of `d66233b`.
The Calls rows of `timed-{1,2,3}` (27eea1c, without ca06: Rocq 1.17 s,
Lean 1.28 s, F\* 1.21 s, Verus 1.69 s) are **superseded** by
`timed-calls2-{1,2,3}` (Rocq 1.20 s, Lean 1.47 s, F\* 1.92 s, Verus
3.30 s). Entry 7's Calls figures are those of the reruns, as entry 3's
are.

### 4. RSS rule (entries 3-7)

The review read Lean Calls (565 MB; runs 533, 565 and 538 MB) as the
only cell giving the maximum where the others give the median.
Recomputed from the `summary.tsv` files, **all 16 peak-RSS cells** of
entries 3-6 are the maximum of the three runs, truncated to whole MB
(`maxrss_kb` / 1024): for example Lean Absent 512 (runs 512.4, 499.0,
502.5), Lean FIND_LONGEST 504 (494.5, 497.5, 504.0), Verus Calls 328
(326.7, 327.2, 328.2). The rule was consistent but not stated. It is
now: **peak RSS is the maximum over the three runs, truncated to whole
MB**; times stay medians. No cell changes. Between runs the cells vary by under 3%,
except Lean Calls (6%).

## Not changed

- Problem 5 (housekeeping: PR label, issue body) is fixed on GitHub, not
  in the notebook.
- Follow-ups 1-5 of the review (discriminating lemmas, Pulse, notebook
  sign-off, spec intake of D-08-1 and of the absent-operator
  equivalence, marking eliminated stacks) are left to the maintainer.
