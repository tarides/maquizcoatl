type format = Dune_rocq | Lake | Fstar | Rustc | Isabelle | Failed_steps

let lines s = String.split_on_char '\n' s

(* [between ~prefix ~stop s] is the text of [s] after [prefix] (which [s]
   starts with) and up to the first [stop] character. *)
let between ~prefix ~stop s =
  if String.starts_with ~prefix s then
    let rest =
      String.sub s (String.length prefix)
        (String.length s - String.length prefix)
    in
    match String.index_opt rest stop with
    | Some i when i > 0 -> Some (String.sub rest 0 i)
    | _ -> None
  else None

let rec strip_dot_slash p =
  if String.starts_with ~prefix:"./" p then
    strip_dot_slash (String.sub p 2 (String.length p - 2))
  else p

let dune_rocq log =
  let _, files =
    List.fold_left
      (fun (current, files) line ->
        match between ~prefix:"File \"" ~stop:'"' line with
        | Some file -> (Some (strip_dot_slash file), files)
        | None when String.starts_with ~prefix:"Warning" line -> (None, files)
        | None -> (
            match current with
            | Some file when String.starts_with ~prefix:"Error" line ->
                (None, file :: files)
            | _ -> (current, files)))
      (None, []) (lines log)
  in
  files

let lake log =
  List.filter_map
    (fun line ->
      if String.starts_with ~prefix:"error: " line then
        match
          String.split_on_char ':' (String.sub line 7 (String.length line - 7))
        with
        | file :: l :: c :: _
          when Filename.check_suffix file ".lean"
               && Text.is_digits l && Text.is_digits c ->
            Some (strip_dot_slash file)
        | _ -> None
      else None)
    (lines log)

(* "* Error 19 at A.fst(12,3-14,5):" or "A.fst(12,3-14,5): (Error 19) ...". *)
let fstar log =
  let location s =
    match String.index_opt s '(' with
    | Some i when i > 0 -> Some (String.sub s 0 i)
    | _ -> None
  in
  List.filter_map
    (fun line ->
      let line = String.trim line in
      if String.starts_with ~prefix:"* Error " line then
        match String.split_on_char ' ' line with
        | "*" :: "Error" :: _ :: "at" :: loc :: _ -> location loc
        | _ -> None
      else
        match String.split_on_char ' ' line with
        | loc :: "(Error" :: _ when String.ends_with ~suffix:"):" loc ->
            location loc
        | _ -> None)
    (lines log)

(* rustc and Verus: an [error] line, then the first [--> p:l:c] line before
   the next [warning] or [error]: the primary location. Secondary locations
   ([::: p:l:c]) and notes are not counted. *)
let rustc log =
  let location line =
    let line = String.trim line in
    if String.starts_with ~prefix:"--> " line then
      let loc = String.trim (String.sub line 4 (String.length line - 4)) in
      match List.rev (String.split_on_char ':' loc) with
      | c :: l :: (_ :: _ as file) when Text.is_digits l && Text.is_digits c ->
          Some (String.concat ":" (List.rev file))
      | _ -> None
    else None
  in
  let _, files =
    List.fold_left
      (fun (in_error, files) line ->
        if String.starts_with ~prefix:"error" line then (true, files)
        else if String.starts_with ~prefix:"warning" line then (false, files)
        else
          match (in_error, location line) with
          | true, Some file -> (false, strip_dot_slash file :: files)
          | _ -> (in_error, files))
      (false, []) (lines log)
  in
  files

(* Isabelle: [*** ... (line n of "p")] lines, as [isabelle build] prints the
   errors of a failed session. *)
let isabelle log =
  let marker = "(line " in
  List.filter_map
    (fun line ->
      let line = String.trim line in
      if String.starts_with ~prefix:"***" line then
        let rec find i =
          if i + String.length marker > String.length line then None
          else if String.sub line i (String.length marker) = marker then
            let rest = String.sub line i (String.length line - i) in
            match String.index_opt rest '"' with
            | Some j -> (
                let after =
                  String.sub rest (j + 1) (String.length rest - j - 1)
                in
                match String.index_opt after '"' with
                | Some k when k > 0 -> Some (String.sub after 0 k)
                | _ -> None)
            | None -> None
          else find (i + 1)
        in
        find 0
      else None)
    (lines log)

let files format log =
  let found =
    match format with
    | Dune_rocq -> dune_rocq log
    | Lake -> lake log
    | Fstar -> fstar log
    | Rustc -> rustc log
    | Isabelle -> isabelle log
    | Failed_steps -> []
  in
  List.sort_uniq String.compare found
