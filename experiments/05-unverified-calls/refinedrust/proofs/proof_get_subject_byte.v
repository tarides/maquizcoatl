(* proof_get_subject_byte.v: the manual RefinedRust proof of the read
   accessor (run F of experiment #5). The generated template stops at
   two points that RefinedRust's automation does not resolve by itself,
   as in the minivec case study's get_unchecked (case_studies/minivec,
   RefinedRust 2862b1d8):
   1. the call of ptr::add needs an alloc_alive_witness whose kind and
      fraction are evars: they are instantiated with the precondition's;
   2. ptr::read needs the ownership of the one byte read, which sits in
      the owned array at s: updateable_typed_array_access takes it out,
      and a stratification before the return folds the array back.
   Two side conditions are closed by hand at the end (list_insert_id,
   wrap_to_it_id). Everything else is RefinedRust's automation (liRStep)
   and its side condition solvers. *)
From radium Require Import lang notation.
From refinedrust Require Import typing shims.
From refinedrust.examples.vu.generated Require Import generated_code_vu generated_specs_vu generated_template_get_subject_byte.

Set Default Proof Using "Type".
Local Typeclasses Opaque alloc_alive_token alloc_alive_witness.

Section proof.
Context `{RRGS : !refinedrustGS Σ}.

Lemma get_subject_byte_proof (π : thread_id) :
  get_subject_byte_lemma π.
Proof.
  get_subject_byte_prelude.

  (* 1. up to the call of ptr::add in the in-bounds branch *)
  repeat liRStep; liShow.
  liInst Hevar_x1 AliveAlloc.
  liInst Hevar_x0 q.
  (* 2. up to the statement that calls ptr::read *)
  repeat (lazymatch goal with
          | |- environments.envs_entails _ (typed_stmt _ _ _ ?st _ _ _ _) =>
              lazymatch st with
              | context [const_ptr_read_u8_loc] => fail
              | _ => liRStep
              end
          | _ => liRStep
          end).
  lazymatch goal with
  | |- context [(s offsetst{IntSynType u8}ₗ ?o)] =>
      apply_update (updateable_typed_array_access s o (IntSynType u8))
  end.
  (* 3. up to the return, where the array is folded back *)
  repeat (lazymatch goal with
          | |- environments.envs_entails _ (typed_stmt _ _ _ ?st _ _ _ _) =>
              lazymatch st with
              | context [Return _] => fail
              | _ => liRStep
              end
          | _ => liRStep
          end).
  apply_update (updateable_stratify s StratRefoldFull StratifyUnblockOp).
  repeat liRStep; liShow.

  all: print_remaining_goal.
  Unshelve. all: sidecond_solver.
  Unshelve. all: sidecond_hammer.
  (* The two side conditions left: the byte read is the one in bs, so
     putting it back changes nothing; and a byte (0..255) cast to i32 is
     unchanged. *)
  all: try by apply list_insert_id.
  all: try (symmetry; apply wrap_to_it_id; apply int_elem_of_it_iff).
  all: repeat match goal with H : context [MaxInt u8] |- _ => rewrite MaxInt_eq in H end.
  all: have ? : max_int u8 = 255 by vm_compute; reflexivity.
  all: have ? : max_int i32 = 2147483647 by vm_compute; reflexivity.
  all: have ? : min_int i32 = -2147483648 by vm_compute; reflexivity.
  all: lia.
  Unshelve. all: print_remaining_sidecond.
Qed.
End proof.
