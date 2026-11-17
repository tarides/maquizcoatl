# Sources

The specification in this directory is derived from an analysis of the
original C implementation of Oniguruma.

| Field         | Value                                                              |
|---------------|--------------------------------------------------------------------|
| Upstream      | <https://github.com/kkos/oniguruma> (archived, read-only)          |
| Commit        | `f95747b462de672b6f8dbdeb478245ddf061ca53` (2025-04-24, last commit) |
| Describe      | `v6.9.10-28-gf95747b` (28 commits after release v6.9.10)           |
| SWHID         | `swh:1:rev:f95747b462de672b6f8dbdeb478245ddf061ca53`               |
| Archive       | <https://archive.softwareheritage.org/swh:1:rev:f95747b462de672b6f8dbdeb478245ddf061ca53> |
| License       | BSD-2-Clause, Copyright (c) 2002-2021 K.Kosako (see `upstream/COPYING`) |
| Local copy    | git submodule at `upstream/`, pinned to the commit above           |

## Citation convention

References to the original code are written as `upstream/<path>:<line>`
(or `:<start>-<end>`) and always refer to the commit above, e.g.
`upstream/src/regcomp.c:1234`.

To fetch the sources:

    git submodule update --init

## License notes

Oniguruma is BSD-2-Clause. Excerpts quoted from the original sources
must retain its copyright notice and license conditions.
