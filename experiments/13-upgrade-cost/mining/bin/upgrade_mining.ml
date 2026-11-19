(* Mines the history of the projects of experiment #13 and writes the result
   tables. See plans/13-upgrade-cost.md, Part C. *)

open Upgrade_mining

let usage =
  "upgrade_mining --clones DIR --releases DIR --out DIR [--since DATE] \
   [--until DATE] [PROJECT ...]"

let write path contents =
  Out_channel.with_open_bin path (fun oc ->
      Out_channel.output_string oc contents);
  Printf.printf "wrote %s\n%!" path

let main ~clones_dir ~releases_dir ~out ~since ~until names =
  let tools = Hashtbl.create 8 in
  let tool_of name =
    match Hashtbl.find_opt tools name with
    | Some t -> t
    | None ->
        let t =
          match List.find_opt (fun (n, _, _) -> n = name) Projects.tools with
          | Some (_, scheme, prefixes) ->
              Tool.make ~name ~scheme ~prefixes ~until
                (Release.load (Filename.concat releases_dir (name ^ ".tsv")))
          | None -> failwith ("unknown tool " ^ name)
        in
        Hashtbl.add tools name t;
        t
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
  let repos = Hashtbl.create 16 in
  let clones name =
    match Hashtbl.find_opt repos name with
    | Some r -> r
    | None ->
        let dir = Filename.concat clones_dir name in
        if not (Sys.file_exists dir) then failwith ("missing clone " ^ dir);
        let r = Repo.git dir in
        Hashtbl.add repos name r;
        r
  in
  let results =
    List.map
      (fun (p : Project.t) ->
        Printf.printf "mining %s\n%!" p.name;
        let tool = tool_of p.tool in
        let rows = Mine.run p ~tool ~clones ~since ~until in
        write
          (Filename.concat out
             (Printf.sprintf "%s-exp-13-%s-bumps.csv" until p.name))
          (Report.rows_csv rows);
        { Report.project = p.name; tool; rows })
      projects
  in
  write
    (Filename.concat out (until ^ "-exp-13-per-release.csv"))
    (Report.per_release_csv results);
  write
    (Filename.concat out (until ^ "-exp-13-mining-summary.md"))
    (Report.summary_md ~since ~until results)

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
      ("--out", Arg.Set_string out, "DIR directory for the result files");
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
  with Repo.Git_error msg | Failure msg | Sys_error msg ->
    prerr_endline ("upgrade_mining: " ^ msg);
    exit 1
