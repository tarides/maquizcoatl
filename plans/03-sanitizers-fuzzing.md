# Plan: experiment #3, sanitizers and fuzzing

Issue: https://github.com/tarides/maquizcoatl/issues/9 (the issue body is
the reference for scope, inputs, decisions and done-criteria; this plan
says how).
Source: maintainer's state-of-the-art report, section "Experiments before
deciding": https://claude.ai/artifact/8w6PVuiTsLCKpugpCowMHc

## Objective

Find the bugs that remain in Oniguruma at `f95747b` (crashes, memory
errors, undefined behaviour, internal-consistency errors, unbounded work)
by running:

- the 8 upstream test binaries under ASan + UBSan, plus one pass under
  the non-UB integer checks (decision 1);
- the 8 upstream libFuzzer targets plus `fuzzer-deep` (decision 2) for at
  least 3 CPU-days in total.

Each confirmed bug becomes a candidate entry for the deviation log
(#2): the spec will state the correct behaviour and record why it departs
from `f95747b`. The experiment chooses no stack.

Stack exhaustion (maintainer decision (a), issue comment 7008670586): a
`fuzzer-deep` stack overflow at a parse depth within the library default
(4096) is a confirmed bug and deviation-log candidate only if it
reproduces with `read-deep-plain` (non-sanitized) under the default
`ulimit -s`; it is recorded with the pattern depth and the stack size.
An overflow seen only under ASan is a resource finding, recorded in the
notebook and not listed as a deviation candidate.

Prior (issue, "Prior"): these harnesses already ran under OSS-Fuzz for
years, so a low fuzzing yield is expected and is itself a result. The
less-fuzzed surface is the test suite under UBSan, `testp`, the
arithmetic pass, `fuzzer-deluxe`, `fuzzer-regset` and `fuzzer-deep`; the
CPU split below weights them accordingly.

## Where things live

The run happens on the bench host (maintainer decision, issue comment
7007355610). Nothing is built in the repository or in `upstream/`.

- `<hostdir>` = `~/maquizcoatl-work/exp/03-sanitizers-fuzzing/` on the
  bench host:
  - `<hostdir>/src/maquizcoatl/` — clone of the public repository with
    the `upstream` submodule, checked out at the commit of branch
    `exp/03-sanitizers-fuzzing` that carries this plan and the scripts;
  - `<hostdir>/toolchain/` — user-local LLVM release (no root on the host);
  - `<hostdir>/build/{fuzz,tests,arith,plain}/` — four out-of-tree CMake
    builds of `src/maquizcoatl/upstream/` (see step 3);
  - `<hostdir>/harness/` — harness binaries, the `fuzzer-deep` copy of
    `base.c`, the converted UTF-16 dictionaries, and the non-sanitized
    `read-deep-plain`;
  - `<hostdir>/corpus/<target>/`, `<hostdir>/artifacts/<target>/`,
    `<hostdir>/logs/` — campaign state and output.
- `<workdir>` (workstation, outside the repository): staging area for
  results copied back from the host before they are selected into `lab/`,
  including the corpus tarballs in `<workdir>/exp03-results/corpus/`.
- In the repository (branch `exp/03-sanitizers-fuzzing`):
  - `experiments/03-sanitizers-fuzzing/` — the scripts (`setup.sh`,
    `build.sh`, `run-tests.sh`, `fuzz.sh`, `stats.sh`, `triage.sh`), the
    `fuzzer-deep` patch against `upstream/harnesses/base.c`, and
    `split.tsv` (the CPU split). They are committed and pushed to the
    branch before step 1 (the branch held only this plan when it was
    reviewed), and that commit is the one the host checks out and the one
    recorded in `03-provenance.md`;
  - `lab/notebook.md` and `lab/results/` — the lab notebook (see
    "Recording").

## Tools and versions

All actively maintained. Versions are recorded again in the notebook's
provenance at run time.

- LLVM/clang 21.1.8 (official release tarball
  `LLVM-21.1.8-Linux-X64.tar.xz` from the llvm-project GitHub releases,
  same version as checked on the workstation): clang, clang++,
  `libclang_rt.fuzzer`, ASan, UBSan, LeakSanitizer, `llvm-symbolizer`.
  Installed in `<hostdir>/toolchain/`; its SHA-256 is recorded.
  Pre-checked on the workstation before the bench window (step 0): the
  release asset exists (2,019,005,384 bytes, with a `.jsonl` attestation
  alongside).
- CMake 3.28 and GNU Make (host packages).
- Python 3 (host package, standard library only, run with `-I`) for
  `upstream/harnesses/dict_conv.py` and the triage scripts.
- git, tmux, nohup (host packages).

## Machine budget

**Revision at execution time.** The bench host is shared with
experiments #7 and #11, so this run uses at most 40 parallel jobs,
pinned with `taskset` to CPUs 8-31 and 40-63 (#11 pins CPUs 4-7 and
their SMT siblings 36-39). The campaign therefore runs 40 workers for
110 min (73.3 CPU-hours, still above the 72 required); `split.tsv` holds
the actual split (encode 4, syntax 4, utf16-be 3, utf16-le 3, regset 6,
deluxe 6, onig 3, onig-full 3, deep 8). The figures below are the
reviewed 48-worker plan, kept for reference. The `fuzzer-deep` patch
also makes the 4 MB input buffer of the `STANDALONE` `main` static, so
that `read-deep-plain` measures the library's stack use under the
default `ulimit -s` and not the harness's.

Bench host: at most 48 parallel jobs and at most 3 hours of wall-clock
for the whole run. 3 CPU-days is 72 CPU-hours, i.e. 1 h 30 min at 48
workers. Planned timeline:

| Phase | Wall-clock | Jobs |
|---|---|---|
| Setup: clone, toolchain download and check | 0:00–0:20 | 1–4 |
| Builds (4 CMake trees + harnesses) | 0:20–0:30 | 4 × 12 |
| Test suite: ASan+UBSan pass and arithmetic pass | 0:30–0:45 | 16 |
| Fuzzing campaign | 0:45–2:25 (100 min) | 48 |
| Final stats, deduplication, minimisation, copy back | 2:25–3:00 | ≤ 48 |

100 min × 48 workers = 80 CPU-hours, 8 above the 72 required, as margin
for worker start-up and restarts. Root-cause attribution (criterion 3)
and the candidate deviation-log entries (criterion 4) are desk work on
the workstation from the copied reproducers and use no bench time. If
minimisation does not finish in the window, the unminimised reproducers
are copied back, minimised later in a second short session, and the
notebook says so.

Follow-up (not in this run): a long campaign (for example a CPU-week,
or continuous fuzzing) on the targets that still find new coverage at
the end, notably `fuzzer-deep`.

### CPU split across the 9 targets

Workers per target for the 100-minute campaign (`split.tsv`); the actual
split, including restarts, is recorded.

| Target | Harness | Workers | CPU-hours |
|---|---|---|---|
| `fuzzer-encode` | `base.c` | 5 | 8.3 |
| `fuzzer-syntax` | `base.c -DSYNTAX_TEST` | 5 | 8.3 |
| `fuzzer-utf16-be` | `base.c -DUTF16_BE` | 4 | 6.7 |
| `fuzzer-utf16-le` | `base.c -DUTF16_LE` | 4 | 6.7 |
| `fuzzer-regset` | `regset.c` | 7 | 11.7 |
| `fuzzer-deluxe` | `deluxe.c` | 7 | 11.7 |
| `libfuzzer-onig` | `libfuzzer-onig.cpp` | 3 | 5.0 |
| `libfuzzer-onig-full` | `libfuzzer-onig.cpp -DFULL_TEST` | 4 | 6.7 |
| `fuzzer-deep` | patched copy of `base.c` (own input format) | 9 | 15.0 |
| **Total** | | **48** | **80.0** |

## Approach

0. **Before the bench window (workstation).** Commit and push
   `experiments/03-sanitizers-fuzzing/` (scripts, patch, `split.tsv`).
   Download `LLVM-21.1.8-Linux-X64.tar.xz` into `<workdir>`, check its
   size (2,019,005,384 bytes) and its `.jsonl` attestation, record its
   SHA-256, and list the tarball (`tar -tJf`) to find
   `libclang_rt.fuzzer*.a`. The release may use either runtime layout,
   `lib/clang/21/lib/linux/libclang_rt.fuzzer-x86_64.a` or the
   per-target `lib/clang/21/lib/x86_64-unknown-linux-gnu/libclang_rt.fuzzer.a`;
   `build.sh` accepts both. The hash and the path found are recorded and
   checked again on the host.
1. **Host setup.** On the bench host, create `<hostdir>`, clone
   `tarides/maquizcoatl` with `--recurse-submodules`, check out the
   branch commit, and check that `upstream` is at `f95747b`. Record CPU
   model (`lscpu`), kernel version (`uname -r`), core count and RAM.
   Nothing else about the host is recorded.
2. **Toolchain.** Download the LLVM 21.1.8 release tarball into
   `<hostdir>/toolchain/`, record its SHA-256, extract it, and check that
   the `libclang_rt.fuzzer` found in step 0 exists (either layout) and that a trivial fuzz target links and
   runs with `-fsanitize=fuzzer,address,undefined`. Set
   `ASAN_SYMBOLIZER_PATH`/`UBSAN_SYMBOLIZER_PATH` to its
   `llvm-symbolizer`. If the release lacks the fuzzer runtime, see Risks.
3. **Builds** (all `cmake -S src/maquizcoatl/upstream -B build/<name>`,
   `CC`/`CXX` from the toolchain, `-fno-omit-frame-pointer -g`):
   - `build/fuzz`: `-DBUILD_SHARED_LIBS=OFF -DBUILD_TEST=OFF`, flags
     `-O1 -g -fno-omit-frame-pointer` (no `CMAKE_BUILD_TYPE=Debug`, whose
     `-O0` would cut throughput), `CMAKE_C_FLAGS` with
     `-fsanitize=fuzzer-no-link,address,undefined
     -fno-sanitize-recover=undefined`, so that libFuzzer's `cov`/`ft`
     measure the library.
   - `build/tests`: `-DCMAKE_BUILD_TYPE=Debug -DENABLE_POSIX_API=ON`,
     ASan + recoverable UBSan (`-fsanitize=address,undefined
     -fsanitize-recover=address`); builds the 7 default test binaries
     and `testp`.
   - `build/arith`: `-DCMAKE_BUILD_TYPE=Debug -DENABLE_POSIX_API=ON`,
     `-fsanitize=unsigned-integer-overflow,implicit-conversion`
     (recoverable), same 8 binaries (decision 1).
   - `build/plain`: `-DBUILD_SHARED_LIBS=OFF -DBUILD_TEST=OFF`, flags
     `-O1 -g -fno-omit-frame-pointer`, no sanitizer. Only used to link
     `read-deep-plain`, which confirms stack-overflow representatives
     without ASan's enlarged frames, under the default `ulimit -s`.
   - Harnesses, in `<hostdir>/harness/`, compiled with
     `-O1 -g -fno-omit-frame-pointer`, each fuzz target linked with
     `-fsanitize=fuzzer,address,undefined -fno-sanitize-recover=undefined
     -I src/maquizcoatl/upstream/src` against `build/fuzz/libonig.a`,
     with the same `-D` flags as `upstream/harnesses/makefile:22-62`;
     the `read-*` variants of the `base.c`, `deluxe.c` and `regset.c`
     targets with `-fsanitize=address,undefined -DSTANDALONE` (they read
     the input from stdin, `base.c:752-757`). `libfuzzer-onig.cpp` has
     no `STANDALONE` variant; its artifacts are replayed by running the
     fuzz binary itself with the artifact path as argument.
   - `fuzzer-deep`: copy `upstream/harnesses/base.c` to
     `<hostdir>/harness/base-deep.c` and apply the committed patch:
     `PARSE_DEPTH_LIMIT` 8 → 4096, `MAX_SUBEXP_CALL_NEST_LEVEL` 8 → 20,
     and a two-byte pattern-size field (`NUM_CONTROL_BYTES` 7 → 8). In
     upstream the size is one byte (`pattern_size_choice`,
     `base.c:639-653`), which caps the pattern at 255 bytes; since depth
     grows by about 2 per `(`, the reachable depth would be about 510,
     far from 4096. Other limits are unchanged. `fuzzer-deep` therefore
     has its own input format, and its own corpus (no sharing with
     `fuzzer-encode`). The copy keeps Oniguruma's copyright notice.
     Build `fuzzer-deep` like `fuzzer-encode`, and from the same patched
     copy `read-deep` (ASan + UBSan) and `read-deep-plain` (against
     `build/plain`).
   - Dictionaries: `upstream/harnesses/ascii_compatible.dict` as is, and
     UTF-16 BE/LE versions written by `build.sh` as
     `python3 -I upstream/harnesses/dict_conv.py utf16_be
     < upstream/harnesses/ascii_compatible.dict
     > <hostdir>/harness/utf16_be.dict` (and `utf16_le` likewise): one
     argument, dictionary on stdin.
4. **Test suite, ASan + UBSan pass.** Run the 8 binaries of
   `build/tests` in parallel, each with
   `ASAN_OPTIONS=halt_on_error=0:detect_leaks=1:log_path=<logs>/tests/<bin>`
   and `UBSAN_OPTIONS=halt_on_error=0:print_stacktrace=1:log_path=...`,
   so that a binary keeps running after a report and both every report
   and the `RESULT` line are collected. Keep stdout (the `RESULT` line)
   and every sanitizer log. If a binary still stops early (for example
   on a SEGV), the truncated run is recorded explicitly as such. Compare the
   SUCC/FAIL/ERROR counts with the unsanitized expectations listed in the
   issue. Attribute each leak to the library or the test program.
5. **Test suite, arithmetic pass.** Same for `build/arith`. Deduplicate
   reports by source location (`file:line:col` plus check kind) and
   count occurrences. Split the table into library locations
   (`upstream/src/`) and test-program locations (`upstream/test/`); only
   the library locations are classified.
6. **Fuzzing campaign.** For each target, in its own tmux window under
   `nohup`, run libFuzzer in fork mode with the worker count of the
   split table: `-fork=N -ignore_crashes=1 -ignore_timeouts=1
   -ignore_ooms=1 -max_total_time=6000 -timeout=30 -rss_limit_mb=2048
   -print_final_stats=1 -artifact_prefix=<hostdir>/artifacts/<target>/`,
   `-dict=` the ASCII or UTF-16 dictionary, empty starting corpus in
   `<hostdir>/corpus/<target>/` (raw test patterns do not follow the
   control-byte format of `base.c:476-482`). `fuzzer-deep` gets
   `-max_len=16384` so a 4096-deep pattern fits (with the two-byte size
   field of step 3); the others keep libFuzzer's default. ASan options: `detect_leaks=1`,
   `print_stacktrace=1` for UBSan. Check the load and the logs at
   least every 20 minutes.
7. **Final statistics.** For each target, one non-fork pass over the
   final corpus with `-runs=0`; the end `cov`/`ft` are taken from its
   `INITED`/`DONE` status line (`-print_final_stats=1` does not print
   them), with the fork parent's last `#N: cov: ... ft: ...` line as a
   cross-check. `stats.sh` parses those lines. Record executions and
   time from the fork-mode logs, and corpus file count and total bytes.
   Archive each corpus as a tarball on the host and record its SHA-256
   and size.
8. **Deduplication and minimisation.** Symbolise every artifact by
   replaying it: `triage.sh` pipes it into the matching `read-*` binary
   on stdin, or, for `libfuzzer-onig` and `libfuzzer-onig-full`, runs the
   fuzz binary with the artifact path as argument. Each stack-overflow
   representative of `fuzzer-deep` is also replayed with
   `read-deep-plain` under the default `ulimit -s`, and the outcome and
   pattern depth are recorded; this outcome decides between confirmed
   bug and resource finding (decision 3). Group by the top 3
   symbolised frames of the sanitizer report; group `exit(-2)` artifacts
   ("fuzz target exited") by ONIG error code plus input, as criterion 3
   says; group timeouts by the top frames of the timeout stack. Minimise
   one representative per group with `-minimize_crash=1 -runs=10000`
   (crashes) or by re-running with `-timeout` (timeouts). Check that
   `git -C src/maquizcoatl/upstream status` is clean.
9. **Copy back.** `rsync` the logs, statistics, minimised reproducers
   (with their unminimised originals), group summaries and the
   arithmetic-pass table to `<workdir>/exp03-results/` on the
   workstation, and the per-target corpus tarballs to
   `<workdir>/exp03-results/corpus/` (outside the repository; only their
   sizes and hashes go into `lab/`).
10. **Triage (desk work).** For each group: root cause at
    `upstream/<path>:<line>`, or "unexplained". Timeouts despite the
    harness limits are findings; `ONIGERR_*_LIMIT_OVER` results are not.
    Classify each arithmetic-pass location as intended
    wrap-around/truncation, suspicious, or bug. Write each confirmed bug
    as a candidate deviation-log entry (input, observed behaviour,
    correct behaviour, location).
11. **Record and publish.** Record the results with the lab-notebook
    skill, commit from the local worktree (signed off), and open the PR.

## Recording (lab-notebook skill)

`lab/notebook.md` is the index; `lab/results/` holds the entries,
append-only, never overwritten. The maintainer decides what is worth
keeping; candidates are:

- `lab/results/03-provenance.md`: CPU model, kernel version, toolchain
  version and SHA-256, path of `libclang_rt.fuzzer` in the release,
  CMake version, commit of the repository (the one carrying the scripts,
  step 0) and of `upstream`, exact build flags and sanitizer options,
  and `ulimit -s` on the host.
- `lab/results/03-tests-asan-ubsan.md`: per binary, the `RESULT` line,
  the sanitizer reports (deduplicated, with counts) and leak attribution.
- `lab/results/03-tests-arith.md`: the location table, split into
  `upstream/src/` and `upstream/test/`, with classification of the
  library locations.
- `lab/results/03-fuzz-campaign.md`: planned and actual CPU split; per
  target time, executions, final `cov`/`ft`, corpus files and bytes,
  corpus tarball hash; crash/timeout/oom counts.
- `lab/results/03-triage.md`: the deduplicated groups with reproducer,
  root cause or "unexplained", and the candidate deviation-log entries.
- `lab/results/03-sanitizers-fuzzing/repro/`: minimised reproducers
  (small binary files), one directory per group.

Fuzzing is stochastic: a later campaign is a replication, kept as data
in a new entry, not an overwrite.

## Outputs

- The scripts and the `fuzzer-deep` patch in
  `experiments/03-sanitizers-fuzzing/`.
- The lab notebook entries above, with reproducers.
- A list of candidate deviation-log entries handed to #2.
- A PR from `exp/03-sanitizers-fuzzing` with the results and a summary
  comment on #9.

## Done-criteria (copied from the issue)

1. All 7 default test binaries, plus `testp`, built with ASan + UBSan
   (recoverable UBSan, see Method), and run. For each: the
   `RESULT SUCC/FAIL/ERROR` line and every sanitizer report, recorded in
   the lab notebook. Same for the arithmetic pass (decision 1), with its
   reports deduplicated by source location and each location classified
   (intended, suspicious, bug).
2. Every fuzz target listed under Inputs (8 upstream targets plus
   `fuzzer-deep`) built out of tree with ASan + UBSan and run. Total
   fuzzing time of at least 3 CPU-days, with the split across the 9
   targets stated in the plan and recorded; per target: time,
   executions, coverage (`cov`/`ft`) at the end, and corpus size (file
   count and total bytes) recorded.
3. Every crash, sanitizer report or timeout is deduplicated (by stack
   trace), minimised, and either attributed to a root cause at
   `upstream/<path>:<line>` or marked unexplained. Exception:
   `base.c:353-357,367-373,684` and `regset.c:180-184,213-217,355` call
   `exit(-2)` on `ONIGERR_PARSER_BUG`/`STACK_BUG`/`UNDEFINED_BYTECODE`/
   `UNEXPECTED_BYTECODE`; libFuzzer reports these as "fuzz target
   exited" with an identical stack, so they are deduplicated by error
   code plus minimised input and listed as internal-consistency bugs.
4. Each confirmed bug is listed as a candidate deviation-log entry:
   input, observed behaviour, correct behaviour, location. A
   `fuzzer-deep` stack exhaustion within the default depth limit counts
   as a confirmed bug only if it reproduces in the plain, non-sanitized
   build (decision 3), and is listed with its depth and stack size;
   ASan-only exhaustions are listed in the notebook as resource findings.
5. `upstream/` is unchanged (`git -C upstream status` is clean) at the
   end.

## Risks

- **No clang on the host, no root.** Mitigation: the LLVM release
  tarball (about 2 GB) in `<hostdir>/toolchain/`. If it lacks
  `libclang_rt.fuzzer` or does not run on the host's glibc 2.39, fall
  back to building only compiler-rt from the llvm-project 21.1.8 source
  with the host's GCC 13 (adds about 15 minutes, taken from the fuzzing
  window's margin), and record it.
- **Arithmetic-pass noise.** `implicit-conversion` and unsigned
  overflow fire on deliberate hashing and byte packing. Mitigation:
  deduplicate by location; classify locations, not occurrences. If the
  location count is too large to classify in the triage session, record
  the full table, classify the locations in `regcomp.c`/`regexec.c`
  around length and distance computations (the CVE-2019-19012 area)
  first, and list the rest as follow-up.
- **`fuzzer-deep` throughput and stack exhaustion.** Deep patterns are
  slow and ASan enlarges frames; stack overflows are the expected
  finding, not a harness failure. Many timeouts may lower throughput;
  they are counted, not fixed.
- **Many identical `exit(-2)` or timeout artifacts** could swamp
  deduplication. Mitigation: grouping rules of step 8; only one
  representative per group is minimised.
- **SSH drop.** Long jobs run under tmux and `nohup`; the campaign
  continues and is resumed from the corpora.
- **Shared bench host.** Other users' load could slow the campaign. The
  CPU-hours are measured from libFuzzer's own time counters; if the
  3 CPU-days are not reached in the window, the shortfall is recorded
  and completed in a second session.
- **Leaking host details.** Only CPU model and kernel version go in the
  notebook; logs are checked for hostnames, IP addresses and home paths
  before they are committed, and paths are rewritten to `<hostdir>`.
