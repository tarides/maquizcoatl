# Experiment 5: summary table

One row per tool, with the columns of issue #13. Updated after each
milestone; a tool whose milestone has not run is "pending", which is not
a verdict. Trusted lines are counted by `count-trusted.sh` from each
tool's `TRUSTED` file. Details and raw outputs: the `prototypes-m<N>`
entries of `lab/notebook.md`, and the `review-fixes` entry for the re-run
of milestones 1 and 2 after the independent review.

Last update: fixes after the review of run D (entry
`2026-11-21-exp-05-runD-corrections`): RefinedRust pinned, CN's
Cerberus commit is `a0f7071` (its `cn.opam` pin-depends), the three
milestone 4 disk sizes marked as guesses. Before that: run D of the pipeline (run id `runD`, milestone 4,
entry `2026-11-21-exp-05-runD`): Bedrock2, CN and RefinedC pinned
(commits, disk estimates) but still pending: the disk was under the
20 GB floor before the run started (19 GB free), so their installs
were refused by `setup-pipeline.sh` and are not written; no milestone 4
prototype was written, since none could be checked. The single summary
table of the experiment (all tools of milestones 1-4) is posted on
issue #13 under "Results". Before that: run C of the pipeline (run id `runC`, milestone 3,
entry `2026-11-21-exp-05-runC`, corrected by
`2026-11-21-exp-05-runC-corrections`): the hax rows; the other
milestone 3 tools stay pending (the pinned F\* for hax is refused by
the 20 GB disk floor; the hax Lean, Creusot and RefinedRust installs
are not written yet). Before that: run B of the pipeline (run id `runB`): the read accessor
`vu_get_subject_byte` in `proto.h` and the six prototypes, each with a
second negative control; the Isabelle-LLVM composition proof of shape
(a). Entry `2026-11-21-exp-05-runB` of the lab notebook, corrected by
`2026-11-21-exp-05-runB-corrections` (Verus and Aeneas trusted counts,
callee assumptions, how two read controls fail).

| Tool | Version | Verdict | Modelling style | Trusted lines | Callee assumptions | Re-entrancy (a) | Re-entrancy (b) |
|---|---|---|---|---|---|---|---|
| Why3 (C extraction) | 1.9.0; Alt-Ergo 2.6.5, Z3 4.15.3 | works with trusted shim (140 lines) | trusted shim at driver level (indirect calls, struct fields, `void *`), with a client contract per call | 140 (`vu.mlw` module `Client` 109, `vu.drv` 31) | terminates and returns normally; result any `int32`; the encoding writes no verified-side state; the callout writes only the data slots, through `vu_set_slot`; the subject is an immutable part of the model (no ownership: nothing in the model says who else may write it), whose invariant (`const_args`: `subject_len >= 0`, every byte in 0-255) is assumed of the C caller, not checked; `apply_all` changes the record only through `vu_i_apply` | yes; the function's address comes from a trusted driver entry | yes |
| F\* + Pulse, KaRaMeL | F\* 2026.11.15 (`b92b0f87`), krml `3384ecaf` | works | client contract (Pulse function-typed parameters, which KaRaMeL emits as C function pointers) | 28 (callee contracts 15, hand-written ABI mapping 13) | may diverge (partial correctness); result any `int32_t`; the encoding gets a read fraction of `*p`; the callout gets `*args` and must give it back with the verified-side fields unchanged, and a read fraction of the subject array, given back with the same bytes; the accessor requires `SZ.fits_u32` (`size_t` holds 32 bits), a platform fact the C caller is assumed to meet and cannot be checked against; `apply_all` gets `vu_i_apply` and must give the record back well formed | yes | yes |
| Verus | 0.2026.11.02.8bf68ee, Rust 1.99.1 | works with trusted shim (117 lines) | trusted shim (`external_body` indirect calls with empty specifications, plus `unsafe` C glue) | 117 (shim 25, C glue 92) | terminates and returns an `int`; no range on the result; no assumption on what the callout writes into `args` (the verified side restores its own fields); the C caller passes valid, aligned, non-NULL pointers that nobody else writes during the call; the subject is `subject_len` readable bytes, turned into a shared slice by the trusted glue (the verified side holds no permission on it) | yes, each call meets `vu_i_apply`'s spec; the function's address is taken in trusted code (`shim.rs`); nothing is proven across the client's sequence of calls | yes |
| Charon + Aeneas | Aeneas nightly-2026.11.19-8f4466d, Charon 0.1.321 (`61c67516`), Rust nightly-2026-09-17, Lean 4.36.0-rc2 | works with trusted shim (122 lines) | trusted shim (one trait per client C function; the verified functions are generic over the traits and the Lean theorems quantify over every implementation; the one implementation, in unverified Rust, does the indirect call), plus a client contract for (a) | 122 (shims 30, C glue 88, client contract 4) | terminates and returns normally; no range on the result; may write anything into `args` (the verified side restores its fields); the subject is `subject_len` readable bytes, turned into a shared slice by the trusted glue (the verified side holds no permission on it); keeps no pointer after returning; for (a), reaches the record only through the function it is given; each callee is modelled as a pure function of its arguments (deterministic, with no hidden state the verified side sees), harmless here with one call per function | yes, proved under the client contract; the function's address is taken in trusted code (`c_apply` in `ffi.rs`); a Lean model of `caller.c`'s client meets it | yes |
| VST + CompCert | VST 2.17, CompCert 3.18 (prints 3.17), Rocq 9.2.0 | works | client contract (each client pointer comes with a VST funspec, `func_ptr'`; VST checks the indirect calls that `vu.c` makes itself, and CompCert compiles the same `vu.c`) | 54 (callee funspecs and the representation predicates they use) | may diverge (partial correctness); result any `int`; touches no memory it was not lent (frame rule); the encoding gets a read share of `*p`; the callout gets `*args` and must give it back with `subject`, `subject_len`, `pos` and `num` unchanged, and a read share of the subject (unchanged, since a read share cannot write); `apply_all` gets `vu_i_apply` with its proven funspec and must give the record back well formed | yes; `vu_i_apply`'s pointer carries its proven funspec, and `vu_funcs` (`semax_func`) checks the six bodies together, so that funspec is the proven one | yes |
| Isabelle-LLVM | Isabelle2026, AFP 2026-11-19, Isabelle-LLVM `e42f4781`; clang 23.1.5 | works with trusted shim (108 lines) | trusted shim (three C functions make the indirect calls; their contracts are hypotheses of the theorems, not axioms) | 108 (C shim 8 and its declaration 7, callee hypotheses and their predicates 20, hand-written ABI mapping 67, symbol rename 6) | terminates (total correctness); no range on the result; lent memory comes back: the byte at `p` unchanged, `args` with its verified-side fields unchanged, the subject whole (full ownership: no read-only share) with the same bytes; for (a), reaches the record only through the `vu_i_apply` it is given | yes, through the shim (C takes `vu_i_apply`'s address); proved under a client contract (`respects_i_apply`), composed with `vu_i_apply_correct` in `vu_fold_all_composed` | yes |
| hax (F\* backend) | cargo-hax v0.5.0 (`a045d15a`), Rust nightly-2025-11-08; F\* v2025.10.06 not installed | pending (milestone 3, run C): hax extracts `Vu.fst`, but F\* 2026.11.15 cannot check it (`FStar.Mul` missing, error 134) and the F\* that hax pins was refused by the disk floor (this F\* does not list `--cmi`, so `build.sh` drops it and logs it) | trusted shim, as Aeneas (one trait per client C function, implemented in unverified Rust by the indirect call), plus a client contract for (a) on `ApplyAll` | 126 (shims 30, C glue 91, client contract 5) | not checked yet; the extracted model takes each callee as a type-class method, a pure function of its arguments; as written, no range on the result and nothing assumed of what the callout writes into `args` (the verified side restores its fields); the subject is a shared slice made by the glue (length agreement is a precondition); pointers the verified side passes through are `usize` addresses (no raw pointer type in hax) | built and run (C caller output equal to `expected.txt`), not proved; `vu_i_apply`'s address is taken in trusted code (`c_apply` in `ffi.rs`) | built and run, not proved |
| hax (Rocq backend) | cargo-hax v0.5.0 (`a045d15a`), Rocq 9.3.0, hax `Core` library at the tag | does not work (at v0.5.0): the extracted model does not type-check against the tag's own Rocq library, for the prototype (`t_VuFoldRec` undefined: records are emitted as `VuFoldRec_record`) and for two minimal probes (a one-field struct; one comparison, `f_lt` vs the library's `PartialOrd_f_lt`); ensures clauses are emitted as `Admitted` lemmas. Upstream status: hax's README at the tag rates the Rocq/Coq backend "Experimental" (F\* "Stable", Lean via Aeneas "Recommended"); no CI workflow at the tag mentions Coq or Rocq, and the Coq snapshots are compared as text, never compiled; `main` is 2 commits past the tag, none under `engine/backends/coq` or `hax-lib/proof-libs/coq` (last functional commits 2026-02-17 and 2025-07-21), so a re-check on `main` cannot differ. Experiment #1: 0 callouts and UTF-8 only in its 5,870 triples | as F\* backend (same prototype) | 126 (same glue) | as F\* backend; besides, the Rocq classes drop the trait contracts, so the client contract of (a) is lost | no model to prove it on | no model to prove it on |
| hax (Lean backend) | cargo-hax v0.5.0, which runs Charon `nightly-2026.10.31` + Aeneas `build-2b9e3ea` (the Charon + Aeneas pipeline, not the hax engine) | pending (milestone 3, run C): its Lean library needs Lean v4.35.0, Mathlib and Aeneas's Lean library at `2b9e3ea4` (about 10 GB); the install is not written yet (`setup.sh` has only its disk check) and the disk floor refuses it; a verdict would be Aeneas's model with hax-lib's specifications in front, not a third hax model | | | | | |
| Creusot | v0.14.0 | pending (milestone 3, run C): install (about 7 GB) not written yet (`setup.sh` has only its disk check), and refused by the disk floor | | | | | |
| RefinedRust | `lgaeher/refinedrust-dev` `2862b1d8` (2026-11-16) | pending (milestone 3, run C): install (about 6 GB) not written yet (`setup.sh` has only its disk check), and refused by the disk floor | | | | | |
| Bedrock2 | `mit-plv/bedrock2` `67b682a5` (2026-11-19), Rocq 9.2 or 9.3 (its CI) | pending (milestone 4, run D): install (about 3 GB, a guess, not measured) not written, and refused by the disk floor (19 GB free, 23 GB needed) | | | | | |
| CN | `rems-project/cn` `f2e8eeb4`, `cerberus-lib` at `rems-project/cerberus` `a0f7071` (the pin-depends of CN's `cn.opam`) | pending (milestone 4, run D): install (about 3 GB, a guess, not measured) not written, and refused by the disk floor (19 GB free, 23 GB needed); CN has moved out of the Cerberus repository into its own | | | | | |
| RefinedC | `iris/refinedc` `d0575839`, Coq 9.1.0, `cerberus-lib` `f11e6b3` | pending (milestone 4, run D): install (about 5 GB, a guess, not measured) not written, and refused by the disk floor (19 GB free, 25 GB needed) | | | | | |

## Notes

- **Milestone 4 (run D).** Nothing was measured: the bench host had
  19 GB free before the run, under the 20 GB floor, so
  `setup-pipeline.sh` refused each install, and even an install of
  0 GB (`install-refusals.txt` of the `runD` raw outputs). The three
  tools are pinned in `pins.json`; their installs are disk checks
  followed by `vu_die`, as for milestone 3's last three tools. CN and
  RefinedC would check C source like VST's `vu.c` (annotations added),
  Bedrock2 its own source language compiled to C; none of the three
  prototypes was written, since none could be checked.

- **hax (run C).** The prototype is Aeneas's, with hax-lib
  specifications. `callout_step` returns the callee's raw result as a
  ghost second component, which the glue drops. It links with
  `caller.c` and runs clean under Miri (Stacked and Tree Borrows). Miri
  warns that the glue's `with_exposed_provenance` may hide pointer bugs:
  hax has no raw pointer type, so the subject address is a `usize`. The
  release binary of cargo-hax only runs the Lean backend; the F\* and
  Rocq backends need the OCaml engine built from source (2.2 GB opam
  switch). The F\* of milestone 1 (2026.11.15) cannot check hax
  v0.5.0's output, so the F\* backend needs its own F\* (v2025.10.06).
  hax's Lean backend (`cargo hax into lean`) is the Charon + Aeneas
  pipeline: it downloads its own Charon and Aeneas build (604 MB) and
  emits Aeneas's files; only the hax engine's `legacy-lean` output is
  hax's own.

- **Read accessor (run B).** `vu_get_subject_byte(args, i)` reads byte
  `i` of the subject behind the pointer held in `args`, with a bounds
  check against `subject_len`; the C caller calls it from a callout
  (with `vu_set_slot`) and directly. How each tool expresses shared read
  access to that engine state, and its trusted-line cost:
  - Why3 (+12): the subject is an immutable field of the read-only model
    `const_args`, read by a driver entry; Why3 has no ownership, so the
    model cannot say that the callout may not write it.
  - F\* + Pulse (+3): a fraction of the subject array, lent to the
    callout and to the accessor and given back with the same bytes. The
    accessor also requires `SZ.fits_u32` (Pulse indexes arrays with
    `size_t`, whose width F\* leaves to the target).
  - Verus (+15) and Aeneas (+13): the raw pointer has no model, so the
    trusted glue turns it into a shared slice `&[u8]` of `subject_len`
    bytes, and the verified accessor takes the slice (Verus: a
    precondition ties its length to `subject_len`; Aeneas: a theorem
    hypothesis). Neither lends anything for the subject across the
    callout: the verified side holds no permission on it.
  - VST (+10): a readable share of the subject array, lent to the
    callout and to the accessor.
  - Isabelle-LLVM (+6 for the accessor): no fractional permissions, so
    the callout and the accessor get the subject whole and the contract
    says the bytes come back the same. It is the one tool here that
    cannot express the access without lending full ownership.
- **Second negative control (run B), `run.sh -r`:** the upper bound
  test of `vu_get_subject_byte` is removed, so that it may read past
  `subject_len`; each proof is rejected at the read (Why3: precondition
  of the driver read and the in-range postcondition, not proved by
  either prover: Alt-Ergo times out at 10 s, Z3 runs out of memory at
  6 s; Pulse: F\* error 19 on the array index; Verus: "index in
  bounds"; VST: the index side condition). Two are rejected by a
  proof-script failure rather than an unprovable goal named by the
  tool. Aeneas: the index step leaves the bound `(↑j).succ.le
  subject.length` (`j < subject.length`) open, and the next tactics
  fail on it (`Proofs.lean:288`, anonymous constructor with that bound
  as expected type; `:291`, `intro`). Isabelle-LLVM: "Failed to finish
  proof" at line 526 of the control's `VU.thy` with three subgoals:
  twice that the address read is in the subject's range
  (`(s +ₐ sint i) -ₐ s ∈ {0..<sint l}`), and that when `i ≥ l` the
  byte read equals `err_invalid_argument`.
- **Miri (run B).** A pure-Rust client (`miri/client.rs`) calls
  `vu_get_slot`, `vu_set_slot` and `vu_get_subject_byte` through the raw
  pointer during a callout, and calls `vu_i_apply` back through the
  pointer `vu_fold_all` hands it; under Miri (Stacked and Tree Borrows)
  it runs clean against the Aeneas sources and an erased copy of the
  Verus sources. A first version of the new glue, which made the slice
  from a one-byte reference, was rejected by Stacked Borrows and fixed.
- Every prototype of milestones 1 and 2 links with `caller/caller.c`,
  its output equals `caller/expected.txt`, and its negative control (the
  clamp of `vu_char_len` removed) is rejected by the prover. Why3's
  control is rejected as "not proved in 10 s": both provers time out on
  the range goal rather than return a counterexample; reading
  `call_enc_len`, which gives the result no range, shows the goal is
  unprovable.
- Every build refuses proof escapes in the verified part: Why3 (no
  `val`, `axiom` or `assume` in module `Vu`), Pulse (no `admit`,
  `assume`, `magic`, `--admit_smt_queries`), Verus (`--no-cheating`
  refuses only the three shims of `shim.rs`), Aeneas and VST (no
  `sorry` or `admit`, standard axioms only), Isabelle-LLVM (no `sorry`,
  `axiomatization`, `oracle` or `quick_and_dirty`).
- The trusted-line counts are not directly comparable. Why3's include
  the model of the C structs and of `void *`. Verus's and Aeneas's
  include the C entry points in `unsafe` Rust, and the size, alignment
  and member-offset assertions (15 lines each) that check their
  `#[repr(C)]` mirrors of `proto.h`'s structs against its LP64 layout,
  written as numbers; the mirrors themselves are not counted.
  Isabelle-LLVM's include
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
- Callout postcondition: Why3 (ghost trace), Verus (ghost value), Aeneas
  (`hcall`) and Isabelle-LLVM (predicate `Q`) tie the result to the value
  the callee returned. Pulse and VST only say that there is some `int`
  `r` with result = rule(dir, r); the code calls the callee once and
  applies the rule to its result, but the specification does not name
  that value.
- Isabelle-LLVM, shape (a), since run B: `vu_fold_all_composed` proves
  `vu_fold_all`'s postcondition from `respects_i_apply` (the client
  reaches the record only through `vu_i_apply`) and
  `vu_i_apply_correct`, as Aeneas does with `Respects`; the earlier
  hypothesis on the client (record well formed) is no longer trusted.
  Unlike Aeneas, no model of `caller.c`'s client is shown to meet the
  contract.
- Aeneas warning "extracted external, unknown definitions" (run B): it
  refers to `core::num::<impl i32>::MAX` (read by `i_apply`), which
  Aeneas maps to its library's `core.num.I32.MAX`. `export_global` sets
  the warning's flag (Aeneas `src/Translate.ml:1007` at `8f4466d`)
  before it checks for a library definition (`:1009-1012`), and
  `src/Main.ml:777-782` prints the warning from that flag, so the
  warning is a false positive here: a one-function crate reading
  `i32::MAX` gets it and one reading no global does not
  (`aeneas/probes/warn.sh`), and `-split-files` writes no file of
  external definitions. The model has
  no axiom or opaque definition.
- Re-entrancy (a): only Pulse and VST take `vu_i_apply`'s address in
  verified code. Why3 (a driver entry), Verus (`shim.rs`), Aeneas
  (`c_apply` in `ffi.rs`) and Isabelle-LLVM (`shim.c`) take it in
  trusted code.
- Isabelle-LLVM has no function-pointer type (a `TFptr` exists only in
  its LLVM writer) and calls external functions by name only, hence the
  C shim. Its exported names carry the theory prefix and are renamed
  with `objcopy` (counted as trusted).
- F\* extraction finding: a Pulse function whose body is a tail call
  ending with its own last parameter is eta-reduced, and the C function
  loses that parameter, with no warning. The prototype avoids the shape,
  and `pulse/abi_check.c` rejects it. Reproducer in `pulse/probes/`.
- The first "does not work" verdict is hax's Rocq backend (run C).
  Experiment #1's numbers are cited next to it, as the plan requires:
  0 callouts and UTF-8 only across its 5,870 triples. The failure is
  not about calls to unverified code: the backend's output at v0.5.0
  does not type-check even for a one-field struct.
