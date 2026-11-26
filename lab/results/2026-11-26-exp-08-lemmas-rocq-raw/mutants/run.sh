#!/bin/bash
# Run-2 rerun of run 1's eight desugaring mutants on the 29 cases (ab01-ab29),
# plus a control on the recorded Desugar.v.  Untimed, nice -n 10, CPUs 8-11.
cd "$(dirname "$0")"
. ~/maquizcoatl-work/cache/env.sh
O=~/maquizcoatl-work/cache/bin/opam
for f in Absent Desugar DM1_engine_no_restore DM2_tail_no_reinstall DM3_rclear_no_restore DM4_simple_no_final_restore DM5_general_not_atomic DM6_no_simple_dispatch DM7_tail_no_restore DM8_no_rewind; do
  nice -n 10 taskset -c 8-11 $O exec --switch provers -- rocq compile -R . S $f.v >/dev/null 2>&1 || echo "BUILD FAILED $f"
done
for t in TM0_control TM1_engine_no_restore TM2_tail_no_reinstall TM3_rclear_no_restore TM4_simple_no_final_restore TM5_general_not_atomic TM6_no_simple_dispatch TM7_tail_no_restore TM8_no_rewind; do
  echo "== ${t#TM}"
  nice -n 10 taskset -c 8-11 $O exec --switch provers -- rocq compile -R . S $t.v 2>&1 | tr '\n' ' ' | sed 's/  */ /g'; echo
done
