# Experiment #9: fragment cases (written by cases/select.py)

Input: 152 in-subset cases of experiment #6.

| | x2 | x3 | n | e | total |
|---|---:|---:|---:|---:|---:|
| fragment | 36 | 13 | 1 | 0 | 50 |
| dropped: character class or anychar | 41 | 5 | 10 | 0 | 56 |
| dropped: multibyte literal | 26 | 15 | 2 | 0 | 43 |
| dropped: compile error (kind e: no AST, the fragment has no parser) | 0 | 0 | 0 | 3 | 3 |

Re-check over the full extraction (4565 cases): OK; fragment syntax in context: 50; quantifier with no target in context (kind e, dropped above): test_utf8:1784, test_utf8:1785.

Fragment syntax outside the context (informational; the recogniser reads bytes, so the EUC-JP and UTF-16 counts are byte-level):

| Reason | Cases |
|---|---:|
| encoding UTF16_BE | 67 |
| backward search | 47 |
| encoding EUC_JP | 44 |
| options | 20 |
| syntax GREP | 4 |
| syntax PERL | 2 |
| syntax POSIX_BASIC | 2 |
| syntax JAVA | 1 |
| syntax EMACS | 1 |
