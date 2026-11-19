(* Mines the history of the projects of experiment #13 and writes the result
   tables. See plans/13-upgrade-cost.md, Part C. *)

open Upgrade_mining

let usage =
  "upgrade_mining --clones DIR --releases DIR --out DIR [--since DATE] \
   [--until DATE] [PROJECT ...]"

(* The result files never replace existing ones: the recorded tables carry
   hand-filled classification columns. *)
let write path contents =
  Out_channel.with_open_gen [ Open_wronly; Open_creat; Open_excl; Open_binary ]
    0o644 path (fun oc -> Out_channel.output_string oc contents);
  Printf.printf "wrote %s\n%!" path

let bumps_file ~out ~until (p : Project.t) =
  Filename.concat out (Printf.sprintf "%s-exp-13-%s-bumps.csv" until p.name)

let per_release_file ~out ~until =
  Filename.concat out (until ^ "-exp-13-per-release.csv")

let summary_file ~out ~until =
  Filename.concat out (until ^ "-exp-13-mining-summary.md")

let main ~clones_dir ~releases_dir ~out ~since ~until names =
  let tool_of =
    Util.memo (fun name ->
        match List.find_opt (fun (n, _, _) -> n = name) Projects.tools with
        | Some (_, scheme, prefixes) ->
            Tool.make ~name ~scheme ~prefixes ~until
              (Release.load (Filename.concat releases_dir (name ^ ".tsv")))
        | None -> failwith ("unknown tool " ^ name))
  in
  let projects =
    match names with
    | [] -> Projects.all
    | names ->
        List.map
          (fun n ->
            match
              List.find_opt (fun (p : Project.t) -> p.name = n) Projects.all
            with
            | Some p -> p
            | None -> failwith ("unknown project " ^ n))
          names
  in
  (match
     List.filter Sys.file_exists
       (per_release_file ~out ~until
       :: summary_file ~out ~until
       :: List.map (bumps_file ~out ~until) projects)
   with
  | [] -> ()
  | existing ->
      failwith
        (Printf.sprintf
           "%s already exist; result files are never overwritten (they may \
            hold manual classification): choose another --out directory"
           (String.concat ", " existing)));
  let clones =
    Util.memo (fun name ->
        let dir = Filename.concat clones_dir name in
        if not (Sys.file_exists dir) then failwith ("missing clone " ^ dir);
        Repo.git dir)
  in
  let results =
    List.map
      (fun (p : Project.t) ->
        Printf.printf "mining %s\n%!" p.name;
        let tool = tool_of p.tool in
        let missing = Mine.missing_paths p ~clones ~since ~until in
        List.iter
          (fun (m : Mine.missing) ->
            Printf.printf "warning: %s: %s\n%!" p.name
              (Mine.missing_to_string m))
          missing;
        let rows = Mine.run p ~tool ~clones ~since ~until in
        write (bumps_file ~out ~until p) (Report.rows_csv rows);
        { Report.project = p.name; tool; rows; missing })
      projects
  in
  write (per_release_file ~out ~until) (Report.per_release_csv results);
  write (summary_file ~out ~until) (Report.summary_md ~since ~until results)

let () =
  let clones = ref "" and releases = ref "" and out = ref "" in
  let since = ref "2025-11-19" and until = ref "2026-11-19" in
  let names = ref [] in
  Arg.parse
    [
      ("--clones", Arg.Set_string clones, "DIR directory holding the clones");
      ( "--releases",
        Arg.Set_string releases,
        "DIR directory holding <tool>.tsv release lists" );
      ( "--out",
        Arg.Set_string out,
        "DIR directory for the result files (existing ones are never \
         overwritten)" );
      ("--since", Arg.Set_string since, "DATE start of the window (included)");
      ("--until", Arg.Set_string until, "DATE snapshot date (included)");
    ]
    (fun n -> names := n :: !names)
    usage;
  if !clones = "" || !releases = "" || !out = "" then (
    prerr_endline usage;
    exit 2);
  if not (Release.is_date !since && Release.is_date !until && !since <= !until)
  then (
    prerr_endline
      "upgrade_mining: --since and --until must be dates YYYY-MM-DD, in order";
    exit 2);
  try
    main ~clones_dir:!clones ~releases_dir:!releases ~out:!out ~since:!since
      ~until:!until (List.rev !names)
  with
  | Repo.Git_error msg | Failure msg | Sys_error msg ->
      prerr_endline ("upgrade_mining: " ^ msg);
      exit 1
  | Fun.Finally_raised e ->
      prerr_endline ("upgrade_mining: " ^ Printexc.to_string e);
      exit 1
