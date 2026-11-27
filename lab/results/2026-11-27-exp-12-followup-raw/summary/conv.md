| Family | Engine | runs | median ns/call | IQR/median | ns/byte | bytes/call | minor words/call | major words/call |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| jq | rocq | 10 | 17.4 | 0.6% | 2.457 | 7.1 | 27.37 | 0.0024 |
| jq | fstar | 10 | 17.4 | 0.4% | 2.458 | 7.1 | 27.37 | 0.0024 |
| php | rocq | 10 | 12.8 | 1.0% | 2.936 | 4.4 | 19.21 | 0.0011 |
| php | fstar | 10 | 12.8 | 1.3% | 2.930 | 4.4 | 19.21 | 0.0011 |
| vscode | rocq | 10 | 29.0 | 1.2% | 1.763 | 16.5 | 55.39 | 0.0158 |
| vscode | fstar | 10 | 29.0 | 0.4% | 1.759 | 16.5 | 55.39 | 0.0158 |
| longphp | rocq | 10 | 57,738,113 | 0.4% | 27.532 | 2,097,150.0 | 6291460.00 | 6251033.7000 |
| longphp | fstar | 10 | 57,756,396 | 0.7% | 27.540 | 2,097,150.0 | 6291460.00 | 6251033.7000 |

Whole-subject conversion (scan mode; one conversion per process, in the untimed warm-up of `scan`):

| Engine | Subject | ns/byte | minor words | major words | heap after (MB) | major collections |
|---|---|---:|---:|---:|---:|---:|
| rocq | log-1m | 37.150 | 3,145,635 | 2,883,564 | 24.7 | 6 |
| rocq | src-1m | 37.359 | 3,145,584 | 2,883,564 | 24.7 | 6 |
| rocq | log-16m | 39.707 | 50,331,255 | 49,938,228 | 419.3 | 9 |
| rocq | src-16m | 39.851 | 50,331,588 | 50,200,371 | 419.3 | 9 |
| fstar | log-1m | 37.058 | 3,145,635 | 2,883,564 | 24.7 | 6 |
| fstar | src-1m | 36.889 | 3,145,584 | 2,883,564 | 24.7 | 6 |
| fstar | log-16m | 39.523 | 50,331,255 | 49,938,228 | 419.3 | 9 |
| fstar | src-16m | 39.598 | 50,331,588 | 50,200,371 | 419.3 | 9 |

GC settings: minor_heap_size 262144, space_overhead 120, max_overhead 0, window_size 0, custom_major_ratio 44, OCAMLRUNPARAM unset.
