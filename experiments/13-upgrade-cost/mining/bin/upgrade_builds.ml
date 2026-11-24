(* Installs the toolchains of experiment #13, prepares and runs the builds of
   Part A, and records their rows. See plans/13-upgrade-cost.md, Part A. *)

open Upgrade_builds
open Cmdliner
open Cmdliner.Term.Syntax

let exit_failed = 3

let exits =
  Cmd.Exit.info exit_failed
    ~doc:
      "when a step failed or the driver was interrupted; its row is recorded \
       (prepare and run)."
  :: Cmd.Exit.info 1
       ~doc:
         "on a driver error: nothing ran, or the row could not be written (the \
          logs are kept)."
  :: Cmd.Exit.defaults

let conv ~docv parser print =
  Arg.Conv.make ~docv ~parser
    ~pp:(fun ppf x -> Format.pp_print_string ppf (print x))
    ()

let cpuset = conv ~docv:"CPUS" Cpuset.of_string Cpuset.to_string

let duration =
  conv ~docv:"DURATION" Limits.duration_of_string (Printf.sprintf "%ds")

let date =
  conv ~docv:"DATE"
    (fun s ->
      if Upgrade_mining.Release.is_date s then Ok s
      else Error (Printf.sprintf "%S is not a date YYYY-MM-DD" s))
    Fun.id

(* Today's date in UTC, YYYY-MM-DD. *)
let today () = String.sub (Exec.timestamp (Unix.gettimeofday ())) 0 10

let workdir =
  Arg.(
    required
    & opt (some string) None
    & info [ "workdir" ] ~docv:"DIR"
        ~doc:
          "Work directory ($(b,<workdir>/exp13) in the plan): opam root, \
           downloads, toolchains, checkouts and logs go under it.")

let cpus =
  Arg.(
    required
    & opt (some cpuset) None
    & info [ "cpus" ] ~docv:"CPUS"
        ~doc:
          "CPUs every command is pinned to with $(b,taskset), as a list like \
           $(b,8-15) or $(b,8-11,40-43). Required: the bench host is shared.")

let jobs =
  Arg.(
    value & opt int 8
    & info [ "j"; "jobs" ] ~docv:"N"
        ~doc:"Parallel jobs given to opam, dune, make, Lean and Why3.")

let nice =
  Arg.(
    value & opt int 10
    & info [ "nice" ] ~docv:"N" ~doc:"Niceness of every command (0 to 19).")

let timeout =
  Arg.(
    value
    & opt duration (6 * 3600)
    & info [ "timeout" ] ~docv:"DURATION"
        ~doc:
          "Time allowed to each command, like $(b,90s), $(b,30m) or $(b,6h); \
           the command gets TERM, then KILL a minute later.")

let dry_run =
  Arg.(
    value & flag
    & info [ "n"; "dry-run" ]
        ~doc:"Print the steps and their command lines; run and write nothing.")

let config =
  let+ workdir and+ cpus and+ jobs and+ nice and+ timeout and+ dry_run in
  match Limits.make ~jobs ~cpus ~nice ~timeout with
  | Error _ as e -> e
  | Ok limits ->
      List.iter
        (fun w -> prerr_endline ("upgrade_builds: warning: " ^ w))
        (Limits.warnings limits);
      Ok { Driver.layout = Layout.make workdir; limits; dry_run }

let report = function
  | Ok code -> code
  | Error msg ->
      prerr_endline ("upgrade_builds: " ^ msg);
      1

(* Driver errors raised by the file system or the system calls. *)
let guard f =
  try report (f ())
  with Sys_error msg | Unix.Unix_error (_, _, msg) -> report (Error msg)

let list_cmd =
  let doc = "List the toolchains, projects, sides and variants." in
  let term =
    let+ () = Term.const () in
    List.iter (fun t -> print_endline (Toolchain.name t)) Toolchain.all;
    print_newline ();
    List.iter
      (fun t ->
        Printf.printf "%s: pinned %s, latest %s\n" (Target.name t)
          (Toolchain.name (Target.toolchain t Target.Pinned))
          (Toolchain.name (Target.toolchain t Target.Latest));
        List.iter
          (fun (n, d) -> Printf.printf "  variant %s: %s\n" n d)
          (Target.variants t))
      Target.all;
    0
  in
  Cmd.make (Cmd.info "list" ~doc) term

let install_cmd =
  let doc = "Install toolchains under the work directory." in
  let toolchains =
    Arg.(
      non_empty
      & pos_all
          (enum (List.map (fun t -> (Toolchain.name t, t)) Toolchain.all))
          []
      & info [] ~docv:"TOOLCHAIN" ~doc:"Toolchains, as $(b,list) shows them.")
  in
  let term =
    let+ config and+ toolchains in
    guard (fun () ->
        let open Result.Syntax in
        let* c = config in
        let+ () = Driver.install c toolchains in
        0)
  in
  Cmd.make (Cmd.info "install" ~doc ~exits) term

let phase_cmd name phase ~doc =
  let target =
    Arg.(
      required
      & pos 0
          (some (enum (List.map (fun t -> (Target.name t, t)) Target.all)))
          None
      & info [] ~docv:"PROJECT" ~doc:"Project, as $(b,list) shows it.")
  in
  let side =
    Arg.(
      required
      & pos 1
          (some (enum [ ("pinned", Target.Pinned); ("latest", Target.Latest) ]))
          None
      & info [] ~docv:"SIDE" ~doc:"$(b,pinned) or $(b,latest).")
  in
  let variant =
    Arg.(
      value
      & opt (some string) None
      & info [ "variant" ] ~docv:"NAME"
          ~doc:"Variant of the project ($(b,list)).")
  in
  let out =
    Arg.(
      required
      & opt (some string) None
      & info [ "out" ] ~docv:"DIR"
          ~doc:"Directory of $(b,<date>-exp-13-builds.csv) (lab/results).")
  in
  let date =
    Arg.(
      value
      & opt date (today ())
      & info [ "date" ] ~docv:"DATE"
          ~doc:"Date in the name of the result file (default: today, UTC).")
  in
  let term =
    let+ config and+ target and+ side and+ variant and+ out and+ date in
    guard (fun () ->
        let open Result.Syntax in
        let* c = config in
        let+ ok = Driver.run c phase ~out ~date target side ~variant in
        if ok then 0 else exit_failed)
  in
  Cmd.make (Cmd.info name ~doc ~exits) term

let prepare_cmd =
  phase_cmd "prepare" Driver.Prepare
    ~doc:
      "Check out a side of a project and install what its build needs (not \
       timed for the wall-clock ratio)."

let run_cmd =
  phase_cmd "run" Driver.Build
    ~doc:"Run the timed build and check of a prepared side of a project."

let () =
  let doc = "Part A driver of experiment #13 (upgrade cost)." in
  exit
    (Cmd.eval'
       (Cmd.group
          (Cmd.info "upgrade_builds" ~doc)
          [ list_cmd; install_cmd; prepare_cmd; run_cmd ]))
