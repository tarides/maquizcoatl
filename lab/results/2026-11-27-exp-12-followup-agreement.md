# Experiment #12 follow-up (issue #22), entry 3: agreement on the fragment subset

**What.** Issue #10's criterion 7 for the two extracted columns of run
`x1`: experiment #12's `agree` subcommand on every call of experiment
#1's workloads that is inside experiment #9's fragment, for `c`, `stubs`,
`ctypes`, `vm`, `rocq` and `fstar`. On the long-PHP row it also runs
`rocq-scan` and `fstar-scan`, the subject mode that the timing uses
there. C is the reference. The entry also checks the C driver against
experiment #1's expected results.

**Why.** A timed column only counts if it computes the same thing as
Oniguruma. The plan also predicted that no call in the fragment would
make C give up on a retry or stack limit. If that held, the extracted
columns, which run with fuel `max_int` and no limits, would face no call
whose cost C bounds and they do not.

Provenance: [entry 1](2026-11-27-exp-12-followup-provenance.md).
Command: `run22.py agree x1`, 4 jobs, `nice -n 10`, CPUs 0-3,32-35.
Raw: [`agree/`](2026-11-27-exp-12-followup-raw/agree/) (VS Code files
gzipped), [`agree.txt`](2026-11-27-exp-12-followup-raw/agree.txt).

## Results

| Family | Calls | stubs = C | ctypes = C | VM = C | Rocq = C | F\* = C | scan modes = C | C limit code (-15, -17, -18) | kept for timing | C = experiment #1 expected |
|---|---:|---:|---:|---:|---:|---:|---|---:|---:|---|
| jq | 91 | 91 | 91 | 91 | 91 | 91 | - | 0 | 91 | 91 / 91 |
| PHP | 63 | 63 | 63 | 63 | 63 | 63 | - | 0 | 63 | 63 / 63 |
| VS Code | 77,067 | 77,067 | 77,067 | 77,067 | 77,067 | 77,067 | - | 0 | 77,067 | 215 / 215 scanner searches |
| long PHP | 10 | 10 | 10 | 10 | 10 | 10 | 10, 10 | 0 | 10 | 10 / 10 |

Each column's output (result, number of registers, every capture bound)
is byte-identical to C's on all 77,231 calls. No call is excluded, so
every `<fam>.agreed.work` equals its `<fam>.frag.work`.

- **Limit codes.** As predicted, no fragment call made C return -15,
  -17 or -18. Experiment #12's three limit-code calls are outside the
  fragment. So the extracted columns, with fuel `max_int` and no retry
  or stack limit, faced no call on which C gave up. The `agree` jobs
  have no `timeout`, and each one finished in under 2 s.
- **Expected spans.** For VS Code, the check covers the scanner
  searches that have at least one member and whose members are all in
  the fragment: 215 of 11,263. The 12 searches on the 5 member-less
  scanners are skipped, as in experiment #12's `summarise.py`. For each
  search, the expected member index and span are recomputed from the
  per-member C results with `ONIG_REGSET_POSITION_LEAD`. These figures
  are for the 215 searches only, not for the family (requirement 11).
- **Escapes.** The admitted patterns include `\?`, `\\` (Ruby), escaped
  metacharacters, `\&`, `\-`, `\/`, `\<` and `\>` (Oniguruma). The
  agreement confirms that the three syntaxes read them as literals, as
  the extracted columns do.
