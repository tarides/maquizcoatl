# exp-05 prototypes-m2: Charon + Aeneas, VST + CompCert and Isabelle-LLVM call client C pointers

## What

Approach steps 5 to 8 of `plans/05-unverified-calls.md` for milestone 2
of experiment 5 (issue #13): one prototype per tool of the four
verified functions of `proto.h` (`vu_char_len`, `vu_callout_step`,
`vu_i_apply` with `vu_fold_all`, `vu_get_slot` with `vu_set_slot`), its
proof, its link with `caller/caller.c`, its negative control, and its
trusted-line count. Raw outputs, all redacted by the scripts, are in
[`2026-11-20-exp-05-prototypes-m2-raw/`](2026-11-20-exp-05-prototypes-m2-raw/).
The summary table is
[`experiments/05-unverified-calls/table.md`](../../experiments/05-unverified-calls/table.md).

## Why

Every libonig entry point that takes a client function pointer
(encodings, callouts, `apply_all_case_fold`) needs verified code to call
unverified C, and to be called back by it. A tool that cannot do this
with a usable specification is ruled out before the comparison wave.

## Setup

- Prototypes: `experiments/05-unverified-calls/{aeneas,vst,isabelle-llvm}/`,
  each with a `build.sh` that follows `run.sh`'s contract, a `TRUSTED`
  file and a `negative-control.txt`.
- Bench host and toolchains as in the `toolchains-m2` entry: AMD EPYC
  7502P, Ubuntu 24.04.5, Linux 6.8.0-100, GCC 13.3.0. Tool versions
  and machine details are in `provenance-vst.txt` and
  `provenance-isabelle-llvm.txt`; there is none for the Aeneas run (see
  Deviations).
- As in milestone 1, each tool ran from a copy of the harness in
  `<exp>/build/<tool>/harness` whose files have the same sha256 as the
  committed ones (checked after the runs); builds are in
  `<exp>/build/<run-id>/<tool>`.
- CPUs, under `nice`, 4 jobs: Aeneas on 50-53, VST on 24-27,
  Isabelle-LLVM on 40-43. The pins were checked before each run. Other
  pinned jobs were seen at times on 24-25, 24-27 and 40-43, which are
  also the CPU sets of this milestone's own runs; no run shared its CPUs
  with a pinned job, and 4-7 and 36-39 were never used. No other
  Isabelle or Poly/ML process ran during the Isabelle-LLVM runs.
- Commands: `run.sh <tool> <run-id>`, then `run.sh -n <tool> <run-id>`
  (negative control), then `count-trusted.sh aeneas vst isabelle-llvm`.
  Run ids: `m2-aeneas-3` (2026-11-20, about 11:05 UTC), `m2-vst`
  (11:28-11:29 UTC), `m2-isabelle-llvm` (11:29-11:31 UTC).

## Results

| Tool | Normal run | Wall, peak RSS | Negative control | Trusted lines | Verdict |
|---|---|---|---|---|---|
| Charon 0.1.321 + Aeneas nightly-2026.11.19-8f4466d, Lean 4.36.0-rc2 | 11 Lean theorems check; `#print axioms` on the 10 that are not `rfl` lists only `propext`, `Classical.choice`, `Quot.sound`; `link=ok`, `caller_output=same` | 17.1 s, 1.6 GB | rejected: one error, in `char_len_spec`; `scalar_tac` cannot prove `min ≤ r ∧ r ≤ max` for the callee's unconstrained `r`; the other theorems still check | 94 | works with trusted shim |
| VST 2.17 + CompCert 3.18, Rocq 9.2.0 | 6 `semax_body` proofs; `Print Assumptions` lists only the 6 allowed axioms (classical logic and extensionality, used by VST itself); `link=ok`, `caller_output=same` | 53.2 s (proofs about 51 s), 1.1 GB | rejected: `lo <= r <= hi` left unproved; the only fact on `r` is the `int` range from the callee's funspec | 44 | works |
| Isabelle-LLVM `e42f4781`, Isabelle2026, AFP 2026-11-19 | session `VU` (proofs and `export_llvm`) in 24 s; ABI and layout checks pass; `link=ok`, `caller_output=same` | 40.6 s, 3.8 GB | rejected: one failed proof, `vu_char_len_correct`; open goal `sint mn ≤ sint r ∧ sint r ≤ sint mx` for an arbitrary `r` | 100 | works with trusted shim |

In every control, the failing goal shows that the declaration of the
encoding callee gives its result no range, so no over-strong assumption
can make the clamp-free proof pass.

Trusted lines (`trusted.tsv`, by `count-trusted.sh`):

| Tool | File | Lines |
|---|---|---|
| Aeneas | `src/ffi.rs:41-80`: one trait implementation per client function, each doing only the indirect call, and `c_apply`, the C entry point handed to the client of `vu_fold_all` | 30 |
| Aeneas | `src/ffi.rs:17-39`, `:82-132`: the C glue (function pointer types, layout assertions, NULL checks, the six exported functions) | 60 |
| Aeneas | `proofs/Proofs.lean:173-180`: the client contract `Respects` of re-entrancy (a) | 4 |
| VST | `verif_vu.v:57-59`, `62-63`, `65`: the representations of `vu_args` and `vu_fold_rec`, and "well formed" | 6 |
| VST | `verif_vu.v:110-143`: funspecs of the encoding and callout callees | 23 |
| VST | `verif_vu.v:166-187`: funspec of the client's `apply_all_case_fold` | 15 |
| Isabelle-LLVM | `shim.c`: the three indirect calls | 8 |
| Isabelle-LLVM | `VU.thy:80-87`: the shim's declaration (types, C names) | 7 |
| Isabelle-LLVM | `VU.thy`: the three callee hypotheses (8) and the predicates they use (5) | 13 |
| Isabelle-LLVM | `abi.expected` (raw): the `declare` and `define` lines `vu.ll` must contain | 9 |
| Isabelle-LLVM | `layout.c:18-78`: the LLVM structs written as C structs | 57 |
| Isabelle-LLVM | `build.sh:119-124`: the `objcopy` rename of the exported symbols | 6 |

## Per tool

### Charon + Aeneas

- **Modelling style:** trusted shim. Aeneas has no function-pointer
  type; the three forms tried are rejected: `fn(u32, i32, &mut Rec) ->
  i32` ("arrow types with locally quantified regions"), a by-value `fn`
  type ("Arrow types are not supported yet"), and a `fn` item passed as
  an `FnMut` bound ("found an occurrence of a lifetime constraint
  relating"). Each client C function is therefore a trait (`EncLen`,
  `Callout`, `ApplyAll`); the verified functions are generic over it,
  and in Lean each trait is a structure parameter over which the
  theorems quantify, so no axiom and no callee specification is
  assumed. The one implementation of each trait, in `src/ffi.rs`
  (which Charon does not translate), does only the indirect call.
- **Proven:** `vu_char_len`'s result is in `[min, max]` for every callee
  result (given `min ≤ max`), and an in-range result is returned
  unchanged; `st` is not given to the callee. `vu_callout_step` returns
  `step_rule dir r` for the three directions; the engine state is the
  one before the call whatever the callee wrote, and an invalid `dir`
  gives -30 with `args` unchanged. `vu_i_apply` has an exact effect and
  keeps the record well formed; `vu_fold_all` hands out `vu_i_apply`
  (by `rfl`) and keeps the record well formed under the client
  contract, which a Lean model of `caller.c`'s client meets. The
  accessors are bounds checked.
- **Callee assumptions:** the callee returns (the theorems take "the
  call returned `r`" as a hypothesis for every `r`; a panic or
  divergence is outside them); no range on any result; the callout may
  write anything into `args`; no pointer kept after returning; the C
  caller passes valid, aligned, non-NULL pointers (NULL aborts); for
  (a), the client contract.
- **Ownership lent:** the encoding gets only `p`, never `st`; the
  callout is lent `args` mutably, and the verified side restores its
  four fields afterwards, so only the slots carry the callee's writes;
  the apply-all function is lent `rec` mutably.
- **Re-entrancy:** (a) works and is proved under the client contract.
  The verified side picks the function by type (`apply_all::<IApply>`)
  and a generic `c_apply::<A>` turns it into a C pointer; the client
  receives `c_apply::<IApply>`, which behaves like the exported
  `vu_i_apply` but has another address (`caller.c` does not compare
  them). (b) works.
- **Output:** Aeneas emits only the Lean model (`Vu.lean`, 339 lines).
  The library is rustc's build of the same `src/lib.rs` with
  `-C overflow-checks=on`, so an overflow panics in the library as it
  fails in the model; that the model translates `lib.rs` faithfully is
  trusted, as part of the toolchain. `build.sh` refuses any `axiom`,
  `opaque` or `sorry` in the model and any non-standard axiom in a
  theorem.
- **Notes:** the `i32 -> usize` casts need `IScalar.hcast_inBounds_spec`
  explicitly, since the default `step` lemma does not give the array
  bound. Aeneas warns about "extracted external, unknown definitions",
  although the model has no axiom; its option
  `-print-unknown-externals` crashes on a tuple name. The Aeneas lines
  of `build.log` keep ANSI colour codes.

### VST + CompCert

- **Modelling style:** client contract. Each client pointer is a
  parameter whose precondition holds `func_ptr' SPEC f`; VST's
  `forward_call` checks each indirect call, which `vu.c` makes itself,
  against `SPEC`, and the pointer types in the funspecs are checked
  against the Clight types. There is no shim, no axiom and no C glue;
  `vu.c` includes `proto.h` directly, so there is no hand-written ABI
  mapping either.
- **Proven:** `vu_char_len`'s result is in `[lo, hi]`, with `*st` and
  `*p` unchanged. `vu_callout_step` returns `step_result dir r`, with
  the progress, retraction and each-match rules written in Rocq from
  `regexec.c`; the verified-side state is unchanged, and the slots too
  when `dir` is invalid. `vu_i_apply` has an exact effect on the
  record; `vu_fold_all` returns it well formed. The accessors are
  bounds checked and read or write nothing out of range.
- **Callee assumptions:** partial correctness, so callees may diverge;
  callees follow C semantics and the frame rule holds for them (they
  touch no memory they were not lent, which is why `*st` is unchanged
  across the encoding call); the result is any `int`; the callout gives
  `*args` back with `subject`, `subject_len`, `pos` and `num` unchanged
  and any `int64` slots; `apply_all` gives the record back well formed
  (`0 <= recorded <= 8`).
- **Ownership lent:** the encoding gets a read share of the byte at `p`;
  the callout gets a writable share of `*args`, enough for
  `vu_get_slot` and `vu_set_slot`, and only the slots may change; no
  ownership of `user_data` passes through the verified code;
  `apply_all` gets a writable share of `*rec` and `vu_i_apply` with its
  proven funspec.
- **Re-entrancy:** (a) works: `make_func_ptr _vu_i_apply` gives the
  pointer its proven funspec, and the client contract receives it as
  `func_ptr' i_apply_fs f`. (b) works: the accessors are verified
  exported symbols that the client's callout calls by name, and the
  callout contract lends the permission their preconditions need.
- **Code:** `vu.c` stays in VST's Clight subset (early returns instead of
  `switch`). CompCert compiles it to a 2,104-byte `libvu.a`.
- **Notes:** `clightgen` (C to Clight, unproven) and the ABI agreement
  between CompCert's object and GCC's `caller.c` stay in the trusted
  toolchain. A `semax_func` lemma over all six bodies did not go through
  `semax_func_cons` and was dropped; the six `semax_body` lemmas stand.
  The normal run's `build.log` prints the header "Unproved goal, with
  its pure hypotheses:" with nothing after it: the reporting tactic
  `unproved` of `verif_vu.v`, applied with `all:` to no goal, still
  prints its first `idtac`; the proofs end with `Qed` and nothing is
  unproved.

### Isabelle-LLVM

- **Modelling style:** trusted shim, with no axiom. Isabelle-LLVM's code
  generator has no function-pointer type (its types are integers,
  floats, pointers to data, structs and unions; a `TFptr` exists only
  inside its LLVM text writer, for the parallel-call wrapper), and it
  calls external functions by name only (`LLVM_EXTERNAL`). `shim.c`
  makes the three indirect calls and returns the callee's raw result;
  the clamp and the branching stay in verified code. In `VU.thy` the
  shim functions are constants with no definition, and the client's
  contract on each is a hypothesis of the theorem that uses it
  (`assumes [vcg_rules]`), so the theorems hold for any shim and client
  that meet the hypotheses. A client function pointer is an opaque
  `8 word ptr`.
- **Proven:** `vu_char_len`'s result is in `[min, max]` (as `sint`),
  with `st` and the byte at `p` unchanged. `vu_callout_step`, for a
  valid `dir`, returns `step_res d r` for a callee result `r`
  satisfying an arbitrary predicate `Q`, with the verified-side state
  unchanged; for an invalid `dir`, -30, `args` unchanged, and the callee
  is not called. `vu_i_apply` has an exact effect and keeps the record
  well formed (`to` is never read); `vu_fold_all` keeps the record well
  formed. The accessors give exact results, -30 out of range with
  nothing read or written, and `vu_set_slot` keeps the verified-side
  state.
- **Callee assumptions:** total correctness (`llvm_htriple`), so every
  hypothesis assumes the callee terminates without failing; no range on
  any result; ownership is always full (`ll_pto` has no fractions) and
  must come back: the byte at `p` unchanged, `args` with only the slots
  changed, the fold record well formed.
- **Re-entrancy:** (a) is built and run through the shim, which takes
  `vu_i_apply`'s address in C. `vu_fold_all`'s hypothesis on `g` is
  justified by `vu_i_apply_correct`, but only informally: the two are
  not composed in a proof. (b) works: `vu_get_slot` and `vu_set_slot`
  are exported and called by name from the client's callout.
- **ABI:** the `declare` and `define` lines of `vu.ll` must equal
  `abi.expected`; `layout.c` checks with `_Static_assert` that the C
  mirror of the LLVM structs has `proto.h`'s layout. Isabelle-LLVM has
  no arrays inside structs, so the arrays are nested pair structs
  (consecutive fields, as in Pulse), with `vu_args` nested so that `num`
  lands at offset 16 and the slots at 24.
- **Compile:** `export_llvm` writes typed pointers (`i8*`), which clang
  23.1.5 reads as opaque pointers; clang takes `--target` from the
  module's triple. The exported names carry the theory prefix
  (`VU_vu_char_len`); an `is` clause would rename them but also makes
  `export_llvm` write a C header, which needs named fields in every
  struct, so `build.sh` renames the six symbols with `objcopy` (counted
  as trusted).
- **Proof-rejection test:** `build.sh` returns 3 only when every distinct
  error of `isabelle build_log -H Error VU` is "Failed to finish proof"
  or "Failed to apply ... proof method"; tested on the real control log
  and on two synthetic logs (a type error, and a mix with an undefined
  fact).

## Outputs and disk

| Tool | Generated code (not committed) | `<exp>` use |
|---|---|---|
| Aeneas | `Vu.lean`, 339 lines, sha256 `66cde72cb516f8ad35c1d63f64d5b822867e2812d7823fdab8860185582cf597`; `libvu.a`, 23,389,594 bytes, sha256 `5d2872be26c08b2270190cff2f58634ac557b87f92cd68592b8d5933256bbb25` | 29 MB per run (3 runs), 1.2 MB of exploration |
| VST | Clight `vu.v`, 684 lines, sha256 `80a9aa581dba13bddde057ff784a732359ad4c335b8192e65610162f57efcee2`; `libvu.a` (CompCert), 2,104 bytes, sha256 `17279c8471d520f0dc5e9f0766000fe0335eff89a04bada5953f839719581a56` | about 7 MB (recorded run and two trials) |
| Isabelle-LLVM | `vu.ll`, 671 lines, sha256 `2ec7639dc03a64166e7def9d30e85a5ef8bc9f6be25bd52362d77884fc3e7a8e` | about 0.9 MB (recorded run, one trial, one dev run) |

The prototypes installed nothing into `<cache>`. Isabelle's user home
there (`<cache>/isabelle/home`, with the session heaps) is 287 MB.
`<cache>` is 37 GB; about 67 GB remain free on the bench host.

## Deviations

- As in milestone 1, runs used a harness copy per tool, so
  `provenance.txt` reads `repo_commit: unknown` and
  `upstream_commit: unknown`; the committed files have the same sha256
  as the copies that ran.
- `provenance.sh` was run with the VST and Isabelle-LLVM runs, not with
  the Aeneas run. Its tool versions cover Charon and Aeneas. Its `lean`
  line fails ("no default toolchain configured") because Lean comes
  from the Aeneas library's `lean-toolchain`; the Lean version above is
  the one printed in the Aeneas `build.log`.
- Aeneas: the recorded run is `m2-aeneas-3`. `m2-aeneas` and
  `m2-aeneas-2` came before two fixes and are superseded: the proof of
  `char_len_spec` no longer depends on the code's shape (the control
  used to fail on a `split_ifs` tactic instead of the postcondition),
  and `build.sh` no longer flags a subset of the standard axioms as
  non-standard.
- VST: trials `try1-vst` and `try2-vst` preceded the recorded run; in
  the first, the control was misclassified because the error line was
  taken from the first `File` line of the log, which `build.sh` now
  fixes.
- Isabelle-LLVM: the trial `m2-isabelle-llvm-try1` passed too; it was
  redone only because a log message counted the same error twice.
  Forced by the tool: the C shim, the `objcopy` rename, typed-pointer IR
  read by clang 23, pair structs in place of arrays.

## Open points

- Isabelle-LLVM, re-entrancy (a): compose `vu_fold_all`'s hypothesis on
  the client with `vu_i_apply_correct` in a proof?
- Isabelle-LLVM is in this account's `<cache>`, which experiment #4's
  account cannot read (see `toolchains-m2`); nothing was posted on
  issue #7 by these runs.
- No independent review agent was available to the prototype runs;
  each was checked by its prover, ShellCheck on its `build.sh`, the
  caller comparison and the negative control.

## Verdicts

- Charon + Aeneas: **works with trusted shim** (94 lines).
- VST + CompCert: **works**.
- Isabelle-LLVM: **works with trusted shim** (100 lines).

## Later

The `review-fixes` entry
([2026-11-20-exp-05-review-fixes.md](2026-11-20-exp-05-review-fixes.md))
re-runs these prototypes after the independent review. Its trusted-line
count for Aeneas (109, with offset assertions) supersedes the one above,
and VST now also proves `semax_func` over the six bodies (`vu_funcs`).
