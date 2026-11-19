# exp-01 workloads: patterns with subjects for #11 and #12

## What

Dynamic capture of the regex calls that VS Code (vscode-textmate +
vscode-oniguruma), jq and PHP mbregex make on their own test material,
packaged as fixed-format JSONL workloads with expected results from stock
Oniguruma `f95747b`. Format and reproduction:
`experiments/01-pattern-inventory/README.md`; data:
`experiments/01-pattern-inventory/workloads/data/`.

## Why

Criterion 6 of issue #5: #11 (baselines) and #12 (FFI vs native OCaml)
need realistic (pattern, subject) workloads before any implementation
exists. Published before the classification entry so that #11 is not
blocked on criteria 3-5. The capture also checks the static extraction
(triples seen only at run time are reported as dynamic-only).

## Provenance

- Repository: branch `exp/01-pattern-inventory`, scripts as of the commit
  that adds this file (parent `9484a70`).
- Oniguruma: upstream `f95747b462de672b6f8dbdeb478245ddf061ca53`, built
  out of tree, `CMAKE_BUILD_TYPE=Release`, shared library (GCC 15.2.0,
  `-O3 -DNDEBUG` from CMake's Release defaults), installed in `<workdir>/prefix`.
- Hosts: microsoft/vscode `184833947d794fddbe2cda93f3ad318c42724f55`
  (colorize fixtures, grammars); npm vscode-textmate 9.3.2 and
  vscode-oniguruma 1.7.0 (the versions VS Code's `package.json` pins);
  jq 1.8.2 (tarball sha256 `71b8d6e8…af3af`, tag commit `34f7186b`) and
  PHP 8.5.12 (tarball sha256 `08bc2eba…81209`, tag commit `136e049a`),
  both built from the release tarballs against the stock `f95747b`
  library (PHP: `--disable-all --enable-mbstring`; `MB_ONIGURUMA_VERSION`
  reports 6.9.10).
- Tools: CMake 4.2.3, GNU Make 4.4.1, Python 3.14.4 (stdlib, `-I`),
  Node.js 22.22.1, npm 9.2.0, git 2.53.0.
- Machine: 12th Gen Intel Core i7-1260P (16 threads), 15 GiB RAM,
  Ubuntu 26.04.1 LTS, Linux 7.0.0-43-generic. At most 4 parallel jobs.
- Run by Claude Code (Opus 5.5) in the experiment pipeline, 2026-11-19
  around 11:30 UTC.

Commands (from `<workdir>`, see `workloads/build.sh` for the full sequence):

    node workloads/replay_vscode.js src/vscode node/node_modules out/vscode-log.jsonl     # 20 s, exit 0
    jq --run-tests tests/{jq,onig,optional,man,manonig}.test  under LD_PRELOAD=libonigshim.so
    php run-tests.php -j4 ext/mbstring/tests  under the shim, ONIGSHIM_MAX_SUBJECT=4096, ONIGSHIM_MAX_LOG=200 MB
    python3 -I workloads/build_workloads.py … 0  …   # complete set, out/workloads-full
    python3 -I workloads/build_workloads.py … 20 …   # sample committed in workloads/data

Host test results under the shim: jq 537/550 (`jq.test`; the failures are
locale, module-path and `$ENV.PAGER` tests, none regex), 47/47
(`onig.test`), 229/231 (`man.test`, `$ENV.PAGER`), 19/19 (`manonig.test`),
1/2 (`optional.test`, locale); PHP 437 passed, 9 skipped, 0 failed of 446.

## Data

| Source | capture | calls/searches | distinct compiled triples | dynamic-only triples | committed |
|---|---|---:|---:|---:|---|
| VS Code | JS wrapper around `OnigScanner` | 473,134 distinct searches over 1,492 scanners, 112 fixture files, 152,225 lines | 4,221 | 381 | first 20 searches per scanner: 11,263 |
| jq | `LD_PRELOAD` shim | 217 `onig_search` | 44 | 0 | all |
| PHP | `LD_PRELOAD` shim | 421 packaged `onig_search`/`onig_match` (15,003 calls with subjects over 4 KiB not packaged; per-process cap 5000 calls) | 194 | 131 | all |

- VS Code: 42 searches (all in `test.log`) where stock `f95747b` and
  vscode-oniguruma 1.7.0 disagree. In every one the scanner contains a
  `log.tmLanguage.json` pattern such as `(?<=^[\s\d\p]*)\bE\b`, which
  `f95747b` rejects (`ONIGERR_INVALID_CHAR_PROPERTY_NAME`, -223) while the
  Oniguruma bundled in vscode-oniguruma 1.7.0 accepts it. All other
  473,092 searches give the same winning index and match.
- VS Code dynamic-only triples are scanner variants: `\A`/`\G` replaced by
  U+FFFF, and `\N` in `end`/`while` replaced by the begin capture text.
- PHP: match parameters are logged per call; 15,416 searches use
  retry limit 1,000,000 and stack limit 100,000 (PHP's INI defaults);
  four calls use other values (stack limit 10,000, 30,000 or 30,001, and
  one retry limit of 100,000). Upstream defaults are retry 10,000,000 and
  an unlimited stack (`upstream/src/regint.h:110-111`).
- PHP dynamic-only: patterns built from variables in the tests (131 triples,
  70 of them case-insensitive through `mb_eregi`).

## Analysis and open questions

- The VS Code workload is dominated by `vscode-colorize-perf-tests`
  (large TypeScript files); the committed sample caps each scanner at 20
  searches, so it keeps every scanner but not the frequency profile. #11
  should use the complete set from `build.sh` for timing.
- Incident: the first PHP capture had no size cap and one stress test
  logged about 22 GB in a few seconds, filling the shared disk to 100%
  for under a minute before the log was deleted. The shim now caps
  subjects, calls per process and log size.
- The `\p]` difference is a compatibility question for the spec: a
  grammar shipped with VS Code depends on behaviour that upstream's final
  version rejects.
