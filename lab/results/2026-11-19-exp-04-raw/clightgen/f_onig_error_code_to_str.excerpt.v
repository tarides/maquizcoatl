156:Definition f_onig_error_code_to_str := {|
157-  fn_return := tint;
158-  fn_callconv := {|cc_vararg:=(Some 2); cc_unproto:=false; cc_structret:=false|};
159-  fn_params := ((_s, (tptr tuchar)) :: (_code, tint) :: nil);
160-  fn_vars := ((_ap, (tarray tulong 3)) :: nil);
161-  fn_temps := ((_einfo, (tptr (Tstruct __512 noattr))) :: (_t'3, tint) ::
162-               (_t'2, (tptr tschar)) :: (_t'1, tulong) :: nil);
163-  fn_body :=
164-(Ssequence
165-  (Sset _einfo
166-    (Ecast (Econst_int (Int.repr 0) tint) (tptr (Tstruct __512 noattr))))
167-  (Ssequence
168-    (Scall None
169-      (Evar ___builtin_va_start (Tfunction ((tptr tvoid) :: nil) tvoid
170-                                  cc_default))
