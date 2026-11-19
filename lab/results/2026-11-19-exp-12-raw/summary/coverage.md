| Family | Triples in subset / total | Calls in subset / total | Weighted calls (frequency profile) | Top rejection reasons |
|---|---|---|---|---|
| jq | 21 / 44 | 136 / 217 (62.7%) | - | `(?_group` 41, `option:0x1` 26, `option:0x20` 6, `\b` 5, `option:0x3` 2 |
| php | 61 / 187 | 159 / 421 (37.8%) | - | `encoding` 151, `nested_class_/_posix_bracket` 39, `(?_group` 23, `option:0x2` 14, `unicode-ctype-on-non-ascii-subject` 12 |
| vscode | 949 / 4221 | 123,982 / 429,020 (28.9%) | 198,837 / 759,850 (26.2%) | `(?_group` 397,571, `\b` 95,818, `nested_class_/_posix_bracket` 29,221, `possessive` 21,512, `escaped_non-ASCII` 10,785 |
| longphp | 4 / 5 | 13 / 18 (72.2%) | - | `option:0x1` 5 |

Triples are counted per (syntax, options, retry limit, stack limit, pattern); a triple is in the subset when at least one of its calls is admitted. VS Code calls are scanner searches expanded to one search per member triple (11,263 committed searches; weights from the frequency profile). Invalid-in-subset (Oniguruma compile error) calls: none in the workloads.
