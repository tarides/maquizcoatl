# Experiment #12, entry 10: corrections after the results review

**What.** Corrections to entries 4, 5 and 7 that the automated results
review on issue #10 asked for
([comment](https://github.com/tarides/maquizcoatl/issues/10#issuecomment-7017131208),
problems 1, 3, 4 and 5), and the conclusion restated with the new
measurement of [entry 9](2026-11-19-exp-12-optimiser-share.md).
Problem 2 (provenance) is answered by
[entry 8](2026-11-19-exp-12-provenance-addendum.md). Entries 1-7 are left
as recorded, apart from a one-line pointer to this entry at the top of
entries 1, 4, 5 and 7.

**Why.** The review reproduced every number from the raw CSV. It found
one wrong count, one attribution that was inferred rather than measured,
one figure whose scope was not stated, and a conclusion that went beyond
what was measured.

## Provenance

Text corrections on the data of entries 1-7 (run `r1`), plus the
measurement of entry 9 (run `r2`, scripts at `5bb7b02`). No other rerun.

The branch was rebased on `main` after the runs, which changed every
commit id that entries 1-7 cite. Old to new: `73a7c49` → `d52e54f`
(plan), `3a2ec22` → `6c36304` (plan review fixes), `3d11767` →
`bde2d07` (code), `37370a2` → `e55c7ff` (C driver fix), `e742e4d` →
`0964ea3` (results of `r1`), `8947ce6` → `5bb7b02` (run `r2` scripts).
The trees are unchanged except for `main`'s documentation commits.
The bench host's clone ran `r1` at the old ids and `r2` at `8947ce6`.

## Corrections

### Entry 4 (short subjects): calls per pass

Entry 4 says "Calls per pass: … VS Code 759,850 (123,982 distinct
searches)". This is wrong. `short.csv` has `calls_per_pass = 198,837` for
every VS Code cell except `ocaml-re`, which has **192,444** (120,144 of
the 123,982 distinct searches, 3,838 skipped). The correct line is:

> Calls per pass: jq 136, PHP 158, VS Code **198,837** (123,982
> distinct in-subset searches, each repeated `weight` times;
> `ocaml-re` 192,444), long PHP 11.

759,850 is the weighted total of *all* expanded VS Code searches per
pass, in or out of the subset (entry 1's coverage table). 198,837 is
its in-subset share (26.2%). The ns/call figures are unaffected because
they divide by the calls actually made in a pass.

### Entries 4 and 7: what the "FFI crossing" figure includes

The C driver calls `onig_search_with_param` directly in a static loop.
The OCaml harness (`lab/12-ffi-vs-native/bench/main.ml`) calls
`E.search` through a first-class `ENGINE` module, an indirect call that
cannot be inlined, and `Stubs_engine.search` then calls the external.
The +3.5 ns (jq) to +7.8 ns (VS Code) per call of entries 4 and 7 is
therefore **stubs plus harness dispatch (first-class `ENGINE` module
call and the `Stubs_engine` wrapper) minus C**, an upper bound on the
crossing itself. The VM columns pay the same dispatch, so the VM's
−32% on jq slightly understates the VM's advantage.

The timed loop never reads captures back. A caller that does pays two
more `[@@noalloc]` calls per capture group (`beg` and `end` in
`stubs/onig.ml`), each a crossing of the same kind. Neither point
changes the ranking.

### Entries 5 and 7: attribution of the large-subject gap, now measured

Entries 5 and 7 attributed the VM's 7-11x large-subject gap "mostly" to
the missing search optimiser, from the optimiser's choices alone. Entry
9 measures it with Oniguruma built with `ONIG_DONT_OPTIMIZE` on the same
subjects and patterns. Without its optimiser Oniguruma runs at
75-78 MB/s (median over patterns, against 440-660 MB/s optimised and
58 MB/s for the VM). The corrected sentence for both entries is:

> The VM's 7-11x gap on large subjects is mostly the missing search
> optimiser, now measured: compiling Oniguruma's optimiser out
> (`ONIG_DONT_OPTIMIZE`) makes it 5.9-8.5x slower on these patterns, about
> 72% of the time the VM loses (median over patterns; 41-95% per
> pattern, except `\s*(\[)` where the optimiser does not help). The
> remaining 1.3x (1.0-1.4x on literals, about 2x on alternations) is the
> VM against Oniguruma's matcher without search skipping.

This holds for the large-subject patterns, which are all literals or
literal alternations. On the short VS Code calls the attribution stays
the inference of entry 4: those searches were not rerun without the
optimiser.

### Entry 7: conclusion restated

Items 1 and 3 of entry 7's conclusion stand, with the crossing figure
read as above. Item 2 and item 4 are replaced by:

2. **The engine cost of a naive native OCaml VM is large, and most of it
   is the missing search optimiser, measured on large subjects.** The VM
   is faster than Oniguruma on jq's tiny searches (−32% to −40%). It is
   7-8x slower on VS Code line scans and 7-11x on large subjects. On
   large subjects about 72% of that gap disappears when Oniguruma's own
   optimiser is compiled out (entry 9), and the rest is 1.3x. On pure
   backtracking (catastrophic patterns, no skipping possible) the VM
   pays 2-3.4x per retry. flambda `-O3` recovers 11-31%.
4. **Which way the evidence points on the open question:** on cost,
   bindings. A good binding's FFI tax (an upper bound of a few ns per
   call including harness dispatch, zero allocation, plus one
   `noalloc` call per capture bound read) is one to two orders of
   magnitude smaller than a first native VM's engine gap. A native
   engine closes that gap only if it carries a search optimiser and
   tighter backtracking. **The portability and assurance arguments for
   native code are unchanged** by these results: js_of_ocaml and
   wasm_of_ocaml cannot link the C core, and binding code sits outside
   the proofs. The trade-off between cost on one side and portability
   and assurance on the other is left to the maintainer. A native
   engine's retry-count semantics (one PHP call differs) needs a spec
   decision on whether retry counts are observable.

The sentence "The stub binding is the low-risk default for the OCaml
deliverable" is withdrawn. It was a recommendation on the deliverable,
and the experiment measured only cost.

## Analysis

- No figure in entries 2-6 changes. The only numeric correction is the
  calls-per-pass count. The other corrections narrow what the figures
  claim (crossing: an upper bound) or replace an inference with a
  measurement (optimiser share).
- Follow-ups added by the review: shuffle the expanded call list once
  per pass in the short shape (the current pass repeats each call
  `weight` times back to back, which keeps caches and predictors warm);
  rank a second set of large-subject patterns by VM time per call; open
  a spec issue on whether the retry count is observable behaviour (PHP
  case 419).
