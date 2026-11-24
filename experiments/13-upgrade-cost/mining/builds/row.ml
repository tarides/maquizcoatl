type t = {
  project : string;
  side : string;
  variant : string;
  phase : string;
  toolchain : string;
  limits : Limits.t;
  host : Host.t;
  load_before : float option;
  load_after : float option;
  start : float;
  results : Exec.step_result list;
  failing_files : string list;
  log_dir : string;
}

let outcome results =
  let failed =
    List.filter (fun (r : Exec.step_result) -> Exec.failed r.outcome) results
  in
  let any p = List.exists (fun (r : Exec.step_result) -> p r.outcome) failed in
  if failed = [] then "ok"
  else if any (function Exec.Interrupted _ -> true | _ -> false) then
    "interrupted"
  else if any (function Exec.Timed_out -> true | _ -> false) then "timeout"
  else if any (function Exec.Driver_error _ -> true | _ -> false) then "error"
  else "failed"

let header =
  [
    "project";
    "side";
    "variant";
    "phase";
    "toolchain";
    "outcome";
    "steps";
    "failed_steps";
    "first_failure";
    "failing_files";
    "failing_list";
    "wall_s";
    "user_s";
    "sys_s";
    "jobs";
    "cpus";
    "nice";
    "timeout_s";
    "host";
    "cpu_model";
    "processors";
    "load_before";
    "load_after";
    "start";
    "log_dir";
  ]

let seconds x = Printf.sprintf "%.1f" x
let opt f = function Some x -> f x | None -> ""
let sum f rs = List.fold_left (fun acc r -> acc +. f r) 0. rs

let fields r =
  let failed =
    List.filter (fun (s : Exec.step_result) -> Exec.failed s.outcome) r.results
  in
  [
    r.project;
    r.side;
    r.variant;
    r.phase;
    r.toolchain;
    outcome r.results;
    string_of_int (List.length r.results);
    string_of_int (List.length failed);
    (match failed with s :: _ -> s.label | [] -> "");
    string_of_int (List.length r.failing_files);
    String.concat ";" r.failing_files;
    seconds (sum (fun (s : Exec.step_result) -> s.wall) r.results);
    seconds (sum (fun (s : Exec.step_result) -> s.user) r.results);
    seconds (sum (fun (s : Exec.step_result) -> s.sys) r.results);
    string_of_int r.limits.jobs;
    Cpuset.to_string r.limits.cpus;
    string_of_int r.limits.nice;
    string_of_int r.limits.timeout;
    r.host.hostname;
    opt Fun.id r.host.cpu_model;
    opt string_of_int r.host.processors;
    opt (Printf.sprintf "%.2f") r.load_before;
    opt (Printf.sprintf "%.2f") r.load_after;
    Exec.timestamp r.start;
    r.log_dir;
  ]

let step_header =
  [
    "index";
    "label";
    "outcome";
    "start";
    "wall_s";
    "user_s";
    "sys_s";
    "log";
    "command";
  ]

let step_fields (s : Exec.step_result) =
  [
    string_of_int s.index;
    s.label;
    Exec.outcome_to_string s.outcome;
    Exec.timestamp s.start;
    seconds s.wall;
    seconds s.user;
    seconds s.sys;
    opt Fun.id s.log;
    s.command;
  ]

let line fields =
  String.concat "," (List.map Upgrade_mining.Report.csv_field fields) ^ "\n"

let csv header lines = String.concat "" (List.map line (header :: lines))

(* Whether [file] needs [header] first: [Ok true] if it is missing or empty,
   [Ok false] if it starts with [header]. *)
let needs_header ~file ~header =
  let dir = Filename.dirname file in
  match
    Sys.is_directory dir
    &&
    (Unix.access dir [ Unix.W_OK; Unix.X_OK ];
     true)
  with
  | exception (Sys_error msg | Unix.Unix_error (_, _, msg)) ->
      Error (dir ^ ": " ^ msg)
  | false -> Error (dir ^ " is not a directory")
  | true -> (
      match
        if Sys.file_exists file then
          In_channel.with_open_bin file In_channel.input_line
        else None
      with
      | exception Sys_error msg -> Error msg
      | None | Some "" -> Ok true
      | Some first when first ^ "\n" = line header -> Ok false
      | Some _ -> Error (file ^ ": its header is not the build table's"))

let check ~file ~header = Result.map ignore (needs_header ~file ~header)

let append ~file ~header fields =
  match needs_header ~file ~header with
  | Error _ as e -> e
  | Ok first -> (
      try
        Out_channel.with_open_gen
          [ Open_wronly; Open_creat; Open_append; Open_binary ] 0o644 file
          (fun oc ->
            Out_channel.output_string oc
              ((if first then line header else "") ^ line fields));
        Ok ()
      with Sys_error msg -> Error msg)
