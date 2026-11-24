(* proof_record_at.v: the RefinedRust proof of record_at (run F of
   experiment #5), the generated template with one addition: in the last
   branch (k is none of 0..6), the side conditions need k = 7, which
   RefinedRust's solvers do not derive from 0 <= k < 8 by themselves,
   and the frame of that write (list_subequiv) is shown entry by entry. *)
From radium Require Import lang notation.
From refinedrust Require Import typing shims.
From refinedrust.examples.vu.generated Require Import generated_code_vu generated_specs_vu generated_template_record_at.

Set Default Proof Using "Type".
Local Transparent list_subequiv.

Section proof.
Context `{RRGS : !refinedrustGS Σ}.

Lemma record_at_proof (π : thread_id) :
  record_at_lemma π.
Proof.
  record_at_prelude.

  repeat liRStep; liShow.

  all: print_remaining_goal.
  Unshelve. all: sidecond_solver.
  Unshelve. all: sidecond_hammer.
  all: assert (k = 7) as -> by lia.
  all: sidecond_hammer.
  (* the frame of the write: every entry but entry 7 is unchanged *)
  all: unfold list_subequiv; intros j; split; [done|]; intros Hj;
       do 8 (destruct j as [|j]; [first [done | exfalso; apply Hj; constructor] |]); done.
  Unshelve. all: print_remaining_sidecond.
Qed.
End proof.
