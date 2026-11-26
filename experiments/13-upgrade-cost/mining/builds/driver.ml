type config = { layout : Layout.t; limits : Limits.t; dry_run : bool }
type phase = Prepare | Build

let phase_to_string = function Prepare -> "prepare" | Build -> "build"
let ( / ) = Filename.concat

let builds_file ?(table = "builds") ~out ~date () =
  out / Printf.sprintf "%s-exp-13-%s.csv" date table

let plan c steps =
  let prefix = Limits.prefix c.limits in
  let env =
    Printf.sprintf "# environment of every command: %s\n"
      (String.concat ", "
         (List.map
            (function
              | Command.Set (n, v) -> Command.quote (n ^ "=" ^ v)
              | Command.Unset n -> "unset " ^ n
              | Command.Prepend_path d ->
                  "PATH=" ^ Command.quote d ^ ":\"$PATH\"")
            (Layout.environment c.layout)))
  in
  env
  ^ String.concat ""
      (List.mapi
         (fun i s ->
           Printf.sprintf "%2d. %s\n" (i + 1) (Step.describe ~prefix s))
         steps)

(* A log directory name that sorts by time: [what-YYYYMMDDTHHMMSSZ]. *)
let new_log_dir c what =
  let stamp =
    String.to_seq (Exec.timestamp (Unix.gettimeofday ()))
    |> Seq.filter (fun ch -> ch <> '-' && ch <> ':')
    |> String.of_seq
  in
  let dir = Layout.logs c.layout / (what ^ "-" ^ stamp) in
  Exec.mkdir_p dir;
  Exec.mkdir_p (Layout.cache c.layout);
  dir

let warn msg = Printf.eprintf "upgrade_builds: warning: %s\n%!" msg

(* The per-step table. A failure to write it is reported, not fatal: the
   results still reach the row. *)
let write_steps dir results =
  let file = dir / "steps.csv" in
  try
    Out_channel.with_open_bin file (fun oc ->
        Out_channel.output_string oc
          (Row.csv Row.step_header (List.map Row.step_fields results)))
  with Sys_error msg -> warn (file ^ ": " ^ msg)

let execute c ~log_dir steps =
  Exec.run ~limits:c.limits ~env:(Layout.environment c.layout) ~log_dir steps

let probe c ~log_dir commands =
  Exec.probe ~limits:c.limits
    ~env:(Layout.environment c.layout)
    ~file:(log_dir / "versions.txt") commands

(* Checks that [taskset] accepts the CPU set on this host, so that a wrong
   [--cpus] is a driver error before anything runs, not a failed step. *)
let check_cpus c =
  Result.map_error
    (fun msg -> "the CPU set cannot be used on this host: " ^ msg)
    (Result.map ignore
       (Exec.capture ~limits:c.limits ~env:[] (Command.v ~cwd:"/" "true" [])))

let interrupted_error what dir =
  Error (Printf.sprintf "%s interrupted, see %s" what dir)

let install_one c t =
  match Toolchain.install c.layout c.limits t with
  | Error _ as e -> e
  | Ok steps when c.dry_run ->
      Printf.printf "# install %s\n%s\n" (Toolchain.name t) (plan c steps);
      Ok ()
  | Ok steps ->
      let dir = new_log_dir c ("install-" ^ Toolchain.name t) in
      Printf.printf "install %s, logs in %s\n%!" (Toolchain.name t) dir;
      let results = execute c ~log_dir:dir steps in
      write_steps dir results;
      probe c ~log_dir:dir
        (Toolchain.probes c.layout t ~cwd:(Toolchain.home c.layout t));
      if Exec.interrupted () then
        interrupted_error ("install of " ^ Toolchain.name t) dir
      else if Row.outcome results = "ok" then Ok ()
      else
        Error
          (Printf.sprintf "install of %s failed, see %s" (Toolchain.name t) dir)

let install c ts =
  let open Result.Syntax in
  let* () = if c.dry_run then Ok () else check_cpus c in
  Exec.with_interrupts (fun () ->
      List.fold_left
        (fun acc t ->
          match acc with Ok () -> install_one c t | Error _ -> acc)
        (Ok ()) ts)

let failing_files target results =
  let failed =
    List.filter (fun (r : Exec.step_result) -> Exec.failed r.outcome) results
  in
  match Target.failure_format target with
  | Failures.Failed_steps ->
      List.map (fun (r : Exec.step_result) -> r.label) failed
  | format ->
      List.concat_map
        (fun (r : Exec.step_result) ->
          match r.log with
          | Some log -> (
              match In_channel.with_open_bin log In_channel.input_all with
              | contents -> Failures.files format contents
              | exception Sys_error msg ->
                  warn msg;
                  [])
          | None -> [])
        failed
      |> List.sort_uniq String.compare

(* Checks, before a measured build, that the shared switch pins what the
   checkout needs. *)
let check_pins c target side v =
  match Target.pin_list c.layout target side with
  | None -> Ok ()
  | Some command ->
      Result.bind
        (Exec.capture ~limits:c.limits
           ~env:(Layout.environment c.layout)
           command)
        (fun output ->
          Result.map_error
            (fun msg -> msg ^ ": prepare this side again")
            (Target.check_pins target v output))

let run ?table c phase ~out ~date target side ~variant =
  let open Result.Syntax in
  let* v = Target.variant target variant in
  let variant_name = Option.fold ~none:"" ~some:Target.variant_name v in
  let checkout = Target.dir c.layout target side v in
  let what =
    String.concat "-"
      (List.filter (( <> ) "")
         [
           Target.name target;
           Target.side_to_string side;
           variant_name;
           phase_to_string phase;
         ])
  in
  let* steps =
    match phase with
    | Prepare -> Ok (Target.prepare c.layout c.limits target side v)
    | Build -> Target.measured c.layout c.limits target side v
  in
  let file = builds_file ?table ~out ~date () in
  if c.dry_run then (
    Printf.printf "# %s (toolchain %s)\n%s" what
      (Toolchain.name (Target.toolchain target side))
      (plan c steps);
    Ok true)
  else
    let* () = check_cpus c in
    let* () = Row.check ~file ~header:Row.header in
    let* () =
      match (phase, Target.stale c.layout target side v) with
      | Build, _ when not (Sys.file_exists checkout) ->
          Error (checkout ^ " does not exist: prepare it first")
      | Build, (_ :: _ as stale) ->
          Error
            (Printf.sprintf
               "%s holds the outputs of an earlier build (%s): prepare it again"
               checkout (String.concat ", " stale))
      | Build, [] -> check_pins c target side v
      | Prepare, _ -> Ok ()
    in
    Exec.with_interrupts (fun () ->
        let dir = new_log_dir c what in
        Printf.printf "%s, logs in %s\n%!" what dir;
        let host = Host.current () in
        let load_before = Host.load () in
        let start = Unix.gettimeofday () in
        let results = execute c ~log_dir:dir steps in
        let load_after = Host.load () in
        let row =
          {
            Row.project = Target.name target;
            side = Target.side_to_string side;
            variant = variant_name;
            phase = phase_to_string phase;
            toolchain = Toolchain.name (Target.toolchain target side);
            limits = c.limits;
            host;
            load_before;
            load_after;
            start;
            results;
            failing_files = failing_files target results;
            log_dir = dir;
          }
        in
        (* The row first: the step table and the probes must not lose it. *)
        let recorded = Row.append ~file ~header:Row.header (Row.fields row) in
        write_steps dir results;
        probe c ~log_dir:dir (Target.probes c.layout target side v);
        let+ () = recorded in
        let outcome = Row.outcome results in
        Printf.printf "%s: %s, row added to %s\n%!" what outcome file;
        outcome = "ok")
