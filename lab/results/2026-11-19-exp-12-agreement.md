# Experiment #12, entry 3: agreement on the workloads

**What.** Criterion 7: on every in-subset call of experiment #1's
workloads, result code, match span and all capture positions from the C
driver (reference: Oniguruma `f95747b`), the `[@@noalloc]` stubs,
ctypes, the VM in both switches and `ocaml-re`.

**Why.** The FFI columns must agree byte for byte (a check of the
bindings); the VM's speed figures are only meaningful where it computes
the same answer.

## Provenance

As [entry 1](2026-11-19-exp-12-provenance.md). `run.py prepare r1`
(untimed, 4 jobs): `prep.py` flattens the JSONL files, `main.exe
classify` keeps the in-subset calls, then `cdriver agree` and `main.exe
agree <engine>` on each family. The PHP calls use their recorded match
param (retry limit 1,000,000 and stack limit 100,000, or the recorded
values for the long-subject sample); jq and VS Code the defaults
(retry limit 10,000,000 in match, 0 in search).

## Results

| Family | Calls run | stubs = C | ctypes = C | VM (`ffi`) = C | VM (`ffi-flambda`) = VM (`ffi`) | C = experiment #1 `expected` |
|---|---|---|---|---|---|---|
| jq | 136 | yes | yes | 136 / 136 | yes | 136 / 136 |
| PHP | 159 | yes | yes | 158 / 159 | yes | 159 / 159 |
| VS Code | 123,982 | yes | yes | 123,982 / 123,982 | yes | 906 / 906 scanner searches whose members are all in the subset |
| PHP long subjects (synthetic) | 13 | yes | yes | 11 / 13 | yes | 13 / 13 |

"yes" means the output files are byte-identical (all registers of
every call). The VS Code `expected` check rebuilds the
`ONIG_REGSET_POSITION_LEAD` answer (smallest match start, then lowest
member index) from the per-member results.

### VM disagreements (all listed)

| Family / case | Pattern, subject | Oniguruma | VM | Cause |
|---|---|---|---|---|
| PHP 419 | `A(B\|C+)+D\|AC+X` (Ruby, options 12), `"A" "C"x19 "X"`, retry limit 1,000,000 | match 0-21 | -17 (retry limit) | Retry-count fidelity: the first alternative backtracks exponentially; Oniguruma's `OP_PUSH_OR_JUMP_EXACT1` / `PUSH_IF_PEEK_NEXT` (`upstream/src/regcomp.c:1430-1460`) avoid pushing choice points whose next character cannot match, so it spends fewer than 1,000,000 retries before reaching `AC+X`; the VM pushes every choice point and exhausts the budget first. |
| PHP long 0, 1 | `\s+$` (Ruby, options 12) on 30,000 spaces, match stack limit 10,000 | -15 (`ONIGERR_MATCH_STACK_LIMIT_OVER`) | match 0-30000 | The VM does not model the match-stack limit. |

Disagreement rate: 3 of 124,290 calls (0.002%), below the plan's stop
threshold. The three calls are excluded from all timed columns
(`*.agreed.work`). `ocaml-re` is a reference only: it differs from C on
4 PHP, 3,868 VS Code (3,838 not expressible in `Re.Perl`) and 2 long
PHP calls (byte semantics, no retry budget).

Raw: [`agree/`](2026-11-19-exp-12-raw/agree/) (VS Code: C output
gzipped, the stubs, ctypes, VM and VM-flambda outputs have the same
sha256, `agree/vscode.sha256`), expected values in
[`work/`](2026-11-19-exp-12-raw/work/).

## Analysis

The two FFI bindings are exact. The VM reproduces Oniguruma on every
workload call whose answer does not depend on resource limits. Its
retry counter is not Oniguruma's: for a pattern that nearly exhausts the
budget, the outcome can differ (one call here). Matching Oniguruma's
count exactly would require reproducing its peephole choices
(`PUSH_OR_JUMP_EXACT1`, `PUSH_IF_PEEK_NEXT`, `ANYCHAR_STAR`), which is a
spec question (is the retry count part of the observable behaviour?)
rather than a VM one.
