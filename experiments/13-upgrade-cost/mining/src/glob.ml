let matches pattern path =
  let n = String.length pattern and m = String.length path in
  let rec go i j =
    if i = n then j = m
    else
      match pattern.[i] with
      | '*' when i + 1 < n && pattern.[i + 1] = '*' ->
          if i + 2 < n && pattern.[i + 2] = '/' then
            (* "**/": zero or more whole directories. *)
            let rec from k =
              go (i + 3) k
              ||
              match String.index_from_opt path k '/' with
              | Some s -> from (s + 1)
              | None -> false
            in
            from j
          else
            let rec from k = go (i + 2) k || (k < m && from (k + 1)) in
            from j
      | '*' ->
          let rec from k =
            go (i + 1) k || (k < m && path.[k] <> '/' && from (k + 1))
          in
          from j
      | '?' -> j < m && path.[j] <> '/' && go (i + 1) (j + 1)
      | c -> j < m && path.[j] = c && go (i + 1) (j + 1)
  in
  go 0 0

let under dir path =
  let d = String.length dir in
  path = dir
  || (String.length path > d && String.sub path 0 d = dir && path.[d] = '/')
