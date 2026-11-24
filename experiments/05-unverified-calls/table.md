# Experiment 5: summary table

One row per tool, with the columns of issue #13. Updated after each
milestone; a tool whose milestone has not run is "pending", which is not
a verdict. Trusted lines are counted by `count-trusted.sh` from each
tool's `TRUSTED` file. Details and raw outputs: the `prototypes-m<N>`
entries of `lab/notebook.md`, and the `review-fixes` entry for the re-run
of milestones 1 and 2 after the independent review.

Last update: run G of the pipeline (run id `runG`, entry
`2026-11-24-exp-05-runG`, maintainer decision of 2026-11-24): Bedrock2
works with trusted shim (119 lines; the three indirect calls are
`cmd.interact` actions made by a C shim, with their `ext_spec`
contracts as theorem hypotheses; the read accessor reads the subject in
verified code, lent whole); every row now has a verdict. Before that:
fixes after the review of run F (entry
`2026-11-22-exp-05-runF-corrections`): RefinedRust counts 152 trusted
lines, was 156 (its accessor's own subject precondition is no longer
counted, as for CN; no rank changes); Bedrock2 was not started although
run F stopped at 2h01 of its 3 hours (decision 16:38 UTC, results 18:39
UTC), about 59 minutes unused; Creusot's control check no longer passes
the obsolete word `prove` and logs the target's output. Before that:
run F of the pipeline (run id `runF`, entry
`2026-11-22-exp-05-runF`): RefinedRust works with trusted shim (156
lines; the read accessor reads the subject through a raw pointer in
verified code, with a manual proof); Bedrock2 still pending (not
started); Creusot's negative controls now count only if a prover
answered Invalid or Unknown (why3find reports a timeout as it reports
a refutation), and both are still rejected; hax F\* listed as its own
route (note below). Before that: fixes after the review of run E (entry
`2026-11-21-exp-05-runE-corrections`): RefinedRust and Bedrock2 stay
pending because run E stopped at 1h08 of its 3 hours (results at 18:09
UTC), not because the cap was reached; RefinedRust's install finished
(status 0, 3869 s) about two minutes later; the hax Rocq row counts the
two `requires(true)` client contracts of the shared source (134, was
126). Before that: run E of the pipeline (run id `runE`, entry
`2026-11-21-exp-05-runE`): hax's F\* backend (works with trusted shim,
134 lines, with the pinned F\* v2025.10.06), Creusot (works with
trusted shim, 123), CN (works with trusted shim, 22), RefinedC (works,
25); hax's Lean backend not run (maintainer decision); RefinedRust and
Bedrock2 installed but still pending (prototypes not checked; the run
stopped at 1h08 of its 3 hours). Before that: fixes after the review of run D (entry
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
| hax (F\* backend) | cargo-hax v0.5.0 (`a045d15a`), Rust nightly-2025-11-08, F\* v2025.10.06 (`7b347386`, the F\* hax pins) | works with trusted shim (134 lines) | trusted shim, as Aeneas (one trait per client C function, implemented in unverified Rust by the indirect call; the extracted F\* takes each as a type-class argument), plus client contracts: `requires(true)` on `EncLen` and `Callout`, the record invariant on `ApplyAll` for (a) | 134 (shims 30, C glue 91, client contracts 13) | terminates and returns normally (F\* `Pure`: total); each callee is a type-class method, a pure function of its arguments (deterministic, no hidden state the verified side sees); the encoding function and the callout accept every argument (`requires(true)`, which F\* needs to call them: without it, the method's precondition is abstract and no caller can meet it); no range on the result; nothing assumed of what the callout writes into `args` (the verified side restores its fields); the subject is a shared slice made by the glue (length agreement is a precondition); pointers the verified side passes through are `usize` addresses (no raw pointer type in hax); for (a), the client keeps the record well formed (`ApplyAll`'s contract, trusted) | yes, proved under the client contract; `vu_i_apply`'s address is taken in trusted code (`c_apply` in `ffi.rs`) | yes |
| hax (Rocq backend) | cargo-hax v0.5.0 (`a045d15a`), Rocq 9.3.0, hax `Core` library at the tag | does not work (at v0.5.0): the extracted model does not type-check against the tag's own Rocq library, for the prototype (`t_VuFoldRec` undefined: records are emitted as `VuFoldRec_record`) and for two minimal probes (a one-field struct; one comparison, `f_lt` vs the library's `PartialOrd_f_lt`); ensures clauses are emitted as `Admitted` lemmas. Upstream status: hax's README at the tag rates the Rocq/Coq backend "Experimental" (F\* "Stable", Lean via Aeneas "Recommended"); no CI workflow at the tag mentions Coq or Rocq, and the Coq snapshots are compared as text, never compiled; `main` is 2 commits past the tag, none under `engine/backends/coq` or `hax-lib/proof-libs/coq` (last functional commits 2026-02-17 and 2025-07-21), so a re-check on `main` cannot differ. Experiment #1: 0 callouts and UTF-8 only in its 5,870 triples | as F\* backend (same prototype) | 134 (same glue and client contracts; was 126 before the review of run E) | as F\* backend; besides, the Rocq classes drop the trait contracts, so the client contract of (a) is lost | no model to prove it on | no model to prove it on |
| hax (Lean backend) | cargo-hax v0.5.0, which runs Charon `nightly-2026.10.31` + Aeneas `build-2b9e3ea` | not run (maintainer decision of 2026-11-21): same pipeline as Charon + Aeneas, with hax-lib specifications in front; not run, saving its 10 GB | | | | | |
| Creusot | v0.14.0 (`65349025`), Rust nightly-2026-08-03, Why3 1.8.2+git (`05bf4ddf`), why3find `0f054b93`; Alt-Ergo 2.6.4, Z3 (prints 5.1.0), CVC5 1.4.1, CVC4 1.8 (creusot-install's downloads) | works with trusted shim (123 lines) | trusted shim, as Aeneas (one trait per client C function, implemented in unverified Rust by the indirect call; `ffi.rs` is `cfg(not(creusot))`), plus a client contract for (a) on `ApplyAll` | 123 (shims 30, C glue 88, client contract 5) | may diverge (partial correctness); a trait method without contract is a relation, so no determinism is assumed (unlike Aeneas and hax); no range on the result; nothing assumed of what the callout writes into `args` (the verified side restores its fields); the subject is a shared slice made by the glue (length agreement is a precondition; the verified side holds no permission on the subject across the callout); for (a), the client keeps the record well formed (`ApplyAll`'s contract, trusted: Creusot does not see the implementation in `ffi.rs`, so it checks no refinement of it) | yes, proved under the client contract; `vu_i_apply`'s address is taken in trusted code (`c_apply` in `ffi.rs`) | yes; Miri (Stacked and Tree Borrows) accepts a Rust client calling the accessors through the raw pointer during a callout |
| RefinedRust | `lgaeher/refinedrust-dev` `2862b1d8` (2026-11-16), Rocq 9.2.0 (switch `refinedrust`, with `refinedrust-stdlib`), frontend Rust nightly-2026-11-15 | works with trusted shim (152 lines) | trusted shim, as Aeneas, hax and Creusot (one trait per client C function, with a RefinedRust trait specification; the one implementation per trait, in `ffi.rs`, is `#[rr::skip]` and does the indirect call), plus client contracts: the trait specifications of `EncLen`, `Callout` (no precondition: the client accepts every argument) and `ApplyAll` (the record invariant, for (a)); `proto.h`'s arrays spelt as one field per element (RefinedRust at `2862b1d8` cannot fold an array back after an element write); three of the twelve proof files are manual (`proofs/`) | 152 (shims 37, C glue 99, client contracts 16; the subject precondition of `get_subject_byte` is not counted, as CN's) | may diverge (partial correctness); any result; the encoding is lent nothing; the callout gets `*args` mutably and may leave any values in its nine fields (the verified side restores its four); the C caller meets `get_subject_byte`'s precondition: the subject is `subject_len` live bytes, owned for the call; the subject is lent **whole** (an owned array, given back with the same bytes), and read in verified code (`ptr::add`, `ptr::read`, manual proof) | yes, proved under the client contract; `IApply` refines `Apply`'s specification (checked); address taken in trusted code | yes, three accessors called by name, proved; Miri clean (Stacked and Tree Borrows) |
| Bedrock2 | `mit-plv/bedrock2` `67b682a5` (2026-11-19), coqutil `4c399b76`, Rocq 9.3.0 (`provers`) | works with trusted shim (119 lines) | trusted shim (the three indirect calls are external actions, `cmd.interact`, made by three C functions; Bedrock2 calls functions by name only); the contract of each action on `ext_spec` is a section variable of `VU.v`, so a hypothesis of every theorem (`Print Assumptions`: closed under the global context), and `ext_spec.ok` is assumed; for (a), a client contract stated on the function the client is given (`respects_i_apply`, as Isabelle-LLVM); `ToCString` prints the C, wrapped to `proto.h` by a trusted ABI layer (every Bedrock2 value is a machine word) | 119 (C shim 13, ABI mapping 59: `b2ext.h` 16, `abi.c` 31, struct offsets 12; callee contracts, `ext_spec.ok` and the memory predicates they use 47) | returns (an external call's `ext_spec` gives a postcondition for its results: no divergence); result any `int` (the shim sign-extends it); the encoding is lent the byte at `p` (whole) and gives it back unchanged; the callout is lent the whole `args` record and the subject **whole** (no fractional permission in Bedrock2's separation logic) and gives back the record with `subject`, `subject_len`, `pos` and `num` unchanged (slots and padding any) and the subject with the same bytes; for (a), the client reaches the record only through the `vu_i_apply` it is given | yes, through the shim (C takes `vu_i_apply`'s address); proved under the client contract `respects_i_apply`, composed with `b2_vu_i_apply_ok` (`i_apply_rec_wf`) in `b2_vu_fold_all_ok` | yes, three accessors called by name, proved; the read accessor reads the subject in verified code (`load1` from the lent array) |
| CN | `rems-project/cn` `f2e8eeb4` (its `--version` prints "unknown"), `cerberus-lib` at `rems-project/cerberus` `a0f7071`, OCaml 5.4.1; Z3 4.15.3 | works with trusted shim (22 lines) | trusted shim (three C functions marked `trusted` make the indirect calls; their CN specifications are the callee contracts) | 22 (the three shims with their specifications 19, `rec_wf` 3) | may diverge (partial correctness); result any `int`; the encoding is lent nothing; the callout gets `*args` (`RW`) and gives back some `vu_args` (the verified side restores its fields); the callout is lent no access to the subject; the apply-all function keeps the record well formed (the shim's contract); the read accessor takes the subject whole (`RW`, CN has no read-only share) and gives it back with the same bytes | yes; `vu_i_apply`'s address is taken in the trusted shim | yes |
| RefinedC | `iris/refinedc` `d0575839` (with `coq-lithium` at the same commit), Rocq 9.1.0, Iris `fc84ea73`, `cerberus-lib` `f11e6b33` | works | client contract (each client pointer argument has a `function_ptr` type carrying the callee's specification; RefinedC checks the indirect calls that `vu.c` makes itself) | 25 (callee contracts 12, the refinement types of `vu_args` and `vu_fold_rec` they use 12, `rec_wf` 1) | may diverge (partial correctness); result any `int`; the encoding is lent nothing (`p` as `place`); the callout gets `*args` owned and gives back some `vu_args` (the verified side restores its fields); the subject is a shared, read-only array (`&shr`) held in `vu_args`, so neither the callout nor the accessor can write it; `apply_all` gets `vu_i_apply` with its proven specification and must give the record back well formed | yes, in verified code: `vu_fold_all` passes `vu_i_apply`, whose `function_ptr` type is its proven specification | yes |

## Notes

- **Routes, not stacks: hax F\*** (maintainer decision of 2026-11-22).
  hax's F\* backend is its own route, Rust → F\* through hax, built as a
  Rust library; it is not stack C (F\* + Pulse, C generated by
  KaRaMeL). The report's matrix lists hax only under stack A (its Rocq
  backend). Its verdict (works with trusted shim, 134) does not change
  which stacks are eliminated.

- **Run G (Bedrock2).** Bedrock2's language has no function pointer:
  `cmd.call` names a function of the program, and anything else is an
  external action (`cmd.interact`), whose effect the proofs take from
  `ext_spec` and which `ToCString` prints as a C call to a function of
  the action's name. The three indirect calls are three such actions
  (`shim.c`), as Isabelle-LLVM's shim; `VU.v` defines no `ext_spec`:
  each action's contract is a section variable, a hypothesis of every
  theorem. Every Bedrock2 value is a machine word, so `abi.c` converts
  `proto.h`'s `int` arguments (sign extension) and results (proven in the
  `int` range), and 32-bit fields are read with `load4` and
  sign-extended in verified code. The slot accessors and the record
  write of `vu_i_apply` select the field with a chain of tests on the
  index, as Isabelle-LLVM's prototype; the read accessor computes the
  address `s + i` and reads it from the lent byte array. The read
  access is expressed by lending the subject whole (as Isabelle-LLVM,
  CN and RefinedRust): Bedrock2's separation logic has no fractional or
  read-only permission. Proof automation: `straightline` plus a
  word-arithmetic tactic (`wsolve`); the seven functions check in about
  3 minutes.

- **Run F.** RefinedRust: the structs are plain field lists (a
  `#[rr::refined_by]` struct becomes an invariant type and the proofs
  get stuck folding it back), with `slot[5]` and `from[8]` spelt as
  fields (asserted to have the C layout in `ffi.rs`); the read accessor
  owns the subject array in its precondition and reads it with
  `ptr::add` and `ptr::read` (manual proof, as minivec's
  `get_unchecked` in RefinedRust's case studies); `record_at` and
  `i_apply` need a few manual lines; the branch rules and the record
  test are separate verified functions (the first proofs took 15-25
  minutes each, the crate now checks in 7). Creusot: on a crate whose
  goals are all provable, why3find with 1 ms limits prints "proof
  failed", "✘" and "N unproved files", the summary of a refutation; the
  control check now proves the target alone with the prover answers
  logged and needs an Invalid or Unknown answer. `Unknown` is not a
  refutation by itself (a prover also answers it on a valid goal it
  cannot decide): the rejection is genuine because the normal run
  proves the same target at the same limits (`normal_run=passed`).

- **Run E.** No install was refused (69 GB free at the start). CN
  cannot call a function pointer unless it is provably a defined
  function, hence three `trusted` shims; RefinedC calls the client
  pointers from verified code with a `function_ptr` type that carries
  the callee's specification, and passes `vu_i_apply` with its proven
  specification (shape (a) in verified code, as Pulse and VST). Read
  access: RefinedC lends a shared, read-only array (`&shr`); CN has no
  read-only share and lends the subject whole (as Isabelle-LLVM);
  Creusot and hax read a shared slice made by trusted glue (as Verus
  and Aeneas). hax F\*: a trait method needs `requires(true)` to be
  callable from F\*, an obligation on the C client counted as trusted
  (8 lines; hax F\* is 134, was 126; hax Rocq also 134 since the review of run E). `count-trusted.sh` counts CN's
  `/*@ ... @*/` specifications and RefinedC's `//@` Rocq prelude as
  code. Miri accepts Creusot's and hax's sources.

- **Milestone 4 (run D; run E installed the three tools and checked CN and RefinedC).** Nothing was measured: the bench host had
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
  `axiomatization`, `oracle` or `quick_and_dirty`), Bedrock2 (no `admit`,
  `Admitted`, `Axiom`, `Parameter` or `Hypothesis`; `Print Assumptions`
  of the seven theorems: closed under the global context).
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
  (`hcall`), Isabelle-LLVM (predicate `Q`) and Bedrock2 (the trace in
  `spec_of_callout_step`) tie the result to the value the callee
  returned. Pulse and VST only say that there is some `int`
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
  (`c_apply` in `ffi.rs`), Isabelle-LLVM (`shim.c`) and Bedrock2
  (`bedrock2/shim.c`) take it in trusted code.
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
