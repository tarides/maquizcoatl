| Family | n | c | stubs | ctypes | vm | vm-flambda | re | outcomes agree with C |
|---|---|---|---|---|---|---|---|---|
| jq | 16 | nomatch 1.77 ms | nomatch 1.76 ms | nomatch 1.78 ms | nomatch 7.17 ms | nomatch 6.60 ms | nomatch 0.02 ms | stubs:yes ctypes:yes vm:yes vm-flambda:yes |
| jq | 32 | limit 129.84 ms | limit 129.77 ms | limit 130.02 ms | limit 270.28 ms | limit 244.05 ms | nomatch 0.02 ms | stubs:yes ctypes:yes vm:yes vm-flambda:yes |
| jq | 64 | limit 130.00 ms | limit 129.87 ms | limit 129.82 ms | limit 270.67 ms | limit 245.77 ms | nomatch 0.02 ms | stubs:yes ctypes:yes vm:yes vm-flambda:yes |
| jq | 128 | limit 129.69 ms | limit 129.72 ms | limit 129.91 ms | limit 272.42 ms | limit 246.25 ms | nomatch 0.02 ms | stubs:yes ctypes:yes vm:yes vm-flambda:yes |
| jq | 256 | limit 129.93 ms | limit 129.52 ms | limit 129.67 ms | limit 271.77 ms | limit 243.80 ms | nomatch 0.02 ms | stubs:yes ctypes:yes vm:yes vm-flambda:yes |
| jq | 512 | limit 129.69 ms | limit 129.88 ms | limit 129.68 ms | limit 272.96 ms | limit 244.97 ms | nomatch 0.02 ms | stubs:yes ctypes:yes vm:yes vm-flambda:yes |
| jq | 1024 | limit 129.74 ms | limit 129.81 ms | limit 129.87 ms | limit 273.19 ms | limit 245.05 ms | nomatch 0.03 ms | stubs:yes ctypes:yes vm:yes vm-flambda:yes |
| jq | 2048 | limit 129.73 ms | limit 130.04 ms | limit 129.73 ms | limit 272.66 ms | limit 246.40 ms | nomatch 0.03 ms | stubs:yes ctypes:yes vm:yes vm-flambda:yes |
| jq | 4096 | limit 130.68 ms | limit 130.03 ms | limit 129.78 ms | limit 272.49 ms | limit 247.53 ms | nomatch 0.03 ms | stubs:yes ctypes:yes vm:yes vm-flambda:yes |
| php | 16 | nomatch 0.19 ms | nomatch 0.20 ms | nomatch 0.20 ms | nomatch 0.64 ms | nomatch 0.56 ms | nomatch 0.04 ms | stubs:yes ctypes:yes vm:yes vm-flambda:yes |
| php | 32 | limit 84.76 ms | limit 85.06 ms | limit 85.18 ms | limit 288.28 ms | limit 246.67 ms | nomatch 0.04 ms | stubs:yes ctypes:yes vm:yes vm-flambda:yes |
| php | 64 | limit 84.84 ms | limit 85.69 ms | limit 85.21 ms | limit 288.19 ms | limit 245.48 ms | nomatch 0.04 ms | stubs:yes ctypes:yes vm:yes vm-flambda:yes |
| php | 128 | limit 85.13 ms | limit 84.87 ms | limit 86.12 ms | limit 288.07 ms | limit 248.77 ms | nomatch 0.04 ms | stubs:yes ctypes:yes vm:yes vm-flambda:yes |
| php | 256 | limit 84.86 ms | limit 85.26 ms | limit 85.80 ms | limit 288.28 ms | limit 247.27 ms | nomatch 0.04 ms | stubs:yes ctypes:yes vm:yes vm-flambda:yes |
| php | 512 | limit 85.02 ms | limit 85.45 ms | limit 85.07 ms | limit 288.56 ms | limit 250.11 ms | nomatch 0.04 ms | stubs:yes ctypes:yes vm:yes vm-flambda:yes |
| php | 1024 | limit 85.14 ms | limit 85.50 ms | limit 85.43 ms | limit 288.29 ms | limit 248.79 ms | nomatch 0.05 ms | stubs:yes ctypes:yes vm:yes vm-flambda:yes |
| php | 2048 | limit 85.30 ms | limit 85.92 ms | limit 85.67 ms | limit 286.81 ms | limit 252.55 ms | nomatch 0.05 ms | stubs:yes ctypes:yes vm:yes vm-flambda:yes |
| php | 4096 | limit 85.75 ms | limit 86.02 ms | limit 85.71 ms | limit 287.33 ms | limit 251.26 ms | nomatch 0.05 ms | stubs:yes ctypes:yes vm:yes vm-flambda:yes |
| vscode | 16 | nomatch 4.55 ms | nomatch 4.55 ms | nomatch 4.59 ms | nomatch 11.13 ms | nomatch 9.56 ms | nomatch 0.03 ms | stubs:yes ctypes:yes vm:yes vm-flambda:yes |
| vscode | 32 | limit 113.11 ms | limit 113.47 ms | limit 113.35 ms | limit 278.89 ms | limit 239.12 ms | nomatch 0.03 ms | stubs:yes ctypes:yes vm:yes vm-flambda:yes |
| vscode | 64 | limit 113.37 ms | limit 113.44 ms | limit 113.44 ms | limit 278.36 ms | limit 238.58 ms | nomatch 0.03 ms | stubs:yes ctypes:yes vm:yes vm-flambda:yes |
| vscode | 128 | limit 113.45 ms | limit 113.48 ms | limit 113.31 ms | limit 278.40 ms | limit 239.13 ms | nomatch 0.03 ms | stubs:yes ctypes:yes vm:yes vm-flambda:yes |
| vscode | 256 | limit 113.65 ms | limit 113.39 ms | limit 113.75 ms | limit 279.90 ms | limit 238.83 ms | nomatch 0.03 ms | stubs:yes ctypes:yes vm:yes vm-flambda:yes |
| vscode | 512 | limit 113.82 ms | limit 113.51 ms | limit 113.47 ms | limit 279.55 ms | limit 238.91 ms | nomatch 0.03 ms | stubs:yes ctypes:yes vm:yes vm-flambda:yes |
| vscode | 1024 | limit 113.11 ms | limit 113.60 ms | limit 113.42 ms | limit 279.73 ms | limit 239.70 ms | nomatch 0.03 ms | stubs:yes ctypes:yes vm:yes vm-flambda:yes |
| vscode | 2048 | limit 113.32 ms | limit 113.55 ms | limit 113.38 ms | limit 280.57 ms | limit 239.28 ms | nomatch 0.03 ms | stubs:yes ctypes:yes vm:yes vm-flambda:yes |
| vscode | 4096 | limit 113.62 ms | limit 113.45 ms | limit 113.47 ms | limit 278.07 ms | limit 239.87 ms | nomatch 0.04 ms | stubs:yes ctypes:yes vm:yes vm-flambda:yes |

Cell: outcome over the 10 runs (`limit` = ONIGERR_RETRY_LIMIT_IN_MATCH_OVER, -17, retry budget 10,000,000 per start position) and median wall time of the search. `re` has no backtracking and no budget: reference only.
