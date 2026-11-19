type outcome =
  | Success
  | Skipped
  | Exit of int
  | Timed_out
  | Signal of int
  | Interrupted of string
  | Driver_error of string

(* OCaml numbers the signals it knows with negative integers; [timeout]'s
   exit codes use the system's numbers. *)
let posix_signal s =
  match
    List.assoc_opt s
      Sys.
        [
          (sighup, 1);
          (sigint, 2);
          (sigquit, 3);
          (sigill, 4);
          (sigabrt, 6);
          (sigbus, 7);
          (sigfpe, 8);
          (sigkill, 9);
          (sigsegv, 11);
          (sigpipe, 13);
          (sigalrm, 14);
          (sigterm, 15);
        ]
  with
  | Some n -> n
  | None -> s

let classify ~timeout ~wall = function
  | Unix.WEXITED 0 -> Success
  | Unix.WEXITED 124 -> Timed_out
  | Unix.WEXITED c when c > 128 && wall >= float_of_int timeout -> Timed_out
  | Unix.WEXITED c when c > 128 -> Signal (c - 128)
  | Unix.WEXITED c -> Exit c
  | Unix.WSIGNALED s | Unix.WSTOPPED s -> Signal (posix_signal s)

let failed = function Success | Skipped -> false | _ -> true

let outcome_to_string = function
  | Success -> "ok"
  | Skipped -> "skipped"
  | Exit c -> Printf.sprintf "exit %d" c
  | Timed_out -> "timeout"
  | Signal s -> Printf.sprintf "signal %d" s
  | Interrupted s -> "interrupted " ^ s
  | Driver_error msg -> "error: " ^ msg

type step_result = {
  index : int;
  label : string;
  command : string;
  start : float;
  wall : float;
  user : float;
  sys : float;
  outcome : outcome;
  log : string option;
}

let log_name index label =
  let safe = function
    | ('a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '.' | '-') as c -> c
    | _ -> '_'
  in
  Printf.sprintf "%02d-%s.log" index (String.map safe label)

let timestamp t =
  let tm = Unix.gmtime t in
  Printf.sprintf "%04d-%02d-%02dT%02d:%02d:%02dZ" (tm.tm_year + 1900)
    (tm.tm_mon + 1) tm.tm_mday tm.tm_hour tm.tm_min tm.tm_sec

let sha256sum output =
  let hex = function '0' .. '9' | 'a' .. 'f' -> true | _ -> false in
  match String.split_on_char ' ' (String.trim output) with
  | digest :: _ when String.length digest = 64 && String.for_all hex digest ->
      Some digest
  | _ -> None

let rec mkdir_p dir =
  if not (Sys.file_exists dir) then begin
    mkdir_p (Filename.dirname dir);
    try Sys.mkdir dir 0o755 with Sys_error _ when Sys.file_exists dir -> ()
  end

let rec remove_tree path =
  match (Unix.lstat path).st_kind with
  | Unix.S_DIR ->
      Array.iter
        (fun e -> remove_tree (Filename.concat path e))
        (Sys.readdir path);
      Unix.rmdir path
  | _ -> Unix.unlink path
  | exception Unix.Unix_error (Unix.ENOENT, _, _) -> ()

(* Interruptions. [received] is the signal the driver got, [child] the
   command running. The handler only sends [TERM] to the child: the code
   waiting for it records the interruption. *)

let received : string option ref = ref None
let child : int option ref = ref None
let interrupted () = Option.is_some !received

let signals =
  [ (Sys.sigint, "INT"); (Sys.sigterm, "TERM"); (Sys.sighup, "HUP") ]

let terminate pid =
  try Unix.kill pid Sys.sigterm with Unix.Unix_error (Unix.ESRCH, _, _) -> ()

let with_interrupts f =
  received := None;
  let previous =
    List.map
      (fun (signal, name) ->
        ( signal,
          Sys.signal signal
            (Sys.Signal_handle
               (fun _ ->
                 received := Some name;
                 Option.iter terminate !child)) ))
      signals
  in
  Fun.protect
    ~finally:(fun () ->
      List.iter (fun (signal, b) -> Sys.set_signal signal b) previous)
    f

let write_all fd s =
  let rec go off =
    if off < String.length s then
      go (off + Unix.write_substring fd s off (String.length s - off))
  in
  go 0

let open_log ~append file =
  Unix.openfile file
    ([ Unix.O_WRONLY; Unix.O_CREAT; Unix.O_CLOEXEC ]
    @ if append then [ Unix.O_APPEND ] else [ Unix.O_TRUNC ])
    0o644

let rec wait pid =
  match Unix.waitpid [] pid with
  | _, status -> status
  | exception Unix.Unix_error (Unix.EINTR, _, _) -> wait pid

(* Runs [argv] from [cwd] with [env], output to [out_fd]; [prog] is the
   resolved program. In the child, a failure before [execve] is written to
   [out_fd], and the child ends with code 127 whatever happens: it never
   returns into the driver's code. The child is [!child] until it is waited
   for; a signal received meanwhile, even just before, terminates it. *)
let spawn ~prog ~argv ~env ~cwd ~out_fd =
  flush_all ();
  match Unix.fork () with
  | 0 ->
      Fun.protect
        ~finally:(fun () -> Unix._exit 127)
        (fun () ->
          try
            Unix.chdir cwd;
            let null =
              Unix.openfile "/dev/null" [ Unix.O_RDONLY; Unix.O_CLOEXEC ] 0
            in
            Unix.dup2 null Unix.stdin;
            Unix.dup2 out_fd Unix.stdout;
            Unix.dup2 out_fd Unix.stderr;
            Unix.execve prog argv env
          with Unix.Unix_error (e, f, arg) ->
            write_all out_fd
              (Printf.sprintf "upgrade_builds: %s %s: %s\n" f arg
                 (Unix.error_message e));
            Unix._exit 127)
  | pid ->
      child := Some pid;
      if interrupted () then terminate pid;
      pid

let reap pid =
  Fun.protect ~finally:(fun () -> child := None) (fun () -> wait pid)

(* The environment and argument vector of [command] run with the base
   changes [env], and its resolved program. *)
let resolved ~env (command : Command.t) =
  let env = Command.environment (env @ command.env) (Unix.environment ()) in
  match Command.resolve ~path:(Command.path_of env) command.prog with
  | None -> Error (command.prog ^ ": not found in PATH")
  | Some prog -> Ok (prog, env)

let prepare ~env (command : Command.t) =
  match Command.argv command with
  | Error _ as e -> e
  | Ok argv ->
      Result.map
        (fun (prog, env) -> (prog, Array.of_list argv, env))
        (resolved ~env command)

(* Runs [command] with its output in [out_fd]: its status and the wall, user
   and system times. *)
let execute ~env ~out_fd (command : Command.t) =
  match prepare ~env command with
  | Error _ as e -> e
  | Ok _ when interrupted () -> Error "interrupted before it started"
  | Ok (prog, argv, env) -> (
      let t0 = Unix.gettimeofday () and c0 = Unix.times () in
      match spawn ~prog ~argv ~env ~cwd:command.cwd ~out_fd with
      | exception Unix.Unix_error (e, f, _) ->
          Error (f ^ ": " ^ Unix.error_message e)
      | pid ->
          let status = reap pid in
          let c1 = Unix.times () in
          Ok
            ( status,
              Unix.gettimeofday () -. t0,
              c1.tms_cutime -. c0.tms_cutime,
              c1.tms_cstime -. c0.tms_cstime ))

let result ~index ~label ~command ?log ?(wall = 0.) ?(user = 0.) ?(sys = 0.)
    ~start outcome =
  { index; label; command; start; wall; user; sys; outcome; log }

(* The program of [command] itself, found before [command] is put under the
   limits, whose own program is [timeout]: a missing [lake] or [opam] is a
   driver error, not a failed build. *)
let check_program ~env command = Result.map ignore (resolved ~env command)

(* Makes [dir] an empty directory. *)
let empty_dir dir =
  remove_tree dir;
  mkdir_p dir

let digest file =
  match
    let ic = Unix.open_process_args_in "sha256sum" [| "sha256sum"; file |] in
    let output = In_channel.input_all ic in
    (output, Unix.close_process_in ic)
  with
  | exception (Unix.Unix_error (_, _, msg) | Sys_error msg) ->
      Error ("sha256sum: " ^ msg)
  | output, Unix.WEXITED 0 -> (
      match sha256sum output with
      | Some d -> Ok d
      | None -> Error ("unexpected sha256sum output: " ^ output))
  | _, _ -> Error ("sha256sum failed on " ^ file)

let run_command ~limits ~env ~log_dir ~index ~label ~start command =
  let command = Command.prefixed (Limits.prefix limits) command in
  let shown = Command.to_string command in
  let log = Filename.concat log_dir (log_name index label) in
  match open_log ~append:false log with
  | exception Unix.Unix_error (e, _, _) ->
      result ~index ~label ~command:shown ~start
        (Driver_error (log ^ ": " ^ Unix.error_message e))
  | out_fd ->
      Fun.protect
        ~finally:(fun () -> Unix.close out_fd)
        (fun () ->
          write_all out_fd
            (Printf.sprintf "# %s\n# %s\n# start %s\n\n" label shown
               (timestamp start));
          let finish ?wall ?user ?sys outcome =
            write_all out_fd
              (Printf.sprintf "\n# %s\n" (outcome_to_string outcome));
            result ~index ~label ~command:shown ~log ?wall ?user ?sys ~start
              outcome
          in
          match (execute ~env ~out_fd command, !received) with
          | Ok (_, wall, user, sys), Some signal ->
              finish ~wall ~user ~sys (Interrupted signal)
          | Error _, Some signal -> finish (Interrupted signal)
          | Error msg, None -> finish (Driver_error msg)
          | Ok (status, wall, user, sys), None ->
              finish ~wall ~user ~sys
                (classify ~timeout:limits.Limits.timeout ~wall status))

let run_step ~limits ~env ~log_dir ~index step =
  let label = Step.label step in
  let start = Unix.gettimeofday () in
  let describe = Step.describe ~prefix:(Limits.prefix limits) step in
  let done_ outcome = result ~index ~label ~command:describe ~start outcome in
  let guarded f =
    match f () with
    | () -> done_ Success
    | exception (Sys_error msg | Unix.Unix_error (_, _, msg)) ->
        done_ (Driver_error msg)
  in
  match step with
  | Step.Run { creates = Some path; _ } when Sys.file_exists path ->
      done_ Skipped
  | Step.Run { command; clears; _ } -> (
      let error msg =
        (* A signal received before the command started stops the step
           too: it is an interruption, not a driver error. *)
        match !received with
        | Some signal -> done_ (Interrupted signal)
        | None -> done_ (Driver_error msg)
      in
      match check_program ~env command with
      | Error msg -> error msg
      | Ok () -> (
          match Option.iter empty_dir clears with
          | exception (Sys_error msg | Unix.Unix_error (_, _, msg)) -> error msg
          | () when interrupted () -> error "interrupted"
          | () -> run_command ~limits ~env ~log_dir ~index ~label ~start command
          ))
  | Step.Edit { dir; edits; _ } ->
      let rec apply = function
        | [] -> Success
        | e :: rest -> (
            match Edit.apply ~dir e with
            | Ok () -> apply rest
            | Error msg -> Driver_error msg)
      in
      done_ (apply edits)
  | Step.Mkdir dir -> guarded (fun () -> mkdir_p dir)
  | Step.Touch file ->
      guarded (fun () ->
          if not (Sys.file_exists file) then
            Out_channel.with_open_bin file ignore)
  | Step.Remove path -> guarded (fun () -> remove_tree path)
  | Step.Rename { src; dst } ->
      if Sys.file_exists src then guarded (fun () -> Sys.rename src dst)
      else if Sys.file_exists dst then done_ Skipped
      else done_ (Driver_error (src ^ " does not exist"))
  | Step.Sha256 { file; expected } -> (
      match digest file with
      | Error msg -> done_ (Driver_error msg)
      | Ok d when d = expected -> done_ Success
      | Ok d ->
          (* A bad file must not be taken as done by the next install. *)
          let removed =
            match Sys.remove file with
            | () -> "deleted"
            | exception Sys_error msg -> "not deleted: " ^ msg
          in
          done_
            (Driver_error
               (Printf.sprintf "%s: SHA-256 %s, expected %s (%s)" file d
                  expected removed)))

let on_failure = function
  | Step.Run { on_failure; _ } -> on_failure
  | Step.Edit _ | Step.Mkdir _ | Step.Touch _ | Step.Rename _ | Step.Sha256 _
  | Step.Remove _ ->
      Step.Stop

let run ~limits ~env ~log_dir steps =
  let total = List.length steps in
  let rec go index acc = function
    | [] -> List.rev acc
    | _ :: _ when interrupted () -> List.rev acc
    | step :: rest ->
        let r = run_step ~limits ~env ~log_dir ~index step in
        Printf.printf "[%d/%d] %s: %s (%.1f s)\n%!" index total r.label
          (outcome_to_string r.outcome)
          r.wall;
        let acc = r :: acc in
        if
          (failed r.outcome && on_failure step = Step.Stop)
          || match r.outcome with Interrupted _ -> true | _ -> false
        then List.rev acc
        else go (index + 1) acc rest
  in
  go 1 [] steps

let probe_timeout = 300

let probe ~limits ~env ~file commands =
  let limits = Limits.with_timeout probe_timeout limits in
  match open_log ~append:true file with
  | exception Unix.Unix_error (e, _, _) ->
      Printf.eprintf "upgrade_builds: %s: %s\n%!" file (Unix.error_message e)
  | out_fd ->
      Fun.protect
        ~finally:(fun () -> Unix.close out_fd)
        (fun () ->
          List.iter
            (fun command ->
              if not (interrupted ()) then begin
                let inner = command in
                let command = Command.prefixed (Limits.prefix limits) command in
                write_all out_fd
                  (Printf.sprintf "$ %s\n" (Command.to_string command));
                let status =
                  match
                    Result.bind (check_program ~env inner) (fun () ->
                        execute ~env ~out_fd command)
                  with
                  | Error msg -> "error: " ^ msg
                  | Ok (Unix.WEXITED c, _, _, _) -> Printf.sprintf "exit %d" c
                  | Ok ((Unix.WSIGNALED s | Unix.WSTOPPED s), _, _, _) ->
                      Printf.sprintf "signal %d" (posix_signal s)
                in
                write_all out_fd (Printf.sprintf "# %s\n\n" status)
              end)
            commands)

let capture ~limits ~env command =
  let limits = Limits.with_timeout probe_timeout limits in
  let inner = command in
  let command = Command.prefixed (Limits.prefix limits) command in
  let shown = Command.to_string command in
  let fail msg = Error (shown ^ ": " ^ msg) in
  match
    Result.bind (check_program ~env inner) (fun () -> prepare ~env command)
  with
  | Error msg -> fail msg
  | Ok (prog, argv, env) -> (
      let read_fd, write_fd = Unix.pipe ~cloexec:true () in
      let spawned =
        match spawn ~prog ~argv ~env ~cwd:command.cwd ~out_fd:write_fd with
        | pid -> Ok pid
        | exception Unix.Unix_error (e, f, _) ->
            Error (f ^ ": " ^ Unix.error_message e)
      in
      (* The parent's copy of the write end must be closed for the read to
         see the end of the output. *)
      Unix.close write_fd;
      match spawned with
      | Error msg ->
          Unix.close read_fd;
          fail msg
      | Ok pid -> (
          let ic = Unix.in_channel_of_descr read_fd in
          let output =
            match In_channel.input_all ic with
            | output -> Ok output
            | exception Sys_error msg -> Error msg
          in
          In_channel.close ic;
          (* Always waited for, so that no zombie or stale pid remains. *)
          match (reap pid, output) with
          | _, Error msg -> fail ("reading its output: " ^ msg)
          | Unix.WEXITED 0, Ok output -> Ok output
          | Unix.WEXITED c, Ok output ->
              fail (Printf.sprintf "exit %d\n%s" c output)
          | (Unix.WSIGNALED s | Unix.WSTOPPED s), Ok _ ->
              fail (Printf.sprintf "signal %d" (posix_signal s))))
