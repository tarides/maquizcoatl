type side = Pinned | Latest

let side_to_string = function Pinned -> "pinned" | Latest -> "latest"

type change = Edits of Edit.t list | Why3_reduced

type variant = {
  vname : string;
  doc : string;
  change : change;
  vpins : (string * string) list;  (** Replace the pins of the same packages. *)
}

type source = {
  url : string;
  commit : string;
  tag : string option;  (** Shallow clone of this tag, which is [commit]. *)
  sparse : string list;  (** Cone of a sparse checkout; [[]] for all. *)
}

(* A dependency checked out next to the latest side, [<dir>-<cname>], and
   edited: verus-tla for Anvil. *)
type dep_checkout = { cname : string; csource : source; cedits : Edit.t list }

type kind =
  | Rocq of { rocqchk : Command.arg list; dune_targets : string list }
      (** [dune_targets]: what [dune build] builds; [[]] for its default. *)
  | Lean
  | Pulse
  | Why3_gallery
  | Verus of { crate : string; latest_deps : dep_checkout list }
      (** [crate]: the package whose verification is measured. *)
  | Isabelle_afp of { entries : string list; sessions : string list }
      (** [entries]: the AFP entries checked out (one [-d] each); [sessions]:
          the sessions built in the measured run. *)

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
    (* .github/workflows/ci.yml at d4b0e22. Its CI runs [npm install] before
       [dune build @all]; the rules that bundle JavaScript with webpack
       (tests/test262, examples) are left out, so that the build measures
       the Rocq mechanization and the extracted engines only. *)
    kind =
      Rocq
        {
          dune_targets = [ "@mechanization/all"; "@engines/all" ];
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
          dune_targets = [];
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

(* Anvil at 3c95bbb (2026-07-23), its last commit pinning a Verus release
   (decision 1 of issue #25). verus-tla at 8bb157b is its
   verus_temporal_logic dependency, which pins the same vstd. *)
let anvil_vstd_pinned = "=0.0.0-2026-07-12-0122"
let anvil_vstd_latest = "=0.0.0-2026-11-22-0344"
let verus_tla_url = "https://github.com/anvil-verifier/verus-tla"
let verus_tla_commit = "8bb157b50b6200296d4b04d1302644d269e29443"

let vstd_bump file =
  Edit.Replace
    {
      file;
      old = Printf.sprintf "vstd = %S" anvil_vstd_pinned;
      by = Printf.sprintf "vstd = %S" anvil_vstd_latest;
    }

let anvil =
  {
    name = "anvil";
    source =
      {
        url = "https://github.com/anvil-verifier/anvil.git";
        commit = "3c95bbbe812dfa488ac59b341932f1858d01f343";
        tag = None;
        sparse = [];
      };
    pinned = Toolchain.Verus "0.2026.07.12.0b42f4c";
    latest = Toolchain.Verus "0.2026.11.22.1ce6a59";
    latest_edits =
      [
        Edit.Replace
          {
            file = "rust-toolchain.toml";
            old = {|channel = "1.96.0"|};
            by = {|channel = "1.100.0"|};
          };
        vstd_bump "Cargo.toml";
        (* verus-tla 8bb157b, checked out next to the checkout with the same
           bump, replaces the git dependency on the same commit. (Edit.Replace
           cannot add a [patch] section: the new text would contain the old.) *)
        Edit.Replace
          {
            file = "Cargo.toml";
            old =
              Printf.sprintf "verus_temporal_logic = { git = %S, rev = \"%s\" }"
                verus_tla_url verus_tla_commit;
            by =
              {|verus_temporal_logic = { path = "../anvil-latest-verus-tla" }|};
          };
      ];
    variants = [];
    pins = [];
    kind =
      Verus
        {
          crate = "verifiable-controllers";
          latest_deps =
            [
              {
                cname = "verus-tla";
                csource =
                  {
                    url = verus_tla_url ^ ".git";
                    commit = verus_tla_commit;
                    tag = None;
                    sparse = [];
                  };
                cedits = [ vstd_bump "Cargo.toml" ];
              };
            ];
        };
  }

(* The six AFP regex entries of AFP 2025-2 and the entries that the sessions
   of every listed entry require, as parent or in [sessions] (computed from
   the ROOT files at fa30b560ab75): [isabelle build] reads every session of
   each [-d] directory, so an entry's other sessions need their entries too
   (Show's [Old_Datatype_Show] needs Datatype_Order_Generator). *)
let afp_regex =
  let entries =
    [
      "Automatic_Refinement";
      "Binomial-Heaps";
      "CAVA_Automata";
      "Coinductive_Languages";
      "Collections";
      "Containers";
      "Datatype_Order_Generator";
      "Deriving";
      "Efficient-Mergesort";
      "Finger-Trees";
      "Formula_Derivatives";
      "Functional-Automata";
      "List-Index";
      "MSO_Regex_Equivalence";
      "Native_Word";
      "Posix-Lexing";
      "Refine_Monadic";
      "Regex_Equivalence";
      "Regular-Sets";
      "Show";
      "SpecCheck";
      "Trie";
      "Word_Lib";
    ]
  in
  {
    name = "afp-regex";
    source =
      {
        url = "https://github.com/isabelle-prover/mirror-afp-2025-2.git";
        commit = "fa30b560ab754bfbb7a721ee45a921d4b3c04358";
        tag = None;
        sparse = List.map (fun e -> "thys/" ^ e) entries;
      };
    pinned = Toolchain.Isabelle "Isabelle2025-2";
    latest = Toolchain.Isabelle "Isabelle2026";
    latest_edits = [];
    variants = [];
    pins = [];
    kind =
      Isabelle_afp
        {
          entries;
          sessions =
            [
              "Regular-Sets";
              "Regex_Equivalence";
              "Posix-Lexing";
              "Formula_Derivatives";
              "Formula_Derivatives-Examples";
              "MSO_Regex_Equivalence";
              "Functional-Automata";
            ];
        };
  }

let all =
  [
    warblre; linden; lean_regex; pulse_examples; why3_gallery; anvil; afp_regex;
  ]

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

let checkout_source l s dir =
  let build = Layout.build l in
  let git args = Command.v ~cwd:dir "git" args in
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

let checkout l t dir = checkout_source l t.source dir
let dep_dir d c = d ^ "-" ^ c.cname

(* Isabelle: [-j] sessions in parallel with [threads] each, from the run's
   jobs: 8 jobs give [-j 2 -o threads=4], as the plan fixes. *)
let isabelle_parallel n =
  let threads = min n 4 in
  [
    "-j";
    string_of_int (max 1 (Int.div n threads));
    "-o";
    Printf.sprintf "threads=%d" threads;
  ]

let isabelle_dirs d entries =
  List.concat_map (fun e -> [ "-d"; d / "thys" / e ]) entries

let isabelle_build_options = [ "-b"; "-o"; "document=false" ]
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
  | Why3_gallery | Verus _ | Isabelle_afp _ -> []

let clean l t side v =
  let d = dir l t side v in
  match t.kind with
  | Pulse ->
      [
        Step.run "make clean"
          (Toolchain.command l (toolchain t side) ~cwd:d "make"
             (lits [ "-C"; pulse_examples_dir; "clean" ]));
      ]
  | Rocq _ | Lean | Why3_gallery | Isabelle_afp _ ->
      List.map (fun p -> Step.Remove (d / p)) (outputs t)
  | Verus { crate; _ } ->
      [
        Step.run
          ("cargo clean -p " ^ crate)
          (Toolchain.command l (toolchain t side) ~cwd:d "cargo"
             (lits [ "clean"; "-p"; crate ]));
      ]

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
    | Verus _ ->
        (* Dependencies built and verified ([vstd], [verus_temporal_logic],
           the kube crates); the measured crate type-checked only. *)
        [
          Step.run "cargo fetch"
            (Toolchain.command l tc ~cwd:d "cargo" (lits [ "fetch" ]));
          Step.run "cargo verus verify, dependencies"
            (Toolchain.command l tc ~cwd:d "cargo"
               (lits
                  [
                    "verus";
                    "verify";
                    "--fwd-verus-args-to";
                    "roots";
                    "--lib";
                    "-j";
                    jobs lim;
                    "--";
                    "--no-verify";
                  ]));
        ]
    | Isabelle_afp { entries; sessions } ->
        let isabelle label args =
          Step.run label (Toolchain.command l tc ~cwd:d "isabelle" (lits args))
        in
        let selection =
          isabelle_dirs d entries @ [ "-R" ]
          @ List.concat_map (fun s -> [ "-x"; s ]) sessions
          @ sessions
        in
        [
          isabelle "isabelle sessions, requirements" ("sessions" :: selection);
          isabelle "isabelle build, requirements"
            ([ "build" ] @ isabelle_build_options
            @ isabelle_parallel (lim : Limits.t).jobs
            @ selection);
        ]
  in
  let deps_checkouts =
    match (t.kind, side) with
    | Verus { latest_deps; _ }, Latest ->
        List.concat_map
          (fun c ->
            let cd = dep_dir d c in
            checkout_source l c.csource cd
            @ [
                Step.Edit
                  { label = "edits " ^ c.cname; dir = cd; edits = c.cedits };
              ])
          latest_deps
    | _ -> []
  in
  checkout l t d @ deps_checkouts @ edit_steps @ deps @ clean l t side v

(* The cargo fingerprints of [crate]'s library in [target/*/.fingerprint]. *)
let crate_fingerprints d crate =
  let target = d / "target" in
  let entries p = try Array.to_list (Sys.readdir p) with Sys_error _ -> [] in
  let prefix = String.map (function '-' -> '_' | c -> c) crate ^ "-" in
  let prefix' = crate ^ "-" in
  List.concat_map
    (fun profile ->
      let fp = "target" / profile / ".fingerprint" in
      List.filter_map
        (fun e ->
          if
            String.starts_with ~prefix e || String.starts_with ~prefix:prefix' e
          then Some (fp / e)
          else None)
        (entries (d / fp)))
    (List.filter (fun p -> Sys.is_directory (target / p)) (entries target))

let stale l t side v =
  let d = dir l t side v in
  match t.kind with
  | Verus { crate; _ } -> crate_fingerprints d crate
  | _ -> List.filter (fun p -> Sys.file_exists (d / p)) (outputs t)

let measured l lim t side v =
  let d = dir l t side v in
  let tc = toolchain t side in
  let run ?env ?on_failure ?(cwd = d) label prog args =
    Step.run ?on_failure label (Toolchain.command l tc ?env ~cwd prog args)
  in
  match t.kind with
  | Rocq { rocqchk; dune_targets } ->
      Ok
        [
          run "dune build"
            ~env:[ Command.Set ("DUNE_CACHE", "disabled") ]
            "dune"
            (lits ([ "build"; "-j"; jobs lim ] @ dune_targets));
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
  | Verus _ ->
      Ok
        [
          run "cargo verus verify" "cargo"
            (lits
               [
                 "verus";
                 "verify";
                 "--fwd-verus-args-to";
                 "roots";
                 "--lib";
                 "-j";
                 jobs lim;
                 "--";
                 "--num-threads";
                 jobs lim;
                 "--time-expanded";
               ]);
        ]
  | Isabelle_afp { entries; sessions } ->
      (* Coinductive_Languages requires Regular-Sets: it is built here, and
         named so that -c rebuilds it too. *)
      Ok
        [
          run "isabelle build" "isabelle"
            (lits
               ([ "build" ] @ isabelle_build_options
              @ isabelle_parallel lim.jobs @ [ "-c" ] @ isabelle_dirs d entries
              @ sessions
               @ [ "Coinductive_Languages" ]));
        ]

let failure_format t =
  match t.kind with
  | Rocq _ -> Failures.Dune_rocq
  | Lean -> Failures.Lake
  | Pulse -> Failures.Fstar
  | Why3_gallery -> Failures.Failed_steps
  | Verus _ -> Failures.Rustc
  | Isabelle_afp _ -> Failures.Isabelle

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
  | Verus { latest_deps; _ } -> (
      [ git [ "diff" ] ]
      @
      match side with
      | Pinned -> []
      | Latest ->
          List.concat_map
            (fun c ->
              let cd = dep_dir d c in
              [
                Command.v ~cwd:cd "git" [ "rev-parse"; "HEAD" ];
                Command.v ~cwd:cd "git" [ "diff" ];
              ])
            latest_deps)
  | _ -> []
