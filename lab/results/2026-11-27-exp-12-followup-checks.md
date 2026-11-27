# Experiment #12 follow-up (issue #22), entry 2: checks before timing, conversion, position loop, fuel

**What.** Plan requirement 6's checks (i)-(iii), run on the bench host on
the regenerated extracted code before any timing. This entry also records
the subject conversion rules (requirement 4) and their measured cost, the
position loop (requirement 3), and the fuel and limits (requirement 5) of
the two extracted columns of run `x1`.

**Why.** The timed figures are only meaningful if three things hold: the
unverified parser port reads every pattern as experiment #9's recogniser
does; the harness-side position loop has `search_from`'s meaning; and the
conversion to the extracted representation loses nothing. Step 6 is the
gate that stops the run before timing if any of these fails.

Provenance: [entry 1](2026-11-27-exp-12-followup-provenance.md). Raw:
[`checks/`](2026-11-27-exp-12-followup-raw/checks/),
[`conv.csv`](2026-11-27-exp-12-followup-raw/conv.csv),
[`conv-subject.txt`](2026-11-27-exp-12-followup-raw/conv-subject.txt).

## Checks (i)-(iii): all pass

| Check | What | Result |
|---|---|---|
| (i) `x22.exe astcheck` | the OCaml port of `recognise` against column 10 (AST) and column 9 (ncap) of `lab/09-representative-proof/cases/fragment.tsv` and `extra.tsv` | 70 / 70 |
| (ii) `x22.exe astwork` | the port's s-expression against `prep22.py`'s (Python `recognise`, imported unchanged) for every admitted pattern | jq 10/10, PHP 21/21, VS Code 277/277, long PHP 1/1, large 15/15 |
| (iii) `x22.exe verdicts rocq` | per-position (`match_` at each p) and search verdicts through the adapter that the harness uses, against the `vm` lines of `2026-11-25-exp-09-correction-1-raw/rocq/fragment.verdicts.txt` (339 lines) and `2026-11-25-exp-09-raw/rocq/extra.verdicts.txt` (14) | byte-identical |
| (iii) `x22.exe verdicts fstar` | same, against `2026-11-25-exp-09-fstar-m1-raw/fstar/fragment.verdicts.txt` (339) and `extra.verdicts.txt` (14) | byte-identical |

Check (iii) also covers the parser, since the adapters compile from the
pattern bytes and not from the case file's AST. It covers the position
loop and the conversion as well. Experiment #9's reference used fuel
10,000,000 and the adapters use `max_int`; no reference line is
`LIMIT`, so the two fuels give the same verdicts here. The same checks
passed on the workstation before the run, against experiment #9's
copies of the extracted files.

## Position loop (requirement 3)

`lab/22-extracted-ocaml/adapter/engine22.ml` is harness code, not
verified code. It never calls the extracted `search` and never passes an
absolute position. For each start position p from `start` to
`min range n`, one byte at a time, it runs the extracted
`vm fuel code ncap suffix_p 0` on the subject suffix from p. It adds p
back to the match end and to every capture bound, and it stops at the
first result that is not `NoMatch`. This is the meaning of `search_from`
(`lab/09-representative-proof/rocq/Syntax.v:69-79`; `FRAGMENT.md`
section 7: the search is the same function of the per-position
results). `match_` is one `vm` call at `at`. A backward call (range <
start) returns -2001; no such call is in the subset.

## Fuel and limits (requirement 5)

Fuel is `max_int` (Rocq) and `Z.of_int max_int` (F\*) in every harness
call. `ENGINE.compile`'s `limit` and `stack_limit` are ignored.
`OutOfFuel` would be code -2000, which no call returned. The 63 PHP
calls carry `retry_limit_in_match` 1,000,000 and `match_stack_limit`
100,000. The extracted columns do not apply them, and C completed every
call under them ([entry 3](2026-11-27-exp-12-followup-agreement.md)).

## Conversion (requirement 4)

The representation is one list element per byte: `int list` for Rocq
(`ExtrOcamlNatInt`) and `Z.t list` for F\*. Bytes are small integers,
which zarith keeps unboxed, so both lists have the same layout and cost.
The short shape converts the suffix from `start` inside each call, and
that conversion is inside the timed figure. The long-PHP row and the
large shape use the scan mode: one conversion per subject, done in the
untimed warm-up, with a cursor on the suffix.

Per-call conversion alone (`x22.exe conv`), 10 interleaved runs on CPU
2, same passes and protocol as `time`, on each `<fam>.agreed.work`:

| Family | Engine | median ns/call | bytes/call | ns/byte | minor words/call |
|---|---|---:|---:|---:|---:|
| jq | rocq / fstar | 17.4 / 17.4 | 7.1 | 2.46 | 27.4 |
| PHP | rocq / fstar | 12.8 / 12.8 | 4.4 | 2.93 | 19.2 |
| VS Code | rocq / fstar | 29.0 / 29.0 | 16.5 | 1.76 | 55.4 |
| long PHP (not used in timing; for scale) | rocq / fstar | 57.7 ms / 57.8 ms | 2,097,150 | 27.5 | 6.29 M |

On the short shape, conversion is 1.7% (VS Code) to 8.8% (jq) of the
Rocq column's time per call, and 0.7% to 5.0% of the F\* column's
(entry 4). Converting the 2 MiB
long-PHP subject on every call would cost about 58 ms per call. That is
about 380,000 times the 151 ns that the scan-mode F\* column measures.

Whole-subject conversion (`x22.exe conv-subject`, one process per row,
default GC settings, `OCAMLRUNPARAM` unset; minor heap 262,144 words,
`space_overhead` 120):

| Subject | ns/byte (rocq, fstar) | words allocated | heap after |
|---|---|---:|---:|
| 1 MiB (log, src) | 37.1-37.4, 36.9-37.1 | 3.1 M minor, 2.9 M promoted | 24.7 MB |
| 16 MiB (log, src) | 39.7-39.9, 39.5-39.6 | 50.3 M minor, 50.2 M promoted | 419.3 MB |

A 16 MiB subject becomes a 419 MB list in the major heap. Scan
throughput therefore includes the major GC work that this live data
causes, as part of the cost of the representation (plan, Risks).

## Analysis

The gate passed, so the timing went ahead in run `x1`. Converting the
subject per call is cheap next to the extracted engines' own cost on
short subjects. On long subjects it is prohibitive, which is why the
plan's scan mode is needed and not just convenient.
