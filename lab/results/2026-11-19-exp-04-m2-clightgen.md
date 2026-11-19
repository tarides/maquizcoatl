# exp-04 m2-clightgen: VST's front end on the mechanism 2 C stub

## What

CompCert's `clightgen` (the front end VST proofs start from) run on the
hand-written C of mechanism 2: the generated stub (`stub.c`, its data
initialisers from `stub_data.h`), the POSIX part (`stub_posix.c`) and
the variadic `onig_error_code_to_str` (`stub_shell.c`). Last step of
milestone 1 in `plans/04-abi-feasibility.md`, boxed at 30 minutes.

## Why

For the VST route of mechanism 2 the proofs are about the hand-written
C itself, so criterion 5 depends on whether the verifier's front end
accepts the ABI-relevant constructs: file-scope struct initialisers
holding function pointers, a variadic definition with `va_list`, and
the pointers to opaque structs (`OnigCalloutArgs` is opaque in the
installed header, see the [oracle entry](2026-11-19-exp-04-oracle.md)).

## Provenance

- Script `experiments/04-abi-feasibility/m2-c/clightgen.sh`, inputs as
  built in the [m2-c-stub entry](2026-11-19-exp-04-m2-c-stub.md).
- Machine and pinning as in the oracle entry.
- Tools: a new opam switch `compcert` in the shared cache
  (`<cache>/opam`), OCaml 5.4.1, with the Rocq released repository
  (`rocq-released`, https://rocq-prover.org/opam/released) added for
  that switch only: `coq-compcert` 3.18 (`clightgen -version` prints
  3.17), Rocq 9.2.0 (the solver chose 9.2.0, not 9.3.0, for CompCert
  3.18), Menhir 20260209. Install about 10 minutes with 12 jobs, in the
  background while mechanism 3 ran. CompCert's licence is
  non-commercial for most of its sources: fine for a feasibility check,
  to be weighed if VST is chosen.
- Command: `opam exec --switch compcert -- scripts/m2-c/clightgen.sh
  repo/upstream w`, each file with and without `-normalize`.

## Data

Raw: [`2026-11-19-exp-04-raw/clightgen/`](2026-11-19-exp-04-raw/clightgen/)
(logs, versions, two excerpts of the Clight output).

| File | Construct | `clightgen` | `clightgen -normalize` |
|---|---|---|---|
| `stub.c` | 171 definitions; 30 `OnigEncodingType` initialisers with 16 function pointers each; 12 nested `OnigSyntaxType` initialisers; `OnigDefaultSyntax = &OnigSyntaxOniguruma` | accepted, `.v` produced, no message | same |
| `stub_posix.c` | 8 `onig_posix_*` functions, compiled with upstream's `regex_t` renaming | accepted | same |
| `stub_shell.c` | variadic `onig_error_code_to_str(OnigUChar*, int, ...)` with `va_start` / `va_arg(OnigErrorInfo*)` / `va_end` | accepted | same |

In the Clight output the encoding struct is a global with
`gvar_init := Init_addrof _s_mbc_enc_len ... :: Init_addrof
___stringlit_30 ...` (function addresses and the name string, field
for field), and the variadic function has `cc_vararg := Some 2`;
`va_start` becomes the builtin `__builtin_va_start` and `va_arg` a call
to the runtime helper `__compcert_va_int64` (`EF_runtime`).

## Analysis

- The front end accepts every ABI construct of the stub, including the
  variadic definition. Nothing in mechanism 2's C has to be rewritten
  for VST's input language.
- What this does not show: whether VST can *prove* anything about
  `onig_error_code_to_str`. After `clightgen` the variadic access is a
  call to CompCert runtime externals (`__compcert_va_int64`, builtins
  `__builtin_va_start`/`_end`) that VST would need specifications for;
  without them the variadic function stays outside the proofs, as for
  the other mechanisms. Checking VST's support for these builtins is
  not part of this run.
