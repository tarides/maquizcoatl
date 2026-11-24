(* proof_i_apply.v: the RefinedRust proof of i_apply (run F of
   experiment #5), the generated template with one addition: the literal
   2147483647 (INT_MAX) must be shown to be an i32, which needs the
   value of MaxInt i32 (RefinedRust's solvers only know 127 <= MaxInt i32). *)
From radium Require Import lang notation.
From refinedrust Require Import typing shims.
From refinedrust.examples.vu.generated Require Import generated_code_vu generated_specs_vu generated_template_i_apply.

Set Default Proof Using "Type".

Section proof.
Context `{RRGS : !refinedrustGS Σ}.

Lemma i_apply_proof (π : thread_id) :
  i_apply_lemma π.
Proof.
  i_apply_prelude.

  repeat liRStep; liShow.

  all: print_remaining_goal.
  Unshelve. all: sidecond_solver.
  Unshelve. all: sidecond_hammer.
  all: rewrite MinInt_eq MaxInt_eq.
  all: have ? : max_int i32 = 2147483647 by vm_compute; reflexivity.
  all: have ? : min_int i32 = -2147483648 by vm_compute; reflexivity.
  all: lia.
  Unshelve. all: print_remaining_sidecond.
Qed.
End proof.
