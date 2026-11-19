# Deviation log

Maquizcoatl specifies Oniguruma as of upstream `f95747b`, but it is not
bug-for-bug compatible with it (see `CLAUDE.md`). Where the C code is
wrong (crash, memory error, CVE, inconsistent result) or disagrees with
Oniguruma's own documentation, the specification states the correct
behaviour, and this file records the deviation from upstream and its
reason. A behaviour of `f95747b` not listed here is meant to be
reproduced.

Entries are never renumbered. A decision that changes later gets a new
entry that supersedes the old one, and the old entry's status says so.

## Entry format

Each entry is a `## DEV-NNN: <title>` section with these fields:

- **Upstream behaviour at `f95747b`**: what the C library does, with
  citations `upstream/<path>:<line>` (always commit `f95747b`) and the
  probe ids that show it (probe data in `probes/`, results in
  `lab/results/`).
- **Maquizcoatl behaviour**: what the specification requires instead.
- **Alternatives considered**: other positions, and why they were not
  chosen.
- **Reason**: why upstream is not followed (bug-free goal,
  disagreement between documentation and code, ...).
- **Evidence**: links to the recorded results.
- **Status**: who decided, and when.

---

## DEV-004: `\p` not followed by `{` is a one-letter property only when the letter names one

Origin: experiment #1, pattern inventory (issue #5), review follow-up
and maintainer decision
(https://github.com/tarides/maquizcoatl/issues/5#issuecomment-7008852226).

**Upstream behaviour at `f95747b`.** Commit `005482a` (2025-02-10, "add
Unicode property notation \pL etc..", after v6.9.10; no release tag
contains it) added the syntax flag `ONIG_SYN_ESC_P_WITH_ONE_CHAR_PROP`
(`upstream/src/oniguruma.h:537`). It is set in the Oniguruma syntax
(`upstream/src/regparse.c:108`), in Perl (`upstream/src/regsyntax.c:194`)
and in Perl_NG (`upstream/src/regsyntax.c:236`), not in Ruby, Java or
Python. Under these three syntaxes, `\p` or `\P` followed by anything
other than `{` is tokenised as a character property with no braces,
outside classes (`upstream/src/regparse.c:6140-6144`) and inside them
(`upstream/src/regparse.c:5404-5408`).
`fetch_char_property_to_ctype` then takes exactly the next character as
the property name (`upstream/src/regparse.c:6780-6793`) and fails with
-223 (`ONIGERR_INVALID_CHAR_PROPERTY_NAME`) if it is not one. So
`[\s\d\p]` reads `]` as a property name and the pattern is rejected
with -223, and so is a `\p` at the end of the pattern. Without the
flag (Ruby, Java, Python, and every syntax in released Oniguruma),
`\p` not followed by `{` is an identity escape for the literal `p`:
under Ruby, `^[\s\d\p]+$` compiles and matches `p` and `1 p`.

Valid one-letter names at `f95747b` (checked by compiling `\pX` for
every printable ASCII `X` against the stock library, Oniguruma syntax):

- Unicode encodings (UTF-8, UTF-16BE/LE, UTF-32BE/LE, which use
  `onigenc_unicode_property_name_to_ctype`,
  `upstream/src/unicode.c:1191`): `C`, `L`, `M`, `N`, `P`, `S`, `Z`,
  the seven General_Category major classes, in either case (the name
  table is a case-insensitive gperf table,
  `upstream/src/unicode_property_data.c:2`; one-letter entries at
  `:28422`, `:28452`, `:28465`, `:28600`, `:28607`, `:28766`, `:28775`).
  A one-letter user-defined property registered with
  `onig_unicode_define_user_property` is also found (the user table is
  searched first, `upstream/src/unicode.c:1217-1226`).
- Other encodings (checked: US-ASCII, ISO-8859-1, EUC-JP, Shift_JIS):
  none. Their property tables (`onigenc_minimum_property_name_to_ctype`,
  `upstream/src/regenc.c:877`, and the EUC-JP and Shift_JIS tables) have
  no one-letter names, so every `\pX` is -223 there.

Affected corpus patterns: five VS Code `log.tmLanguage.json` patterns
`(?<=^[\s\d\p]*)\b<L>\b` with `<L>` one of `D`, `E`, `I`, `V`, `W`
(triple ids `769727f713cd`, `2e1ea425b16c`, `e87edd753424`,
`6fcdb45d3c23`, `b957ec86322f` in
`experiments/01-pattern-inventory/patterns/vscode.jsonl`, on branch
`exp/01-pattern-inventory`). The Oniguruma bundled in vscode-oniguruma
1.7.0 (v6.9.8), which VS Code ships, compiles them, and the 42 VS Code
searches where stock `f95747b` and the host disagree all come from them.

**Maquizcoatl behaviour.** Under a syntax with
`ONIG_SYN_ESC_P_WITH_ONE_CHAR_PROP`, `\pX` and `\PX` (with `X` not `{`)
are a one-letter property (negated for `\P`) when `X` names a valid
one-letter property for the encoding (the list above, including
user-defined one-letter properties). Otherwise `\p` (`\P`) is parsed as
in released Oniguruma: an identity escape for the literal `p` (`P`),
and `X` is parsed normally. So `[\s\d\p]` is the class of white space,
digits and `p`, and the five log grammar patterns compile. Syntaxes
without the flag are unchanged. `\p{...}` is unchanged.

**Alternatives considered.**

- (a) Follow `f95747b`: reject `[\s\d\p]` with -223. Breaks a grammar
  that ships with VS Code, the main host, for an unreleased syntax
  extension.
- (b) Follow released Oniguruma: drop the one-letter form altogether.
  Compatible with every released version, but drops the `\pL` notation
  the last upstream commits added on purpose (and that Perl users
  expect).

**Reason.** Compatibility with deployed patterns: a grammar shipped
with VS Code depends on the released behaviour, and the change that
breaks it was never released. The chosen rule keeps every `\pX` that
upstream accepts with the same meaning, and accepts the patterns that
released versions accept.

**Evidence.** Compile failures in
[`tables.md`](https://github.com/tarides/maquizcoatl/blob/exp/01-pattern-inventory/experiments/01-pattern-inventory/tables/tables.md)
(VS Code compiled form); host disagreements in
[`workloads/data/summary.json`](https://github.com/tarides/maquizcoatl/blob/exp/01-pattern-inventory/experiments/01-pattern-inventory/workloads/data/summary.json);
[workloads lab entry](../lab/results/2026-11-19-exp-01-workloads.md);
[re-run lab entry](../lab/results/2026-11-19-exp-01-review-fixes.md);
review (https://github.com/tarides/maquizcoatl/issues/5#issuecomment-7008480225).

**Status.** Decided by the maintainer 2026-11-19, option (c)
(https://github.com/tarides/maquizcoatl/issues/5#issuecomment-7008852226).
