(* VU.thy: the verified functions of experiment #5 in Isabelle-LLVM,
   exported as LLVM IR by export_llvm. The C interface is ../proto.h.

   Isabelle-LLVM's code generator has no function-pointer type: its
   types are integers, floats, pointers to data, structs and unions
   (LLC_Intermediate in thys/basic/kernel/LLVM_Codegen.thy), and an
   external function is called by name only (LLVM_EXTERNAL). So each
   indirect call goes through a C shim (shim.c) that is declared here as
   an external constant, with no definition and no axiom. The client's
   contract on the shim is a hypothesis ("assumes") of each theorem that
   uses it: nothing is assumed about the shim beyond what the theorem
   states. A client C function pointer is an opaque "8 word ptr" here,
   never dereferenced: at the LLVM level every pointer is "ptr", which
   has the same ABI as a C function pointer.

   The upstream rules modelled here are cited in ../proto.h and in
   lab/results/2026-11-19-exp-05-harness.md. *)
theory VU
  imports Isabelle_LLVM.LLVM_DS_All
begin

text \<open>The VCG rules of the LLVM instructions (memory, arithmetic,
  control) are declared in this locale.\<close>
interpretation llvm_prim_setup .

text \<open>Signed comparisons are reasoned about on sint.\<close>
declare word_sless_alt[simp] word_sle_def[simp]

section \<open>Data types and constants\<close>

text \<open>The C layouts of proto.h, written with Isabelle-LLVM's pair
  structs (it has no array type inside a struct, so the arrays of
  proto.h are consecutive fields of the same type, which have the same
  layout). The nesting is chosen so that the LLVM layout equals the C
  one; layout.c checks it:
  \<^item> vu_enc_state = {min_enc_len, max_enc_len};
  \<^item> vu_args = {{subject, {subject_len, pos}}, {num, {slot0, ... slot4}}}:
    the first half has size 16, so num is at offset 16 and slot0 at 24;
  \<^item> vu_fold_rec = {calls, {recorded, {from0, ... from7}}}: ten 4-byte
    fields, no padding.\<close>

type_synonym enc_state = "32 word \<times> 32 word"
type_synonym args_hd = "8 word ptr \<times> 32 word \<times> 32 word"
type_synonym args_tl = "32 word \<times> 64 word \<times> 64 word \<times> 64 word \<times> 64 word \<times> 64 word"
type_synonym vu_args = "args_hd \<times> args_tl"
type_synonym froms = "32 word \<times> 32 word \<times> 32 word \<times> 32 word \<times> 32 word \<times> 32 word \<times> 32 word \<times> 32 word"
type_synonym fold_rec = "32 word \<times> 32 word \<times> froms"

text \<open>The verified-side state of vu_args (subject, subject_len, pos,
  num) and its data slots.\<close>
definition same_state :: "vu_args \<Rightarrow> vu_args \<Rightarrow> bool" where
  "same_state a b \<longleftrightarrow> fst a = fst b \<and> fst (snd a) = fst (snd b)"

text \<open>The subject pointer and length held in vu_args, and the subject
  itself: subject_len bytes at the subject pointer, with contents bs
  (indexed from 0). Isabelle-LLVM has no fractional permissions, so
  whoever holds this assertion owns the bytes; the verified functions
  and the callout give it back unchanged. ll_range already holds that
  the pointer is a base address (abase); the pure copy lets the VCG
  use it.\<close>
definition subj_ptr :: "vu_args \<Rightarrow> 8 word ptr" where "subj_ptr a = fst (fst a)"
definition subj_len :: "vu_args \<Rightarrow> 32 word" where "subj_len a = fst (snd (fst a))"
definition subject_assn where
  "subject_assn a bs =
    (\<upharpoonleft>(ll_range {0..<sint (subj_len a)}) bs (subj_ptr a) ** \<up>(abase (subj_ptr a)))"

definition slots :: "vu_args \<Rightarrow> 64 word list" where
  "slots a = (case a of (_, _, x0, x1, x2, x3, x4) \<Rightarrow> [x0, x1, x2, x3, x4])"

text \<open>The fields of vu_fold_rec.\<close>
definition fr_calls :: "fold_rec \<Rightarrow> 32 word" where "fr_calls r = fst r"
definition fr_recorded :: "fold_rec \<Rightarrow> 32 word" where "fr_recorded r = fst (snd r)"
definition fr_from :: "fold_rec \<Rightarrow> 32 word list" where
  "fr_from r = (case r of (_, _, f0, f1, f2, f3, f4, f5, f6, f7) \<Rightarrow> [f0, f1, f2, f3, f4, f5, f6, f7])"

text \<open>Well-formed vu_fold_rec: 0 <= recorded <= VU_FOLD_REC_MAX.\<close>
definition rec_wf :: "fold_rec \<Rightarrow> bool" where
  "rec_wf r \<longleftrightarrow> 0 \<le> sint (fr_recorded r) \<and> sint (fr_recorded r) \<le> 8"

text \<open>VU_ERR_INVALID_ARGUMENT, written as an unsigned literal for the
  code generator.\<close>
abbreviation err_invalid_argument :: "32 word" where
  "err_invalid_argument \<equiv> 0xFFFFFFE2"

lemma err_invalid_argument_value: "sint err_invalid_argument = -30"
  by simp


section \<open>The client's functions, through the trusted shim\<close>

text \<open>Declared, not defined: these are the C functions of shim.c. Their
  contracts are the hypotheses of the theorems below.\<close>
consts vu_call_enc_len :: "8 word ptr \<Rightarrow> 8 word ptr \<Rightarrow> 32 word llM"
consts vu_call_callout :: "8 word ptr \<Rightarrow> vu_args ptr \<Rightarrow> 8 word ptr \<Rightarrow> 32 word llM"
consts vu_call_apply_all :: "8 word ptr \<Rightarrow> fold_rec ptr \<Rightarrow> 32 word llM"

lemmas [llvm_code_raw] =
  LLVM_EXTERNALI[of vu_call_enc_len "''vu_call_enc_len''"]
  LLVM_EXTERNALI[of vu_call_callout "''vu_call_callout''"]
  LLVM_EXTERNALI[of vu_call_apply_all "''vu_call_apply_all''"]


section \<open>1. vu_char_len\<close>

(* CLAMP-BEGIN *)
definition vu_clamp :: "32 word \<Rightarrow> 32 word \<Rightarrow> 32 word \<Rightarrow> 32 word llM" where [llvm_inline]:
  "vu_clamp r mn mx \<equiv> doM {
    lt \<leftarrow> ll_icmp_slt r mn;
    llc_if lt (Mreturn mn) (doM {
      gt \<leftarrow> ll_icmp_slt mx r;
      llc_if gt (Mreturn mx) (Mreturn r)
    })
  }"
(* CLAMP-END *)

definition vu_char_len :: "8 word ptr \<Rightarrow> 8 word ptr \<Rightarrow> enc_state ptr \<Rightarrow> 32 word llM"
  where [llvm_code]:
  "vu_char_len f p st \<equiv> doM {
    r \<leftarrow> vu_call_enc_len f p;
    s \<leftarrow> ll_load st;
    case s of (mn, mx) \<Rightarrow> vu_clamp r mn mx
  }"

text \<open>The encoding callee may read the byte p points to and gives it
  back unchanged; it returns some 32-bit value: no range is assumed.\<close>
lemma vu_char_len_correct:
  assumes [vcg_rules]: "\<And>c. llvm_htriple
    (\<upharpoonleft>ll_pto c p) (vu_call_enc_len f p) (\<lambda>_. \<upharpoonleft>ll_pto c p)"
  shows "llvm_htriple
    (\<upharpoonleft>ll_pto c p ** \<upharpoonleft>ll_pto (mn, mx) st ** \<up>(1 \<le> sint mn \<and> sint mn \<le> sint mx))
    (vu_char_len f p st)
    (\<lambda>res. \<upharpoonleft>ll_pto c p ** \<upharpoonleft>ll_pto (mn, mx) st **
      \<up>(sint mn \<le> sint res \<and> sint res \<le> sint mx))"
  unfolding vu_char_len_def vu_clamp_def
  by vcg'


section \<open>2. vu_callout_step\<close>

text \<open>Branch rules on the callee's result r (proto.h): progress
  direction (d = 0), retraction (d = 1), each-match callback (d = 2).\<close>
definition progress_res :: "32 word \<Rightarrow> 32 word" where
  "progress_res r = (if r = 1 then 1 else if r = 0 then 0
    else if 0 < sint r then err_invalid_argument else r)"

definition retraction_res :: "32 word \<Rightarrow> 32 word" where
  "retraction_res r = (if r = 0 \<or> r = 1 then 0
    else if 0 < sint r then err_invalid_argument else r)"

definition each_match_res :: "32 word \<Rightarrow> 32 word" where
  "each_match_res r = (if sint r < 0 then r else 1)"

definition valid_dir :: "32 word \<Rightarrow> bool" where
  "valid_dir d \<longleftrightarrow> d = 0 \<or> d = 1 \<or> d = 2"

definition step_res :: "32 word \<Rightarrow> 32 word \<Rightarrow> 32 word" where
  "step_res d r = (if d = 0 then progress_res r
    else if d = 1 then retraction_res r else each_match_res r)"

definition vu_callout_step :: "32 word \<Rightarrow> 8 word ptr \<Rightarrow> vu_args ptr \<Rightarrow> 8 word ptr \<Rightarrow> 32 word llM"
  where [llvm_code]:
  "vu_callout_step d f args ud \<equiv> doM {
    d0 \<leftarrow> ll_icmp_eq d 0;
    llc_if d0 (doM {
      r \<leftarrow> vu_call_callout f args ud;
      b \<leftarrow> ll_icmp_eq r 1;
      llc_if b (Mreturn 1) (doM {
        b \<leftarrow> ll_icmp_eq r 0;
        llc_if b (Mreturn 0) (doM {
          b \<leftarrow> ll_icmp_slt 0 r;
          llc_if b (Mreturn err_invalid_argument) (Mreturn r)
        })
      })
    }) (doM {
    d1 \<leftarrow> ll_icmp_eq d 1;
    llc_if d1 (doM {
      r \<leftarrow> vu_call_callout f args ud;
      b \<leftarrow> ll_icmp_ule r 1;
      llc_if b (Mreturn 0) (doM {
        b \<leftarrow> ll_icmp_slt 0 r;
        llc_if b (Mreturn err_invalid_argument) (Mreturn r)
      })
    }) (doM {
    d2 \<leftarrow> ll_icmp_eq d 2;
    llc_if d2 (doM {
      r \<leftarrow> vu_call_callout f args ud;
      b \<leftarrow> ll_icmp_slt r 0;
      llc_if b (Mreturn r) (Mreturn 1)
    }) (Mreturn err_invalid_argument)
    })
    })
  }"

lemma word32_le_1_iff: "(r::32 word) \<le> 1 \<longleftrightarrow> r = 0 \<or> r = 1"
  by (metis le_zero_eq word_le_sub1 word_less_1 word_order.not_eq_extremum
    linorder_not_le order_le_less)

text \<open>The callout callee gets the whole args record (so that it can
  call vu_get_slot and vu_set_slot) and gives it back with the
  verified-side state unchanged; only the slots may differ. It also gets
  the subject (so that it can call vu_get_subject_byte) and gives it
  back unchanged: Isabelle-LLVM cannot lend it read-only, so the
  contract says the bytes come back the same. Its result satisfies Q,
  an arbitrary predicate (Q = (\<lambda>_. True) for an unknown client).
  user_data is opaque: no permission on it is held or lent.\<close>
lemma vu_callout_step_correct:
  assumes [vcg_rules]: "\<And>a. llvm_htriple
    (\<upharpoonleft>ll_pto a args ** subject_assn a bs) (vu_call_callout f args ud)
    (\<lambda>r. EXS a'. \<upharpoonleft>ll_pto a' args ** subject_assn a bs ** \<up>(same_state a a' \<and> Q r))"
  shows "llvm_htriple
    (\<upharpoonleft>ll_pto a args ** subject_assn a bs)
    (vu_callout_step d f args ud)
    (\<lambda>res. EXS a'. \<upharpoonleft>ll_pto a' args ** subject_assn a bs ** \<up>(same_state a a' \<and>
      (if valid_dir d then \<exists>r. Q r \<and> res = step_res d r
       else a' = a \<and> res = err_invalid_argument)))"
proof -
  obtain s l q n x0 x1 x2 x3 x4 where A: "a = ((s, l, q), n, x0, x1, x2, x3, x4)"
    by (metis surj_pair)
  show ?thesis
    unfolding vu_callout_step_def A
    apply vcg'
    apply (auto simp: valid_dir_def step_res_def progress_res_def
      retraction_res_def each_match_res_def same_state_def word32_le_1_iff)
    \<comment> \<open>retraction with a callee result of 0, then of 1\<close>
    subgoal by (rule exI[where x = 0]) simp
    subgoal by (rule exI[where x = 1]) simp
    done
qed


section \<open>3. Re-entrancy (a): vu_i_apply and vu_fold_all\<close>

text \<open>What vu_i_apply does to the record: calls + 1, saturating at
  INT_MAX; when 1 <= to_len <= VU_MAX_TO_LEN and 0 <= recorded <
  VU_FOLD_REC_MAX, from[recorded] := from and recorded + 1; nothing
  else changes.\<close>
definition i_apply_rel :: "fold_rec \<Rightarrow> fold_rec \<Rightarrow> 32 word \<Rightarrow> 32 word \<Rightarrow> bool" where
  "i_apply_rel r r' fr to_len \<longleftrightarrow>
    fr_calls r' = (if sint (fr_calls r) < 2147483647 then fr_calls r + 1 else fr_calls r) \<and>
    (if 1 \<le> sint to_len \<and> sint to_len \<le> 3 \<and>
        0 \<le> sint (fr_recorded r) \<and> sint (fr_recorded r) < 8
     then fr_recorded r' = fr_recorded r + 1 \<and>
          fr_from r' = (fr_from r)[nat (sint (fr_recorded r)) := fr]
     else fr_recorded r' = fr_recorded r \<and> fr_from r' = fr_from r)"

definition set_from_at :: "froms \<Rightarrow> 32 word \<Rightarrow> 32 word \<Rightarrow> froms llM" where [llvm_inline]:
  "set_from_at fs i x \<equiv> (case fs of (f0, f1, f2, f3, f4, f5, f6, f7) \<Rightarrow> doM {
    b \<leftarrow> ll_icmp_slt i 1; llc_if b (Mreturn (x, f1, f2, f3, f4, f5, f6, f7)) (doM {
    b \<leftarrow> ll_icmp_slt i 2; llc_if b (Mreturn (f0, x, f2, f3, f4, f5, f6, f7)) (doM {
    b \<leftarrow> ll_icmp_slt i 3; llc_if b (Mreturn (f0, f1, x, f3, f4, f5, f6, f7)) (doM {
    b \<leftarrow> ll_icmp_slt i 4; llc_if b (Mreturn (f0, f1, f2, x, f4, f5, f6, f7)) (doM {
    b \<leftarrow> ll_icmp_slt i 5; llc_if b (Mreturn (f0, f1, f2, f3, x, f5, f6, f7)) (doM {
    b \<leftarrow> ll_icmp_slt i 6; llc_if b (Mreturn (f0, f1, f2, f3, f4, x, f6, f7)) (doM {
    b \<leftarrow> ll_icmp_slt i 7; llc_if b (Mreturn (f0, f1, f2, f3, f4, f5, x, f7))
      (Mreturn (f0, f1, f2, f3, f4, f5, f6, x)) }) }) }) }) }) })
  })"

text \<open>1 <= to_len <= VU_MAX_TO_LEN and 0 <= recorded < VU_FOLD_REC_MAX.\<close>
definition can_append :: "32 word \<Rightarrow> 32 word \<Rightarrow> 1 word llM" where [llvm_inline]:
  "can_append to_len n \<equiv> doM {
    b \<leftarrow> ll_icmp_sle 1 to_len;
    llc_if b (doM {
      b \<leftarrow> ll_icmp_sle to_len 3;
      llc_if b (doM {
        b \<leftarrow> ll_icmp_sle 0 n;
        llc_if b (ll_icmp_slt n 8) (Mreturn 0)
      }) (Mreturn 0)
    }) (Mreturn 0)
  }"

definition vu_i_apply :: "32 word \<Rightarrow> 32 word ptr \<Rightarrow> 32 word \<Rightarrow> fold_rec ptr \<Rightarrow> 32 word llM"
  where [llvm_code]:
  "vu_i_apply fr to to_len rc \<equiv> doM {
    x \<leftarrow> ll_load rc;
    case x of (c, n, fs) \<Rightarrow> doM {
      b \<leftarrow> ll_icmp_slt c 0x7FFFFFFF;
      c' \<leftarrow> llc_if b (ll_add c 1) (Mreturn c);
      ok \<leftarrow> can_append to_len n;
      llc_if ok (doM {
        fs' \<leftarrow> set_from_at fs n fr;
        n' \<leftarrow> ll_add n 1;
        ll_store (c', n', fs') rc;
        Mreturn 0
      }) (doM {
        ll_store (c', n, fs) rc;
        Mreturn 0
      })
    }
  }"

lemma sint_incr_small: "0 \<le> sint (w::32 word) \<Longrightarrow> sint w < 8 \<Longrightarrow> sint (w + 1) = sint w + 1"
  by (simp add: sint_word_ariths signed_take_bit_int_eq_self)

lemma sint_cases_rec: "sint (n::32 word) < 0 \<or> sint n = 0 \<or> sint n = 1 \<or> sint n = 2 \<or>
  sint n = 3 \<or> sint n = 4 \<or> sint n = 5 \<or> sint n = 6 \<or> sint n = 7 \<or> 8 \<le> sint n"
  by arith

text \<open>"to" is never read: no permission on it is required.\<close>
lemma vu_i_apply_correct:
  "llvm_htriple
    (\<upharpoonleft>ll_pto r rc)
    (vu_i_apply fr to to_len rc)
    (\<lambda>res. EXS r'. \<upharpoonleft>ll_pto r' rc **
      \<up>(res = 0 \<and> i_apply_rel r r' fr to_len \<and> (rec_wf r \<longrightarrow> rec_wf r')))"
proof -
  obtain c n f0 f1 f2 f3 f4 f5 f6 f7 where A: "r = (c, n, f0, f1, f2, f3, f4, f5, f6, f7)"
    by (metis surj_pair)
  show ?thesis
    unfolding vu_i_apply_def can_append_def set_from_at_def A
    using sint_cases_rec[of n]
    apply (elim disjE)
    apply (all \<open>vcg'\<close>)
    apply (auto simp: i_apply_rel_def rec_wf_def fr_calls_def fr_recorded_def fr_from_def
      sint_incr_small)
    done
qed

text \<open>The client's apply_all_case_fold, called through the shim, which
  passes it vu_i_apply as a C pointer: given the record well formed, it
  gives it back well formed. A client that changes the record only
  through vu_i_apply meets this contract, by vu_i_apply_correct.\<close>
definition vu_fold_all :: "8 word ptr \<Rightarrow> fold_rec ptr \<Rightarrow> 32 word llM"
  where [llvm_code]:
  "vu_fold_all g rc \<equiv> doM {
    res \<leftarrow> vu_call_apply_all g rc;
    Mreturn res
  }"

lemma vu_fold_all_correct:
  assumes [vcg_rules]: "\<And>r. llvm_htriple
    (\<upharpoonleft>ll_pto r rc ** \<up>(rec_wf r)) (vu_call_apply_all g rc)
    (\<lambda>_. EXS r'. \<upharpoonleft>ll_pto r' rc ** \<up>(rec_wf r'))"
  shows "llvm_htriple
    (\<upharpoonleft>ll_pto r rc ** \<up>(rec_wf r))
    (vu_fold_all g rc)
    (\<lambda>_. EXS r'. \<upharpoonleft>ll_pto r' rc ** \<up>(rec_wf r'))"
  unfolding vu_fold_all_def
  apply vcg'
  done

subsection \<open>Composition with vu_i_apply's theorem\<close>

text \<open>The client contract of re-entrancy shape (a), stated on the
  function the client is given instead of on the record: the client
  reaches the record only through vu_i_apply (which the shim hands it),
  so it preserves every property of the record that every call of
  vu_i_apply preserves. Assumed of the C client, checked nowhere; it is
  the same contract as Aeneas's Respects. It is stated for any apply
  function ai and apply-all function apply_all (respects_at), so that a
  model of a client can be proved to meet it (VU_Client.thy), and
  instantiated (respects_i_apply) with vu_i_apply and the shim.\<close>
definition respects_at :: "(32 word \<Rightarrow> 32 word ptr \<Rightarrow> 32 word \<Rightarrow> fold_rec ptr \<Rightarrow> 32 word llM) \<Rightarrow> (fold_rec ptr \<Rightarrow> 32 word llM) \<Rightarrow> fold_rec ptr \<Rightarrow> bool" where
  "respects_at ai apply_all rc \<longleftrightarrow> (\<forall>P.
    (\<forall>fr to to_len r. P r \<longrightarrow> llvm_htriple
       (\<upharpoonleft>ll_pto r rc) (ai fr to to_len rc)
       (\<lambda>_. EXS r'. \<upharpoonleft>ll_pto r' rc ** \<up>(P r'))) \<longrightarrow>
    (\<forall>r. llvm_htriple
       (\<upharpoonleft>ll_pto r rc ** \<up>(P r)) (apply_all rc)
       (\<lambda>_. EXS r'. \<upharpoonleft>ll_pto r' rc ** \<up>(P r'))))"

definition respects_i_apply where "respects_i_apply g rc \<longleftrightarrow> respects_at vu_i_apply (vu_call_apply_all g) rc"

text \<open>Every call of vu_i_apply keeps the record well formed: a
  consequence of vu_i_apply_correct.\<close>
lemma vu_i_apply_rec_wf:
  assumes "rec_wf r"
  shows "llvm_htriple
    (\<upharpoonleft>ll_pto r rc) (vu_i_apply fr to to_len rc)
    (\<lambda>_. EXS r'. \<upharpoonleft>ll_pto r' rc ** \<up>(rec_wf r'))"
  apply (rule cons_post_rule[OF vu_i_apply_correct])
  using assms
  apply (auto simp: sep_algebra_simps)
  apply blast
  done

text \<open>The hypothesis of vu_fold_all_correct follows from the client
  contract and vu_i_apply_correct: vu_fold_all's theorem then rests on
  the contract alone.\<close>
lemma vu_fold_all_composed:
  assumes "respects_i_apply g rc"
  shows "llvm_htriple
    (\<upharpoonleft>ll_pto r rc ** \<up>(rec_wf r))
    (vu_fold_all g rc)
    (\<lambda>_. EXS r'. \<upharpoonleft>ll_pto r' rc ** \<up>(rec_wf r'))"
proof -
  have "\<forall>fr to to_len r. rec_wf r \<longrightarrow> llvm_htriple
     (\<upharpoonleft>ll_pto r rc) (vu_i_apply fr to to_len rc)
     (\<lambda>_. EXS r'. \<upharpoonleft>ll_pto r' rc ** \<up>(rec_wf r'))"
    using vu_i_apply_rec_wf by blast
  with assms have "\<And>r. llvm_htriple
     (\<upharpoonleft>ll_pto r rc ** \<up>(rec_wf r)) (vu_call_apply_all g rc)
     (\<lambda>_. EXS r'. \<upharpoonleft>ll_pto r' rc ** \<up>(rec_wf r'))"
    unfolding respects_i_apply_def respects_at_def by blast
  then show ?thesis by (rule vu_fold_all_correct)
qed


section \<open>4. Re-entrancy (b): vu_get_slot and vu_set_slot\<close>

text \<open>Slot k of a, for 0 <= k < VU_SLOT_NUM.\<close>
definition slot_at :: "vu_args \<Rightarrow> 32 word \<Rightarrow> 64 word llM" where [llvm_inline]:
  "slot_at a k \<equiv> (case a of (_, _, x0, x1, x2, x3, x4) \<Rightarrow> doM {
    b \<leftarrow> ll_icmp_slt k 1; llc_if b (Mreturn x0) (doM {
    b \<leftarrow> ll_icmp_slt k 2; llc_if b (Mreturn x1) (doM {
    b \<leftarrow> ll_icmp_slt k 3; llc_if b (Mreturn x2) (doM {
    b \<leftarrow> ll_icmp_slt k 4; llc_if b (Mreturn x3) (Mreturn x4) }) }) })
  })"

definition set_slot_at :: "vu_args \<Rightarrow> 32 word \<Rightarrow> 64 word \<Rightarrow> vu_args llM" where [llvm_inline]:
  "set_slot_at a k v \<equiv> (case a of (h, n, x0, x1, x2, x3, x4) \<Rightarrow> doM {
    b \<leftarrow> ll_icmp_slt k 1; llc_if b (Mreturn (h, n, v, x1, x2, x3, x4)) (doM {
    b \<leftarrow> ll_icmp_slt k 2; llc_if b (Mreturn (h, n, x0, v, x2, x3, x4)) (doM {
    b \<leftarrow> ll_icmp_slt k 3; llc_if b (Mreturn (h, n, x0, x1, v, x3, x4)) (doM {
    b \<leftarrow> ll_icmp_slt k 4; llc_if b (Mreturn (h, n, x0, x1, x2, v, x4))
      (Mreturn (h, n, x0, x1, x2, x3, v)) }) }) })
  })"

definition in_slots :: "32 word \<Rightarrow> 1 word llM" where [llvm_inline]:
  "in_slots k \<equiv> doM {
    b \<leftarrow> ll_icmp_sle 0 k;
    llc_if b (ll_icmp_slt k 5) (Mreturn 0)
  }"

definition vu_get_slot :: "vu_args ptr \<Rightarrow> 32 word \<Rightarrow> 64 word ptr \<Rightarrow> 32 word llM"
  where [llvm_code]:
  "vu_get_slot args k out \<equiv> doM {
    ok \<leftarrow> in_slots k;
    llc_if ok (doM {
      a \<leftarrow> ll_load args;
      x \<leftarrow> slot_at a k;
      ll_store x out;
      Mreturn 0
    }) (Mreturn err_invalid_argument)
  }"

definition vu_set_slot :: "vu_args ptr \<Rightarrow> 32 word \<Rightarrow> 64 word \<Rightarrow> 32 word llM"
  where [llvm_code]:
  "vu_set_slot args k v \<equiv> doM {
    ok \<leftarrow> in_slots k;
    llc_if ok (doM {
      a \<leftarrow> ll_load args;
      a' \<leftarrow> set_slot_at a k v;
      ll_store a' args;
      Mreturn 0
    }) (Mreturn err_invalid_argument)
  }"

lemma sint_cases_slot: "sint (k::32 word) < 0 \<or> sint k = 0 \<or> sint k = 1 \<or> sint k = 2 \<or>
  sint k = 3 \<or> sint k = 4 \<or> 5 \<le> sint k"
  by arith

lemma vu_get_slot_correct:
  "llvm_htriple
    (\<upharpoonleft>ll_pto a args ** \<upharpoonleft>ll_pto w out)
    (vu_get_slot args k out)
    (\<lambda>res. EXS w'. \<upharpoonleft>ll_pto a args ** \<upharpoonleft>ll_pto w' out **
      \<up>(if 0 \<le> sint k \<and> sint k < 5
         then res = 0 \<and> w' = slots a ! nat (sint k)
         else res = err_invalid_argument \<and> w' = w))"
proof -
  obtain s l q n x0 x1 x2 x3 x4 where A: "a = ((s, l, q), n, x0, x1, x2, x3, x4)"
    by (metis surj_pair)
  show ?thesis
    unfolding vu_get_slot_def in_slots_def slot_at_def A
    using sint_cases_slot[of k]
    apply (elim disjE)
    apply (all \<open>vcg'\<close>)
    apply (auto simp: slots_def)
    done
qed

lemma vu_set_slot_correct:
  "llvm_htriple
    (\<upharpoonleft>ll_pto a args)
    (vu_set_slot args k v)
    (\<lambda>res. EXS a'. \<upharpoonleft>ll_pto a' args ** \<up>(same_state a a' \<and>
      (if 0 \<le> sint k \<and> sint k < 5
       then res = 0 \<and> slots a' = (slots a)[nat (sint k) := v]
       else res = err_invalid_argument \<and> a' = a)))"
proof -
  obtain s l q n x0 x1 x2 x3 x4 where A: "a = ((s, l, q), n, x0, x1, x2, x3, x4)"
    by (metis surj_pair)
  show ?thesis
    unfolding vu_set_slot_def in_slots_def set_slot_at_def A
    using sint_cases_slot[of k]
    apply (elim disjE)
    apply (all \<open>vcg'\<close>)
    apply (auto simp: slots_def same_state_def)
    done
qed


section \<open>5. Read accessor: vu_get_subject_byte\<close>

text \<open>0 <= i < subject_len.\<close>
(* READ-BEGIN *)
definition in_subject :: "32 word \<Rightarrow> 32 word \<Rightarrow> 1 word llM" where [llvm_inline]:
  "in_subject i l \<equiv> doM {
    b \<leftarrow> ll_icmp_sle 0 i;
    llc_if b (ll_icmp_slt i l) (Mreturn 0)
  }"
(* READ-END *)

definition vu_get_subject_byte :: "vu_args ptr \<Rightarrow> 32 word \<Rightarrow> 32 word llM"
  where [llvm_code]:
  "vu_get_subject_byte args i \<equiv> doM {
    a \<leftarrow> ll_load args;
    case a of ((s, l, q), t) \<Rightarrow> doM {
      ok \<leftarrow> in_subject i l;
      llc_if ok (doM {
        p \<leftarrow> ll_ofs_ptr s i;
        x \<leftarrow> ll_load p;
        ll_zext x TYPE(32 word)
      }) (Mreturn err_invalid_argument)
    }
  }"

text \<open>The accessor needs the subject (whole, as Isabelle-LLVM has no
  read-only share) and gives it back unchanged, with args.\<close>
lemma vu_get_subject_byte_correct:
  "llvm_htriple
    (\<upharpoonleft>ll_pto a args ** subject_assn a bs)
    (vu_get_subject_byte args i)
    (\<lambda>res. \<upharpoonleft>ll_pto a args ** subject_assn a bs **
      \<up>(if 0 \<le> sint i \<and> sint i < sint (subj_len a)
         then res = UCAST(8 \<rightarrow> 32) (bs (sint i))
         else res = err_invalid_argument))"
proof -
  obtain s l q t where A: "a = ((s, l, q), t)"
    by (metis surj_pair)
  show ?thesis
    unfolding vu_get_subject_byte_def in_subject_def subject_assn_def
      subj_ptr_def subj_len_def A
    supply [simp] = is_up'
    apply vcg'
    done
qed


section \<open>Export\<close>

text \<open>The exported names carry the theory name as a prefix (VU_vu_char_len,
  ...): build.sh renames them in the object file. An "is" clause would
  set the name, but it also makes export_llvm write a C header, which
  needs a named field for every struct field.\<close>
export_llvm
  vu_char_len
  vu_callout_step
  vu_i_apply
  vu_fold_all
  vu_get_slot
  vu_set_slot
  vu_get_subject_byte
  file "vu.ll"

end
