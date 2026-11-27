| Family | C driver (ns/call) | stubs - C | ctypes - C | VM - C | Rocq - C | F\* - C | Rocq - VM, gross | Rocq - VM, net of conversion | F\* - VM, gross | F\* - VM, net of conversion |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| jq | 123.2 | 10.9 (1.1x) | 617.2 (6.0x) | -41.8 (0.7x) | 74.4 (1.6x) | 226.4 (2.8x) | 116.1 (2.4x) | 98.7 | 268.2 (4.3x) | 250.7 |
| php | 93.8 | 11.3 (1.1x) | 620.0 (7.6x) | -5.9 (0.9x) | 96.2 (2.0x) | 222.9 (3.4x) | 102.1 (2.2x) | 89.3 | 228.9 (3.6x) | 216.1 |
| vscode | 67.4 | 8.6 (1.1x) | 598.9 (9.9x) | 416.2 (7.2x) | 1685.5 (26.0x) | 3808.9 (57.5x) | 1269.3 (3.6x) | 1240.3 | 3392.7 (8.0x) | 3363.7 |
| longphp | 131.6 | 40.8 (1.3x) | 663.7 (6.0x) | -74.4 (0.4x) | -25.7 (0.8x) | 19.7 (1.1x) | 48.7 (1.9x) | - | 94.1 (2.6x) | - |

Differences of medians in ns per call; the factor is the ratio of the two medians. Net of conversion: the extracted column minus its median per-call conversion cost (conv.md), minus the hand-written VM. Long PHP runs the extracted columns in scan mode, so its figures exclude the conversion already.
