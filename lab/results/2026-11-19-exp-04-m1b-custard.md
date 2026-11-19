# exp-04 m1b-custard: mechanism 1b, C from F* + Pulse through Custard

## What

Mechanism 1, emitter 1b, of experiment #4 (issue #7): the same
generated `OnigStub` F\* + Pulse module as 1a
([m1a-krml entry](2026-11-19-exp-04-m1a-krml.md)), extracted with
Custard's direct C backend (`--codegen C --custard_entry_module
OnigStub --custard_c_no_prefix OnigStub`), compiled with its C shell
into `libonig.so.5` and checked for criteria 1-4.

## Why

Decision (b) on the issue: both F\* to C routes are measured, because
they may need different shells around the proofs.

## Provenance

As in the m1a-krml entry (same F\* 2026.11.15 release, same scripts:
`m1-pulse/build.sh` builds both emitters from one F\* check), plus
`m1-pulse/shell_custard_init.c`. Source-level run:
`EXTRA_CMAKE="-DEMITTER=custard" scripts/source-level.sh repo/upstream w
w/stubs/m1b scripts/m1-pulse <gen>/dc`.

## Data

Raw: [`2026-11-19-exp-04-raw/m1/`](2026-11-19-exp-04-raw/m1/)
(`m1b-*` files, `m1b-init.txt`, `m1b-noinit.txt`, `data_init.txt`).

### What Custard emits (probe and full stub)

| Construct | Custard direct C output |
|---|---|
| exported function | exact name with `--custard_c_no_prefix OnigStub` |
| record with function-typed fields | `struct onig_encoding_type_s { int32_t (*mbc_enc_len)(uint8_t *); ... };` |
| exact mixed-case data name | **yes**: `[@@ rename_let "OnigEncodingUTF8"]` gives `extern onig_encoding_type OnigEncodingUTF8;` |
| global record initialised with function pointers | **runtime initialisation**: the global is left zero (`B`, in `.bss`) and filled by `custard_init_globals()`, e.g. `OnigEncodingASCII = (onig_encoding_type){ .mbc_enc_len = s_mbc_enc_len, ... };`. Scalar globals get a static initialiser (`OnigDefaultCaseFoldFlag = 0x40000000U`, `D`) |
| pointer to another global, variadic definition | not expressible, as for 1a |

### Hand-written C shell (outside the proofs)

- `shell_custard_init.c`: a load-time constructor
  (`__attribute__((constructor))`) calling `custard_init_globals()`;
- `shell_data.c` (`OnigDefaultSyntax`) and `stub_shell.c` (variadic),
  shared with 1a; the CMake glue.

Without the constructor (same objects relinked without
`shell_custard_init.c`), `data_init` reads `OnigEncodingUTF8` as all
zero: `max_enc_len=0`, `mbc_enc_len=NULL` (`m1b-noinit.txt`). With it,
the values match 1a and the C stub.

### Criteria 1-4

| Check | default | POSIX |
|---|---|---|
| 1 symbols | 225: all 208 public, 0 kind or data-size mismatch; 114 internal missing; **17 extra** (16 `s_*` callbacks and `custard_init_globals`) | 233: all 216 public; same |
| 1 SONAME, three names | pass | pass |
| 2 layout, `layout.c` against shipped upstream headers | 10/10 | 12/12 |
| 2' layout of the generated structs vs upstream | identical | |
| 3 binaries | 22/22 pass | 24/24 pass |
| 4 CMake, pkg-config + client, emscripten + wasm client | pass, pass, pass | |

## Analysis

- **Binary drop-in: yes, at stub level, with a C shell; source
  drop-in: yes.**
- Custard removes 1a's rename layer (`rename_let` gives the exact
  names) but adds a different obligation: data symbols with function
  pointers are initialised by code, so the library needs a load-time
  constructor, outside the proofs, and the data is wrong for anything
  that reads it before constructors run. KaRaMeL's static initialisers
  do not have this problem.
- Outside the proofs, per criterion 5: the constructor, `OnigDefaultSyntax`,
  the variadic `onig_error_code_to_str` (Custard has no variadic
  definitions either), the build glue; `custard_init_globals` is an
  extra exported symbol.
