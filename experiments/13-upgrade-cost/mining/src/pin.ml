type format =
  | Whole_file
  | Make_var of string
  | Yaml_list of string
  | Yaml_scalar of string
  | Opam_dep of string
  | Toml_string of string

type resolve = Release | Commit of string | Opaque

type t = {
  files : string list;
  format : format;
  strip : string list;
  resolve : resolve;
}

let unquote s =
  let s = String.trim s in
  let n = String.length s in
  if
    n >= 2
    && ((s.[0] = '"' && s.[n - 1] = '"') || (s.[0] = '\'' && s.[n - 1] = '\''))
  then String.sub s 1 (n - 2)
  else s

(* Drops a trailing comment from a value: a [#] that follows a blank and lies
   outside quotes. *)
let uncomment s =
  let n = String.length s in
  let rec go i quote =
    if i >= n then s
    else
      match (s.[i], quote) with
      | ('"' | '\''), None -> go (i + 1) (Some s.[i])
      | c, Some q when c = q -> go (i + 1) None
      | '#', None when i > 0 && (s.[i - 1] = ' ' || s.[i - 1] = '\t') ->
          String.trim (String.sub s 0 i)
      | _ -> go (i + 1) quote
  in
  go 0 None

let lines contents = Util.lines contents |> List.map String.trim
let is_comment l = String.starts_with ~prefix:"#" l

(* [key_value ~seps key line] is the text after [key], optional blanks and
   one of the separators [seps], if [line] has that shape. *)
let key_value ~seps key line =
  if not (String.starts_with ~prefix:key line) then None
  else
    let rest = String.trim (Util.after ~prefix:key line) in
    List.find_map
      (fun sep ->
        if String.starts_with ~prefix:sep rest then
          Some (String.trim (Util.after ~prefix:sep rest))
        else None)
      seps

let make_var name contents =
  lines contents
  |> List.filter (fun l -> not (is_comment l))
  |> List.filter_map (fun l ->
      let l =
        if String.starts_with ~prefix:"export " l then
          String.trim (Util.after ~prefix:"export " l)
        else l
      in
      key_value ~seps:[ ":="; "?="; "=" ] name l |> Option.map uncomment)

let yaml_list key contents =
  let rec go acc = function
    | [] -> List.rev acc
    | l :: rest when is_comment l -> go acc rest
    | l :: rest -> (
        match key_value ~seps:[ ":" ] key l with
        | Some v when v <> "" ->
            let v = uncomment v in
            let n = String.length v in
            if n >= 2 && v.[0] = '[' && v.[n - 1] = ']' then
              let items =
                String.sub v 1 (n - 2)
                |> String.split_on_char ',' |> List.map unquote
                |> List.filter (( <> ) "")
              in
              go (List.rev_append items acc) rest
            else go acc rest
        | Some _ ->
            let rec items acc = function
              | l :: rest when is_comment l -> items acc rest
              | l :: rest when String.starts_with ~prefix:"- " l ->
                  items
                    (unquote (uncomment (Util.after ~prefix:"- " l)) :: acc)
                    rest
              | rest -> (acc, rest)
            in
            let acc, rest = items acc rest in
            go acc rest
        | None -> go acc rest)
  in
  go [] (lines contents)

let yaml_scalar key contents =
  lines contents
  |> List.filter (fun l -> not (is_comment l))
  |> List.filter_map (fun l ->
      match key_value ~seps:[ ":" ] key l with
      | Some v when v <> "" && v.[0] <> '[' -> Some (unquote (uncomment v))
      | _ -> None)

(* The opam file format, as far as the [depends] field needs it. *)
module Opam = struct
  type token =
    | Str of string
    | Lbrack
    | Rbrack
    | Lbrace
    | Rbrace
    | Word of string

  let tokens s =
    let n = String.length s in
    let is_space = function ' ' | '\t' | '\n' | '\r' -> true | _ -> false in
    let rec skip_to_eol i =
      if i < n && s.[i] <> '\n' then skip_to_eol (i + 1) else i
    in
    let rec skip_block i =
      if i + 1 >= n then failwith "opam: unterminated comment"
      else if s.[i] = '*' && s.[i + 1] = ')' then i + 2
      else skip_block (i + 1)
    in
    let string_end i =
      let b = Buffer.create 16 in
      let rec go i =
        if i >= n then failwith "opam: unterminated string"
        else
          match s.[i] with
          | '"' -> (Buffer.contents b, i + 1)
          | '\\' when i + 1 < n ->
              Buffer.add_char b s.[i + 1];
              go (i + 2)
          | c ->
              Buffer.add_char b c;
              go (i + 1)
      in
      go i
    in
    let rec word_end i =
      if
        i < n && (not (is_space s.[i])) && not (String.contains "\"[]{}#" s.[i])
      then word_end (i + 1)
      else i
    in
    let rec go acc i =
      if i >= n then List.rev acc
      else
        match s.[i] with
        | c when is_space c -> go acc (i + 1)
        | '#' -> go acc (skip_to_eol i)
        | '(' when i + 1 < n && s.[i + 1] = '*' -> go acc (skip_block (i + 2))
        | '"' ->
            let str, j = string_end (i + 1) in
            go (Str str :: acc) j
        | '[' -> go (Lbrack :: acc) (i + 1)
        | ']' -> go (Rbrack :: acc) (i + 1)
        | '{' -> go (Lbrace :: acc) (i + 1)
        | '}' -> go (Rbrace :: acc) (i + 1)
        | _ ->
            let j = word_end i in
            go (Word (String.sub s i (j - i)) :: acc) j
    in
    go [] 0

  (* The tokens of a constraint, up to its closing brace, and the rest. *)
  let constraint_ tokens =
    let rec go acc = function
      | Rbrace :: rest -> (String.concat " " (List.rev acc), rest)
      | (Str w | Word w) :: rest -> go (w :: acc) rest
      | (Lbrack | Rbrack | Lbrace) :: _ | [] ->
          failwith "opam: unterminated package constraint"
    in
    go [] tokens

  (* The constraints of [pkg] in the list that starts after [depends: \[]. *)
  let in_depends pkg tokens =
    let rec go acc = function
      | Rbrack :: rest -> (List.rev acc, rest)
      | Str p :: Lbrace :: rest ->
          let c, rest = constraint_ rest in
          go (if p = pkg then c :: acc else acc) rest
      | Str p :: rest -> go (if p = pkg then "" :: acc else acc) rest
      | Lbrace :: rest -> go acc (snd (constraint_ rest))
      | (Word _ | Lbrack | Rbrace) :: rest -> go acc rest
      | [] -> failwith "opam: unterminated depends field"
    in
    go [] tokens

  let depends pkg contents =
    let rec go acc = function
      | Word "depends:" :: Lbrack :: rest
      | Word "depends" :: Word ":" :: Lbrack :: rest ->
          let found, rest = in_depends pkg rest in
          go (List.rev_append found acc) rest
      | _ :: rest -> go acc rest
      | [] -> List.rev acc
    in
    go [] (tokens contents)
end

let toml_string key contents =
  lines contents
  |> List.filter (fun l -> not (is_comment l))
  |> List.filter_map (fun l ->
      match key_value ~seps:[ "=" ] key l with
      | Some v when v <> "" -> Some (unquote (uncomment v))
      | _ -> None)

let read format contents =
  match format with
  | Whole_file -> ( match String.trim contents with "" -> [] | v -> [ v ])
  | Make_var name -> make_var name contents
  | Yaml_list key -> yaml_list key contents
  | Yaml_scalar key -> yaml_scalar key contents
  | Opam_dep pkg -> Opam.depends pkg contents
  | Toml_string key -> toml_string key contents

let matches_file pin path = List.exists (fun p -> Glob.matches p path) pin.files

let strip_all prefixes v =
  List.fold_left
    (fun v prefix ->
      if String.starts_with ~prefix v then Util.after ~prefix v else v)
    v prefixes

let file_values pin files =
  List.filter_map
    (fun (path, contents) ->
      if matches_file pin path then
        let values =
          match read pin.format contents with
          | values -> values
          | exception Failure msg -> failwith (path ^ ": " ^ msg)
        in
        Some
          (path, List.map (strip_all pin.strip) values |> List.sort_uniq compare)
      else None)
    files
  |> List.sort (fun (a, _) (b, _) -> compare a b)

let union file_values =
  List.concat_map snd file_values |> List.sort_uniq compare

let values pin files = union (file_values pin files)
