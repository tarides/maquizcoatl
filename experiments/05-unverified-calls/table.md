# Experiment 5: summary table

One row per tool, with the columns of issue #13. Updated after each
milestone; a tool whose milestone has not run is "pending", which is not
a verdict. Trusted lines are counted by `count-trusted.sh` from each
tool's `TRUSTED` file. Details and raw outputs: the `prototypes-m<N>`
entries of `lab/notebook.md`.

Last update: milestone 1 (Why3, F\* + Pulse, Verus).

| Tool | Version | Verdict | Modelling style | Trusted lines | Callee assumptions | Re-entrancy (a) | Re-entrancy (b) |
|---|---|---|---|---|---|---|---|
| Why3 (C extraction) | 1.9.0; Alt-Ergo 2.6.5, Z3 4.15.3 | works with trusted shim (124 lines) | trusted shim at driver level (indirect calls, struct fields, `void *`), with a client contract per call | 124 (`vu.mlw` module `Client` 96, `vu.drv` 28) | terminates and returns normally; result any `int32`; the encoding writes no verified-side state; the callout writes only the data slots, through `vu_set_slot`; `apply_all` changes the record only through `vu_i_apply` | yes; the function's address comes from a trusted driver entry | yes |
| F\* + Pulse, KaRaMeL | F\* 2026.11.15 (`b92b0f87`), krml `3384ecaf` | works | client contract (Pulse function-typed parameters, which KaRaMeL emits as C function pointers) | 25 (callee contracts 13, hand-written ABI mapping 12) | may diverge (partial correctness); result any `int32_t`; the encoding gets a read fraction of `*p`; the callout gets `*args` and must give it back with the verified-side fields unchanged; `apply_all` gets `vu_i_apply` and must give the record back well formed | yes | yes |
| Verus | 0.2026.11.02.8bf68ee, Rust 1.99.1 | works with trusted shim (87 lines) | trusted shim (`external_body` indirect calls with empty specifications, plus `unsafe` C glue) | 87 (shim 25, C glue 62) | terminates and returns an `int`; no range on the result; no assumption on what the callout writes into `args` (the verified side restores its own fields); the C caller passes valid, aligned, non-NULL pointers that nobody else writes during the call | yes, each call meets `vu_i_apply`'s spec; nothing is proven across the client's sequence of calls | yes |
| Charon + Aeneas | | pending (milestone 2) | | | | | |
| VST + CompCert | | pending (milestone 2) | | | | | |
| Isabelle-LLVM | | pending (milestone 2) | | | | | |
| hax | | pending (milestone 3) | | | | | |
| Creusot | | pending (milestone 3) | | | | | |
| RefinedRust | | pending (milestone 3) | | | | | |
| Bedrock2 | | pending (milestone 4) | | | | | |
| CN | | pending (milestone 4) | | | | | |
| RefinedC | | pending (milestone 4) | | | | | |

## Notes

- Every prototype of milestone 1 links with `caller/caller.c`, its
  output equals `caller/expected.txt`, and its negative control (the
  clamp of `vu_char_len` removed) is rejected by the prover.
- The trusted-line counts are not directly comparable. Why3's include
  the model of the C structs and of `void *`. Verus's include the C
  entry points. Pulse needs neither, because KaRaMeL emits the structs
  and the indirect calls; its 12 lines of ABI mapping only restate
  `proto.h`'s types for a compile-time check.
- F\* + Pulse is "works" because its trusted lines are the callees'
  declared types and contracts and that type mapping, which the plan
  allows for this verdict.
- F\* extraction finding: a Pulse function whose body is a tail call
  ending with its own last parameter is eta-reduced, and the C function
  loses that parameter, with no warning. The prototype avoids the shape,
  and `pulse/abi_check.c` rejects it. Reproducer in `pulse/probes/`.
- No tool has a "does not work" verdict so far, so experiment 1's
  numbers are not cited here yet.
