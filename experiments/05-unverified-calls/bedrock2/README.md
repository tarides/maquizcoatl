# Bedrock2 prototype (experiment #5, run G)

- `VU.v`: the seven functions of `proto.h` in Bedrock2's language
  (`b2_vu_*`), their specifications and proofs, with the callee
  contracts as section variables (hypotheses of every theorem);
- `ToC.v`: prints the C code with Bedrock2's `ToCString`;
- `Check.v`: `Print Assumptions` of the seven theorems;
- `shim.c`: the external actions (`cmd.interact`), which make the
  indirect calls (trusted);
- `b2ext.h`, `abi.c`: the word-level C names and the `proto.h` wrappers
  (trusted);
- `layout.c`: compile-time check of the struct offsets the memory
  predicates assume;
- `build.sh`: under `../run.sh`'s contract; `TRUSTED`: the trusted lines.
