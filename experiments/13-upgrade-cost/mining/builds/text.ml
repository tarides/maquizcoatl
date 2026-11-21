let is_digits s =
  s <> "" && String.for_all (function '0' .. '9' -> true | _ -> false) s
