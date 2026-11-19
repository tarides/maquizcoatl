| Family | Cases run | stubs = C | ctypes = C | VM (ffi) = C | VM (flambda) = VM (ffi) | C = experiment #1 expected |
|---|---|---|---|---|---|---|
| jq | 136 | yes | yes | 136 / 136 | yes | 136 / 136 |
| php | 159 | yes | yes | 158 / 159 | yes | 159 / 159 |
| vscode | 123,982 | yes | yes | 123,982 / 123,982 | yes | 906 / 906 scanner searches with all members in subset |
| longphp | 13 | yes | yes | 11 / 13 | yes | 13 / 13 |

VM disagreements (case id, Oniguruma `result nregs beg end ...`, VM):

- php case 419: C `0 2 0 21 -1 -1`, VM `-17`
- longphp case 0: C `-15`, VM `0 1 0 30000`
- longphp case 1: C `-15`, VM `0 1 0 30000`
