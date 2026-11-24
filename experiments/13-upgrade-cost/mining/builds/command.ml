type files = { dir : string; suffix : string; depth : int option }
type arg = Lit of string | Files of files
type env = Set of string * string | Unset of string | Prepend_path of string
type t = { prog : string; args : arg list; cwd : string; env : env list }

let lits = List.map (fun a -> Lit a)
let v ?(env = []) ~cwd prog args = { prog; args = lits args; cwd; env }

let prefixed prefix t =
  match prefix with
  | [] -> t
  | prog :: args -> { t with prog; args = lits (args @ [ t.prog ]) @ t.args }

let describe_files { dir; suffix; depth } =
  Printf.sprintf "<files *%s under %s%s>" suffix dir
    (match depth with None -> "" | Some d -> Printf.sprintf ", at depth %d" d)

let find_files ~cwd ({ dir; suffix; depth } as f) =
  let rec walk rel level acc =
    let entries = Sys.readdir (Filename.concat cwd rel) in
    Array.sort String.compare entries;
    Array.fold_left
      (fun acc name ->
        let rel = rel ^ "/" ^ name in
        match (Unix.lstat (Filename.concat cwd rel)).st_kind with
        | Unix.S_DIR -> (
            match depth with
            | Some d when level >= d -> acc
            | _ -> walk rel (level + 1) acc)
        | (Unix.S_REG | Unix.S_LNK)
          when String.ends_with ~suffix name
               && match depth with None -> true | Some d -> level = d ->
            rel :: acc
        | _ -> acc)
      acc entries
  in
  match walk dir 1 [] with
  | [] -> Error ("no file matches " ^ describe_files f)
  | files -> Ok (List.sort String.compare files)
  | exception (Sys_error msg | Unix.Unix_error (_, _, msg)) ->
      Error (describe_files f ^ ": " ^ msg)

let argv t =
  let rec expand acc = function
    | [] -> Ok (t.prog :: List.rev acc)
    | Lit s :: rest -> expand (s :: acc) rest
    | Files f :: rest -> (
        match find_files ~cwd:t.cwd f with
        | Ok files -> expand (List.rev_append files acc) rest
        | Error _ as e -> e)
  in
  expand [] t.args

let split kv =
  match String.index_opt kv '=' with
  | Some i ->
      Some (String.sub kv 0 i, String.sub kv (i + 1) (String.length kv - i - 1))
  | None -> None

let environment changes base =
  let set name value vars =
    if List.mem_assoc name vars then
      List.map (fun (n, v) -> if n = name then (n, value) else (n, v)) vars
    else vars @ [ (name, value) ]
  in
  let apply vars = function
    | Set (name, value) -> set name value vars
    | Unset name -> List.filter (fun (n, _) -> n <> name) vars
    | Prepend_path dir ->
        set "PATH"
          (match List.assoc_opt "PATH" vars with
          | Some "" | None -> dir
          | Some path -> dir ^ ":" ^ path)
          vars
  in
  List.fold_left apply (Array.to_list base |> List.filter_map split) changes
  |> List.map (fun (n, v) -> n ^ "=" ^ v)
  |> Array.of_list

let path_of env =
  Array.to_list env |> List.filter_map split |> List.assoc_opt "PATH"
  |> Option.value ~default:""

let executable file =
  match Unix.stat file with
  | { st_kind = Unix.S_REG; _ } -> (
      try
        Unix.access file [ Unix.X_OK ];
        true
      with Unix.Unix_error _ -> false)
  | _ -> false
  | exception Unix.Unix_error _ -> false

let resolve ~path prog =
  if String.contains prog '/' then Some prog
  else
    String.split_on_char ':' path
    |> List.find_map (fun dir ->
        let file = Filename.concat (if dir = "" then "." else dir) prog in
        if executable file then
          Some
            (if Filename.is_relative file then
               Filename.concat (Sys.getcwd ()) file
             else file)
        else None)

let quote s =
  let plain = function
    | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' -> true
    | '_' | '.' | '/' | '=' | ':' | ',' | '+' | '@' | '%' | '-' -> true
    | _ -> false
  in
  if s <> "" && String.for_all plain s then s
  else "'" ^ String.concat "'\\''" (String.split_on_char '\'' s) ^ "'"

(* The final effect of [changes] on a variable, from an unknown inherited
   environment: removed, or a value, which for PATH may end with the
   inherited PATH. *)
type final = Removed | Value of { value : string; inherits_path : bool }

(* The final effects of [changes], by variable, in order of first change. *)
let finals changes =
  let update name f vars =
    if List.mem_assoc name vars then
      List.map (fun (n, e) -> if n = name then (n, f (Some e)) else (n, e)) vars
    else vars @ [ (name, f None) ]
  in
  List.fold_left
    (fun vars -> function
      | Set (name, value) ->
          update name (fun _ -> Value { value; inherits_path = false }) vars
      | Unset name -> update name (fun _ -> Removed) vars
      | Prepend_path dir ->
          update "PATH"
            (function
              | None -> Value { value = dir; inherits_path = true }
              | Some Removed
              | Some (Value { value = ""; inherits_path = false }) ->
                  Value { value = dir; inherits_path = false }
              | Some (Value { value; inherits_path }) ->
                  Value { value = dir ^ ":" ^ value; inherits_path })
            vars)
    [] changes

let to_string t =
  let finals = finals t.env in
  let unset =
    List.filter_map
      (function n, Removed -> Some (" && unset " ^ n) | _, Value _ -> None)
      finals
  in
  let assignments =
    List.filter_map
      (function
        | _, Removed -> None
        | n, Value { value; inherits_path } ->
            Some
              (quote (n ^ "=" ^ value)
              ^ if inherits_path then ":\"$PATH\"" else ""))
      finals
  in
  let args =
    List.map (function Lit s -> quote s | Files f -> describe_files f) t.args
  in
  "(cd " ^ quote t.cwd ^ String.concat "" unset ^ " && "
  ^ String.concat " " (assignments @ (quote t.prog :: args))
  ^ ")"
