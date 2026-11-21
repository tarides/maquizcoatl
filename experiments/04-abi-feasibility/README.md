# Experiment #4: ABI feasibility per output mechanism

Scripts and stub sources for experiment #4 (issue #7, plan
`plans/04-abi-feasibility.md`). Results and verdicts are in the lab
notebook: `lab/results/2026-11-19-exp-04-*.md`, summary table in
`lab/results/2026-11-19-exp-04-verdicts.md`, superseded by
`lab/results/2026-11-20-exp-04-verdicts-m4.md` (all four mechanisms).

## Files

| Path | Role |
|---|---|
| `oracle.sh` | Release builds of upstream (default, POSIX), installed; `nm`, `readelf`, file names |
| `classify.py`, `symbols.tsv` | exported symbols classified public / internal, with declaring header line |
| `harness.sh` | the 24 harness binaries (7 tests, `testp`, 15 samples, `client_encoding`), layout references, golden outputs |
| `check-stub.sh` | criteria 1-3 for one installed stub prefix |
| `layout.c`, `layout_posix.c` | `sizeof` / `offsetof` / `_Alignof` of every non-opaque public struct |
| `client_encoding.c` | caller-filled `OnigEncodingType` (shared with experiment #5) |
| `variadic_call.c`, `data_init.c` | `onig_error_code_to_str` with and without its optional argument; data symbols read before any call |
| `source-level.sh` | criterion 4: CMake prefix, pkg-config + client, emscripten + wasm client |
| `m2-c/` | mechanism 2: C stub generator, data initialisers, variadic shell, CMake, `clightgen.sh` |
| `m2-why3/` | mechanism 2, Why3: WhyML ABI constructs extracted with `why3 extract -D c` |
| `m3-rust/` | mechanism 3: Rust `cdylib` stub, generator, naked trampoline, layout example, cbindgen check |
| `m1-pulse/` | mechanism 1: construct probe, F\* + Pulse stub generator, C shells for 1a (KaRaMeL) and 1b (Custard), CMake, generated-layout check |
| `m4-isabelle/` | mechanism 4: toolchain install (`install.sh`, adapted from experiment #5's `setup.sh`), stub generator for Isabelle-LLVM (`gen_isabelle_stub.py`), build into `libonig.so.5` (`build.sh`), construct probe (`probe.sh`) |
| `exports.sh` | export control: relinks the C stubs (and builds two Rust variants) with a version script of the public names from `symbols.tsv`; checks exports, visibility, data preemption (`-Bsymbolic` control) |
| `posix_syntax_size.c` | `onig_copy_syntax` into the `OnigSyntaxType` an `onigposix.h`-only client sees |

## Replay

On a Linux x86-64 host with GCC, CMake, binutils, patchelf, pkg-config,
Python 3; `<w>` is a work directory outside the repository and
`<upstream>` a checkout of `upstream/` at `f95747b`:

    oracle.sh <upstream> <w> 12
    python3 -I classify.py <upstream>/src <w>/oracle/default.nm <w>/oracle/posix.nm > symbols.tsv
    harness.sh <upstream> <w>
    check-stub.sh <w>/oracle/default default <w>          # validation: all pass
    m2-c/build.sh <upstream> <w> 12                         # also writes the -aux-info files
    check-stub.sh <w>/stubs/m2/default default <w>
    EMSDK_ENV=<emsdk>/emsdk_env.sh source-level.sh <upstream> <w> <w>/stubs/m2 m2-c <w>/stubs/m2/gen
    opam exec --switch <switch with why3> -- m2-why3/run.sh <w>
    opam exec --switch <switch with coq-compcert> -- m2-c/clightgen.sh <upstream> <w>
    m3-rust/build.sh <upstream> <w> 12                     # needs rustc/cargo >= 1.88
    m3-rust/cbindgen.sh <w> <path to cbindgen>
    m1-pulse/probe.sh <w>; m1-pulse/build.sh <upstream> <w> 12   # fstar.exe and krml on PATH
    m1-pulse/layout_gen.sh <w>

    m4-isabelle/install.sh <cache> <cpus> 16                # Isabelle2026, AFP, Isabelle-LLVM, LLVM 23.1.5
    m4-isabelle/build.sh <upstream> <w> <cache> 16          # after m2-c/build.sh and exports.sh
    m4-isabelle/probe.sh <w> <cache> 16

then `check-stub.sh` on `<w>/stubs/{m3,m1a,m1b,m4}/{default,posix}`, and
`exports.sh <upstream> <w> 8` (after both builds above). The lab entries
give the exact tool versions used.
