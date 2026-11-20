# exp-04 m4-isabelle-llvm: mechanism 4, stub exported by Isabelle-LLVM

## What

Mechanism 4 of experiment #4 (issue #7, plan step 7): a stub of the
whole public API written as Isabelle-LLVM definitions, generated
mechanically from the public headers, exported to LLVM IR by
`export_llvm`, compiled by clang 23.1.5, linked with a hand-written C
shell into `libonig.so.5` (default and POSIX variants, public-only
version script as decided in DEV-005), and checked for criteria 1-3.
A construct probe records which ABI constructs Isabelle-LLVM's export
can express. Criterion 4 is predicted, not measured (decision (b) on
the issue).

## Why

Mechanism 4 was deferred in the first run because its session build
had to run alone on the bench host. It is the last row of the results
table that the maintainer's choice of output mechanism reads.

## Provenance

- Branch `exp/04-abi-feasibility` at `723c1d2` plus the new scripts in
  `experiments/04-abi-feasibility/m4-isabelle/` (`gen_isabelle_stub.py`,
  `build.sh`, `probe.sh`); upstream `f95747b`.
- Toolchain from the [m4-toolchain entry](2026-11-20-exp-04-m4-toolchain.md):
  Isabelle2026, AFP `afp-2026-11-19`, Isabelle-LLVM `e42f4781`, LLVM
  23.1.5 (clang compiles the IR and the C shell; `-fuse-ld=bfd`, GNU ld
  2.42). The harness, oracle and version scripts are those of the first
  run (`w/harness`, `w/oracle`, `w/exports/onig-{default,posix}.map`;
  test binaries built with GCC 13.3.0).
- Bench host: AMD EPYC 7502P, 503 GiB RAM, Ubuntu 24.04.5, Linux
  6.8.0-100; idle (load average below 2, no other experiment running),
  CPUs 16-31, nice 10.
- Commands, from `<bench-workdir>/exp/04-abi-feasibility`:
  - `taskset -c 16-31 scripts/m4-isabelle/build.sh repo/upstream w <cache> 16`
    (14:18:20Z to 14:18:44Z, 24 s; the session `Onig_Stub_M4` took 6 s
    elapsed, peak RSS 3.7 GB). A first attempt at 14:17:43Z failed only
    on the example proof (postcondition `sint.assn 0 r` left the goal
    `ENTAILS □ (sint.assn 0 0)`); the generator now states it as
    `\<up>(r = 0)`, which `vcg'` closes.
  - `scripts/check-stub.sh w/stubs/m4/{default,posix} {default,posix} w`
  - `bin-variadic_call` and `bin-data_init` against `w/stubs/m4/default`
  - `taskset -c 16-31 scripts/m4-isabelle/probe.sh w <cache> 16`
    (14:22:59Z to 14:25:53Z).

## Data

Raw (redacted): [`2026-11-20-exp-04-raw/m4/`](2026-11-20-exp-04-raw/m4/):
`m4-default.tsv`, `m4-posix.tsv` (criteria 1-3), `runs.txt`,
`build/` (generated theories, IR, Isabelle's generated headers,
`mapping.tsv`, `sizes.c`, step logs), `probe/` (`results.tsv`,
`headers.txt`, one log per probe).

### Criteria 1-3

| | default | POSIX |
|---|---|---|
| exported functions from Isabelle-LLVM IR | 163 | 171 (163 + 8 `onig_posix_*`) |
| hand-written C | variadic `onig_error_code_to_str`, 44 data symbols | same |
| 1 public symbols exported | 208 / 208 | 216 / 216 |
| 1 leaked internals (114) | not exported (DEV-005) | not exported |
| 1 extra symbols | 0 | 0 |
| 1 kind or data-size mismatch | 0 | 0 |
| 1 SONAME, three names | pass | pass |
| 2 layout | 10 / 10 structs pass | 12 / 12 pass |
| 3 binaries (load and link) | 22 / 22 pass | 24 / 24 pass |

Criteria 1-3 rows are byte-identical to those of the mechanism 2 stub
relinked with the same version script (`exports/m2-vs-*.tsv` of the
first run), exit statuses included (crashes after load at the first
wrong result, as for every stub). `variadic_call` gives the same output
as mechanism 2 (`13 [stub error -5]`, `27 [stub error -217 (with
name)]`), and `data_init` reads every data symbol before any call as
the C stubs do.

### Type mapping (outside the proofs)

`export_llvm` signatures accept only `char`, `int8_t`..`int64_t`,
`uint8_t`..`uint64_t`, `float`, `double`, pointers and named struct or
union typedefs (`thys/basic/kernel/LLVM_Codegen.thy:1770-1818` at
`e42f4781`). The generator maps every public C type to an
ABI-equivalent one on x86-64 LP64; `sizes.c` asserts size and
alignment of each (`_Static_assert`, passes):

| C type in the public prototypes | Exported as |
|---|---|
| `int`, the enums `OnigCalloutIn`, `OnigCalloutType`, `OnigRegSetLead`, `OnigType` | `int32_t` |
| `unsigned int`, `OnigCodePoint`, `OnigCaseFoldType`, `OnigOptionType` | `uint32_t` |
| `size_t`, `long unsigned int` | `uint64_t` |
| every pointer, the pointer typedefs `OnigEncoding`, `OnigRegex` and the function-pointer typedefs `OnigWarnFunc`, `OnigCalloutFunc`, `OnigCallbackEachMatchFunc` | `uint8_t*` |

Isabelle-LLVM prints typed pointers (`i8*`), which LLVM 23 reads as
opaque `ptr`; the IR carries its own `target datalayout`
(`p:64:64:64`) and triple `x86_64-pc-linux-gnu`, which clang overrides
with `x86_64-unknown-linux-gnu` (warning `-Woverride-module`, the only
diagnostic of the build). The header Isabelle-LLVM generates
(`build/OnigStub.h`) declares the mapped types, with empty parameter
lists written `()` (unprototyped before C23); it cannot be shipped, so
the stub ships upstream's headers, as all other mechanisms.

### Construct probe (`probe/results.tsv`)

| Construct the ABI needs | Result |
|---|---|
| fixed-width signature (control) | accepted |
| C type `int` in a signature | rejected: `identifier expected, but keyword int was found` |
| `const` in a signature | rejected, same error |
| variadic definition `int32_t f (int32_t, ...)` | rejected: `Outer lexical error: bad input ... at ...)`; also with the signature in a cartouche |
| function-pointer parameter `int32_t (*)(int32_t)` | rejected: `Outer lexical error: unclosed comment ... at (*)(int32_ ...`; also in a cartouche: the inner parser uses Isabelle's lexer, where `(*` opens a comment |
| struct typedef with plain fields (`defines`) | accepted, header shows the declared layout |
| struct typedef with a function-pointer field, `typedef struct { int32_t (*len)(uint8_t*); int32_t min; } enc;` | **accepted silently with the wrong layout**: the generated header has `int32_t field0; int32_t min;`; `(*len)(uint8_t*)` was lexed as a comment and the field read as an anonymous `int32_t` |
| global data definition (the 44 data symbols) | no construct: the IR builder prints only `define` and `declare` of functions (`thys/basic/kernel/LLVM_Builder.ml:814`, `:878`; no `global` anywhere in it) |
| call through a function pointer | no HOL-level type: function pointers exist only inside the ML IR builder (`TFptr`, `LLVM_Builder.ml:440`), used for its parallel-call wrapper (`:1174`); inferred from the sources, not probed |

### Inside and outside the proofs (criterion 5)

- Inside: the 163 / 171 function bodies, HOL definitions in
  Isabelle-LLVM's monad, exported by the code generator whose output
  the Isabelle-LLVM semantics describes. One Hoare triple was proved
  over the exported code (`c_onig_end_correct`, `vcg_monadify` and
  `vcg'`), to show the route from proof to exported symbol.
- Outside: the 44 data symbols (C, the same initialisers as mechanism
  2); the variadic `onig_error_code_to_str` (mechanism 2's `va_list`
  C); the C type mapping of every signature (checked by size and
  alignment, not proved; signedness is a property of the header only);
  the shipped headers (upstream's, not the generated ones); clang's
  compile of the IR with the overridden triple; the version script,
  soname and the three names. A real implementation would also need C
  for every call through a function pointer: the encoding vtables
  (`OnigEncodingType`, client-filled in `client_encoding.c`), the warn
  and callout callbacks and `onig_foreach_name` style iterators.

## Analysis

- Binary drop-in at stub level: yes. Linkage, names, layouts and the
  24 binaries behave exactly as for the hand-written C stub.
- Mechanism 4 has the largest hand-written C layer of the mechanisms
  measured: like Why3, it cannot produce the data half of the ABI; unlike
  every other route, it also cannot name any C type other than
  fixed-width integers, so the correspondence between upstream's
  prototypes and the verified code rests on an unverified mapping table.
- The silent mis-parse of a function-pointer field in `defines` is a
  hazard for any future use of Isabelle-LLVM's header generator with
  Oniguruma's structs: it produces a wrong layout without an error.
  Here it does not matter because the generated headers are not shipped.
- Criterion 4 (predicted "binary level only", stack F): consistent with
  what was seen. The IR fixes the data layout and triple at export
  time, so a source build for another target (emscripten, 32-bit)
  would need Isabelle to re-export, or a different layout in the
  generator; not measured.
- Not covered: behaviour (the stub returns fixed values), and whether
  Isabelle-LLVM can call a C shim for function-pointer calls through
  an external declaration from HOL (`mk_external_call` exists in the ML
  builder; its HOL-level exposure was not checked).
