# Experiment #9: the fragment, its compiler, VM, semantics and theorem

The shared design that every tool (Rocq, F\* + Pulse, Verus) transcribes
(plan `plans/09-representative-proof.md`, "The fragment, the VM and the
theorem"). Written in run 1; Rocq's transcription is in `rocq/`. All
`upstream/` references are to Oniguruma `f95747b` and were checked
against the sources while writing this file. Code quoted from upstream
is Copyright (c) 2002-2025 K.Kosako, BSD-2-Clause (`upstream/COPYING`).

## 0. Scope

Patterns built from literals, concatenation, `|`, greedy `*` and plain
capture groups `( )`, under `ONIG_SYNTAX_ONIGURUMA`, UTF-8, no options,
no case folding, no multibyte literal. Forward search only. There is no
parser in the fragment: the cases carry the AST written by experiment
#6's parser (stack G), so compile errors (`e` cases) are out
(`cases/counts.md`).

## 1. Abstract syntax

```
regex ::= Eps | Lit (list byte) | Cat regex regex | Alt regex regex
        | Star regex | Group k regex          (k >= 1)
```

- `Lit` holds ASCII bytes (`< 0x80`). The case files have one `Lit` per
  character; a `Lit` of several bytes is allowed and means the same as
  their concatenation.
- `Alt` and `Cat` are binary. The parser nests them to the right
  (`a|b|c` is `Alt a (Alt b c)`), which is what makes the compiled code
  equal to upstream's n-ary layout (section 3).
- `Star` is greedy with no bounds. `Star r` where `r` compiles to no
  code (`Eps`, `Lit []`, concatenations of these) is legal in the AST,
  although fragment syntax cannot write it (section 3, `tlen == 0`).
- Groups are numbered by the parser in order of their opening
  parenthesis; `ncap r` is the highest number in `r`.

## 2. Bytecode

The fragment's opcodes, after `upstream/src/regint.h:496-597`:

| Instruction | Upstream | Effect |
|---|---|---|
| `IStr l` | `OP_STR_1` .. `OP_STR_N` (`regint.h:499-504`), collapsed | match the bytes `l` at `pos`, else fail |
| `IPush a` | `OP_PUSH` (`:564`) | push an alternative (`a`, `pos`) |
| `IJump a` | `OP_JUMP` (`:563`) | `pc := a` |
| `IFail` | `OP_FAIL` (`:562`) | backtrack (never emitted for the fragment) |
| `IMemStart k` | `OP_MEM_START` (`:552`) | start of group `k := pos` |
| `IMemStartPush k` | `OP_MEM_START_PUSH` (`:553`) | save group `k` on the stack, start `:= pos`, end `:=` unset |
| `IMemEnd k` | `OP_MEM_END` (`:558`) | end of group `k := pos` |
| `IEmptyStart id` | `OP_EMPTY_CHECK_START` (`:576`) | push (`id`, `pos`) |
| `IEmptyEnd id` | `OP_EMPTY_CHECK_END` (`:577`) | if the iteration was empty, skip the next instruction |
| `IEnd` | `OP_END` (`:498`) | success |

`OP_FINISH` (`regint.h:497`) is not an instruction of the compiled code:
it is the sentinel at the bottom of the backtrack stack
(`upstream/src/regexec.c:3074`, pushed at `:3277`); popping it ends the
attempt with no match (`:4655-4661`).

Jump and push targets are absolute instruction indices. Upstream stores
offsets relative to the instruction; the compiler resolves them, so the
code is the same up to that encoding.

Left out: the peephole variants `OP_PUSH_OR_JUMP_EXACT1` and
`OP_PUSH_IF_PEEK_NEXT` (`regcomp.c:1464-1488`, and `:1444-1452` for the jump prefix of `lower == 1`; emitted by upstream for
stars with a literal head or a literal after the loop,
`USE_OP_PUSH_OR_JUMP_EXACT` is on, `regint.h:92`), `OP_ANYCHAR_STAR*`
(no anychar in the fragment), the merging of adjacent literals into one
`OP_STR_N`, and `OP_EMPTY_CHECK_END_MEMST` (section 6). The theorem is
about the plain layout; the peepholes are outside it.

## 3. Compilation scheme

`comp r pc eid push` is the code of `r` placed at address `pc`, using
empty-check ids from `eid`; `push` says that `r` is inside an
alternation or a star. `compile r = comp r 0 0 false ++ [IEnd]`.
`clen r` is the code length (upstream `compile_length_tree`), `nchecks
r` the number of empty-check ids used, `minlen r` the minimal match
length (upstream `node_min_byte_len`), `nullable r = (minlen r = 0)`.

| Pattern | Code at `pc` | Upstream |
|---|---|---|
| `Eps` | nothing | |
| `Lit l` | `IStr l` (nothing if `l = []`) | `compile_string_node` |
| `Cat a b` | code of `a` at `pc`, then of `b` at `pc + clen a` (ids after `a`'s) | `ND_LIST`, `regcomp.c:2563-2567` |
| `Alt a b` | `IPush L1; a; IJump end; L1: b; end:` | `ND_ALT`, `regcomp.c:2569-2599` |
| `Star a`, `clen a = 0` | nothing | `regcomp.c:1407` (`tlen == 0`) |
| `Star a`, `a` not nullable | `L: IPush out; a; IJump L; out:` | `regcomp.c:1434-1503` (greedy, plain `OP_PUSH` at `:1489-1498`) |
| `Star a`, `a` nullable | `L: IPush out; IEmptyStart id; a; IEmptyEnd id; IJump L; out:` | the same with `compile_quant_body_with_empty_check`, `regcomp.c:958-1004` |
| `Group k a` | `IMemStart k` or `IMemStartPush k` (if `push`); `a`; `IMemEnd k` | `compile_bag_memory_node`, `regcomp.c:1699-1776` |

Details:

- **Alternation.** Upstream compiles the n-ary `ND_ALT` list with every
  `OP_JUMP` going to one goal after the last branch
  (`regcomp.c:2575-2598`). With `Alt` nested to the right, the inner
  alternation's end is the outer one's, so the binary scheme above
  emits exactly the n-ary code.
- **Empty-check ids** are allocated in pre-order, the star's own id
  before its body's (`reg->num_empty_check++` at `regcomp.c:971-974`,
  before `compile_tree(body)` at `:977`). A star that compiles to
  nothing uses no id.
- **When a star gets the check.** Upstream sets `qn->emptiness` when
  `node_min_byte_len(body) == 0` (`regcomp.c:5681-5689`; with
  `USE_RIGID_CHECK_CAPTURES_IN_EMPTY_REPEAT`, `regint.h:80`, the value
  is `BODY_MAY_BE_EMPTY_MEM` when the body holds a group, which still
  compiles to `OP_EMPTY_CHECK_END` unless the quantifier carries
  `EMPTY_STATUS_CHECK`, `regcomp.c:981-991`). `EMPTY_STATUS_CHECK` is
  set only for a group backreferenced outside the loop
  (`regcomp.c:3941-3957`), which no fragment pattern has. So upstream
  emits `OP_EMPTY_CHECK_START`/`OP_EMPTY_CHECK_END` exactly when
  `nullable a`, as this scheme does.
- **`OP_MEM_START_PUSH`.** A group's number is put in
  `backtrack_mem` when the group is under an alternation (`IN_ALT`,
  set for every branch, `regcomp.c:5763-5767`) or a variable repeat
  (`IN_VAR_REPEAT`, `:5694-5695`), `regcomp.c:5819-5821`;
  `push_mem_start = backtrack_mem | cap_history` (`:7540`), and
  `cap_history` is empty without `(?@...)`. So a group gets
  `OP_MEM_START_PUSH` exactly when some ancestor is an `Alt` or a
  `Star`: the `push` flag above.
- **`OP_MEM_END`, never `OP_MEM_END_PUSH`.** `push_mem_end =
  push_mem_start & (backrefed_mem | cap_history)` (`regcomp.c:7547-7551`, the `USE_CALLOUT` branch),
  empty without backreferences and capture history.
- **Stack pop level.** With some `OP_MEM_START_PUSH`, the VM pops at
  `STACK_POP_LEVEL_MEM_START`, else `STACK_POP_LEVEL_FREE`
  (`regcomp.c:7620-7623`); both behave as section 5's `pop` (with no
  `STK_MEM_START` entries the two coincide).

## 4. Reference semantics

A backtracking tree in Linden's style (the techniques of the Linden Rocq
development, not its JavaScript definitions). The semantics unfolds the
pattern, under a list of pending actions (the continuation), into the
tree of choices in priority order; its result is the leftmost leaf that
is a match.

```
action ::= ARe r | ACheck p0 r | AClose k p0
tree   ::= TMismatch | TMatch e g | TChoice t1 t2     (t1 first)

tree(ARe Eps :: k, pos, g)        = tree(k, pos, g)
tree(ARe (Lit l) :: k, pos, g)    = tree(k, pos + |l|, g)  if l is a prefix of s[pos..]
                                  = TMismatch              otherwise
tree(ARe (Cat a b) :: k, pos, g)  = tree(ARe a :: ARe b :: k, pos, g)
tree(ARe (Alt a b) :: k, pos, g)  = TChoice (tree(ARe a :: k, pos, g)) (tree(ARe b :: k, pos, g))
tree(ARe (Star a) :: k, pos, g)   = TChoice (tree(ARe a :: ACheck pos a :: k, pos, g)) (tree(k, pos, g))
tree(ACheck p0 a :: k, pos, g)    = tree(k, pos, g)                  if pos = p0
                                  = tree(ARe (Star a) :: k, pos, g)  otherwise
tree(ARe (Group n a) :: k, pos, g)= tree(ARe a :: AClose n pos :: k, pos, g)
tree(AClose n p0 :: k, pos, g)    = tree(k, pos, g[n := (p0, pos)])
tree([], pos, g)                  = TMatch pos g

sem r s p = leftmost TMatch of tree([ARe r], p, {})
            -> Match e (g(1), ..., g(ncap r)) | NoMatch
```

The `Star` rule is greedy (one more iteration first); `ACheck` is the
empty check (section 6). `Star a` with `clen a = 0` needs no special
rule: its first branch reaches `ACheck pos a` at `pos` and leaves the
loop, so both branches are `tree(k, pos, g)` and the elision of section
3 does not change the result.

**Termination measure.** On a configuration (`acts`, `pos`), with
`pos <= |s|` and every `ACheck p0` in `acts` satisfying `p0 <= pos`
(both invariant), let

```
size Eps = size (Lit _) = 1     size (Cat a b) = size (Alt a b) = size a + size b + 1
size (Star a) = size a + 2      size (Group _ a) = size a + 2
w (ARe r) = size r     w (AClose _ _) = 1
w (ACheck p0 a) at pos = size (Star a) + 1 if p0 < pos, 1 if p0 = pos
mu (acts, pos) = (|s| - pos, sum of w over acts)      (lexicographic)
```

Every rule's recursive calls have a smaller `mu`: a non-empty `Lit`
lowers `|s| - pos`; every other rule keeps `pos` and lowers the sum
(`Star`: `size a + 2` becomes `size a + 1`; `ACheck` with `pos > p0`:
`size (Star a) + 1` becomes `size (Star a)`; with `pos = p0`: `1`
becomes `0`). When `pos` grows, the weights of pending `ACheck`s may
grow, but the first component has dropped. The fact that `Star` comes
back only at a larger position is carried by the `ACheck p0` action;
in a continuation-passing presentation it is hidden in a closure, so a
tool either uses this action-list form or carries that invariant.

**Fuel, per tool.** Rocq: `compute_tree` takes fuel (one unit per call,
`None` when it runs out), and lemma (d) states that some fuel suffices
and that more fuel does not change the result. F\* and Verus: decided
in their M1 runs and written here then.

## 5. The VM

After `match_at` (`upstream/src/regexec.c:3068`). State: `pc`, `pos`,
the captures `m` (per group: start and end, each possibly unset; upstream
`mem_start_stk`/`mem_end_stk`, reset to unset at each attempt,
`regexec.c:3265-3267`) and the backtrack stack:

```
entry ::= EFinish                 bottom STK_ALT to OP_FINISH (regexec.c:3277)
        | EAlt pc pos             STK_ALT (OP_PUSH, :4310-4314)
        | EMemStart k prev        STK_MEM_START with the previous start/end (:2072-2082)
        | EEmptyStart id pos      STK_EMPTY_CHECK_START (:2136-2143)
```

- `IStr l`: `l` a prefix of `s[pos..]` (`DATA_ENSURE`, `:2727`, then the
  byte compare, `:3412-3480`) -> `pos += |l|`, else fail.
- `IPush a`: push `EAlt a pos`. `IJump a`: `pc := a`.
- `IMemStart k`: start of `k := pos`, end unchanged (`:4009-4013`).
- `IMemStartPush k`: push `EMemStart k (m k)`, then start `:= pos`, end
  `:=` unset (`STACK_PUSH_MEM_START`, `:2072-2082`; `:4003-4007`).
- `IMemEnd k`: end of `k := pos` (`:4021-4025`).
- `IEmptyStart id`: push `EEmptyStart id pos` (`:4221-4225`).
- `IEmptyEnd id`: find the topmost `EEmptyStart id p0` on the stack
  (`EMPTY_CHECK_START_SEARCH`, `:2409-2419`;
  `USE_REPEAT_AND_EMPTY_CHECK_LOCAL_VAR` is off, `regint.h:103`, so this
  is the path taken); if `p0 = pos` (`STACK_EMPTY_CHECK`, `:2437-2441`)
  skip the next instruction (`pc += 2`, the loop's `IJump`), else
  `pc += 1` (`:4227-4257`). Upstream never fails to find the entry for
  compiled fragment code (lemma (a)); the VM treats a missing entry as a
  non-empty iteration.
- `IFail`, or `pc` outside the code: fail.
- `IEnd`: success; the region is the match `[p, pos)` and, per group,
  `(start, end)` when the end is set, else unset (`:3285-3357`, region
  at `:3347-3357`).
- **fail** (`STACK_POP`, `:2295-2337`, and `OP_FAIL`, `:4668-4679`): pop
  entries down to the first `EAlt pc' pos'`, restoring the captures
  saved by each `EMemStart` on the way and dropping `EEmptyStart`s, then
  resume at (`pc'`, `pos'`). Reaching `EFinish`: no match.

The VM terminates by fuel only (one unit per instruction):
`vm fuel code n s p -> Match e caps | NoMatch | OutOfFuel`.

The C retry limit (`USE_RETRY_LIMIT`, `regint.h:83`; 10,000,000 by default, `regint.h:111`) is not modelled:
the theorem is about the unbounded VM, and cases where the C library
hits the limit are excluded from the comparison.

## 6. Captures and empty iterations (DEV-008 on the fragment)

- **Captures persist across iterations.** A group not re-entered in the
  last iteration of a star keeps its earlier span (experiment #2, probe
  ei11, `(?:(a)|())*` on `ab`: `1=0-1 2=1-1`). The semantics writes a
  group's span when it closes (`AClose`); backtracking restores the
  older captures because each branch of the tree carries its own map.
  The VM restores them through the `EMemStart` entries.
- **Empty iterations.** The spec's rule is `spec/deviations.md` DEV-008
  (decision 4 of the plan), which supersedes DEV-003: the empty check
  compares only the groups that some backreference of the pattern
  names. The fragment has no backreferences, so no group is compared:
  an iteration that ends where it began leaves the loop, keeping what it
  captured (experiment #2 ei04, `(a|)*` on `aa`: `0-2, 1=2-2`). This is
  upstream's plain check, `OP_EMPTY_CHECK_END`; the fragment's VM has no
  `OP_EMPTY_CHECK_END_MEMST` and the fragment's compiler emits what
  upstream emits (section 3). Experiment #6's milestone-2 semantics
  implements DEV-008 itself (`lab/06-spec-speed/rocq/Spec2.v:292`,
  `same_refs` with no backreferenced group is the plain check); the
  cross-check below compares with it.
- **Open groups.** Upstream's `OP_MEM_START_PUSH` makes the group unset
  until its `OP_MEM_END`; `OP_MEM_START` leaves a stale end in place.
  Neither is observable in the fragment: captures are read only at
  `OP_END`, where no group is open, and nothing else in the fragment
  reads them (no backreference, no conditional). Lemma (b) has to
  carry this.

## 7. Theorem

For every pattern `r` of the fragment, subject `s` and start position
`p <= |s|`:

- **soundness:** whenever `vm fv (compile r) (ncap r) s p` returns
  `Match` or `NoMatch`, it equals `sem fs r s p` for every fuel `fs`
  with which the semantics completes;
- **completeness:** some fuel makes the semantics return a result other
  than `OutOfFuel`, and some fuel makes the VM do so.

Results compare match or no match, the match end and every group's span
(unset as -1 in the case files). Rocq's statement is
`rocq/Statement.v` (`main_theorem_statement`). The search
(`Syntax.search`: start positions left to right, the first one that does
not return `NoMatch`) is the same function of the per-position results
for the VM and the semantics, so the theorem carries over to it.

## 8. Lemma plan, shared across tools

- **(a) Compiler invariants.** `length (comp r pc eid push) = clen r`;
  every jump and push target of `comp r pc ...` lies in
  `[pc, pc + clen r]`; empty-check ids of `comp r pc eid ...` lie in
  `[eid, eid + nchecks r)` and are distinct per star; group numbers are
  those of `r`; a group compiled without `push` has no `Alt` or `Star`
  ancestor, so it is entered exactly once on every path through the
  code of `r`. `IEmptyEnd id` is reached only with an `EEmptyStart id`
  on the stack, pushed by the same iteration.
- **(b) Simulation of one construct with a continuation**, by induction
  on `r` (the backtracking-tree / continuation-passing argument Linden
  uses): if the code at `pc` is `comp r pc eid push` followed by code
  that simulates the actions `k`, then running the VM from
  (`pc`, `pos`, `m`, `stk`) gives the leftmost match of
  `tree(ARe r :: k, pos, g)` if there is one, else what the VM gives
  after popping `stk`; with a relation between `g` and `m` that is
  exact for groups closed on the current path and allows any value for
  a not-yet-entered non-push group (it is written before `IEnd` on every
  path, by (a)), and with the stack discipline of `IPush` and
  `IMemStartPush` (each `EAlt` on `stk` corresponds to a right branch
  of the tree, with the captures that `EMemStart` restores).
- **(c) The star case** with the plain empty check, by well-founded
  induction on `mu` (section 4): one iteration followed by `IEmptyEnd`
  simulates `ACheck pos a`; the empty case skips the `IJump` exactly as
  `ACheck` leaves the loop.
- **(d) Completeness** (fuel): the semantics finishes with fuel larger
  than a bound computed from `mu` (the depth of the tree), and its
  result does not change with more fuel; the VM finishes within a
  number of steps bounded by the tree's size times the code length.
- **(e) Main theorem** from (b)-(d) at `k = []` (code `IEnd`, stack
  `[EFinish]`), and the axiom/admit report (`axioms.sh`).

## 9. Cases and harness

- `cases/select.py`: experiment #6's 152 in-subset cases filtered to the
  fragment (`cases/fragment.tsv`, counts in `cases/counts.md`), and the
  re-check over experiment #6's full extraction (4,565 cases) with an
  independent recogniser of fragment syntax.
- `cases/extra.tsv`: experiment #2's loop probes ei04, ei05, ei07 and
  ei11 (transcribed as `((a)|())*`, so its groups are 2 and 3 and the
  outer group is 1), kept apart from the upstream count, since no
  upstream fragment case has a star over a nullable body.
- `oracle/oracle.c` (experiment #6's, unchanged): `onig_search` verdict
  per case. `oracle/oracle_at.c`: `onig_match` at every start position
  (one `match_at` call, no optimiser).
- Drivers (per tool) print the VM's and the semantics' result at every
  start position and the left-to-right search; `cases/agree.py`
  compares them with both oracles and the C search with the upstream
  test's expectation.
- Transcription cross-check: the same comparison for experiment #6's
  milestone-2 semantics of the same tool (Rocq: `Spec2.v`, with `Star a`
  as `Rep 0 None true a` and no backreferenced group).
