# Experiment #11: r2-r4 output archives repacked without owner names

**What.** The three raw archives
`2026-11-19-exp-11-r2-outputs.tar.xz`, `-r3-outputs.tar.xz` and
`-r4-outputs.tar.xz` are replaced by repacks whose tar headers carry
numeric owner and group 0 instead of a local account name. Nothing else
in the archives changes. Nothing was rerun.

**Why.** Each archive's 216 entries named a contributor's local account
as owner and group in their tar headers, which the project's
public-record rule does not allow. The other experiment #11 archives
(r1 check outputs, r5-r7) already carry `0/0`. The same fix was applied
to experiment #9's run-13 archive (experiment #9, correction 11). The
maintainer decided the repack on 2026-11-25. This is a documented
exception to the rule that recorded raw files are never rewritten: only
the tar headers' owner fields change.

## Method

For each archive:

1. Listed its member order with `tar -tf`.
2. Extracted it in a scratch directory.
3. Re-created it from that directory, in the same member order, with
   `tar --no-recursion --numeric-owner --owner=0 --group=0 -T <order>`,
   compressed with `xz -9`.

## Checks

For each archive:

- the `tar -tv` listings of the old and new archive, without the owner
  column, are identical: 216 members, same names, modes, sizes, mtimes
  and order;
- the extracted trees are identical (`diff -r` empty);
- every member of the new archive has owner `0/0`;
- neither the member contents nor the new uncompressed tar stream
  contain an account name, home-directory path or host name.

| Archive | Original SHA-256 | Repacked SHA-256 |
|---|---|---|
| r2 | `bf5c9c184a70df6e303d64c4dda7a649b0352539b3f9300ea6b4426066026ca6` | `410dbc6bcb36bb5e9cd83730b017d79c0cfcd07fe3a0bb150a9ce4956b5aa103` |
| r3 | `91eb8dbdfa89721eaa62dbd86cfc3777ec114f3dbcd852dd323f8e069a68e652` | `8a3252862518980ed9f48343f4136467e5a2e42e4db38f6ee8fcefddf54fe57d` |
| r4 | `cb59f2694176c5e82770d9d9bbe473b4f5ae2084a615f14e8cc03de023dba9e3` | `d8e2d4e662ccb353232d97f3fb4f00e344ae847a829de12d17e2337d004796d6` |

No entry recorded the original hashes, so no other entry changes. Every
figure derived from these archives stands, since the member contents are
byte-identical.
