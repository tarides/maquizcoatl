| Shape | Workload | C driver | stubs - C (FFI, stubs) | ctypes - C (FFI, ctypes) | VM - C (engine, ffi) | VM - C (engine, flambda) | cheaper option |
|---|---|---|---|---|---|---|---|
| short (ns/call) | jq | 123.2 | 3.5 (+3%) | 628.1 (+510%) | -39.5 (-32%) | -48.8 (-40%) | VM flambda |
| short (ns/call) | php | 6899.3 | -14.7 (-0%) | 611.7 (+9%) | 5880.8 (+85%) | 3474.6 (+50%) | stubs |
| short (ns/call) | vscode | 78.3 | 7.8 (+10%) | 612.5 (+782%) | 568.4 (+725%) | 465.7 (+594%) | stubs |
| synthetic long PHP (ns/call) | longphp | 14,368 | 1067.6 (+7%) | 1713.7 (+12%) | 25,250 (+176%) | 12,849 (+89%) | stubs |
| large (ms per MiB, median over patterns) | log-1m | 1.584 | +0.001 | +0.003 | +16.457 (11.4x) | +15.277 (10.6x) | stubs |
| large (ms per MiB, median over patterns) | log-16m | 1.579 | +0.001 | +0.007 | +16.452 (11.4x) | +15.197 (10.6x) | stubs |
| large (ms per MiB, median over patterns) | src-1m | 2.046 | +0.113 | +2.097 | +16.010 (8.8x) | +14.825 (8.2x) | stubs |
| large (ms per MiB, median over patterns) | src-16m | 2.374 | +0.173 | +2.601 | +15.728 (7.6x) | +14.448 (7.1x) | stubs |
