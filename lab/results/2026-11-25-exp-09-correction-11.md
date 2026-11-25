# Experiment #9, entry 25: run 13's log archive repacked without owner names (correction 11)

**What.** [Entry 19](2026-11-25-exp-09-fstar-m3.md)'s raw archive
`2026-11-25-exp-09-fstar-m3-raw/fstar/logs.tar.xz` is replaced by a
repack whose tar headers carry numeric owner and group 0 instead of a
local account name. Nothing else in the archive changes. No prover was
run.

**Why.** The archive's 682 entries named a local account as owner and
group in their tar headers, which the project's public-record rule does
not allow. Run 14's archive was built with numeric owner 0 from the
start (entry 21). The run-14 and run-15 reviews flagged the run-13
archive, and the maintainer decided to repack it
([issue #4](https://github.com/tarides/maquizcoatl/issues/4)). This is a
documented exception to the rule that recorded raw files are never
rewritten: only the tar headers' owner fields change.

## Method

1. Listed the original archive's member order with `tar -tf`.
2. Extracted it in a scratch directory.
3. Re-created it from that directory, in the same member order, with
   `tar --no-recursion --numeric-owner --owner=0 --group=0 -T <order>`,
   compressed with `xz -9`.

## Checks

- `tar -tv` listings of the two archives, without the owner column, are
  identical: 682 members, same names, modes, sizes and mtimes, same
  order.
- The extracted trees are identical (`diff -r` empty).
- Every member of the new archive has owner `0/0`.
- The uncompressed tar stream of the new archive contains no account
  name, home-directory path or host name.

| | SHA-256 |
|---|---|
| original archive | `66650aad4e047b5498021d3c4d86d8603f7ddba71037250a7a7aca86c0111c2d` |
| repacked archive | `786b509f1148c0c39c4974598bcaee4440089f60dfeea522e5204963082ec2ff` |

No entry recorded the original archive's hash, so no other entry
changes. Every figure derived from the archive (entry 19, correction 8)
stands, since the member contents are byte-identical.
