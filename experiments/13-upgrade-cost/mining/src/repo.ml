type commit = {
  hash : string;
  parents : string list;
  date : string;
  subject : string;
  body : string;
}

type t = {
  first_parent_log :
    head:string ->
    since:string ->
    until:string ->
    paths:string list ->
    commit list;
  files : string -> string list;
  show : string -> string -> string;
  numstat : string -> string -> Numstat.entry list;
  tags_containing : string -> string list option;
  authors : since:string -> until:string -> string -> string list;
}

exception Git_error of string

(* Settings that the user's configuration must not change: paths printed
   unquoted, no signature lines in [git log] output. *)
let config = [ "-c"; "core.quotePath=false"; "-c"; "log.showSignature=false" ]

(* Runs [git -C dir args], with [env] added to the environment; returns its
   exit status, its output, and a function giving its error message. Standard
   error goes to a temporary file, read back on failure. *)
let run ?(env = []) dir args =
  let command = Printf.sprintf "git %s" (String.concat " " args) in
  let err = Filename.temp_file "upgrade-mining" ".err" in
  Fun.protect
    ~finally:(fun () -> Sys.remove err)
    (fun () ->
      try
        let argv = Array.of_list (("git" :: "-C" :: dir :: config) @ args) in
        let env = Array.append (Unix.environment ()) (Array.of_list env) in
        let out_r, out_w = Unix.pipe ~cloexec:true () in
        let err_fd =
          Unix.openfile err
            [ Unix.O_WRONLY; Unix.O_TRUNC; Unix.O_CLOEXEC ]
            0o600
        in
        let pid =
          Fun.protect
            ~finally:(fun () ->
              Unix.close out_w;
              Unix.close err_fd)
            (fun () ->
              Unix.create_process_env "git" argv env Unix.stdin out_w err_fd)
        in
        let output =
          Fun.protect
            ~finally:(fun () -> Unix.close out_r)
            (fun () -> In_channel.input_all (Unix.in_channel_of_descr out_r))
        in
        let _, status = Unix.waitpid [] pid in
        let code = match status with Unix.WEXITED c -> c | _ -> 255 in
        let error () =
          Printf.sprintf "%s (in %s): %s" command dir
            (String.trim (In_channel.with_open_bin err In_channel.input_all))
        in
        (code, output, error)
      with Unix.Unix_error (e, f, _) ->
        raise
          (Git_error
             (Printf.sprintf "%s (in %s): %s: %s" command dir f
                (Unix.error_message e))))

let run_ok ?env dir args =
  match run ?env dir args with
  | 0, output, _ -> output
  | _, _, error -> raise (Git_error (error ()))

let nul_separated s = String.split_on_char '\000' s |> List.filter (( <> ) "")

(* Commits of the tool's clone are looked up without fetching missing objects
   from the remote: a missing commit is a datum, not an error. *)
let no_lazy_fetch = [ "GIT_NO_LAZY_FETCH=1" ]

(* Record and field separators for [git log] output. *)
let rs = '\x1e'
let fs = '\x1f'

let parse_log output =
  String.split_on_char rs output
  |> List.filter_map (fun record ->
      let record = String.trim record in
      if record = "" then None
      else
        match String.split_on_char fs record with
        | [ hash; parents; date; subject; body ] when Release.is_date date ->
            Some
              {
                hash;
                parents =
                  String.split_on_char ' ' parents |> List.filter (( <> ) "");
                date;
                subject;
                body = String.trim body;
              }
        | _ -> raise (Git_error ("unexpected git log record: " ^ record)))

let log_format = "--format=%H%x1f%P%x1f%cs%x1f%s%x1f%b%x1e"
let in_window ~since ~until date = since <= date && date <= until

(* The whole first-parent line is read and filtered here: git's [--since]
   reads dates in the local time zone and stops at the first older commit. *)
let first_parent_log dir ~head ~since ~until ~paths =
  let pathspecs = List.map (fun p -> ":(glob)" ^ p) paths in
  run_ok dir
    ([ "log"; "--first-parent"; "--reverse"; log_format; head ]
    @ if pathspecs = [] then [] else "--" :: pathspecs)
  |> parse_log
  |> List.filter (fun c -> in_window ~since ~until c.date)

let files dir c =
  run_ok dir [ "ls-tree"; "-r"; "-z"; "--name-only"; c ] |> nul_separated

let show dir c path = run_ok dir [ "cat-file"; "blob"; c ^ ":" ^ path ]

let numstat dir a b =
  run_ok dir [ "diff"; "--numstat"; "-z"; "--no-renames"; a; b ]
  |> Numstat.parse

let tags_containing dir c =
  match
    run ~env:no_lazy_fetch dir
      [ "rev-parse"; "--verify"; "--quiet"; c ^ "^{commit}" ]
  with
  | 0, hash, _ ->
      Some
        (run_ok ~env:no_lazy_fetch dir [ "tag"; "--contains"; String.trim hash ]
        |> Util.lines |> List.map String.trim)
  | 1, _, _ -> None
  | _, _, error -> raise (Git_error (error ()))

let authors dir ~since ~until path =
  run_ok dir [ "log"; "--format=%cs%x1f%an"; "--"; path ]
  |> Util.lines
  |> List.filter_map (fun l ->
      match String.split_on_char fs l with
      | [ date; name ] when in_window ~since ~until date -> Some name
      | [ date; _ ] when Release.is_date date -> None
      | _ -> raise (Git_error ("unexpected git log line: " ^ l)))
  |> List.sort_uniq compare

let git dir =
  {
    first_parent_log = first_parent_log dir;
    files = files dir;
    show = show dir;
    numstat = numstat dir;
    tags_containing = tags_containing dir;
    authors = authors dir;
  }
