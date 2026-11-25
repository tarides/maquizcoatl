# Experiment #7 follow-up: which patterns see the 13 Latin-1 ctype differences

**What.** A probe of the C library on the 13 code points below U+0100
where `onigenc_unicode_is_code_ctype` (ISO-8859-1 table) and the `CR_*`
ranges disagree ([fidelity entry](2026-11-19-exp-07-fidelity.md)): each
code point matched under UTF-8 against its ctype outside a class and
inside one, the word-boundary assertions on U+00B2, and the public
`ONIGENC_IS_CODE_*` answers.

**Why.** The fidelity entry left open whether the difference is a
deviation ([review fixes](2026-11-19-exp-07-review-fixes.md)). The
maintainer asked what needs deciding; the answer depends on whether a
pattern can observe the difference. Outcome: maintainer decision (a),
recorded as DEV-009 in `spec/deviations.md`.

## Provenance

- Upstream `f95747b`, built out of tree (CMake Release, static
  `libonig.a`), never inside `upstream/`.
- Program `lab/07-large-tables/latin1ctype.c`, compiled with
  `gcc -Wall -I<upstream>/src -I<builddir> latin1ctype.c <builddir>/libonig.a`.
- Workstation: 12th Gen Intel Core i7-1260P, Linux 7.0.0-43-generic,
  GCC 15.2.0, CMake 4.2.3. Deterministic; one run.
- Run 2026-11-25. Output `2026-11-25-exp-07-latin1-ctype-raw/out.txt`
  (sha256 prefix `8f3a80be1c08231d`).

## Results

| Code points | Outside a class | Inside a class | Public macro |
|---|---|---|---|
| `Word`: U+00B2, B3, B9, BC-BE | `\w`, `\p{Word}` match (ISO) | `[\w]`, `[\p{Word}]`, `[[:word:]]` do not (`CR_*`) | `ONIGENC_IS_CODE_WORD` = 1 (ISO) |
| `Print`: U+0009-000D, U+0085 | `\p{Print}` does not match (`CR_*`) | `[\p{Print}]`, `[[:print:]]` do not (`CR_*`) | `ONIGENC_IS_CODE_PRINT` = 1 (ISO) |
| `Cntrl`: U+00AD | `\p{Cntrl}` does not match (`CR_*`) | `[\p{Cntrl}]`, `[[:cntrl:]]` do not (`CR_*`) | `ONIGENC_IS_CODE_CNTRL` = 1 (ISO) |

On `a²` (U+00B2): `a\b` finds no match, `a\B` matches at 0; on `²`,
`\W` finds no match, `[\W]` matches at 0.

## Analysis

- `Word` is inconsistent inside upstream: the ctype node (`\w`,
  `\p{Word}`, `\b`, `\B`) answers from the ISO table, the class forms
  from `CR_*`. `\p{Word}` is special-cased into a ctype node
  (`upstream/src/regparse.c:6828-6832`); every other property becomes a
  class built by `add_ctype_to_cc`.
- `Print` and `Cntrl` differ only through the public ctype macros; no
  pattern form observed here sees the ISO answer.
- Decision (a): the Unicode data everywhere (DEV-009).
