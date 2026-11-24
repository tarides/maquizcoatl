type selection = Regtests | Reduced

let load_path d = [ "-L"; d ]

let dirs =
  [
    (".", []);
    ("micro-c", []);
    ("python", []);
    ("double_wp", load_path "double_wp");
    ("avl", load_path "avl");
    ("c_cursor", load_path "c_cursor");
    ("foveoos11-cm", []);
    ("vacid_0_binary_heaps", load_path "vacid_0_binary_heaps");
    ( "verifythis_2016_matrix_multiplication",
      load_path "verifythis_2016_matrix_multiplication" );
    ("WP_revisited", []);
    ("prover", load_path "prover" @ [ "--warn-off=unused_variable" ]);
    ("multiprecision", load_path "multiprecision");
    ("numeric", []);
    ("stdlib", []);
    ("tests-provers", []);
    ("check-builtin", []);
    ("bts", []);
    ("logic", []);
    ("bitvectors", load_path "bitvectors");
    ("mlcfg", []);
  ]

let parse_reduced contents =
  String.split_on_char '\n' contents
  |> List.filter_map (fun line ->
      match line with
      | "" -> None
      | _ when line.[0] = ' ' || line.[0] = '#' -> None
      | _ ->
          let stop =
            match (String.index_opt line ' ', String.index_opt line '#') with
            | Some a, Some b -> min a b
            | Some a, None | None, Some a -> a
            | None, None -> String.length line
          in
          Some (String.sub line 0 stop))

let ( / ) = Filename.concat
let relative d name = if d = "." then name else d ^ "/" ^ name

let regtests_sessions ~examples d =
  let dir = examples / d in
  if not (Sys.file_exists dir && Sys.is_directory dir) then []
  else
    Sys.readdir dir |> Array.to_list
    |> List.filter (fun name ->
        Sys.file_exists (dir / name / "why3session.xml"))
    |> List.sort String.compare

let reduced_sessions ~examples d =
  let list = examples / d / "reduced_regtests.list" in
  if Sys.file_exists list then
    parse_reduced (In_channel.with_open_bin list In_channel.input_all)
  else []

let valid_session name =
  name <> ""
  && name.[0] <> '-'
  && Filename.is_relative name
  && not (List.mem ".." (String.split_on_char '/' name))

let sessions ~examples selection =
  if not (Sys.file_exists examples && Sys.is_directory examples) then
    Error (examples ^ " is not a directory")
  else
    match
      List.concat_map
        (fun (d, options) ->
          let names =
            match selection with
            | Regtests -> regtests_sessions ~examples d
            | Reduced -> reduced_sessions ~examples d
          in
          List.map (fun name -> (relative d name, options)) names)
        dirs
    with
    | exception Sys_error msg -> Error msg
    | sessions -> (
        match
          List.find_opt (fun (name, _) -> not (valid_session name)) sessions
        with
        | Some (name, _) ->
            Error (Printf.sprintf "%S is not a valid session name" name)
        | None -> Ok sessions)
