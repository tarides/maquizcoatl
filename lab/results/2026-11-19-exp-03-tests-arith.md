# exp-03 tests under the arithmetic checks

## What

The same 8 test binaries built with
`-fsanitize=unsigned-integer-overflow,implicit-conversion`, recoverable
(`build/arith`, see [provenance](2026-11-19-exp-03-provenance.md)),
run once each. Reports are deduplicated by source location and check
kind; each library location is classified.

## Why

Decision 1 (b) of issue #9: one recorded pass of the non-UB integer
checks, triaged as "suspicious arithmetic" (CVE-2019-19012 class,
`reg->dmax`), not as bugs unless a location turns out to compute a wrong
value.

## Provenance

Commit `7cf1230`, bench host, LLVM 21.1.8. Command:
`sh experiments/03-sanitizers-fuzzing/run-tests.sh arith`. Every binary
exited 0 with the same RESULT lines as the ASan+UBSan pass (1554, 1225,
785, 720, 221, 47, 13, 506 successes, no failure). UBSan prints each
location once per process, so the "binaries" column counts processes,
not occurrences.

## Raw data

60 reports, 14 distinct locations (15 location+column pairs), all in
`upstream/src/`; none in `upstream/test/`.

| Location | Function (caller) | Check, first value seen | Binaries | Class |
|---|---|---|---|---|
| `upstream/src/regparse.c:595:15` | `str_end_hash` (`onig_st_insert`) | unsigned overflow, `109437808 * 997` | 6 | intended |
| `upstream/src/regparse.c:687:15` | `callout_name_table_hash` (`onig_st_insert`) | unsigned overflow, `69645508 * 997` | 8 | intended |
| `upstream/src/regparse.c:1713:19` | `onig_set_callout_of_name` | `int` -2 to `unsigned` | 8 | intended |
| `upstream/src/regparse.c:7305:5` | `prs_cc` | `int` -2 to `unsigned` | 6 | intended |
| `upstream/src/regparse.c:7614:36` | `prs_callout_args` | `int` -2 to `unsigned` | 2 | intended |
| `upstream/src/regparse.c:7868:7` | `set_whole_options` | `int` -1074790401 to `OnigCaseFoldType` | 1 | intended |
| `upstream/src/regparse.c:8979:7` | `prs_exp` | `int` -2 to `unsigned` | 5 | intended |
| `upstream/src/regcomp.c:6694:15` | `optimize_nodes` | `unsigned` 2147483648 to `int` | 3 | intended |
| `upstream/src/regcomp.c:7704:23` | `onig_reg_init` (`onig_new`) | `int` -1074790401 to `OnigCaseFoldType` | 1 | intended |
| `upstream/src/regcomp.c:2579:13` | `compile_tree` (ND_ALT) | unsigned overflow, `0 - 1` | 7 | suspicious |
| `upstream/src/regcomp.c:2579:34` | `compile_tree` (ND_ALT) | unsigned overflow, `4294967295 + 1` | 7 | (same location) |
| `upstream/src/regcomp.c:2073:43` | `compile_anchor_look_behind_node` | `OnigLen` 4294967295 to `LengthType` (-1) | 2 | suspicious |
| `upstream/src/regcomp.c:2209:43` | `compile_anchor_look_behind_not_node` | `OnigLen` 4294967295 to `LengthType` (-1) | 2 | suspicious |
| `upstream/src/regexec.c:4497:11` | `match_at`, `OP_STEP_BACK_NEXT` | `LengthType` -1 to `OnigLen` | 2 | suspicious |

Raw logs (paths rewritten to `<hostdir>`):
[`2026-11-19-exp-03-raw/arith/`](2026-11-19-exp-03-raw/arith/).

## Analysis

Classification, by reading the code at `f95747b`:

- **Intended (10 locations).** `regparse.c:595,687` are multiplicative
  string hashes (`val * 997 + c`) whose wrap-around is the point.
  `regparse.c:1713,7305,7614,8979` and `regcomp.c:7704`,
  `regparse.c:7868` clear flag bits with `x &= ~FLAG` or
  `x = x & ~FLAG`, where `~` of a signed constant is negative and then
  converted to the unsigned flag type: a bit mask, value preserved.
  `regcomp.c:6694` stores `BITSET_AT(...)` (bit 31 of a `Bits` word) in
  an `int` used only as a truth value.
- **Suspicious (4 locations), correct today.**
  - `regcomp.c:2579`: `COP_CURR_OFFSET(reg)` is `ops_used - 1`
    (`regint.h:960`), which wraps to `UINT_MAX` when the alternation is
    the first opcode, and the following `+ 1` wraps back; the goal
    position is right only because the two wraps cancel.
  - `regcomp.c:2073,2209` and `regexec.c:4497`: the look-behind step-back
    count stores `INFINITE_LEN` (`0xFFFFFFFF`, `regint.h:226`) in the
    `int` field `step_back_start.remaining` (`LengthType`,
    `regint.h:626`) as -1, and `match_at` compares it again with
    `INFINITE_LEN` after the reverse conversion. The sentinel round-trip
    relies on implementation-defined signed conversion; it is the
    length/distance area of CVE-2019-19012.
- **Bugs: none.** No location produced a wrong value on the test inputs.

For the spec: lengths and offsets should be modelled as naturals with an
explicit "infinite" constructor, not as wrapped 32-bit values, so the
four suspicious locations disappear by construction. Not a deviation from
`f95747b` (the observable behaviour is the same).
