(* Check.v: the assumptions of each theorem of VU.v (build.sh requires
   "Closed under the global context": the callee contracts are
   hypotheses of the theorems, not axioms). *)
Require VU.VU.
Print Assumptions VU.VU.b2_vu_char_len_ok.
Print Assumptions VU.VU.b2_vu_callout_step_ok.
Print Assumptions VU.VU.b2_vu_i_apply_ok.
Print Assumptions VU.VU.b2_vu_fold_all_ok.
Print Assumptions VU.VU.b2_vu_get_slot_ok.
Print Assumptions VU.VU.b2_vu_set_slot_ok.
Print Assumptions VU.VU.b2_vu_get_subject_byte_ok.
