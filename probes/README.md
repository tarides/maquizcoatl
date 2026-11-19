# Semantic probes

Seed of the characterisation corpus (experiment #2, issue #6). Each probe
runs against upstream Oniguruma `f95747b` (Debug and ASan/UBSan builds)
and against a JavaScript oracle (Node.js / V8), and the three results are
joined per probe.

## Files

| File | Role |
|------|------|
| `harness.c` | Runs one probe file through libonig (`onig_new` + `onig_search`), one TSV record per probe. |
| `oracle.mjs` | Runs the same probe file through JavaScript `RegExp`, with and without `u` (always with `d`). |
| `compare.mjs` | Joins Debug, ASan and JavaScript outputs; adds `asan_same`, `sanitizer` and `cmp`. |
| `run.sh` | Runs all five areas and writes raw and joined TSV into an output directory. |
| `Makefile` | Builds `harness-debug` / `harness-asan` against an out-of-tree upstream build. |
| `captures-in-loops.tsv`, `backref-unset.tsv`, `empty-iterations.tsv`, `lookbehind.tsv`, `case-folding.tsv` | Probe data, one file per area. |

## Probe data format

TSV, `#` lines are comments, one header line:

    id  syntax  encoding  options  pattern  subject  js  note

- `syntax`: `Oniguruma`, `Ruby`, `Perl`, `Perl_NG`, `Java`, `Python`, or
  `Oniguruma+STRICT_BACKREF` (a copy of `OnigSyntaxOniguruma` with
  `ONIG_SYN_STRICT_CHECK_BACKREF` added).
- `encoding`: `UTF-8` or `ISO-8859-1`.
- `options`: comma-separated `ONIG_OPTION_*` suffixes (`IGNORECASE`,
  `IGNORECASE_IS_ASCII`, `EXTEND`, `MULTILINE`, `FIND_LONGEST`,
  `CAPTURE_GROUP`), empty for none.
- `pattern`: passed verbatim to `onig_new`.
- `subject`: UTF-8 text; `\xHH` is one byte (one code point U+00HH on the
  JavaScript side), `\u{H..}` a code point, `\\`, `\t`, `\n`.
- `js`: empty means the pattern verbatim (flag `i` if `IGNORECASE`);
  `/src/flags` gives the JavaScript spelling; `n/a: <clause>` marks a
  probe ECMA-262 2025 cannot express (not run, not counted).

## Result format

Offsets are in code points (the harness also prints byte offsets in
`result_bytes`):

- `M 0-2 | 1=0-1 2=-`: match `[0,2)`, group 1 `[0,1)`, group 2 unset;
- `N`: no match;
- `E <code> <message>`: compile error (Oniguruma) or `SyntaxError` (JS);
- `X <code> <message>`: search-time error (Oniguruma).

`cmp` is `same` when the Oniguruma result equals the JavaScript `u`-mode
result (two compile errors count as the same), `different` otherwise.
`js_marks`: `translated` (explicit `js` spelling), `js-flagged` (needs
`--js-regexp-modifiers` or `--js-regexp-duplicate-named-groups`),
`js-on-codepoints` (ISO-8859-1 probe run on the same code points in
UTF-16).

## Replay

    W=<workdir>
    cmake -S upstream -B $W/build -DCMAKE_BUILD_TYPE=Debug && make -C $W/build -j4
    cmake -S upstream -B $W/build-asan -DCMAKE_BUILD_TYPE=Debug \
      -DCMAKE_C_FLAGS="-fsanitize=address,undefined -fno-omit-frame-pointer" \
      -DCMAKE_EXE_LINKER_FLAGS="-fsanitize=address,undefined" \
      -DCMAKE_SHARED_LINKER_FLAGS="-fsanitize=address,undefined"
    make -C $W/build-asan -j4
    make -C probes BUILD=$W/build      OUT=$W/probes-build harness
    make -C probes BUILD=$W/build-asan OUT=$W/probes-build harness
    probes/run.sh $W/probes-build <out-dir>
