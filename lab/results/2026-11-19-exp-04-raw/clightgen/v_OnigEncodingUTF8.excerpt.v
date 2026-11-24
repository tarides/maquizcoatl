3576:Definition v_OnigEncodingUTF8 := {|
3577-  gvar_info := (Tstruct _OnigEncodingTypeST noattr);
3578-  gvar_init := (Init_addrof _s_mbc_enc_len (Ptrofs.repr 0) ::
3579-                Init_addrof ___stringlit_30 (Ptrofs.repr 0) ::
3580-                Init_int32 (Int.repr 1) :: Init_int32 (Int.repr 1) ::
3581-                Init_addrof _s_is_mbc_newline (Ptrofs.repr 0) ::
3582-                Init_addrof _s_mbc_to_code (Ptrofs.repr 0) ::
3583-                Init_addrof _s_code_to_mbclen (Ptrofs.repr 0) ::
3584-                Init_addrof _s_code_to_mbc (Ptrofs.repr 0) ::
3585-                Init_addrof _s_mbc_case_fold (Ptrofs.repr 0) ::
3586-                Init_addrof _s_apply_all_case_fold (Ptrofs.repr 0) ::
3587-                Init_addrof _s_get_case_fold_codes_by_str (Ptrofs.repr 0) ::
3588-                Init_addrof _s_property_name_to_ctype (Ptrofs.repr 0) ::
3589-                Init_addrof _s_is_code_ctype (Ptrofs.repr 0) ::
3590-                Init_addrof _s_get_ctype_code_range (Ptrofs.repr 0) ::
