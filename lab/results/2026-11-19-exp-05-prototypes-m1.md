# exp-05 prototypes-m1: Why3, F\* + Pulse and Verus call client C pointers

## What

Approach steps 5 to 8 of `plans/05-unverified-calls.md` for milestone 1
of experiment 5 (issue #13): one prototype per tool of the four
verified functions of `proto.h` (`vu_char_len`, `vu_callout_step`,
`vu_i_apply` with `vu_fold_all`, `vu_get_slot` with `vu_set_slot`), its
proof, its link with `caller/caller.c`, its negative control, and its
trusted-line count. Raw outputs, all redacted by the scripts, are in
[`2026-11-19-exp-05-prototypes-m1-raw/`](2026-11-19-exp-05-prototypes-m1-raw/).
The summary table is
[`experiments/05-unverified-calls/table.md`](../../experiments/05-unverified-calls/table.md).

## Why

Every libonig entry point that takes a client function pointer
(encodings, callouts, `apply_all_case_fold`) needs verified code to call
unverified C, and to be called back by it. A tool that cannot do this
with a usable specification is ruled out before the comparison wave.

## Setup

- Prototypes: `experiments/05-unverified-calls/{why3,pulse,verus}/`,
  each with a `build.sh` that follows `run.sh`'s contract, a `TRUSTED`
  file and a `negative-control.txt`.
- Bench host, as in the `toolchains-m1` entry: AMD EPYC 7502P, Ubuntu
  24.04.5, Linux 6.8.0-100, GCC 13.3.0. Tool versions and machine
  details are in `provenance.txt` (recorded with the Pulse run; the
  same toolchains served the three runs).
- Each tool ran from a copy of the harness in `<exp>/build/<tool>/harness`
  whose files have the same sha256 as the committed ones; builds are in
  `<exp>/build/m1-<tool>/<tool>`.
- CPUs, under `nice`, 4 jobs: Why3 on 56-59, Pulse and Verus on 28-31.
  Another experiment pinned 16-23 and 48-55 at the time; those and 4-7,
  36-39 were not used.
- Commands: `run.sh <tool> m1-<tool>`, then `run.sh -n <tool> m1-<tool>`
  (negative control), then `count-trusted.sh why3 pulse verus`.

## Results

| Tool | Normal run | Wall, peak RSS | Negative control | Trusted lines | Verdict |
|---|---|---|---|---|---|
| Why3 1.9.0 | 57/57 goals valid with Alt-Ergo and with Z3; `link=ok`, `caller_output=same` | 6.2 s, 92 MiB | rejected: `vu_char_len`'s range postcondition times out with both provers (Alt-Ergo 10.00 s, Z3 8.76 s), the 56 other goals stay valid | 124 | works with trusted shim |
| F\* 2026.11.15 + Pulse, krml `3384ecaf` | verified, extracted (`Custard.c` 305 lines), ABI checks pass; `link=ok`, `caller_output=same` | 6.1 s, 315 MiB | rejected: F\* error 19, "Failed to prove" the `min` and `max` conjuncts of the range | 25 | works |
| Verus 0.2026.11.02.8bf68ee, Rust 1.99.1 | 17 verified, 0 errors; `link=ok`, `caller_output=same` | 1.2 s, 334 MiB | rejected: "postcondition not satisfied" on the range (16 verified, 1 error) | 87 | works with trusted shim |

In every control, the failing goal shows that the declaration of the
encoding callee gives its result no range, so no over-strong
assumption can make the clamp-free proof pass.

Trusted lines (`trusted.tsv`, by `count-trusted.sh`):

| Tool | File | Lines |
|---|---|---|
| Why3 | `vu.mlw:13-186` (module `Client`: abstract types for the pointers, `void *` and the structs; field accessors; indirect-call vals with their client contracts) | 96 |
| Why3 | `vu.drv` (one C expression per type and val of `Client`) | 28 |
| Pulse | `VU.fst`: callee contracts and the predicates they use | 13 |
| Pulse | `abi_check.c:21-32`: the expected C type of each generated function | 12 |
| Verus | `src/shim.rs`: opaque pointer types, three `external_body` indirect calls with empty specifications | 25 |
| Verus | `src/ffi.rs`: the six `extern "C"` entry points, NULL checks, layout assertions | 62 |

## Per tool

### Why3 (C fragment)

- **Modelling style:** trusted shim at driver level. Why3's C fragment
  has no type for function pointers, `void *` or struct fields, so a
  model module (`Client`) declares them abstractly and the driver gives
  each its C expression, for example `call_enc_len "%1(%2)"`. Each call
  has a client contract (a `val` with `writes` and `ensures`).
- **Proven:** `vu_char_len`'s result is in `[min, max]`, `st` is
  unchanged, the callee is called once. `vu_callout_step` follows the
  three rule sets (progress, retraction, each-match) and keeps
  `subject_len`, `pos` and `num`; an invalid `dir` gives -30 and no
  call. `vu_i_apply` has an exact effect, which satisfies the relation
  `evolves` (proven reflexive and transitive); `vu_fold_all` keeps the
  record well formed and its recorded prefix. The accessors are bounds
  checked.
- **Callee assumptions:** terminates (no `diverges`, so no `longjmp`);
  the encoding writes no verified-side state; the callout writes only
  the slots, through `vu_set_slot`; `apply_all` changes the record only
  by calling `vu_i_apply`. The constants of `Client` are assumed to
  match `proto.h`; pointers of different model types are assumed not to
  alias.
- **Re-entrancy:** (a) works; Why3 cannot take a function's address, so
  `vu_i_apply`'s pointer comes from the trusted driver entry
  `i_apply_ptr`. (b) works; the accessors are external symbols that
  `co_slots` calls by name.
- **Build note:** `vu_i_apply` keeps `proto.h`'s unused `to` parameter,
  so the C compiler warns; the build passes
  `-Wno-error=unused-parameter`, and the warning stays in `build.log`.

### F\* + Pulse with KaRaMeL

- **Modelling style:** client contract. A Pulse parameter of function
  type, for example `(q: ref U8.t) -> stt I32.t pre post`, becomes a C
  function pointer; erased binders are dropped from the pointer type,
  and a higher-order pointer (`vu_fold_all`'s `g`) also works. There is
  no shim, no axiom and no `assume val`.
- **Proven:** `vu_char_len`'s range for any callee result, with `st`
  and `*p` unchanged (from the frame). `vu_callout_step` as relations
  separate from the code, for all three directions; only the slots may
  change. `vu_i_apply` has an exact spec and holds no permission on
  `to`. The accessors are bounds checked. `user_data` is opaque: the
  verified code holds no permission on it.
- **Callee assumptions:** partial correctness, so callees may diverge;
  the encoding gets a read fraction of `*p`; the callout owns `*args`
  during the call and must restore the verified-side fields (writes
  outside the slots are excluded at return only, not during the call);
  `apply_all` gets `vu_i_apply` and returns the record well formed.
- **Re-entrancy:** (a) and (b) both work; `vu_i_apply` is passed as its
  C symbol.
- **ABI:** `abi_check.c` compiles the expected prototypes against the
  generated header, and `layout.c` compares the struct layouts of
  `proto.h` and of the generated header (they are equal). F\* records
  cannot hold inline arrays, so the slots are consecutive scalar fields
  with the same layout. `void *` is written `uint8_t *` or
  `vu_fold_rec *` on the generated side: equivalent on the SysV x86-64
  ABI, though not a compatible type in ISO C.
- **Finding: eta-reduction drops a parameter.** A Pulse `fn` whose body
  is a tail call ending with the function's own last parameter is
  eta-reduced in the Custard IR, and the extracted C function loses that
  parameter, with no warning. `pulse/probes/EtaD.fst` proves that
  `eta_d g a` returns `g a`; both KaRaMeL and Custard's direct C backend
  emit `int32_t (*eta_d(int32_t (*g)(int32_t *)))(int32_t *) { return g;
  }`, which compiles and links; a caller with the two-argument
  prototype gets a wrong value and `g` is never called
  (`pulse/probes/eta-output.txt`). In the prototype, `vu_fold_all`
  first became `return g(vu_i_apply);`, which did not compile. The
  workaround binds the result first (verified, not trusted), and
  `abi_check.c` rejects the reduced form. This may be worth reporting
  upstream.

### Verus

- **Modelling style:** trusted shim. Verus cannot type or call a C
  function pointer: each pointer is an opaque `external_body` struct,
  and each indirect call an `external_body` function that only calls
  and returns the raw `i32`, with no `ensures`. Clamping and branching
  stay in verified code. `verus --no-cheating` rejects exactly the
  three shims.
- **Proven:** `vu_char_len`'s range whenever `min <= max` (no
  precondition needed), and `st` unchanged. `vu_callout_step` returns
  `step_rule(dir, r)` for the callee's result `r`, for the three
  directions; `args`'s verified-side fields are unchanged, because the
  verified code saves them and writes them back after the call (a dev
  run without the restore fails that postcondition). `vu_i_apply` meets
  its spec. `vu_set_slot` changes only slot `k`.
- **Callee assumptions:** terminates and returns an `int`; memory safe
  outside what it is lent; nothing on the result's range or on what the
  callout writes into `args`. The C caller is trusted for valid, aligned,
  non-NULL pointers that nobody else writes while a reference is held.
- **Re-entrancy:** (a) works, each call meets `vu_i_apply`'s spec, but
  nothing is proven across the client's sequence of calls (that would
  need a client contract). (b) works; references are reborrowed from the
  raw pointer during the callout, which our reading of Rust's aliasing
  rules allows (Miri was not run).
- **Output:** native code from rustc as a staticlib (`libvu.a`, 24 MB
  with std and vstd). A dev build of the caller with ASan and UBSan gave
  the expected output and no report.

## Outputs and disk

| Tool | Generated code (not committed) | `<exp>` use |
|---|---|---|
| Why3 | `vu.c`, 101 lines, sha256 `13517908d05ff305cd101116301fb9e429cf33b85e677848df8f9a267084cb07` | under 2 MB |
| Pulse | `Custard.c`, 305 lines, sha256 `2c86481c5f9400be362ffae828994b11e012413de6d8bc44219b743078f9c783`; `Custard.h`, 76 lines, sha256 `7df09e629b25c0c4a5cd89ce761d1a525d22988bffa2f58c345a267032127de9` | 2.2 MB |
| Verus | `libvu.a`, 24,479,232 bytes, sha256 `135a0186db432c91e89e2b9dd29a018bbd8a56aa66d5db98db4983162fd28ac9` | 63 MB |

Nothing was added to `<cache>` by the prototypes. About 101 GB remain
free on the bench host.

## Deviations

- Builds are in `<exp>/build/m1-<tool>/<tool>` (the `run.sh` layout),
  not directly in `<exp>/build/<tool>/`, which holds the harness copy
  and exploratory work.
- Runs used a harness copy per tool instead of `<exp>/repo`, so that
  three tools could be worked on in parallel without touching the
  shared clone. `provenance.txt` therefore reads `repo_commit: unknown`;
  the committed files have the same sha256 as the copies that ran.
- `provenance.sh` was run for the Pulse run only. Its tool versions
  cover the three tools.

## Open points

- Why3: keep `-Wno-error=unused-parameter`, or add a trusted driver
  no-op that emits `(void)to` (2 trusted lines)?
- Pulse: report the eta-reduction bug upstream?
- No independent review agent was available to the prototype runs;
  each was checked by its provers, the caller comparison and the
  negative control.

## Verdicts

- Why3 (C extraction): **works with trusted shim** (124 lines).
- F\* + Pulse with KaRaMeL: **works**.
- Verus: **works with trusted shim** (87 lines).
