(* ToC.v: the C code of the Bedrock2 prototype, printed by Bedrock2's
   ToCString (unverified, part of the toolchain): its prelude, then each
   function of VU.vu_funcs, all with external linkage. build.sh dumps
   vu_c_bytes with Bedrock2's etc/bytedump.py into vu.c. *)
From Stdlib Require Import String List.
Require Import bedrock2.ToCString.
Require VU.VU.

Definition vu_c : string :=
  prelude ++ LF ++ String.concat LF (List.map c_func VU.VU.vu_funcs).
Definition vu_c_bytes := list_byte_of_string vu_c.
