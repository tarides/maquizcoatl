type side = Pinned | Latest

let side_to_string = function Pinned -> "pinned" | Latest -> "latest"

type change = Edits of Edit.t list | Why3_reduced

type variant = {
  vname : string;
  doc : string;
  change : change;
  vpins : (string * string) list;  (** Replace the pins of the same packages. *)
}

type kind =
  | Rocq of { rocqchk : Command.arg list }
  | Lean
  | Pulse
  | Why3_gallery

type source = {
  url : string;
  commit : string;
  tag : string option;  (** Shallow clone of this tag, which is [commit]. *)
  sparse : string list;  (** Cone of a sparse checkout; [[]] for all. *)
}

type t = {
  name : string;
  source : source;
  pinned : Toolchain.t;
  latest : Toolchain.t;
  latest_edits : Edit.t list;
  variants : variant list;
  pins : (string * string) list;
      (** The opam packages the checkout pins (pin-depends), with their commit.
      *)
  kind : kind;
}

let ( / ) = Filename.concat
let lits = Command.lits
let warblre_head = "d4b0e226464650d6854987f6d64364a301659ea0"

(* The Warblre commit of Linden's pin-depends at 3ef2cb4. *)
let linden_warblre = "4321379b887d590a42759818f6d9b1fd2351688e"

let warblre =
  {
    name = "warblre";
    source =
      {
        url = "https://github.com/LindenRegex/Warblre.git";
        commit = warblre_head;
        tag = None;
        sparse = [];
      };
    pinned = Toolchain.Rocq "9.2.0";
    latest = Toolchain.Rocq "9.3.0";
    latest_edits = [];
    variants = [];
    pins = [];
    (* .github/workflows/ci.yml at d4b0e22. *)
    kind =
      Rocq
        {
          rocqchk =
            lits
              [
                "-silent";
                "--output-context";
                "-Q";
                "_build/default/mechanization";
                "Warblre";
              ]
            @ [
                Command.Files
                  {
                    dir = "_build/default/mechanization";
                    suffix = ".vo";
                    depth = None;
                  };
              ];
        };
  }

let linden =
  {
    name = "linden";
    source =
      {
        url = "https://github.com/LindenRegex/Linden.git";
        commit = "3ef2cb4573f86e57a25245f84dd6a13402f418fd";
        tag = None;
        sparse = [];
      };
    pinned = Toolchain.Rocq "9.2.0";
    latest = Toolchain.Rocq "9.3.0";
    latest_edits = [];
    variants =
      [
        {
          vname = "warblre-d4b0e22";
          doc =
            "Warblre moved from 4321379 to d4b0e22 (its Rocq 9.3 fixes) in the \
             pin-depends of linden.opam and of its dune template";
          change =
            (* dune regenerates linden.opam from the template. *)
            Edits
              (List.map
                 (fun file ->
                   Edit.Replace
                     { file; old = linden_warblre; by = warblre_head })
                 [ "linden.opam.template"; "linden.opam" ]);
          vpins = [ ("warblre", warblre_head) ];
        };
      ];
    pins = [ ("warblre", linden_warblre) ];
    (* .github/workflows/ci.yml at 3ef2cb4: rocqchk -R _build/default Linden
       _build/default/*/*.vo *)
    kind =
      Rocq
        {
          rocqchk =
            lits
              [
                "-silent"; "--output-context"; "-R"; "_build/default"; "Linden";
              ]
            @ [
                Command.Files
                  { dir = "_build/default"; suffix = ".vo"; depth = Some 2 };
              ];
        };
  }

let lean_bump file old by = Edit.Replace { file; old; by }

let lean_regex =
  let pinned = "v4.34.0-rc1" and latest = "v4.36.0" in
  let toolchain_bump file =
    lean_bump file
      (Toolchain.lean_toolchain pinned)
      (Toolchain.lean_toolchain latest)
  in
  {
    name = "lean-regex";
    source =
      {
        url = "https://github.com/pandaman64/lean-regex.git";
        commit = "32af6f33d80e1dad2b072da6981da58e92b08b9e";
        tag = None;
        sparse = [];
      };
    pinned = Toolchain.Lean pinned;
    latest = Toolchain.Lean latest;
    latest_edits =
      [
        toolchain_bump "regex/lean-toolchain";
        toolchain_bump "correctness/lean-toolchain";
        lean_bump "correctness/lakefile.toml"
          (Printf.sprintf "rev = %S" pinned)
          (Printf.sprintf "rev = %S" latest);
      ];
    variants = [];
    pins = [];
    kind = Lean;
  }

let pulse_examples =
  {
    name = "pulse-examples";
    source =
      {
        url = "https://github.com/FStarLang/FStar.git";
        commit = "362e792b3aa882f1766b95c7450e3fe63081163d";
        tag = Some "v2026.10.25";
        sparse = [ "pulse"; "mk" ];
      };
    pinned = Toolchain.Fstar "v2026.10.25";
    latest = Toolchain.Fstar "v2026.11.15";
    latest_edits = [];
    variants = [];
    pins = [];
    kind = Pulse;
  }

let why3_gallery =
  {
    name = "why3-gallery";
    source =
      {
        url = "https://gitlab.inria.fr/why3/why3.git";
        commit = "88b18b1ae353852ed5d2e320135cd50d03bf036a";
        tag = Some "1.8.2";
        sparse = [ "examples" ];
      };
    pinned = Toolchain.Why3 "1.8.2";
    latest = Toolchain.Why3 "1.9.0";
    latest_edits = [];
    variants =
      [
        {
          vname = "reduced";
          doc = "only the sessions of the reduced_regtests.list files";
          change = Why3_reduced;
          vpins = [];
        };
      ];
    pins = [];
    kind = Why3_gallery;
  }

let all = [ warblre; linden; lean_regex; pulse_examples; why3_gallery ]
let name t = t.name
let find n = List.find_opt (fun t -> t.name = n) all
let toolchain t = function Pinned -> t.pinned | Latest -> t.latest
let variants t = List.map (fun v -> (v.vname, v.doc)) t.variants
let variant_name v = v.vname

let pins t v =
  let override = match v with Some v -> v.vpins | None -> [] in
  List.map
    (fun (package, commit) ->
      (package, Option.value (List.assoc_opt package override) ~default:commit))
    t.pins

let pin_list l t side =
  match t.pins with
  | [] -> None
  | _ :: _ ->
      let home = Toolchain.home l (toolchain t side) in
      Some (Toolchain.opam l ~cwd:home [ "pin"; "list"; "--switch"; home ])

let check_pins t v output =
  let lines = String.split_on_char '\n' output in
  let pinned package =
    List.filter
      (fun line ->
        String.starts_with ~prefix:(package ^ ".") (String.trim line))
      lines
  in
  List.fold_left
    (fun acc (package, commit) ->
      match (acc, pinned package) with
      | (Error _ as e), _ -> e
      | Ok (), [ line ] when Edit.contains ~sub:("#" ^ commit) line -> Ok ()
      | Ok (), [] ->
          Error (Printf.sprintf "%s is not pinned in the switch" package)
      | Ok (), found ->
          Error
            (Printf.sprintf "%s is pinned to %s in the switch, not to %s"
               package
               (String.concat " and " (List.map String.trim found))
               commit))
    (Ok ()) (pins t v)

let variant t = function
  | None -> Ok None
  | Some n -> (
      match List.find_opt (fun v -> v.vname = n) t.variants with
      | Some v -> Ok (Some v)
      | None ->
          Error
            (Printf.sprintf "%s has no variant %s (variants: %s)" t.name n
               (match t.variants with
               | [] -> "none"
               | vs -> String.concat ", " (List.map (fun v -> v.vname) vs))))

let dir l t side v =
  let suffix =
    match v with Some { vname; change = Edits _; _ } -> "-" ^ vname | _ -> ""
  in
  Layout.build l / Printf.sprintf "%s-%s%s" t.name (side_to_string side) suffix

let edits t side v =
  (match side with Pinned -> [] | Latest -> t.latest_edits)
  @ match v with Some { change = Edits e; _ } -> e | _ -> []

let checkout l t dir =
  let build = Layout.build l in
  let git args = Command.v ~cwd:dir "git" args in
  let s = t.source in
  [
    Step.Mkdir build;
    Step.run ~creates:(dir / ".git") "clone"
      (Command.v ~cwd:build "git"
         ([ "clone"; "--filter=blob:none"; "--no-checkout" ]
         @ (match s.tag with
           | Some tag -> [ "--depth"; "1"; "--branch"; tag ]
           | None -> [])
         @ [ s.url; dir ]));
  ]
  @ (match s.sparse with
    | [] -> []
    | paths ->
        [
          Step.run "sparse checkout"
            (git ([ "sparse-checkout"; "set"; "--cone" ] @ paths));
        ])
  @ [
      Step.run "checkout"
        (git
           [
             "-c"; "advice.detachedHead=false"; "checkout"; "--detach"; s.commit;
           ]);
    ]

let why3_config = "upgrade_builds.why3.conf"
let jobs (lim : Limits.t) = string_of_int lim.jobs
let pulse_examples_dir = "pulse/share/pulse/examples"

(* Build outputs, relative to the checkout, that a measured build must not
   find: lean-regex's own build directories, not its packages (mathlib and its
   cache). The Pulse examples keep [_cache] and [_output] in every directory;
   the top ones show that a build ran. *)
let outputs t =
  match t.kind with
  | Rocq _ -> [ "_build" ]
  | Lean -> [ "regex/.lake/build"; "correctness/.lake/build" ]
  | Pulse -> [ pulse_examples_dir / "_cache"; pulse_examples_dir / "_output" ]
  | Why3_gallery -> []

let clean l t side v =
  let d = dir l t side v in
  match t.kind with
  | Pulse ->
      [
        Step.run "make clean"
          (Toolchain.command l (toolchain t side) ~cwd:d "make"
             (lits [ "-C"; pulse_examples_dir; "clean" ]));
      ]
  | Rocq _ | Lean | Why3_gallery ->
      List.map (fun p -> Step.Remove (d / p)) (outputs t)

let prepare l lim t side v =
  let d = dir l t side v in
  let tc = toolchain t side in
  let edit_steps =
    match edits t side v with
    | [] -> []
    | e -> [ Step.Edit { label = "edits"; dir = d; edits = e } ]
  in
  let deps =
    match t.kind with
    | Rocq _ ->
        [
          Step.run "opam dependencies"
            (Toolchain.opam l ~cwd:d
               [
                 "install";
                 "--switch";
                 Toolchain.home l tc;
                 "--deps-only";
                 "--yes";
                 "--jobs=" ^ jobs lim;
                 ".";
               ]);
        ]
    | Lean ->
        (* Only [correctness/] has dependencies (mathlib): the manifest of
           [regex/] lists no package at 32af6f3, so nothing is fetched there. *)
        let lake label args =
          Step.run label
            (Toolchain.command l tc ~cwd:(d / "correctness") "lake" (lits args))
        in
        (match side with
          | Pinned -> []
          | Latest -> [ lake "lake update" [ "update" ] ])
        @ [ lake "mathlib cache" [ "exe"; "cache"; "get" ] ]
    | Pulse | Why3_gallery -> []
  in
  checkout l t d @ edit_steps @ deps @ clean l t side v

let stale l t side v =
  List.filter (fun p -> Sys.file_exists (dir l t side v / p)) (outputs t)

let measured l lim t side v =
  let d = dir l t side v in
  let tc = toolchain t side in
  let run ?env ?on_failure ?(cwd = d) label prog args =
    Step.run ?on_failure label (Toolchain.command l tc ?env ~cwd prog args)
  in
  match t.kind with
  | Rocq { rocqchk } ->
      Ok
        [
          run "dune build"
            ~env:[ Command.Set ("DUNE_CACHE", "disabled") ]
            "dune"
            (lits [ "build"; "-j"; jobs lim ]);
          run "rocqchk" "rocqchk" rocqchk;
        ]
  | Lean ->
      let env = [ Command.Set ("LEAN_NUM_THREADS", jobs lim) ] in
      Ok
        (List.map
           (fun sub ->
             run ~env ~cwd:(d / sub) ("lake build " ^ sub) "lake"
               (lits [ "build" ]))
           [ "regex"; "correctness" ])
  | Pulse ->
      (* [Toolchain.command] sets FSTAR_EXE, which pulse/mk/test.mk reads. *)
      Ok
        [
          run "make verify" "make"
            (lits [ "-C"; pulse_examples_dir; "-j"; jobs lim; "verify" ]);
        ]
  | Why3_gallery -> (
      let selection =
        match v with
        | Some { change = Why3_reduced; _ } -> Why3_sessions.Reduced
        | _ -> Why3_sessions.Regtests
      in
      let examples = d / "examples" in
      match Why3_sessions.sessions ~examples selection with
      | Error msg -> Error (msg ^ " (run prepare first)")
      | Ok [] -> Error ("no Why3 session under " ^ examples)
      | Ok sessions ->
          (* Written by the run, so that it follows the run's jobs. *)
          let config =
            Step.Edit
              {
                label = "why3 extra configuration";
                dir = d;
                edits =
                  [
                    Edit.Write
                      {
                        file = why3_config;
                        contents =
                          Printf.sprintf "[main]\nrunning_provers_max = %s\n"
                            (jobs lim);
                      };
                  ];
              }
          in
          Ok
            (config
            :: List.map
                 (fun (session, options) ->
                   run ~on_failure:Step.Continue ~cwd:examples session "why3"
                     (lits
                        ([ "replay"; "-q"; "--extra-config"; d / why3_config ]
                        @ options @ [ session ])))
                 sessions))

let failure_format t =
  match t.kind with
  | Rocq _ -> Failures.Dune_rocq
  | Lean -> Failures.Lake
  | Pulse -> Failures.Fstar
  | Why3_gallery -> Failures.Failed_steps

let probes l t side v =
  let d = dir l t side v in
  let git args = Command.v ~cwd:d "git" args in
  Toolchain.probes l (toolchain t side) ~cwd:d
  @ [
      git [ "rev-parse"; "HEAD" ];
      git [ "status"; "--short" ];
      git [ "diff"; "--stat" ];
    ]
  @
  match t.kind with
  | Pulse -> [ git [ "rev-parse"; "HEAD:karamel" ] ]
  | _ -> []
