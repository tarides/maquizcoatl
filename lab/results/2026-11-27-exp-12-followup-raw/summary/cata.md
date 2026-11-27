| Pattern | n | c | c-noopt | stubs | ctypes | vm | rocq | fstar | outcomes = c-noopt |
|---|---:|---|---|---|---|---|---|---|---|
| `(a|aa)*b` | 16 | nomatch 0.001 ms | nomatch 0.126 ms | nomatch 0.001 ms | nomatch 0.004 ms | nomatch 0.572 ms | nomatch 11.006 ms | nomatch 18.749 ms | c:yes stubs:yes ctypes:yes vm:yes rocq:yes fstar:yes |
| `(a|aa)*b` | 32 | nomatch 0.001 ms | nomatch 266.118 ms | nomatch 0.001 ms | nomatch 0.005 ms | limit 257.653 ms | nomatch 28,613.205 ms | nomatch 55,248.903 ms | c:yes stubs:yes ctypes:yes vm:no rocq:yes fstar:yes |
| `(a|aa)*b` | 64 | nomatch 0.001 ms | limit 109.521 ms | nomatch 0.001 ms | nomatch 0.005 ms | limit 258.794 ms | - | - | c:no stubs:no ctypes:no vm:yes |
| `(a|aa)*b` | 128 | nomatch 0.001 ms | limit 110.184 ms | nomatch 0.001 ms | nomatch 0.005 ms | limit 258.140 ms | - | - | c:no stubs:no ctypes:no vm:yes |
| `(a|aa)*b` | 256 | nomatch 0.001 ms | limit 109.532 ms | nomatch 0.001 ms | nomatch 0.007 ms | limit 257.839 ms | - | - | c:no stubs:no ctypes:no vm:yes |
| `(a|aa)*b` | 512 | nomatch 0.002 ms | limit 109.866 ms | nomatch 0.002 ms | nomatch 0.007 ms | limit 257.827 ms | - | - | c:no stubs:no ctypes:no vm:yes |
| `(a|aa)*b` | 1024 | nomatch 0.003 ms | limit 109.570 ms | nomatch 0.003 ms | nomatch 0.008 ms | limit 257.721 ms | - | - | c:no stubs:no ctypes:no vm:yes |
| `(a|aa)*b` | 2048 | nomatch 0.004 ms | limit 111.008 ms | nomatch 0.004 ms | nomatch 0.008 ms | limit 259.166 ms | - | - | c:no stubs:no ctypes:no vm:yes |
| `(a|aa)*b` | 4096 | nomatch 0.007 ms | limit 109.944 ms | nomatch 0.007 ms | nomatch 0.011 ms | limit 259.257 ms | - | - | c:no stubs:no ctypes:no vm:yes |
| `(aa*)*b` | 16 | nomatch 0.001 ms | nomatch 1.542 ms | nomatch 0.001 ms | nomatch 0.005 ms | nomatch 6.442 ms | nomatch 122.153 ms | nomatch 213.344 ms | c:yes stubs:yes ctypes:yes vm:yes rocq:yes fstar:yes |
| `(aa*)*b` | 32 | nomatch 0.001 ms | limit 112.817 ms | nomatch 0.001 ms | nomatch 0.005 ms | limit 239.442 ms | - | - | c:no stubs:no ctypes:no vm:yes |
| `(aa*)*b` | 64 | nomatch 0.001 ms | limit 114.251 ms | nomatch 0.001 ms | nomatch 0.005 ms | limit 239.285 ms | - | - | c:no stubs:no ctypes:no vm:yes |
| `(aa*)*b` | 128 | nomatch 0.001 ms | limit 115.752 ms | nomatch 0.001 ms | nomatch 0.005 ms | limit 239.693 ms | - | - | c:no stubs:no ctypes:no vm:yes |
| `(aa*)*b` | 256 | nomatch 0.001 ms | limit 113.210 ms | nomatch 0.001 ms | nomatch 0.007 ms | limit 238.724 ms | - | - | c:no stubs:no ctypes:no vm:yes |
| `(aa*)*b` | 512 | nomatch 0.002 ms | limit 114.367 ms | nomatch 0.002 ms | nomatch 0.007 ms | limit 239.385 ms | - | - | c:no stubs:no ctypes:no vm:yes |
| `(aa*)*b` | 1024 | nomatch 0.003 ms | limit 114.282 ms | nomatch 0.003 ms | nomatch 0.009 ms | limit 239.436 ms | - | - | c:no stubs:no ctypes:no vm:yes |
| `(aa*)*b` | 2048 | nomatch 0.004 ms | limit 113.396 ms | nomatch 0.004 ms | nomatch 0.008 ms | limit 239.675 ms | - | - | c:no stubs:no ctypes:no vm:yes |
| `(aa*)*b` | 4096 | nomatch 0.007 ms | limit 114.409 ms | nomatch 0.007 ms | nomatch 0.011 ms | limit 240.441 ms | - | - | c:no stubs:no ctypes:no vm:yes |

Cell: outcomes over the runs (`limit` = -17, retry budget 10,000,000 per start position; `cap` = 60 s timeout) and median wall time of one search. `c`, `stubs`, `ctypes` use the default libonig, whose optimiser rejects both subjects before backtracking; `c-noopt` is the same driver on the `-DONIG_DONT_OPTIMIZE` build. `rocq`, `fstar`: fuel `max_int`.

Not comparable: time until `OutOfFuel` with a stated fuel of 10,000,000 VM instructions per start position (fuel counts instructions; the C budget counts backtracks):

| Pattern | n | rocq | fstar |
|---|---:|---|---|
