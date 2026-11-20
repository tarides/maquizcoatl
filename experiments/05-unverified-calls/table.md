# Experiment 5: summary table

One row per tool, with the columns of issue #13. Updated after each
milestone; a tool whose milestone has not run is "pending", which is not
a verdict. Trusted lines are counted by `count-trusted.sh` from each
tool's `TRUSTED` file. Details and raw outputs: the `prototypes-m<N>`
entries of `lab/notebook.md`.

Last update: milestone 2 (Charon + Aeneas, VST + CompCert,
Isabelle-LLVM).

| Tool | Version | Verdict | Modelling style | Trusted lines | Callee assumptions | Re-entrancy (a) | Re-entrancy (b) |
|---|---|---|---|---|---|---|---|
| Why3 (C extraction) | 1.9.0; Alt-Ergo 2.6.5, Z3 4.15.3 | works with trusted shim (124 lines) | trusted shim at driver level (indirect calls, struct fields, `void *`), with a client contract per call | 124 (`vu.mlw` module `Client` 96, `vu.drv` 28) | terminates and returns normally; result any `int32`; the encoding writes no verified-side state; the callout writes only the data slots, through `vu_set_slot`; `apply_all` changes the record only through `vu_i_apply` | yes; the function's address comes from a trusted driver entry | yes |
| F\* + Pulse, KaRaMeL | F\* 2026.11.15 (`b92b0f87`), krml `3384ecaf` | works | client contract (Pulse function-typed parameters, which KaRaMeL emits as C function pointers) | 25 (callee contracts 13, hand-written ABI mapping 12) | may diverge (partial correctness); result any `int32_t`; the encoding gets a read fraction of `*p`; the callout gets `*args` and must give it back with the verified-side fields unchanged; `apply_all` gets `vu_i_apply` and must give the record back well formed | yes | yes |
| Verus | 0.2026.11.02.8bf68ee, Rust 1.99.1 | works with trusted shim (87 lines) | trusted shim (`external_body` indirect calls with empty specifications, plus `unsafe` C glue) | 87 (shim 25, C glue 62) | terminates and returns an `int`; no range on the result; no assumption on what the callout writes into `args` (the verified side restores its own fields); the C caller passes valid, aligned, non-NULL pointers that nobody else writes during the call | yes, each call meets `vu_i_apply`'s spec; nothing is proven across the client's sequence of calls | yes |
| Charon + Aeneas | Aeneas nightly-2026.11.19-8f4466d, Charon 0.1.321 (`61c67516`), Rust nightly-2026-09-17, Lean 4.36.0-rc2 | works with trusted shim (94 lines) | trusted shim (one trait per client C function; the verified functions are generic over the traits and the Lean theorems quantify over every implementation; the one implementation, in unverified Rust, does the indirect call), plus a client contract for (a) | 94 (shims 30, C glue 60, client contract 4) | terminates and returns normally; no range on the result; may write anything into `args` (the verified side restores its fields); keeps no pointer after returning; for (a), reaches the record only through the function it is given | yes, proved under the client contract; a Lean model of `caller.c`'s client meets it | yes |
| VST + CompCert | VST 2.17, CompCert 3.18 (prints 3.17), Rocq 9.2.0 | works | client contract (each client pointer comes with a VST funspec, `func_ptr'`; VST checks the indirect calls that `vu.c` makes itself, and CompCert compiles the same `vu.c`) | 44 (callee funspecs and the representation predicates they use) | may diverge (partial correctness); result any `int`; touches no memory it was not lent (frame rule); the encoding gets a read share of `*p`; the callout gets `*args` and must give it back with `subject`, `subject_len`, `pos` and `num` unchanged; `apply_all` gets `vu_i_apply` with its proven funspec and must give the record back well formed | yes; `vu_i_apply`'s pointer carries its proven funspec | yes |
| Isabelle-LLVM | Isabelle2026, AFP 2026-11-19, Isabelle-LLVM `e42f4781`; clang 23.1.5 | works with trusted shim (100 lines) | trusted shim (three C functions make the indirect calls; their contracts are hypotheses of the theorems, not axioms) | 100 (C shim 8 and its declaration 7, callee hypotheses and their predicates 13, hand-written ABI mapping 66, symbol rename 6) | terminates (total correctness); no range on the result; lent memory comes back: the byte at `p` unchanged, `args` with its verified-side fields unchanged, the record well formed | yes, through the shim (C takes `vu_i_apply`'s address); `vu_fold_all`'s hypothesis on the client is not composed with `vu_i_apply`'s theorem in a proof | yes |
| hax | | pending (milestone 3) | | | | | |
| Creusot | | pending (milestone 3) | | | | | |
| RefinedRust | | pending (milestone 3) | | | | | |
| Bedrock2 | | pending (milestone 4) | | | | | |
| CN | | pending (milestone 4) | | | | | |
| RefinedC | | pending (milestone 4) | | | | | |

## Notes

- Every prototype of milestones 1 and 2 links with `caller/caller.c`,
  its output equals `caller/expected.txt`, and its negative control (the
  clamp of `vu_char_len` removed) is rejected by the prover.
- The trusted-line counts are not directly comparable. Why3's include
  the model of the C structs and of `void *`. Verus's and Aeneas's
  include the C entry points in `unsafe` Rust. Isabelle-LLVM's include
  66 lines of hand-written ABI mapping, mostly a C mirror of the LLVM
  structs (Isabelle-LLVM has no arrays inside structs). Pulse and VST
  need neither: KaRaMeL emits the structs and the indirect calls, and
  VST proves the C source itself; Pulse's 12 lines of ABI mapping only
  restate `proto.h`'s types for a compile-time check.
- F\* + Pulse and VST + CompCert are "works" because their trusted lines
  are the callees' declared types and contracts (and, for Pulse, that
  type mapping), which the plan allows for this verdict.
- Aeneas emits only the Lean model, not the executable. The library is
  rustc's build of the same `src/lib.rs` (with overflow checks on), so
  that the model is a faithful translation of that file is trusted, as
  part of the toolchain. Aeneas has no function-pointer type: the three
  forms tried are rejected, so the client functions are traits.
- VST: `clightgen` (C to Clight, unproven) and the ABI agreement between
  CompCert's object and GCC's `caller.c` stay in the trusted toolchain.
- Isabelle-LLVM has no function-pointer type (a `TFptr` exists only in
  its LLVM writer) and calls external functions by name only, hence the
  C shim. Its exported names carry the theory prefix and are renamed
  with `objcopy` (counted as trusted).
- F\* extraction finding: a Pulse function whose body is a tail call
  ending with its own last parameter is eta-reduced, and the C function
  loses that parameter, with no warning. The prototype avoids the shape,
  and `pulse/abi_check.c` rejects it. Reproducer in `pulse/probes/`.
- No tool has a "does not work" verdict so far, so experiment 1's
  numbers are not cited here yet.
