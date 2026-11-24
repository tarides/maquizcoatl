let loadavg contents =
  match String.split_on_char ' ' (String.trim contents) with
  | first :: _ -> float_of_string_opt first
  | [] -> None

(* The value of a "key\t: value" line of /proc/cpuinfo whose key is [key]. *)
let field key line =
  match String.index_opt line ':' with
  | Some i when String.trim (String.sub line 0 i) = key ->
      Some (String.trim (String.sub line (i + 1) (String.length line - i - 1)))
  | _ -> None

let cpu_model contents =
  String.split_on_char '\n' contents |> List.find_map (field "model name")

let processors contents =
  String.split_on_char '\n' contents
  |> List.filter (fun l -> Option.is_some (field "processor" l))
  |> List.length

type t = {
  hostname : string;
  cpu_model : string option;
  processors : int option;
}

let read file =
  try Some (In_channel.with_open_bin file In_channel.input_all)
  with Sys_error msg ->
    Printf.eprintf "upgrade_builds: warning: %s\n%!" msg;
    None

let current () =
  let cpuinfo = read "/proc/cpuinfo" in
  {
    hostname = Unix.gethostname ();
    cpu_model = Option.bind cpuinfo cpu_model;
    processors = Option.map processors cpuinfo;
  }

let load () = Option.bind (read "/proc/loadavg") loadavg
