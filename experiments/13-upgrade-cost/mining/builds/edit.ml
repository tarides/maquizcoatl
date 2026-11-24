type t =
  | Write of { file : string; contents : string }
  | Replace of { file : string; old : string; by : string }

let file = function Write { file; _ } | Replace { file; _ } -> file

(* Positions of the non-overlapping occurrences of [sub] in [s]. *)
let occurrences ~sub s =
  let n = String.length sub and len = String.length s in
  let rec go i acc =
    if i + n > len then List.rev acc
    else if String.sub s i n = sub then go (i + n) (i :: acc)
    else go (i + 1) acc
  in
  if n = 0 then [] else go 0 []

let contains ~sub s = occurrences ~sub s <> []

let apply_string e s =
  match e with
  | Write { contents; _ } -> Ok contents
  | Replace { file; old; by } -> (
      if old = "" || contains ~sub:old by || contains ~sub:by old then
        Error (Printf.sprintf "%s: %S and %S overlap" file old by)
      else
        match (occurrences ~sub:old s, occurrences ~sub:by s) with
        | [ i ], _ ->
            Ok
              (String.sub s 0 i ^ by
              ^ String.sub s
                  (i + String.length old)
                  (String.length s - i - String.length old))
        | [], [ _ ] -> Ok s
        | found, _ ->
            Error
              (Printf.sprintf "%s: expected one occurrence of %S, found %d" file
                 old (List.length found)))

let apply ~dir e =
  let path = Filename.concat dir (file e) in
  try
    let current =
      match e with
      | Write _ -> ""
      | Replace _ -> In_channel.with_open_bin path In_channel.input_all
    in
    match apply_string e current with
    | Ok contents ->
        Out_channel.with_open_bin path (fun oc ->
            Out_channel.output_string oc contents);
        Ok ()
    | Error _ as error -> error
  with Sys_error msg -> Error msg

let describe = function
  | Write { file; contents } ->
      Printf.sprintf "write %s (%d bytes)" file (String.length contents)
  | Replace { file; old; by } -> Printf.sprintf "in %s, %S -> %S" file old by
