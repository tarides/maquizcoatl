# exp-04 m3-rust-cdylib: mechanism 3, Rust `cdylib`

## What

Mechanism 3 of experiment #4 (issue #7): a Rust `cdylib` stub
(edition 2024) with `#[repr(C)]` mirrors of the public structs, the 44
public data symbols as `#[unsafe(no_mangle)] pub static mut`, and one
generated `extern "C"` function per public function; checked against
the oracle ([oracle entry](2026-11-19-exp-04-oracle.md)) for criteria
1-3; layout checked twice (Rust `offset_of!` output, and `layout.c`
compiled against a `cbindgen` header); the variadic
`onig_error_code_to_str` tried directly in Rust, then by two routes
through a C shim. Criterion 4 is predicted, not run (decision (b) on
the issue).

## Why

Stacks A, B, D and E (via Creusot) would ship a Rust library behind the
C ABI. The questions are whether stable Rust can emit every ABI
construct (exact data symbol names, structs of function pointers, a
C-variadic definition, SONAME and file names) and what stays outside
the Rust code.

## Provenance

- Branch `exp/04-abi-feasibility`, `experiments/04-abi-feasibility/m3-rust/`
  (`Cargo.toml`, `build.rs`, `src/lib.rs`, `gen_rust_stub.py`,
  `examples/layout.rs`, `variadic_try.rs`, `cbindgen.toml`,
  `cbindgen.sh`, `build.sh`); the C shim is
  `m2-c/stub_shell.c`, shared with mechanism 2.
- Machine and pinning as in the [oracle entry](2026-11-19-exp-04-oracle.md).
- Tools: rustc 1.96.0 (ac68faa20 2026-05-25), cargo 1.96.0 (stable,
  rustup, already on the host; newer than the 1.93.1 named in the plan),
  no crate dependencies; cbindgen 0.29.4 (`cargo install`, into
  `<bench-workdir>/cache/cargo`); GCC 13.3.0 for the shim and the
  layout program.
- Commands: `scripts/m3-rust/build.sh repo/upstream w 12` (three
  release builds, about 1 s each, plus the layout example),
  `scripts/check-stub.sh w/stubs/m3/{default,posix,noexport} ... w`,
  `scripts/m3-rust/cbindgen.sh w <cache>/cargo/bin/cbindgen`.

## Data

Raw: [`2026-11-19-exp-04-raw/m3/`](2026-11-19-exp-04-raw/m3/) (check
TSVs per variant, `variadic_try.log`, Rust layout outputs, the
cbindgen header, the generated POSIX function file, the trampoline
disassembly).

### Variadic `onig_error_code_to_str`

| Route | Result |
|---|---|
| Rust definition `extern "C" fn ...(s, code, mut args: ...)` (`variadic_try.rs`) | rejected by stable rustc 1.96.0: `error[E0658]: C-variadic functions are unstable` (rust-lang/rust#44930), plus E0658 on `VaList::arg` (`c_variadic`) |
| C shim (`stub_shell.c`) linked into the cdylib as a whole-archive static library, with `-Wl,--export-dynamic-symbol=onig_error_code_to_str` (variant `noexport`) | symbol **absent** from the library: rustc's version script makes non-Rust symbols local and the linker garbage-collects the unreferenced object; every harness binary fails with 1 undefined symbol (`exit 127`, `symbol lookup error`) |
| C shim body renamed `onig_stub_error_code_to_str_c`, exported name defined in Rust as a `#[unsafe(naked)]` function whose body is `jmp` to the C body (variants `default`, `posix`) | pass: `onig_error_code_to_str` exported as `T`; disassembly `jmp onig_stub_error_code_to_str_c`; `variadic_call` gets both forms (`stub error -5`, `stub error -217 (with name)`), as with the C stub |

### Criteria 1-3

| Check | default | POSIX | noexport (shim linked directly) |
|---|---|---|---|
| 1 symbols | 208 of 322 (all public; 114 internal missing; 0 extra; 0 kind or data-size mismatch) | 216 of 330 (all public; same 114 missing) | 207: `onig_error_code_to_str` missing |
| 1 SONAME `libonig.so.5` (`-Wl,-soname` from `build.rs`) | pass | pass | pass |
| 1 three file names (cargo emits `libonig.so`; the install step makes `libonig.so.5.5.0` and the two symlinks) | pass | pass | pass |
| 2 layout, `layout.c` against shipped upstream headers | 10/10 | 12/12 | 10/10 |
| 3 binaries, load and link | 22/22 pass | 24/24 pass | 0/22 (1 undefined each) |

Layout of the Rust types themselves: `examples/layout.rs` prints
`size_of`, `offset_of!` and `align_of` in `layout.c`'s format; identical
to upstream for all 10 structs and the 2 POSIX structs (`diff` empty).
`cbindgen` header (style `both`, needed because `OnigEncodingType` and
`OnigCaptureTreeNode` refer to themselves): `layout.c` and
`layout_posix.c` compile against it and their output is identical to
upstream's.

### Criterion 4 (predicted, not measured)

Report verdict for stacks B and D: **source level needs Rust**. A
client building libonig from source needs rustc and cargo (edition
2024, rustc >= 1.88 for `#[unsafe(naked)]`) and a C compiler for the
shim, a build glue that installs the three names and an
`oniguruma.pc`; an emscripten build needs the `wasm32-unknown-emscripten`
Rust target. Not run, per decision (b).

## Analysis

- **Binary drop-in: yes, at stub level, on stable Rust**, with one
  piece of C: the variadic body. Exact mixed-case data symbol names,
  statics holding function-pointer tables, all public functions, the
  SONAME and the struct layouts come from Rust without workarounds;
  `static mut` is needed because the structs contain raw pointers
  (not `Sync`).
- **Outside the Rust code (and any Rust proof):** the C body of
  `onig_error_code_to_str` (the `va_list` handling), the naked
  trampoline's `jmp` (inline assembly), the soname link argument and the
  install step that creates the three file names. The obvious route,
  linking a C object into the cdylib, does not work: rustc's export
  list hides it. Once `c_variadic` is stabilised the shim and the
  trampoline can go.
- The function signatures generated here map every pointer to
  `*mut c_void` and C enums to `c_int` (ABI-equivalent on x86-64); a
  real implementation would use the typed `#[repr(C)]` structs, which
  this run shows have the right layout.
- Same 114 leaked internals missing as mechanism 2; no harness binary
  needs them.
