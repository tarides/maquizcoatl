# Lab notebook

One line per recorded run; details in `lab/results/`. Results files are
append-only.

| Date | Experiment | Finding | Link |
|---|---|---|---|
| 2026-11-19 | exp-01 workloads | VS Code, jq, PHP regex calls captured and packaged with stock `f95747b` expected results; 42 VS Code searches differ from the host's bundled Oniguruma (one grammar pattern rejected by `f95747b`) | [results](results/2026-11-19-exp-01-workloads.md) |
| 2026-11-19 | exp-01 corpus | 17,367 VS Code, 69 jq and 144 PHP occurrences from pinned sources; 5,870 / 44 / 73 distinct triples; host configurations confirmed | [results](results/2026-11-19-exp-01-corpus.md) |
| 2026-11-19 | exp-01 compile-and-classify | 96.5% of compiled triples in the linear ReDoS tier; no pattern callouts; absent operator in 2 triples; subexpression calls in 2% of triples but 18/82 VS Code grammars; proposed first subset S2 covers 97.9% | [results](results/2026-11-19-exp-01-compile-and-classify.md) |
| 2026-11-19 | exp-01 review fixes | Shift_JIS naming fixed (6 dynamic-only PHP triples now compile, 131/131); `\z` rewrite changes 10 occurrences / 7 patterns; long-subject PHP sample (18 calls, 2 synthetic subjects); VS Code searches issued 1,486,388 times for 473,134 distinct; corrects two full-capture counts of the workloads entry | [results](results/2026-11-19-exp-01-review-fixes.md) |
