# exp-04 verdicts: criteria 5 and 6 for mechanisms 1a, 1b, 2, 3

## What

Criteria 5 (inside / outside the proofs at the ABI boundary) and 6
(verdict) of experiment #4 (issue #7) for the mechanisms measured in
this run: 1a (F\* + Pulse, KaRaMeL), 1b (F\* + Pulse, Custard), 2 (C
proven directly: hand-written C for VST, and Why3 extraction), 3 (Rust
`cdylib`). Mechanism 4 (Isabelle-LLVM) is deferred. No new
measurement: this entry draws on the
[oracle](2026-11-19-exp-04-oracle.md),
[m2-c-stub](2026-11-19-exp-04-m2-c-stub.md),
[m2-clightgen](2026-11-19-exp-04-m2-clightgen.md),
[m3-rust-cdylib](2026-11-19-exp-04-m3-rust-cdylib.md),
[m1a-krml](2026-11-19-exp-04-m1a-krml.md) and
[m1b-custard](2026-11-19-exp-04-m1b-custard.md) entries.

## Why

Experiment #4 is an eliminator: a mechanism that cannot give a drop-in
is a candidate for elimination. These verdicts are what the
maintainer's decision reads.

## Provenance

Same run, same bench host, same commit as the entries above. Verdicts
are at **stub level**: functions return fixed values, so they cover
linkage, names, layout and the build, not behaviour.

## Data: results table

| | 1a F\*/Pulse, KaRaMeL | 1b F\*/Pulse, Custard | 2 hand-written C (VST) | 2 Why3 to C | 3 Rust `cdylib` | 4 Isabelle-LLVM |
|---|---|---|---|---|---|---|
| 1 public symbols (208 default / 216 POSIX) | all | all | all | not built (see below) | all | deferred |
| 1 leaked internals (114) | not exported | not exported | not exported | | not exported | |
| 1 extra symbols | 16 (callbacks) | 17 (+ `custard_init_globals`) | 0 | | 0 | |
| 1 SONAME, three names | pass | pass | pass | | pass | |
| 2 layout (10 / 12 structs) | pass | pass | pass | | pass (Rust types and cbindgen header too) | |
| 3 binaries (22 / 24) | pass | pass | pass | | pass | |
| 4 CMake / pkg-config / emscripten | pass / pass / pass | pass / pass / pass | pass / pass / pass | | predicted: needs Rust | predicted: binary level only |

Why3 was checked at construct level only: its C extraction cannot emit
the 44 data symbols (names lower-cased, record constants become
functions, function-typed fields and `val` globals dropped), so a
Why3 stub is the extracted functions plus mechanism 2's hand-written C
for everything else; it would score as the hand-written row with a
larger unverified part.

## Criterion 5: inside and outside the proofs

| Mechanism | Inside (generated from, or written in, the verified source) | Outside (hand-written, unverified) | `onig_error_code_to_str` |
|---|---|---|---|
| 1a KaRaMeL | all 163/171 functions; the 30 encoding and 12 syntax records with their function pointers, statically initialised; the case-fold flag; struct layouts | 43 data-symbol renames (`#define onigEncodingUTF8 OnigEncodingUTF8`, force-included), `OnigDefaultSyntax`, build glue | C, outside: KaRaMeL has no variadic definitions |
| 1b Custard | same, with exact names via `rename_let` | load-time constructor calling `custard_init_globals()` (records are initialised by code), `OnigDefaultSyntax`, build glue | C, outside: no variadic definitions |
| 2 hand-written C, VST | all of it is C that `clightgen` accepts, including the variadic and the initialisers | build glue only | C `va_list`, accepted by `clightgen`; lowered to CompCert runtime helpers (`__compcert_va_int64`) that VST would need specifications for |
| 2 Why3 | exported functions with lower-case names | the 44 data symbols, the encoding function-pointer tables, every mixed-case name; build glue | C, outside: WhyML has no variadics |
| 3 Rust | all functions, the 44 data symbols with exact names, function-pointer tables, layouts (in Rust; a Rust verifier such as Verus or Creusot would sit here) | the C body of the variadic, a 1-instruction naked trampoline (inline asm) exporting it, the soname link argument and the install step making the three names | C body behind a Rust `#[unsafe(naked)]` trampoline: stable Rust rejects C-variadic definitions (E0658), and a C object linked into a cdylib is not exported |
| 4 Isabelle-LLVM | deferred | | |

## Criterion 6: verdicts

| Mechanism | Binary drop-in | Source drop-in | Blocker / condition |
|---|---|---|---|
| 1a F\*/Pulse, KaRaMeL | yes (stub level) | yes (measured) | none; a rename layer for the 43 data names |
| 1b F\*/Pulse, Custard | yes (stub level) | yes (measured) | none; a load-time constructor for data initialised by code |
| 2 C, VST | yes (stub level) | yes (measured) | none at the front end; VST support for `va_arg` builtins unchecked |
| 2 C, Why3 | yes only with a hand-written C data layer | yes, same build as the C stub | Why3's C extraction cannot produce the data half of the ABI |
| 3 Rust `cdylib` | yes (stub level) | predicted: needs Rust | stable Rust: variadic needs C plus a naked trampoline |
| 4 Isabelle-LLVM | deferred | predicted: binary level only | not run: must run alone on the bench host (issue #7 scheduling note); experiment #11 was timing benchmarks there |

## Analysis

- No mechanism is eliminated by the ABI at stub level. Every route
  needs a small hand-written shell; its contents differ and are listed
  above. The variadic `onig_error_code_to_str` is outside the proofs in
  every mechanism measured, VST included in practice.
- The 114 leaked internal symbols (106 functions, 8 data) are exported
  by upstream but needed by none of the 24 harness binaries. Whether a
  drop-in must export them (for third-party code linking to internals)
  is a scope question for the maintainer, not answered here.
- Differences that matter for a choice: KaRaMeL keeps data static but
  cannot name it; Custard names it but initialises it at run time; Why3
  cannot produce the data at all; Rust needs C only for the variadic.
- Not covered: behaviour (stubs), the callout and client-encoding paths
  beyond linkage, Isabelle-LLVM.
