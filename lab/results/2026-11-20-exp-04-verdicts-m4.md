# exp-04 verdicts with mechanism 4: criteria 5 and 6 for all four mechanisms

## What

Criteria 5 and 6 of experiment #4 (issue #7) with mechanism 4
(Isabelle-LLVM) added. This entry supersedes the criterion 6 tables of
the [verdicts entry](2026-11-19-exp-04-verdicts.md) and of the
[review-fixes entry](2026-11-19-exp-04-review-fixes.md) (which itself
superseded the first one); the rows for 1a, 1b, 2 and 3 are copied
unchanged from the review-fixes entry. No new measurement beyond the
[m4-isabelle-llvm entry](2026-11-20-exp-04-m4-isabelle-llvm.md).

## Why

Criterion 6 asks for a verdict per mechanism; the experiment stayed
open until mechanism 4 ran.

## Provenance

Same bench host and branch as the m4-isabelle-llvm entry; rows 1a-3
from the 2026-11-19 run (see the entries linked there). DEV-005
(public-only exports) and DEV-006 (`onigposix.h`'s `OnigSyntaxType`)
are decided and unchanged by this run.

## Data: criteria 1-4, all mechanisms

| | 1a F\*/Pulse, KaRaMeL | 1b F\*/Pulse, Custard | 2 hand-written C (VST) | 2 Why3 to C | 3 Rust `cdylib` | 4 Isabelle-LLVM |
|---|---|---|---|---|---|---|
| 1 public symbols (208 / 216) | all | all | all | not built | all | all |
| 1 leaked internals (114) | not exported | not exported | not exported | | not exported | not exported |
| 1 extra symbols (with the version script) | 0 | 0 | 0 | | 0 | 0 |
| 1 SONAME, three names | pass | pass | pass | | pass | pass |
| 2 layout (10 / 12 structs) | pass | pass | pass | | pass | pass (upstream headers shipped) |
| 3 binaries (22 / 24) | pass | pass | pass | | pass | pass |
| 4 CMake / pkg-config / emscripten | pass / pass / pass | pass / pass / pass | pass / pass / pass | | predicted: needs Rust | predicted: binary level only |

## Criterion 6: verdicts (supersede earlier tables)

| Mechanism | Binary drop-in | Source drop-in | Outside the proofs (criterion 5) |
|---|---|---|---|
| 1a F\*/Pulse, KaRaMeL | yes (stub level, measured with the version script) | yes (measured) | 43 data-name renames, `OnigDefaultSyntax`, variadic in C, version script, build glue |
| 1b F\*/Pulse, Custard | yes (stub level, measured with the version script) | yes (measured) | load-time constructor, which needs preemptible data (no `-Bsymbolic` or protected visibility, measured), `OnigDefaultSyntax`, variadic in C, version script, build glue |
| 2 C, VST | yes (stub level, measured with the version script) | yes (measured) | version script and build glue; `va_arg` helpers need VST specifications (unchecked) |
| 2 C, Why3 | inferred, not built: only with a hand-written C data layer | inferred: same build as the C stub | the 44 data symbols, every mixed-case name, variadic, version script |
| 3 Rust `cdylib` | yes (stub level) | predicted: needs Rust | C body of the variadic, exported by a naked trampoline or a version-script entry (both measured); soname and install glue |
| 4 Isabelle-LLVM | yes (stub level, measured with the version script) | predicted: binary level only (the IR fixes the data layout and triple at export) | the 44 data symbols (no global data in Isabelle-LLVM), variadic in C, the C type mapping of every signature (only fixed-width integers, pointers and plain structs are expressible; checked by size and alignment, not proved), shipped headers (upstream's), every call through a function pointer (no HOL-level function-pointer type, inferred from the sources), version script, soname and install glue |

## Analysis

- No mechanism is eliminated by the ABI at stub level: all four give a
  binary drop-in with a hand-written C shell. They differ in the size
  of that shell.
- Smallest to largest shell: 2 VST (build glue only), 3 Rust (the
  variadic), 1a and 1b (data naming or initialisation, plus the
  variadic), then Why3 and Isabelle-LLVM, which cannot produce the data
  half of the ABI at all. Isabelle-LLVM also cannot name `int`,
  `unsigned`, `size_t`, enums or function pointers, so its link to
  upstream's prototypes is an unverified mapping table, and an
  implementation would need C for every encoding vtable and callback
  call.
- Isabelle-LLVM's header generator silently gives a wrong layout to a
  struct with a function-pointer field (probe); a design that relied on
  its generated headers for Oniguruma's structs would ship the wrong
  ABI. The stub avoids it by shipping upstream's headers.
- Criterion 6 is now complete for the four mechanisms. The choice
  between them is the maintainer's; this table is the ABI input to it.
