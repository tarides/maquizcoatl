(* VU_Client.thy: models of the two apply-all clients of
   ../caller/caller.c, proved to meet the client contract respects_at of
   VU.thy (issue #30, follow-up of experiment #5), as Aeneas's
   tableClient_respects does for its model (../aeneas/proofs/Proofs.lean).

   The models are higher-order in the apply function, so they are not
   exported (export_llvm has no function-pointer type): this theory is
   proof only, and vu.ll is written by VU.thy alone. Not modelled, as in
   Aeneas: the contents of the "to" array (any pointer is passed on
   unchanged; vu_i_apply never reads it), the memcpy into the stack
   array, and the counter apply_all_calls, which is the client's private
   state. Nothing checks that these models are faithful to the C code:
   the contract stays a trusted hypothesis (TRUSTED). *)
theory VU_Client
  imports VU
begin

text \<open>The type of vu_i_apply, and of every apply function a client
  may be given.\<close>
type_synonym apply_fn = "32 word \<Rightarrow> 32 word ptr \<Rightarrow> 32 word \<Rightarrow> fold_rec ptr \<Rightarrow> 32 word llM"

text \<open>The (from, to_len) pairs of caller.c's fold_table, in the C
  order (to_len -1 is the word -1).\<close>
definition fold_table :: "(32 word \<times> 32 word) list" where
  "fold_table = [(0x41, 1), (0x61, 1), (0xdf, 2), (0x390, 3), (0x1e9e, 0),
    (0x2000, 4), (0x2001, -1), (0x101, 1), (0x103, 1), (0x105, 1),
    (0x107, 1), (0x109, 1), (0x10b, 1)]"

text \<open>client_apply_all (caller.c:293-303): calls the apply function on
  each entry of the table, stops at the first non-zero result and
  returns it, returns 0 at the end of the table. After Aeneas's walk.\<close>
fun table_client :: "apply_fn \<Rightarrow> 32 word ptr \<Rightarrow> (32 word \<times> 32 word) list \<Rightarrow> fold_rec ptr \<Rightarrow> 32 word llM" where
  "table_client ai to [] rc = Mreturn 0"
| "table_client ai to ((fr, n) # t) rc = doM {
     res \<leftarrow> ai fr to n rc;
     if res \<noteq> 0 then Mreturn res else table_client ai to t rc
   }"

text \<open>client_apply_all_stop (caller.c:305-309): one call, whose result
  is ignored, then -7.\<close>
definition stop_client :: "apply_fn \<Rightarrow> 32 word ptr \<Rightarrow> fold_rec ptr \<Rightarrow> 32 word llM" where
  "stop_client ai to rc \<equiv> doM {
    res \<leftarrow> ai 0x41 to 1 rc;
    Mreturn (-7)
  }"

text \<open>The contract's hypothesis on the apply function, with the
  property in the precondition, the form the VCG uses.\<close>
lemma htriple_pre_pureI:
  assumes "b \<Longrightarrow> llvm_htriple P c Q"
  shows "llvm_htriple (P ** \<up>b) c Q"
  apply (rule htriple_pure_preI)
  using assms by (cases b) (auto simp: sep_algebra_simps pure_part_def)

lemma table_client_rule:
  assumes [vcg_rules]: "\<And>fr to to_len r. llvm_htriple
    (\<upharpoonleft>ll_pto r rc ** \<up>(P r)) (ai fr to to_len rc)
    (\<lambda>_. EXS r'. \<upharpoonleft>ll_pto r' rc ** \<up>(P r'))"
  shows "llvm_htriple
    (\<upharpoonleft>ll_pto r rc ** \<up>(P r)) (table_client ai to tbl rc)
    (\<lambda>_. EXS r'. \<upharpoonleft>ll_pto r' rc ** \<up>(P r'))"
proof (induction tbl arbitrary: r)
  case Nil
  text \<open>The VCG splits the record of the postcondition into its ten
    fields: so is the record of the precondition.\<close>
  obtain c m f0 f1 f2 f3 f4 f5 f6 f7 where A: "r = (c, m, f0, f1, f2, f3, f4, f5, f6, f7)"
    by (metis surj_pair)
  show ?case
    unfolding table_client.simps A
    by vcg'
next
  case (Cons e t)
  obtain fr n where E: "e = (fr, n)"
    by (cases e)
  note [vcg_rules] = Cons.IH
  show ?case
    unfolding E table_client.simps
    by vcg'
qed

lemma stop_client_rule:
  assumes [vcg_rules]: "\<And>fr to to_len r. llvm_htriple
    (\<upharpoonleft>ll_pto r rc ** \<up>(P r)) (ai fr to to_len rc)
    (\<lambda>_. EXS r'. \<upharpoonleft>ll_pto r' rc ** \<up>(P r'))"
  shows "llvm_htriple
    (\<upharpoonleft>ll_pto r rc ** \<up>(P r)) (stop_client ai to rc)
    (\<lambda>_. EXS r'. \<upharpoonleft>ll_pto r' rc ** \<up>(P r'))"
  unfolding stop_client_def
  by vcg'

text \<open>The models meet the client contract, for every apply function.\<close>
lemma table_client_respects: "respects_at ai (table_client ai to tbl) rc"
  unfolding respects_at_def
  apply (intro allI impI)
  apply (rule table_client_rule)
  apply (rule htriple_pre_pureI)
  apply blast
  done

lemma stop_client_respects: "respects_at ai (stop_client ai to) rc"
  unfolding respects_at_def
  apply (intro allI impI)
  apply (rule stop_client_rule)
  apply (rule htriple_pre_pureI)
  apply blast
  done

text \<open>The contract is usable on the models, not only provable: given
  vu_i_apply, as the shim gives it, both keep the record well formed
  (the hypothesis of vu_fold_all_correct).\<close>
lemma vu_i_apply_rec_wf_all:
  "\<forall>fr to to_len r. rec_wf r \<longrightarrow> llvm_htriple
     (\<upharpoonleft>ll_pto r rc) (vu_i_apply fr to to_len rc)
     (\<lambda>_. EXS r'. \<upharpoonleft>ll_pto r' rc ** \<up>(rec_wf r'))"
  using vu_i_apply_rec_wf by blast

lemma table_client_rec_wf:
  "llvm_htriple
    (\<upharpoonleft>ll_pto r rc ** \<up>(rec_wf r)) (table_client vu_i_apply to fold_table rc)
    (\<lambda>_. EXS r'. \<upharpoonleft>ll_pto r' rc ** \<up>(rec_wf r'))"
  using table_client_respects[of vu_i_apply to fold_table rc] vu_i_apply_rec_wf_all
  unfolding respects_at_def by blast

lemma stop_client_rec_wf:
  "llvm_htriple
    (\<upharpoonleft>ll_pto r rc ** \<up>(rec_wf r)) (stop_client vu_i_apply to rc)
    (\<lambda>_. EXS r'. \<upharpoonleft>ll_pto r' rc ** \<up>(rec_wf r'))"
  using stop_client_respects[of vu_i_apply to rc] vu_i_apply_rec_wf_all
  unfolding respects_at_def by blast

end
