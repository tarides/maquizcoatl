| Shape | Workload | C driver | stubs - C | ctypes - C | VM - C | Rocq - C | F\* - C | cheapest OCaml option |
|---|---|---:|---:|---:|---:|---:|---:|---|
| short (ns/call) | jq | 123.2 | 10.9 (1.1x) | 617.2 (6.0x) | -41.8 (0.7x) | 74.4 (1.6x) | 226.4 (2.8x) | VM |
| short (ns/call) | php | 93.8 | 11.3 (1.1x) | 620.0 (7.6x) | -5.9 (0.9x) | 96.2 (2.0x) | 222.9 (3.4x) | VM |
| short (ns/call) | vscode | 67.4 | 8.6 (1.1x) | 598.9 (9.9x) | 416.2 (7.2x) | 1685.5 (26.0x) | 3808.9 (57.5x) | stubs |
| synthetic long PHP (ns/call) | longphp | 131.6 | 40.8 (1.3x) | 663.7 (6.0x) | -74.4 (0.4x) | -25.7 (0.8x) | 19.7 (1.1x) | VM |
| large (ms per MiB, median over patterns) | log-1m | 1.581 | +0.005 (1.0x) | +0.004 (1.0x) | +15.664 (10.9x) | +36.410 (24.0x) | +51.154 (33.4x) | ctypes |
| large (ms per MiB, median over patterns) | log-16m | 1.578 | -0.000 (1.0x) | +0.001 (1.0x) | +15.627 (10.9x) | +37.229 (24.6x) | +52.199 (34.1x) | stubs |
| large (ms per MiB, median over patterns) | src-1m | 2.016 | +0.130 (1.1x) | +2.027 (2.0x) | +15.241 (8.6x) | +36.947 (19.3x) | +51.941 (26.8x) | stubs |
| large (ms per MiB, median over patterns) | src-16m | 2.337 | +0.224 (1.1x) | +1.801 (1.8x) | +14.955 (7.4x) | +37.424 (17.0x) | +51.918 (23.2x) | stubs |
