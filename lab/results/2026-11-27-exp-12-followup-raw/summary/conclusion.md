| Shape | Workload | C driver | stubs - C | ctypes - C | VM - C | Rocq - C | F\* - C | cheapest OCaml option |
|---|---|---:|---:|---:|---:|---:|---:|---|
| short (ns/call) | jq | 123.2 | 10.9 (1.1x) | 617.2 (6.0x) | -41.8 (0.7x) | 74.4 (1.6x) | 226.4 (2.8x) | VM |
| short (ns/call) | php | 93.8 | 11.3 (1.1x) | 620.0 (7.6x) | -5.9 (0.9x) | 96.2 (2.0x) | 222.9 (3.4x) | VM |
| short (ns/call) | vscode | 67.4 | 8.6 (1.1x) | 598.9 (9.9x) | 416.2 (7.2x) | 1685.5 (26.0x) | 3808.9 (57.5x) | stubs |
| synthetic long PHP (ns/call) | longphp | 131.6 | 40.8 (1.3x) | 663.7 (6.0x) | -74.4 (0.4x) | -25.7 (0.8x) | 19.7 (1.1x) | VM |
| large (ms per MiB, median over patterns) | log-1m | 1.581 | +0.002 (1.0x) | +0.002 (1.0x) | +13.150 (9.3x) | +36.228 (23.9x) | +50.323 (32.8x) | stubs |
| large (ms per MiB, median over patterns) | log-16m | 1.578 | +0.000 (1.0x) | +0.000 (1.0x) | +13.146 (9.3x) | +37.179 (24.6x) | +52.131 (34.0x) | stubs |
| large (ms per MiB, median over patterns) | src-1m | 1.686 | +0.043 (1.0x) | +0.999 (1.6x) | +13.360 (8.9x) | +37.179 (23.1x) | +52.082 (31.9x) | stubs |
| large (ms per MiB, median over patterns) | src-16m | 1.842 | +0.078 (1.0x) | +1.352 (1.7x) | +13.164 (8.1x) | +37.350 (21.3x) | +52.174 (29.3x) | stubs |
