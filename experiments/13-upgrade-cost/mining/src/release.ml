type t = { version : string; date : string; prerelease : bool }

let is_date s =
  let digit i = match s.[i] with '0' .. '9' -> true | _ -> false in
  String.length s = 10
  && List.for_all digit [ 0; 1; 2; 3; 5; 6; 8; 9 ]
  && s.[4] = '-'
  && s.[7] = '-'

let parse_line line =
  match String.split_on_char '\t' line with
  | version :: date :: pre :: _ when version <> "" && is_date date -> (
      match pre with
      | "true" -> { version; date; prerelease = true }
      | "false" -> { version; date; prerelease = false }
      | _ -> failwith (Printf.sprintf "releases: bad prerelease flag %S" pre))
  | _ -> failwith (Printf.sprintf "releases: bad line %S" line)

let parse_tsv contents =
  match Util.lines contents with
  | header :: lines -> (
      match String.split_on_char '\t' header with
      | "version" :: "date" :: "prerelease" :: _ -> List.map parse_line lines
      | _ -> failwith (Printf.sprintf "releases: bad header %S" header))
  | [] -> failwith "releases: empty file"

let load file = parse_tsv (In_channel.with_open_bin file In_channel.input_all)
