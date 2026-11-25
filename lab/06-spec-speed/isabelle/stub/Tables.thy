(* Experiment #6 milestone 2, Isabelle/HOL: stub of the table theory,
   with the interface of the generated Tables.thy (cases/gen2.py).
   T_spec checks, exports and compiles Spec2.thy against it, so that it
   measures the semantics alone (the table theory is excluded, as for
   the other rows). *)
theory Tables
  imports Main "HOL-Library.Code_Target_Numeral"
begin

definition fold_of :: "nat \<Rightarrow> nat list" where "fold_of c = [c]"

definition in_prop :: "nat \<Rightarrow> nat \<Rightarrow> bool" where "in_prop p c = False"

end
