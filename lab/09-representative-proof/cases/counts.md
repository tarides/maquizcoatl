# Experiment #9: fragment cases (written by cases/select.py)

Input: 152 in-subset cases of experiment #6.

| | x2 | x3 | n | e | total |
|---|---:|---:|---:|---:|---:|
| fragment, from in.tsv | 36 | 13 | 1 | 0 | 50 |
| fragment, added from the full extraction (not in in.tsv) | 16 | 0 | 0 | 0 | 16 |
| **fragment, total** | 52 | 13 | 1 | 0 | **66** |
| dropped: character class or anychar | 41 | 5 | 10 | 0 | 56 |
| dropped: multibyte literal | 26 | 15 | 2 | 0 | 43 |
| dropped: compile error (kind e: no AST, the fragment has no parser) | 0 | 0 | 0 | 3 | 3 |

Re-check over the full extraction (4565 cases): OK; fragment syntax in context: 66; quantifier with no target in context (kind e, dropped above): test_utf8:1784, test_utf8:1785.

Fragment syntax outside the context (informational; the recogniser reads bytes, so the EUC-JP and UTF-16 counts are byte-level):

| Reason | Cases |
|---|---:|
| encoding UTF16_BE | 67 |
| backward search | 52 |
| encoding EUC_JP | 48 |
| options | 20 |
| syntax GREP | 4 |
| syntax PERL | 2 |
| syntax POSIX_BASIC | 2 |
| syntax JAVA | 1 |
| syntax PYTHON | 1 |
| syntax EMACS | 1 |

Added from the full extraction (pure ASCII literals written with escapes experiment #6's parser does not read):

- test_utf8:167: `\ca` -> `L01`
- test_utf8:168: `\C-b` -> `L02`
- test_utf8:169: `\c\\` -> `L1c`
- test_utf8:750: `\o{101}` -> `L41`
- test_utf8:1363: `\u0040` -> `L40`
- test_utf8:1604: `\x{000A 002f}` -> `(. L0a L2f)`
- test_utf8:1605: `\x{000A 002f }` -> `(. L0a L2f)`
- test_utf8:1606: `\x{007C     001b}` -> `(. L7c L1b)`
- test_utf8:1607: `\x{1 2 3 4 5 6 7 8 9 a b c d e f}` -> `(. L01 (. L02 (. L03 (. L04 (. L05 (. L06 (. L07 (. L08 (. L09 (. L0a (. L0b (. L0c (. L0d (. L0e L0f))))))))))))))`
- test_utf8:1608: `a\x{000A 002f}@` -> `(. L61 (. L0a (. L2f L40)))`
- test_utf8:1609: `a\x{0060<newline>0063}@` -> `(. L61 (. L60 (. L63 L40)))`
- test_utf8:1617: `\o{102}` -> `L42`
- test_utf8:1618: `\o{102 103}` -> `(. L42 L43)`
- test_utf8:1619: `\o{0160 0000161}` -> `(. L70 L71)`
- test_utf8:1620: `\o{1 2 3 4 5 6 7 10 11 12 13 14 15 16 17}` -> `(. L01 (. L02 (. L03 (. L04 (. L05 (. L06 (. L07 (. L08 (. L09 (. L0a (. L0b (. L0c (. L0d (. L0e L0f))))))))))))))`
- test_utf8:1621: `\o{0007 0010 }` -> `(. L07 L08)`
