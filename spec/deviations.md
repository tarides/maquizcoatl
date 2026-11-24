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

## DEV-001: Lookbehind acceptance must not depend on automatic possessivisation

Origin: experiment #2, deviation candidate D1 (issue #6).

**Upstream behaviour at `f95747b`.** Under syntaxes without
`ONIG_SYN_VARIABLE_LEN_LOOK_BEHIND` (probed: Ruby, Perl), a lookbehind
body must have a fixed length, after `alt_reduce_in_look_behind`
(`upstream/src/regcomp.c:4531-4594`) has reduced a head quantifier over
a string, character type, class or backreference to its minimum count
(`:4536-4545`; `a+b` becomes `ab`, `a*b` becomes `b`). But
`tune_look_behind` runs `tune_tree(body)` first (`:4625`, reducer at
`:4628`), and `tune_tree`'s automatic possessivisation
(`upstream/src/regcomp.c:4714-4727`) wraps `a+` or `a*` in an atomic
group whenever the next literal is exclusive of it. The reducer only
accepts a bare quantifier (`:4536`), so the reduction is skipped and the
body is rejected with -122 (`ONIGERR_INVALID_LOOK_BEHIND_PATTERN`).
Result: `(?<=a+a)x` (lb17r/p) and `(?<=\w+b)x` (lb18r/p) compile, but
`(?<=a+b)x` (lb09r/p), `(?<=a*b)x` (lb11r/p) and `(?<!a+b)x`
(lb10r/p, lb20r/p) are rejected, although all five bodies have the same
shape. The bytecode dump confirms that the reduction is skipped under
the Oniguruma syntax too: lb09o compiles to a variable-length step-back
(`step-back-next`), lb16o-lb18o to a fixed one (`step-back-start` only).

**Maquizcoatl behaviour.** Whether a lookbehind compiles is decided on
the parsed pattern, before any optimisation. The head-quantifier
reduction applies to every alternative whose head is a quantifier over
a string, character type, class or backreference, whatever follows it:
lb09r/p, lb10r/p, lb11r/p and lb20r/p compile and give the results the
Oniguruma syntax gives (`M 3-4`, `M 2-3`, `M 1-2`, `N`). An atomic group
or possessive quantifier written by the user is not a bare quantifier
and is not reduced, as upstream.

**Alternatives considered.**

- Never reduce: reject `(?<=a+)x`, `(?<=a+a)x` and `(?<=\w+b)x` under
  Ruby and Perl too. Consistent, but rejects patterns upstream accepts
  (breaks drop-in use) and drops a rewrite upstream added on purpose.
- Keep upstream's behaviour and document it: the accepted language
  would depend on the optimiser's exclusivity test, which is not a
  property a user can read off the pattern.

The reduction is sound in both chosen directions: for a head quantifier
`x{m,n}` with no capture inside, some `x{k}y` (`k >= m`) ends at the
current position if and only if `x{m}y` does, for positive and negative
lookbehind alike.

**Reason.** Bug-free goal: inconsistent result (two patterns of the
same shape differ, and no syntax flag, option or documented rule
explains it).

**Evidence.** [Run 1 analysis, area 4](../lab/results/02-semantic-probes-2026-11-19/README.md#4-lookbehind);
[lookbehind results](../lab/results/02-semantic-probes-2026-11-19-r2/raw/lookbehind.joined.tsv)
and [opcodes](../lab/results/02-semantic-probes-2026-11-19-r2/raw/lookbehind.opcodes.tsv)
(run 2).

**Status.** Decided by the maintainer 2026-11-19.

---

## DEV-002: Captures are allowed inside a negative lookbehind

Origin: experiment #2, deviation candidate D2 (issue #6).

**Upstream behaviour at `f95747b`.** A capture group inside a negative
lookbehind is a compile error (-122) under every syntax: the allowed
bag types for a negative lookbehind, `ALLOWED_BAG_IN_LB_NOT`
(`upstream/src/regcomp.c:3499`), omit `BAG_MEMORY`, which the positive
case `ALLOWED_BAG_IN_LB` (`:3498`) includes; the check is at `:3545`,
called from `tune_look_behind` at `:4610-4614`. Probes lb05o/r/p
(`(?<!(a))b` on `cb`) and lb06o/r/p (on `ab`). `doc/RE:306-317`, which
lists the lookbehind restrictions (absent operators, multi-character
case folding), does not mention it. Captures are allowed in a negative
lookahead (`(?!(a))b` on `b` gives `M 0-1 | 1=-`) and in a positive
lookbehind (lb07, lb08o).

**Maquizcoatl behaviour.** Capture groups are allowed inside a negative
lookbehind under every syntax, with the same meaning as inside a
negative lookahead: while the body is being tried, its groups capture
normally (a backreference inside the body sees them); after the
negative lookbehind succeeds (the body did not match), they are unset.
Expected results: lb05 `M 1-2 | 1=-`, lb06 `N` (the JavaScript results
of those probes). The other lookbehind restrictions (length classes per
syntax, DEV-001, `LOOK_BEHIND_MAX_CHAR_LEN`) are unchanged.

**Alternatives considered.**

- Keep the restriction and document it (amend the deviation to a
  documentation fix only). Smaller to specify and to verify, and
  compatible with every pattern upstream accepts; not chosen because
  the documentation and the rest of the semantics (negative lookahead,
  positive lookbehind) allow captures, and the restriction has no
  stated reason.

**Reason.** Disagreement between documentation and code: `doc/RE`
documents negative lookbehind without this restriction, and the
restriction is inconsistent with captures in negative lookahead.
Every pattern that compiles upstream compiles with the same meaning.

**Evidence.** [Run 1 analysis, area 4](../lab/results/02-semantic-probes-2026-11-19/README.md#4-lookbehind);
[lookbehind results](../lab/results/02-semantic-probes-2026-11-19-r2/raw/lookbehind.joined.tsv)
(run 2).

**Status.** Decided by the maintainer 2026-11-19.

---

## DEV-003: The empty-loop capture-status check covers every group of the loop body

Origin: experiment #2, deviation candidate D3 (issue #6), as refined by
run 2.

**Upstream behaviour at `f95747b`.** After an iteration of an unbounded
loop that matched the empty string, the loop stops, keeping that
iteration's captures. It continues instead if a *selected* capture
group changed during the iteration (`OP_EMPTY_CHECK_END_MEMST`). The
selection is made at compile time: `OP_EMPTY_CHECK_END_MEMST` is emitted
only when the quantifier carries `EMPTY_STATUS_CHECK`
(`upstream/src/regcomp.c:984`), which `set_empty_status_check_trav` sets
only for groups referenced by a backreference *outside* the loop
(`upstream/src/regcomp.c:3941-3957`, the `! is_ancestor_node(ernode,
node)` test). Other loops get the plain `OP_EMPTY_CHECK_END` and stop.
So `(?:\1a|())*` on `a` gives `M 0-0 | 1=0-0` (ei16, plain check, the
result pinned by `upstream/test/test_utf8.c:742`), while the same loop
followed by `\1`, `(?:\1a|())*\1`, gives `M 0-1 | 1=1-1` (ei19,
`memst`): adding a backreference after the loop changes how much the
loop consumes. `doc/RE:592-595` states the rule without the selection
("Zero-width match in an infinite loop stops the repeat, then changes of
the capture group status are checked as stop condition") and gives
`/(?:\1a|())*/ =~ "a"` as its example, a loop the implemented
selection excludes.

**Maquizcoatl behaviour.** The documented rule, for every loop: after an
empty iteration of a loop whose body contains capture groups, the loop
continues if any capture group of the body changed (became set, or
changed its start or end) during that iteration, and stops otherwise.
Results: ei16 `(?:\1a|())*` on `a` gives `M 0-1 | 1=1-1`, like ei19;
`test_utf8.c:742` is a recorded upstream difference. Loops whose groups
are not referenced anywhere give the same results as upstream (a
continued iteration repeats the previous empty one, so the loop then
stops with the same captures): ei04, ei05, ei07-ei09, ei11 unchanged.
Loops already selected upstream are unchanged (ei01-ei03, ei10,
ei17-ei20); recursive bodies keep the push variant's behaviour (ei14,
ei15). The specification must prove that the loop terminates (each
continued empty iteration changes a capture).

**Alternatives considered.**

- Keep upstream's selection (groups backreferenced outside the loop)
  and fix `doc/RE` instead: keeps `test_utf8.c:742`; not chosen because
  the result is not compositional (a backreference after the loop,
  ei19, changes the loop's extent compared with ei16), and the doc's own
  example would illustrate a rule that does not apply to it.
- Select only groups referenced by some backreference, inside or
  outside the loop: observably equal to the chosen rule (an
  unreferenced group cannot change the next iteration), but harder to
  state.
- ECMA-262's rule (reject the empty iteration, RepeatMatcher step 2.b):
  contradicts Oniguruma's documented stop rule and most of area 3
  (ei01, ei04, ei05, ei10, ei11).

**Reason.** Disagreement between documentation and code
(`doc/RE:592-595` vs `upstream/src/regcomp.c:984`, `:3941-3957`), and
bug-free goal (non-compositional result).

**Evidence.** [Run 2 analysis, area 3](../lab/results/02-semantic-probes-2026-11-19-r2/README.md#area-3-corrected-verdict-supersedes-run-1);
[empty-iteration results](../lab/results/02-semantic-probes-2026-11-19-r2/raw/empty-iterations.joined.tsv)
and [opcodes](../lab/results/02-semantic-probes-2026-11-19-r2/raw/empty-iterations.opcodes.tsv)
(run 2).

**Status.** Decided by the maintainer 2026-11-19.

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

---

## DEV-005: Only the public API is exported

Origin: experiment #4, ABI feasibility (issue #7), leaked-internals
question, proposal
(https://github.com/tarides/maquizcoatl/issues/7#issuecomment-7016693095)
and maintainer decision
(https://github.com/tarides/maquizcoatl/issues/7#issuecomment-7019890064).

**Upstream behaviour at `f95747b`.** Upstream's builds have no
visibility control. `ONIG_EXTERN` is plain `extern` outside Windows
(`upstream/src/oniguruma.h:55-71`). `upstream/CMakeLists.txt:90` builds
the library with no `-fvisibility`, no version script and no export
list, and `upstream/src/Makefile.am:59` does the same for libtool. So
`libonig.so.5` exports every non-static symbol of every object.
Besides the public API, which is 208 symbols in the default build
(164 functions, 44 data) and 216 with POSIX (172 functions), it exports
114 symbols that no installed header (`oniguruma.h`, `oniggnu.h`,
`onigposix.h`) declares: 106 functions (`onig_st_*`, `onig_node_*`,
`onigenc_*`, ...) and 8 data (`OnigAsciiLowerMap`,
`OnigEncAsciiCtypeTable`, `OnigEncAsciiToLowerCaseTable`,
`OnigEncDefaultCharEncoding`, `OnigEncISO_8859_1_ToLowerCaseTable`,
`OnigUnicodeFolds1`, `OnigUnicodeFolds2`, `OnigUnicodeFolds3`). The
full classification, with the declaring header line of each symbol, is
in `experiments/04-abi-feasibility/symbols.tsv` (class `internal`).

**Maquizcoatl behaviour.** `libonig.so.5` exports exactly the symbols
that the installed headers declare: 208 in the default build, 216 with
the POSIX API. Nothing else is exported, neither upstream's 114
internals nor any symbol private to the implementation (for example
the encoding callbacks of a generated stub, `s_init`,
`s_mbc_enc_len`, ..., or `custard_init_globals`). Public data symbols
keep default visibility and stay preemptible: no `-Bsymbolic`, no
protected visibility, no symbol versions (an anonymous version script,
as upstream has none). Client executables' copy relocations must keep
working. The specification covers only the public API.

**Alternatives considered.**

- Export the 114 internals as upstream does. This turns upstream's
  missing visibility control into API. The specification would have to
  cover 114 functions and data objects with their exact layout and
  behaviour, and the implementation could never change them. No known
  client and no harness binary needs them.
- Export a chosen subset (for example the 8 data tables). No client
  that uses one was found, so there is nothing to choose it by.

**Reason.** These symbols are not API. They are internals exposed only
because the upstream build lacks an export list. Specifying them would
fix upstream's implementation structure in the specification.

**Evidence.** Vincent Balat's survey of five libonig clients, with the
114 names searched as whole words in client code, finds 0 internal
uses: jq `5c001b1` (9 public symbols used), PHP `ext/mbstring`
`65d1418` (23), vscode-oniguruma `1e38f96` (9), Rust `onig` crate
`73e63eb` (195), Python `onigurumacffi` `ff1e5f4` (14)
(https://github.com/tarides/maquizcoatl/issues/7#issuecomment-7016693095).
None of the 24 harness binaries of experiment #4 needs an internal
symbol
([oracle entry](../lab/results/2026-11-19-exp-04-oracle.md)).
The stubs of mechanisms 1a, 1b and 2, rebuilt with a version script
listing the public names, export exactly those names and still pass
every layout and binary check, including the Custard constructor route
([exports entry](../lab/results/2026-11-19-exp-04-exports.md)).

**Status.** Decided by the maintainer 2026-11-19
(https://github.com/tarides/maquizcoatl/issues/7#issuecomment-7019890064).

---

## DEV-006: `onigposix.h` declares the library's `OnigSyntaxType`

Origin: experiment #4, oracle entry and results review (issue #7).

**Upstream behaviour at `f95747b`.** When a client includes
`onigposix.h` without `oniguruma.h`, as `upstream/sample/posix.c:5`
does, it gets the header's own definition of `OnigSyntaxType`
(`upstream/src/onigposix.h:118-127`, guarded by `#ifndef ONIGURUMA_H`).
That definition has four `unsigned int` fields (`op`, `op2`,
`behavior`, `options`), 16 bytes. The library is compiled with
`oniguruma.h`'s definition (`upstream/src/oniguruma.h:413-419`), which
adds `OnigMetaCharTableType meta_char_table`, six `OnigCodePoint`
fields (`upstream/src/oniguruma.h:119-126`), so 40 bytes, alignment 4
(`OnigSyntaxRuby` is 0x28 bytes in `nm -D -S`). `onigposix.h` still
declares `onig_copy_syntax` and `onig_set_default_syntax` on that type
(`upstream/src/onigposix.h:154-155`). `onig_copy_syntax` is `*to =
*from` (`upstream/src/regsyntax.c:291-294`), so it writes 40 bytes into
the client's 16-byte object, 24 bytes past its end (measured,
`posix_syntax_size.c`). `onig_set_default_syntax` on a client-defined
syntax reads 24 bytes past it. Linking is unaffected: the copy
relocations of the predefined syntaxes take their size from the shared
object.

**Maquizcoatl behaviour.** The type a client sees has the library's
layout whichever public header it includes: `onigposix.h` declares the
same five-field, 40-byte struct as `oniguruma.h`. No API call writes or
reads past an object of a type the client can declare.

**Alternatives considered.**

- Keep upstream's headers and document the hazard. This keeps the
  memory error for `onigposix.h`-only clients that copy or define a
  syntax.
- Drop `onig_copy_syntax` and `onig_set_default_syntax` from
  `onigposix.h`. Source-incompatible for clients that use them through
  that header.

**Reason.** Bug-free goal: memory error (out-of-bounds write) through a
documented header.

**Evidence.** Oracle entry, layout of `OnigSyntaxType` (40 / 4)
([oracle](../lab/results/2026-11-19-exp-04-oracle.md));
[exports entry](../lab/results/2026-11-19-exp-04-exports.md),
`posix_syntax_size.txt` (16 bytes seen, 24 bytes overwritten).

**Status.** Decided by the maintainer 2026-11-19.

---

## DEV-007: The default subexp-call nest limit is 20, as in the code

Origin: experiment #8, hard-feature spec probe (issue #12), deviation
candidate D-08-1
([corpus entry](../lab/results/2026-11-19-exp-08-corpus.md)) and
maintainer decision
(https://github.com/tarides/maquizcoatl/issues/12#issuecomment-7038399798).

**Upstream behaviour at `f95747b`.** The default limit on the nesting of
subexpression calls is 20: `DEFAULT_SUBEXP_CALL_MAX_NEST_LEVEL` is 20
(`upstream/src/regint.h:115`) and initialises `SubexpCallMaxNestLevel`
(`upstream/src/regexec.c:2874`), which `match_at` compares with the call
nest counter (`upstream/src/regexec.c:4426`) and which
`onig_get_subexp_call_max_nest_level` returns
(`upstream/src/regexec.c:6102-6105`). The documentation of that function
says "(default: 24)" (`upstream/doc/API:1020`). The definition site of a
called group is itself compiled as a call
(`upstream/src/regcomp.c:1704-1713`), so limit k admits k-1 nested
recursive calls. Case ca06 (`(?<foo>a|\(\g<foo>\))` on a 24-deep
nesting, default limit) gives `M 5-44`: 19 levels, as limit 20 implies,
not the 23 that limit 24 would give (`M 1-48`).

**Maquizcoatl behaviour.** The default limit is 20, and
`onig_get_subexp_call_max_nest_level` returns 20 until
`onig_set_subexp_call_max_nest_level` changes it. The specification
takes the code as reference; the "24" of `doc/API` is a documentation
error.

**Alternatives considered.**

- Follow `doc/API` and make the default 24. This changes the result of
  every pattern whose recursion depth lies between 20 and 23 compared
  with the library that clients run today (ca06 would match `M 1-48`
  instead of `M 5-44`), to agree with a figure that the code of
  `f95747b` does not use.

**Reason.** Disagreement between documentation and code; the code is
the reference (CLAUDE.md, "Upstream architecture"). The deviation is
from upstream's documentation, not from its behaviour.

**Evidence.** Experiment #8's case corpus, run on the Debug and
ASan/UBSan builds of `f95747b`
([corpus entry](../lab/results/2026-11-19-exp-08-corpus.md)): case ca06
(`lab/08-hard-features/cases/calls.tsv`, result in
[raw/corpus-r2/calls.joined.tsv](../lab/results/2026-11-19-exp-08-raw/corpus-r2/calls.joined.tsv)),
and the nest-limit cases and scans nc01-nc04, ns01 (limits 0-30) and
ns02 (limits 0-30) run with `onig_set_subexp_call_max_nest_level`
(`lab/08-hard-features/cases/nest.tsv`, `cases/nest.c`; results in
[raw/corpus/nest.joined.tsv](../lab/results/2026-11-19-exp-08-raw/corpus/nest.joined.tsv)):
ns01 needs limit 4 for 3 recursive calls, and ns02 at limit k matches
nesting k-1. The four formalisations of experiment #8 take the limit as
a parameter with default 20 and agree with ca06
([calls entry](../lab/results/2026-11-19-exp-08-calls.md),
[review fixes](../lab/results/2026-11-20-exp-08-review-fixes.md)).

**Status.** Decided by the maintainer 2026-11-20
(https://github.com/tarides/maquizcoatl/issues/12#issuecomment-7038399798).
