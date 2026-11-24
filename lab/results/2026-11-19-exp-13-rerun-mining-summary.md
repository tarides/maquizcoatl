Window: 2025-11-19 to 2026-11-19. Lines are added plus removed, pin files, lockfiles and generated files excluded, before manual classification. Bump and snapshot rows are summed per tool series they reach; a series' lines are divided by the releases it spans. Unattributed lines are those of rows that move no resolvable pin to a release (only opaque pins changed, a pin removed, versions dropped from a matrix, a pinned commit in no release), go back to an older series, or belong to a series that spans no release (for example a pinned commit that is already in the latest release).

| Project | Tool | Tool series in window | Bumps | Keyword rows | Snapshot rows | Releases reached | Lines (bumps, snapshots) | Median lines per release | Unattributed lines | Largest row |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| warblre | rocq | 2 | 3 | 2 | 0 | 5 | 2494 | 79.0 | 0 | a5a3120 (2379 lines, 55 files) |
| linden | rocq | 2 | 5 | 2 | 0 | 5 | 816 | 77.0 | 2 | 4312028 (724 lines, 56 files) |
| lean-regex | lean | 11 | 10 | 0 | 0 | 10 | 10131 | 201.2 | 0 | e2e33d6 (7695 lines, 67 files) |
| everparse-cbor | fstar | 28 | 21 | 0 | 0 | 16 | 6864 | 69.3 | 2699 | 77921d0 (2637 lines, 60 files) |
| why3-gallery | why3 | 1 | 0 | 0 | 1 | 1 | 82849 | 82849.0 | 0 | 1.8.2..1.9.0 (82849 lines, 735 files) |
| creusot | why3 | 1 | 8 | 0 | 0 | 0 | 118591 |  | 118591 | eef25e4 (117350 lines, 8358 files) |
| anvil | verus | 53 | 8 | 20 | 0 | 0 | 42954 |  | 42954 | 0cd9f9f (30728 lines, 288 files) |
| afp-regex | isabelle | 3 | 0 | 0 | 18 | 3 | 1574 | 87.0 | 0 | Isabelle2025..Isabelle2025-1 (1455 lines, 8 files) |

Every measured directory holds measured files at the start of the window and at the head (snapshot mode: in the first and last release trees).
