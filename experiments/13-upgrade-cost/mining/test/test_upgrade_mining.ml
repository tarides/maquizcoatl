open Upgrade_mining

let strings = Alcotest.(list string)
let check_bool msg expected actual = Alcotest.(check bool) msg expected actual

let raises_failure f =
  match f () with _ -> false | exception Failure _ -> true

(* Glob *)

let test_glob () =
  check_bool "star in segment" true (Glob.matches "*.opam" "warblre.opam");
  check_bool "star stops at slash" false (Glob.matches "*.opam" "sub/x.opam");
  check_bool "double star, zero dirs" true
    (Glob.matches "**/Cargo.toml" "Cargo.toml");
  check_bool "double star, dirs" true
    (Glob.matches "**/Cargo.toml" "e2e/sub/Cargo.toml");
  check_bool "workflow" true
    (Glob.matches ".github/workflows/*.yml" ".github/workflows/ci.yml");
  check_bool "question mark" true (Glob.matches "a?c" "abc");
  check_bool "question mark not slash" false (Glob.matches "a?c" "a/c");
  check_bool "exact" false
    (Glob.matches "lean-toolchain" "regex/lean-toolchain");
  check_bool "under itself" true (Glob.under "lib/cbor" "lib/cbor");
  check_bool "under child" true (Glob.under "lib/cbor" "lib/cbor/a.fst");
  check_bool "not a prefix of a name" false
    (Glob.under "lib/cbor" "lib/cbor2/a");
  check_bool "trailing double star" true (Glob.matches "lib/**" "lib/a/b.fst");
  check_bool "trailing double star needs the slash" false
    (Glob.matches "lib/**" "lib");
  check_bool "double star alone" true (Glob.matches "**" "a/b/c");
  check_bool "double star inside a name is a star" false
    (Glob.matches "a**z" "a/b/z");
  check_bool "double star inside a name, one segment" true
    (Glob.matches "a**z" "abz");
  check_bool "double star after a name is a star" false
    (Glob.matches "a**/b" "a/x/b");
  check_bool "inner double star, zero dirs" true (Glob.matches "a/**/b" "a/b");
  check_bool "inner double star, dirs" true (Glob.matches "a/**/b" "a/x/y/b");
  check_bool "F* sources" true (Glob.matches "**/*.fst" "src/lowparse/A.fst");
  check_bool "F* sources, top level" true (Glob.matches "**/*.fst" "A.fst");
  check_bool "F* interfaces are another pattern" false
    (Glob.matches "**/*.fst" "A.fsti")

(* Numstat *)

let numstat_output =
  "3\t1\tsrc/a.lean\000-\t-\timg.png\000\00010\t0\tlake-manifest.json\000"

let test_numstat () =
  let entries = Numstat.parse numstat_output in
  Alcotest.(check int) "entries" 3 (List.length entries);
  Alcotest.(check (list string))
    "path with a tab and non-ASCII characters" [ "thys/Café/a\tb.thy" ]
    (List.map
       (fun (e : Numstat.entry) -> e.path)
       (Numstat.parse "1\t0\tthys/Café/a\tb.thy\000"));
  let t = Numstat.totals entries in
  Alcotest.(check (list int))
    "totals" [ 3; 13; 1 ]
    [ t.files; t.added; t.removed ];
  let kept =
    List.filter
      (Numstat.keep ~under:[] ~only:[] ~exclude:[ "**/lake-manifest.json" ])
      entries
  in
  Alcotest.(check int) "excluded" 2 (List.length kept);
  let under =
    List.filter (Numstat.keep ~under:[ "src" ] ~only:[] ~exclude:[]) entries
  in
  Alcotest.(check int) "under" 1 (List.length under);
  let only =
    List.filter
      (Numstat.keep ~under:[] ~only:[ "**/*.lean"; "*.png" ] ~exclude:[])
      entries
  in
  Alcotest.(check int) "only" 2 (List.length only);
  check_bool "bad record" true
    (raises_failure (fun () -> Numstat.parse "1\t2\000"))

(* Repo *)

let test_parse_log () =
  let commits =
    Repo.parse_log
      "h1\x1fp1 p2\x1f2025-11-20\x1fMerge #1\x1fbody line\n\n\
       \x1e\n\
       h2\x1f\x1f2025-11-21\x1fInit\x1f\x1e\n"
  in
  Alcotest.(check (list (pair string (list string))))
    "hashes and parents"
    [ ("h1", [ "p1"; "p2" ]); ("h2", []) ]
    (List.map (fun (c : Repo.commit) -> (c.hash, c.parents)) commits);
  Alcotest.(check (list string))
    "bodies" [ "body line"; "" ]
    (List.map (fun (c : Repo.commit) -> c.body) commits);
  check_bool "bad record" true
    (match Repo.parse_log "h1\x1fp1\x1e" with
    | _ -> false
    | exception Repo.Git_error _ -> true)

(* Releases and tools *)

let releases_tsv =
  "version\tdate\tprerelease\tsource\n\
   v4.24.0\t2025-10-14\tfalse\tx\n\
   v4.25.0-rc1\t2025-10-21\ttrue\tx\n\
   v4.25.0\t2025-11-14\tfalse\tx\n\
   v4.25.1\t2025-11-25\tfalse\tx\n\
   v4.26.0-rc1\t2025-11-18\ttrue\tx\n\
   v4.26.0\t2025-12-13\tfalse\tx\n\
   v4.27.0\t2026-01-23\tfalse\tx\n"

let lean ?(until = "2025-12-31") () =
  Tool.make ~name:"lean" ~scheme:Tool.Minor ~prefixes:[ "leanprover/lean4:" ]
    ~until
    (Release.parse_tsv releases_tsv)

let release t v =
  match Tool.find t v with
  | Some r -> r
  | None -> Alcotest.failf "no release %s" v

let test_release_parse () =
  Alcotest.(check int) "count" 7 (List.length (Release.parse_tsv releases_tsv));
  check_bool "bad header" true
    (raises_failure (fun () -> Release.parse_tsv "tag\tdate\n"));
  check_bool "bad flag" true
    (raises_failure (fun () ->
         Release.parse_tsv "version\tdate\tprerelease\nv1\t2025-01-01\tyes\n"))

let test_tool () =
  let t = lean () in
  Alcotest.(check string)
    "normalise" "4.25.0"
    (Tool.normalise t "leanprover/lean4:v4.25.0");
  check_bool "find with prefix" true
    (Tool.find t "leanprover/lean4:v4.26.0-rc1" <> None);
  check_bool "after the snapshot date" true (Tool.find t "v4.27.0" = None);
  let span a b = Tool.spanned t ~from:[ release t a ] ~to_:[ release t b ] in
  Alcotest.(check (option int))
    "two series" (Some 2)
    (span "v4.24.0" "v4.26.0-rc1");
  Alcotest.(check (option int))
    "rc to stable" (Some 0)
    (span "v4.26.0-rc1" "v4.26.0");
  Alcotest.(check (option int)) "patch" (Some 0) (span "v4.25.0" "v4.25.1");
  Alcotest.(check (option int))
    "unknown" None
    (Tool.spanned t ~from:[] ~to_:[ release t "v4.25.0" ]);
  Alcotest.(check int) "cadence" 2 (Tool.cadence t ~since:"2025-10-15");
  Alcotest.(check int)
    "cadence, stable release on the start date" 2
    (Tool.cadence t ~since:"2025-11-14");
  Alcotest.(check int)
    "cadence, by first stable release" 1
    (Tool.cadence t ~since:"2025-11-15");
  Alcotest.(check int)
    "cadence, series with a pre-release only" 2
    (Tool.cadence
       (Tool.make ~name:"lean" ~scheme:Tool.Minor ~prefixes:[]
          ~until:"2026-12-31"
          (Release.parse_tsv
             (releases_tsv ^ "v4.28.0-rc1\t2026-02-01\ttrue\tx\n")))
       ~since:"2025-12-01");
  match Tool.earliest t [ "v4.26.0"; "other"; "v4.25.1" ] with
  | Some r -> Alcotest.(check string) "earliest" "v4.25.1" r.version
  | None -> Alcotest.fail "earliest"

let test_tool_exact () =
  let t =
    Tool.make ~name:"verus" ~scheme:Tool.Exact
      ~prefixes:[ "release/rolling/"; "release/" ]
      ~until:"2026-12-31"
      (Release.parse_tsv
         "version\tdate\tprerelease\n\
          release/0.2026.01.01.aaa\t2026-01-01\tfalse\n\
          release/rolling/0.2026.01.05.bbb\t2026-01-05\ttrue\n\
          release/0.2026.01.08.ccc\t2026-01-08\tfalse\n")
  in
  check_bool "find pinned value" true (Tool.find t "0.2026.01.08.ccc" <> None);
  Alcotest.(check (option int))
    "pre-releases not counted" (Some 1)
    (Tool.spanned t
       ~from:[ release t "0.2026.01.01.aaa" ]
       ~to_:[ release t "0.2026.01.08.ccc" ])

(* Pins *)

let test_pin_formats () =
  Alcotest.check strings "whole file"
    [ "leanprover/lean4:v4.25.0" ]
    (Pin.read Pin.Whole_file "leanprover/lean4:v4.25.0\n");
  Alcotest.check strings "make var" [ "c6895237" ]
    (Pin.read (Pin.Make_var "FStar_hash")
       "KaRaMeL_hash := 1234\nFStar_hash := c6895237\n");
  Alcotest.check strings "yaml inline list" [ "9.1.1"; "9.2.0" ]
    (Pin.read (Pin.Yaml_list "rocq")
       "matrix:\n\
       \  # rocq: [ \"8.0\" ]\n\
       \  rocq: [ \"9.1.1\", \"9.2.0\" ] # tested\n");
  Alcotest.check strings "yaml block list" [ "9.0.1"; "9.1.1" ]
    (Pin.read (Pin.Yaml_list "rocq")
       "rocq:\n  - \"9.0.1\"\n  - 9.1.1\nocaml: 5.3\n");
  Alcotest.check strings "yaml scalar" [ "0.2026.07.12.0b42f4c" ]
    (Pin.read (Pin.Yaml_scalar "VERUS_TAG")
       "env:\n  VERUS_TAG: \"0.2026.07.12.0b42f4c\" # pinned\n");
  Alcotest.check strings "opam constraint" [ ">= 9.0.0"; "" ]
    (Pin.read (Pin.Opam_dep "rocq-core")
       "depends: [\n  \"rocq-core\" {>= \"9.0.0\"}\n  \"rocq-core\"\n]\n");
  Alcotest.check strings "opam other package, comments" [ "= git-89dd8721" ]
    (Pin.read (Pin.Opam_dep "why3find")
       "depends: [\n\
       \  \"why3\" {= \"git-05bf4ddf\"}\n\
       \  \"why3-ide\" {= \"git-05bf4ddf\" & !?in-creusot-ci}\n\
       \  \"why3find\" {= \"git-89dd8721\"} # update the urls too\n\
        # optional dependencies of why3\n\
       \  \"ocamlgraph\"\n\
        ]\n\
        pin-depends: [ [ \"why3find.git-89dd8721\" \"git+https://x\" ] ]\n");
  Alcotest.check strings "opam constraint over several lines"
    [ ">= 9.0 & < 9.2" ]
    (Pin.read (Pin.Opam_dep "rocq-core")
       "depends: [\n  \"rocq-core\" {>= \"9.0\" &\n   < \"9.2\"}\n]\n");
  Alcotest.check strings "opam: depends field only" [ "= 9.1.1" ]
    (Pin.read (Pin.Opam_dep "rocq-core")
       "# \"rocq-core\" {= \"8.0\"}\n\
        depends: [ (* \"rocq-core\" {= \"8.1\"} *) \"rocq-core\" {= \"9.1.1\"} ]\n\
        conflicts: [ \"rocq-core\" {< \"9.0\"} ]\n");
  check_bool "opam: unterminated constraint" true
    (raises_failure (fun () ->
         Pin.read (Pin.Opam_dep "rocq-core")
           "depends: [ \"rocq-core\" {>= \"9.0\" ]\n"));
  Alcotest.check strings "yaml block list with a comment" [ "9.0.1"; "9.1.1" ]
    (Pin.read (Pin.Yaml_list "rocq")
       "rocq:\n  # - \"8.20\"\n  - \"9.0.1\"\n\n  - \"9.1.1\"\n");
  Alcotest.check strings "make var, export and comment" [ "abc" ]
    (Pin.read (Pin.Make_var "FStar_hash")
       "# FStar_hash := old\nexport FStar_hash := abc # pinned\n");
  Alcotest.check strings "quoted hash sign" [ "a #b" ]
    (Pin.read (Pin.Yaml_scalar "key") "key: \"a #b\" # comment\n");
  Alcotest.check strings "toml string" [ "1.98.0" ]
    (Pin.read (Pin.Toml_string "channel") "[toolchain]\nchannel = \"1.98.0\"\n");
  Alcotest.check strings "toml inline table"
    [ "{ git = \"https://x\" }" ]
    (Pin.read (Pin.Toml_string "vstd") "vstd = { git = \"https://x\" }\n")

let test_pin_values () =
  let pin =
    {
      Pin.files = [ "*.opam" ];
      format = Pin.Opam_dep "why3";
      strip = [ "= git-"; "=" ];
      resolve = Pin.Opaque;
    }
  in
  Alcotest.check strings "strip, dedup, file filter" [ "05bf4ddf" ]
    (Pin.values pin
       [
         ("a.opam", "depends: [ \"why3\" {= \"git-05bf4ddf\"} ]");
         ("b.opam", "depends: [ \"why3\" {= \"git-05bf4ddf\"} ]");
         ("sub/c.opam", "depends: [ \"why3\" {= \"git-ffffffff\"} ]");
       ]);
  Alcotest.(check (list (pair string strings)))
    "per file"
    [ ("a.opam", [ "05bf4ddf" ]); ("b.opam", []) ]
    (Pin.file_values pin
       [
         ("b.opam", "depends: [ ]");
         ("a.opam", "depends: [ \"why3\" {= \"git-05bf4ddf\"} ]");
       ]);
  Alcotest.(check string)
    "error names the file" "x.opam: opam: unterminated depends field"
    (match Pin.values pin [ ("x.opam", "depends: [ \"why3\"") ] with
    | _ -> ""
    | exception Failure msg -> msg)

(* Mining, on an in-memory repository *)

type fake_commit = {
  hash : string;
  parent : string option;
  date : string;
  subject : string;
  tree : (string * string) list;
}

let commit ?parent ~date ~subject hash tree =
  { hash; parent; date; subject; tree }

(* Line-level numstat between two trees: a changed file counts its new lines
   as added and its old lines as removed. *)
let diff a b =
  let lines s = List.length (String.split_on_char '\n' (String.trim s)) in
  let paths = List.sort_uniq compare (List.map fst a @ List.map fst b) in
  List.filter_map
    (fun path ->
      match (List.assoc_opt path a, List.assoc_opt path b) with
      | Some x, Some y when x = y -> None
      | x, y ->
          let count = function Some s -> Some (lines s) | None -> Some 0 in
          Some { Numstat.path; added = count y; removed = count x })
    paths

let fake ?(tags = []) ?(authors = []) commits =
  let find h = List.find (fun c -> c.hash = h) commits in
  let tree h = (find h).tree in
  let to_commit c =
    {
      Repo.hash = c.hash;
      parents = Option.to_list c.parent;
      date = c.date;
      subject = c.subject;
      body = "";
    }
  in
  {
    Repo.first_parent_log =
      (fun ~head:_ ~since ~until ~paths ->
        List.filter
          (fun c ->
            since <= c.date && c.date <= until
            && (paths = []
               ||
               let before = Option.fold ~none:[] ~some:tree c.parent in
               List.exists
                 (fun (e : Numstat.entry) ->
                   List.exists (fun p -> Glob.matches p e.path) paths)
                 (diff before c.tree)))
          commits
        |> List.map to_commit);
    files = (fun h -> List.map fst (tree h));
    show = (fun h path -> List.assoc path (tree h));
    numstat = (fun a b -> diff (tree a) (tree b));
    tags_containing =
      (fun h ->
        if List.mem_assoc h tags then Some (List.assoc h tags) else None);
    authors =
      (fun ~since:_ ~until:_ path ->
        List.assoc_opt path authors |> Option.value ~default:[]);
  }

let lean_pin =
  {
    Pin.files = [ "regex/lean-toolchain"; "correctness/lean-toolchain" ];
    format = Pin.Whole_file;
    strip = [];
    resolve = Pin.Release;
  }

let history ?(keywords = []) ?(periods = []) ?(under = []) ?(only = [])
    ?(head = "c5") pins =
  Project.History
    {
      head;
      pins;
      under;
      only;
      exclude = [ "**/lake-manifest.json" ];
      keywords;
      keyword_periods = periods;
    }

let project mode = { Project.name = "p"; tool = "lean"; clone = "p"; mode }
let tc v = "leanprover/lean4:" ^ v

let lean_history =
  [
    commit "c0" ~date:"2025-10-20" ~subject:"init"
      [
        ("regex/lean-toolchain", tc "v4.24.0");
        ("correctness/lean-toolchain", tc "v4.24.0");
        ("a.lean", "x");
      ];
    commit "c1" ~parent:"c0" ~date:"2025-11-20" ~subject:"bump regex"
      [
        ("regex/lean-toolchain", tc "v4.25.0");
        ("correctness/lean-toolchain", tc "v4.24.0");
        ("a.lean", "y\nz");
        ("regex/lake-manifest.json", "m");
      ];
    commit "c2" ~parent:"c1" ~date:"2025-11-21" ~subject:"bump the rest"
      [
        ("regex/lean-toolchain", tc "v4.25.0");
        ("correctness/lean-toolchain", tc "v4.25.0");
        ("a.lean", "y\nz");
        ("regex/lake-manifest.json", "m");
      ];
    commit "c3" ~parent:"c2" ~date:"2025-11-22"
      ~subject:"fix proofs after upgrade"
      [
        ("regex/lean-toolchain", tc "v4.25.0");
        ("correctness/lean-toolchain", tc "v4.25.0");
        ("a.lean", "w");
        ("regex/lake-manifest.json", "m");
      ];
    commit "c4" ~parent:"c3" ~date:"2025-12-14" ~subject:"v4.26.0"
      [
        ("regex/lean-toolchain", tc "v4.26.0");
        ("correctness/lean-toolchain", tc "v4.26.0");
        ("a.lean", "w");
        ("regex/lake-manifest.json", "m2");
      ];
  ]

let mine ?keywords ?periods ?under ?only ?(pins = [ lean_pin ]) commits =
  Mine.run
    (project (history ?keywords ?periods ?under ?only pins))
    ~tool:(lean ())
    ~clones:(fun _ -> fake commits)
    ~since:"2025-11-19" ~until:"2025-12-31"

let test_mine_grouping () =
  let rows = mine lean_history in
  Alcotest.(check (list (list string)))
    "units"
    [ [ "c1"; "c2" ]; [ "c4" ] ]
    (List.map (fun (r : Mine.row) -> r.units) rows);
  match rows with
  | [ first; second ] ->
      Alcotest.check strings "reached" [ "v4.25.0" ] first.reached;
      Alcotest.(check (option int)) "spanned" (Some 1) first.spanned;
      Alcotest.(check (list int))
        "pin files and lockfiles not measured" [ 1; 2; 1 ]
        [ first.totals.files; first.totals.added; first.totals.removed ];
      Alcotest.check strings "second reached" [ "v4.26.0" ] second.reached;
      Alcotest.(check int) "second measures nothing" 0 second.totals.files
  | _ -> Alcotest.fail "two rows expected"

let test_mine_keywords () =
  let rows = mine ~keywords:[ "fix proofs" ] lean_history in
  Alcotest.(check (list string))
    "kinds"
    [ "bump"; "keyword"; "bump" ]
    (List.map (fun (r : Mine.row) -> Mine.kind_to_string r.kind) rows);
  let kinds periods =
    mine ~keywords:[ "fix proofs" ] ~periods lean_history
    |> List.map (fun (r : Mine.row) -> Mine.kind_to_string r.kind)
  in
  Alcotest.(check (list string))
    "keyword period, both ends included"
    [ "bump"; "keyword"; "bump" ]
    (kinds [ ("2025-11-22", "2025-11-22") ]);
  Alcotest.(check (list string))
    "outside the keyword periods" [ "bump"; "bump" ]
    (kinds [ ("2025-11-23", "2025-12-31"); ("2025-01-01", "2025-11-21") ])

let units rows = List.map (fun (r : Mine.row) -> r.units) rows

(* A selected unit between the two halves of an upgrade keeps them apart. *)
let test_mine_unit_between () =
  let commits =
    match lean_history with
    | c0 :: c1 :: c2 :: rest ->
        let between =
          commit "k" ~parent:"c1" ~date:"2025-11-20"
            ~subject:"fix proofs for v4.25.0" c1.tree
        in
        c0 :: c1 :: between :: { c2 with parent = Some "k" } :: rest
    | _ -> Alcotest.fail "lean_history"
  in
  Alcotest.(check (list (list string)))
    "units"
    [ [ "c1" ]; [ "k" ]; [ "c2" ]; [ "c3" ]; [ "c4" ] ]
    (units (mine ~keywords:[ "fix proofs" ] commits))

(* A bump of an opaque pin months after a release bump, with nothing selected
   in between, does not join it. *)
let test_mine_opaque_after_release () =
  let pins =
    [
      {
        Pin.files = [ "ci.yml" ];
        format = Pin.Yaml_scalar "lean";
        strip = [];
        resolve = Pin.Release;
      };
      {
        Pin.files = [ "rust-toolchain.toml" ];
        format = Pin.Toml_string "channel";
        strip = [];
        resolve = Pin.Opaque;
      };
    ]
  in
  let tree lean channel =
    [
      ("ci.yml", "lean: " ^ lean);
      ("rust-toolchain.toml", "channel = \"" ^ channel ^ "\"");
    ]
  in
  let commits =
    [
      commit "c0" ~date:"2025-10-01" ~subject:"init" (tree "v4.24.0" "1.0");
      commit "c1" ~parent:"c0" ~date:"2025-11-20" ~subject:"bump"
        (tree "v4.25.0" "1.0");
      commit "c2" ~parent:"c1" ~date:"2025-12-30" ~subject:"rust"
        (tree "v4.25.0" "1.1");
    ]
  in
  Alcotest.(check (list (list string)))
    "units" [ [ "c1" ]; [ "c2" ] ]
    (units (mine ~pins commits))

(* Dropping an old version from a CI matrix does not complete the bump that
   added the new one. *)
let test_mine_matrix_shrink () =
  let pins =
    [
      {
        Pin.files = [ "ci.yml" ];
        format = Pin.Yaml_list "lean";
        strip = [];
        resolve = Pin.Release;
      };
    ]
  in
  let commits =
    [
      commit "c0" ~date:"2025-10-01" ~subject:"init"
        [ ("ci.yml", "lean: [v4.24.0]") ];
      commit "c1" ~parent:"c0" ~date:"2025-11-20" ~subject:"test 4.25"
        [ ("ci.yml", "lean: [v4.24.0, v4.25.0]") ];
      commit "c2" ~parent:"c1" ~date:"2025-11-21" ~subject:"drop 4.24"
        [ ("ci.yml", "lean: [v4.25.0]") ];
    ]
  in
  let rows = mine ~pins commits in
  Alcotest.(check (list (list string)))
    "units" [ [ "c1" ]; [ "c2" ] ] (units rows);
  Alcotest.(check (list (list string)))
    "reached" [ [ "v4.25.0" ]; [] ]
    (List.map (fun (r : Mine.row) -> r.reached) rows);
  Alcotest.(check (list (option string)))
    "a shrink reaches no series" [ Some "4.25"; None ]
    (List.map (fun (r : Mine.row) -> r.to_series) rows)

(* A file that is rewritten with the same pin value is not a bump; a pin
   removed after a release was reached does not join that release's row. *)
let test_mine_no_change () =
  let pin = { lean_pin with files = [ "lean-toolchain" ] } in
  let commits =
    [
      commit "c0" ~date:"2025-10-01" ~subject:"init"
        [ ("lean-toolchain", tc "v4.24.0") ];
      commit "c1" ~parent:"c0" ~date:"2025-11-20" ~subject:"reformat"
        [ ("lean-toolchain", tc "v4.24.0" ^ "\n") ];
      commit "c2" ~parent:"c1" ~date:"2025-11-21" ~subject:"bump"
        [ ("lean-toolchain", tc "v4.25.0") ];
      commit "c3" ~parent:"c2" ~date:"2025-11-22" ~subject:"unpin" [];
    ]
  in
  let rows =
    Mine.run
      (project (history [ pin ]))
      ~tool:(lean ())
      ~clones:(fun _ -> fake commits)
      ~since:"2025-11-19" ~until:"2025-12-31"
  in
  Alcotest.(check (list (list string)))
    "units" [ [ "c2" ]; [ "c3" ] ]
    (List.map (fun (r : Mine.row) -> r.units) rows)

let test_mine_commit_pin () =
  let pin =
    {
      Pin.files = [ "deps.mk" ];
      format = Pin.Make_var "TOOL_hash";
      strip = [];
      resolve = Pin.Commit "tool";
    }
  in
  let commits =
    [
      commit "c0" ~date:"2025-10-01" ~subject:"init"
        [ ("deps.mk", "TOOL_hash := aaa") ];
      commit "c1" ~parent:"c0" ~date:"2025-11-20" ~subject:"advance"
        [ ("deps.mk", "TOOL_hash := bbb") ];
      commit "c2" ~parent:"c1" ~date:"2025-11-22" ~subject:"same release"
        [ ("deps.mk", "TOOL_hash := bbc") ];
      commit "c3" ~parent:"c2" ~date:"2025-11-25" ~subject:"advance again"
        [ ("deps.mk", "TOOL_hash := ccc") ];
      commit "c4" ~parent:"c3" ~date:"2025-11-26" ~subject:"lost commit"
        [ ("deps.mk", "TOOL_hash := ddd") ];
    ]
  in
  (* "ddd" is missing from the tool's clone. *)
  let tool_repo =
    fake
      ~tags:
        [
          ("aaa", [ "v4.24.0"; "v4.25.0" ]);
          ("bbb", [ "v4.25.0" ]);
          ("bbc", [ "v4.25.0" ]);
          ("ccc", []);
        ]
      []
  in
  let lookups = ref 0 in
  let tool_repo =
    {
      tool_repo with
      tags_containing =
        (fun c ->
          incr lookups;
          tool_repo.tags_containing c);
    }
  in
  let rows =
    Mine.run
      (project (history [ pin ]))
      ~tool:(lean ())
      ~clones:(function "tool" -> tool_repo | _ -> fake commits)
      ~since:"2025-11-19" ~until:"2025-12-31"
  in
  Alcotest.(check (list (list string)))
    "reached"
    [ [ "v4.25.0" ]; []; [ "unreleased" ]; [ "unknown-commit" ] ]
    (List.map (fun (r : Mine.row) -> r.reached) rows);
  Alcotest.(check (list (option int)))
    "spanned"
    [ Some 1; Some 0; None; None ]
    (List.map (fun (r : Mine.row) -> r.spanned) rows);
  Alcotest.(check int) "one lookup per pinned commit" 5 !lookups

let test_mine_snapshots () =
  let commits =
    [
      commit "r1" ~date:"2025-10-14" ~subject:""
        [ ("thys/A/a.thy", "x"); ("thys/B/b.thy", "y") ];
      commit "r2" ~date:"2025-11-14" ~subject:""
        [ ("thys/A/a.thy", "x\nx"); ("thys/B/b.thy", "y") ];
    ]
  in
  let rows =
    Mine.run
      (project
         (Project.Snapshots
            {
              refs = [ ("v4.24.0", "r1"); ("v4.25.0", "r2") ];
              paths = [ "thys/A"; "thys/B" ];
              exclude_snapshot = [];
              authors_from = Some "devel";
            }))
      ~tool:(lean ())
      ~clones:(function
        | "devel" -> fake ~authors:[ ("thys/A", [ "nipkow" ]) ] []
        | _ -> fake commits)
      ~since:"2025-01-01" ~until:"2025-12-31"
  in
  Alcotest.(check (list int))
    "lines per path" [ 3; 0 ]
    (List.map (fun (r : Mine.row) -> r.totals.added + r.totals.removed) rows);
  Alcotest.(check (list (list string)))
    "authors" [ [ "nipkow" ]; [] ]
    (List.map (fun (r : Mine.row) -> r.authors) rows);
  Alcotest.(check (list string))
    "one per-release line for the release pair"
    [
      "project,tool,series,units,date,reached,releases_spanned,files,added,removed,lines_per_release";
      "p,lean,4.25,v4.24.0..v4.25.0,2025-11-14,v4.25.0,1,1,2,1,3.0";
    ]
    (String.split_on_char '\n'
       (String.trim
          (Report.per_release_csv
             [ { Report.project = "p"; tool = lean (); rows; missing = [] } ])));
  check_bool "missing release" true
    (raises_failure (fun () ->
         Mine.run
           (project
              (Project.Snapshots
                 {
                   refs = [ ("v9", "r1"); ("v4.25.0", "r2") ];
                   paths = [];
                   exclude_snapshot = [];
                   authors_from = None;
                 }))
           ~tool:(lean ())
           ~clones:(fun _ -> fake commits)
           ~since:"2025-01-01" ~until:"2025-12-31"))

(* Report *)

let test_csv () =
  Alcotest.(check string) "plain" "abc" (Report.csv_field "abc");
  Alcotest.(check string) "comma" "\"a,b\"" (Report.csv_field "a,b");
  Alcotest.(check string)
    "quote" "\"say \"\"hi\"\"\""
    (Report.csv_field "say \"hi\"")

let csv_lines s = String.split_on_char '\n' (String.trim s)

let test_rows_csv () =
  Alcotest.(check (list string))
    "lines"
    [
      "project,kind,units,date,subject,from,to,reached,releases_spanned,files,added,removed,authors,class";
      "p,bump,c1; c2,2025-11-21,bump the \
       rest,leanprover/lean4:v4.24.0,leanprover/lean4:v4.25.0,v4.25.0,1,1,2,1,,";
      "p,bump,c4,2025-12-14,v4.26.0,leanprover/lean4:v4.25.0,leanprover/lean4:v4.26.0,v4.26.0,1,0,0,0,,";
    ]
    (csv_lines (Report.rows_csv (mine lean_history)))

let test_per_release () =
  let rows = mine lean_history in
  let csv =
    Report.per_release_csv
      [ { Report.project = "p"; tool = lean (); rows; missing = [] } ]
  in
  Alcotest.(check (list string))
    "lines"
    [
      "project,tool,series,units,date,reached,releases_spanned,files,added,removed,lines_per_release";
      "p,lean,4.25,c1; c2,2025-11-21,v4.25.0,1,1,2,1,3.0";
      "p,lean,4.26,c4,2025-12-14,v4.26.0,1,0,0,0,0.0";
    ]
    (csv_lines csv)

let row ?(kind = Mine.Bump) ~units ?to_series ?spanned ?(date = "2025-12-01")
    lines =
  {
    Mine.project = "q";
    kind;
    units;
    date;
    subject = "";
    from_ = [];
    to_ = [];
    reached = [];
    to_series;
    spanned;
    totals = { files = 1; added = lines; removed = 0 };
    authors = [];
  }

(* A release candidate then the stable release: one series. A downgrade, a
   row that reaches no series, and a series that spans no release are
   unattributed; keyword rows are not measured. *)
let series_rows =
  [
    row ~units:[ "rc" ] ~to_series:"4.26" ~spanned:1 10;
    row ~units:[ "stable" ] ~to_series:"4.26" ~spanned:0 ~date:"2025-12-13" 4;
    row ~units:[ "down" ] ~to_series:"4.25" ~spanned:(-1) 7;
    row ~units:[ "unreleased" ] 5;
    row ~units:[ "same" ] ~to_series:"4.27" ~spanned:0 3;
    row ~kind:Mine.Keyword ~units:[ "kw" ] 100;
  ]

let test_series_groups () =
  Alcotest.(check (list string))
    "per release"
    [
      "project,tool,series,units,date,reached,releases_spanned,files,added,removed,lines_per_release";
      "q,lean,4.26,rc; stable,2025-12-13,,1,2,14,0,14.0";
      "q,lean,4.27,same,2025-12-01,,0,1,3,0,";
    ]
    (csv_lines
       (Report.per_release_csv
          [
            {
              Report.project = "q";
              tool = lean ();
              rows = series_rows;
              missing = [];
            };
          ]))

let test_summary () =
  let summary =
    Report.summary_md ~since:"2025-11-19" ~until:"2025-12-31"
      [
        {
          Report.project = "q";
          tool = lean ();
          rows = series_rows;
          missing = [];
        };
        {
          Report.project = "p";
          tool = lean ();
          rows = mine lean_history;
          missing = [];
        };
        { Report.project = "empty"; tool = lean (); rows = []; missing = [] };
      ]
  in
  match List.rev (csv_lines summary) with
  | check :: "" :: empty :: p :: q :: _ ->
      check_bool "no missing directory" true
        (String.starts_with
           ~prefix:"Every measured directory holds measured files" check);
      Alcotest.(check string)
        "q"
        "| q | lean | 1 | 5 | 1 | 0 | 1 | 29 | 14.0 | 15 | rc (10 lines, 1 \
         files) |"
        q;
      Alcotest.(check string)
        "p"
        "| p | lean | 1 | 2 | 0 | 0 | 2 | 3 | 1.5 | 0 | c1; c2 (3 lines, 1 \
         files) |"
        p;
      Alcotest.(check string)
        "a project without rows keeps its name"
        "| empty | lean | 1 | 0 | 0 | 0 | 0 | 0 |  | 0 |  |" empty
  | _ -> Alcotest.fail "three lines expected"

(* Review fixes: pins *)

let test_pin_comments () =
  Alcotest.check strings "comment right after the key" [ "9.0.1"; "9.1.1" ]
    (Pin.read (Pin.Yaml_list "rocq")
       "rocq: # tested versions\n  - 9.0.1\n  - 9.1.1\n");
  Alcotest.check strings "scalar that is only a comment" []
    (Pin.read (Pin.Yaml_scalar "VERUS_TAG") "VERUS_TAG: # unpinned\n");
  Alcotest.check strings "make variable that is only a comment" []
    (Pin.read (Pin.Make_var "X") "X := # none\nY := 1\n");
  Alcotest.check strings "empty make variable" []
    (Pin.read (Pin.Make_var "X") "X :=\n");
  Alcotest.check strings "apostrophe opens no quoted string" [ "don't" ]
    (Pin.read (Pin.Yaml_scalar "k") "k: don't # comment\n");
  Alcotest.check strings "quoted item in a flow list" [ "a #b"; "c" ]
    (Pin.read (Pin.Yaml_list "rocq") "rocq: [ \"a #b\", c ] # x\n")

let test_opam_triple_quotes () =
  Alcotest.check strings "triple-quoted description" [ "= 9.1.1" ]
    (Pin.read (Pin.Opam_dep "rocq-core")
       "opam-version: \"2.0\"\n\
        description: \"\"\"It's 6\" long.\"\"\"\n\
        depends: [ \"rocq-core\" {= \"9.1.1\"} ]\n");
  Alcotest.check strings "escape in a triple-quoted string" [ "= 9.1.1" ]
    (Pin.read (Pin.Opam_dep "rocq-core")
       "synopsis: \"\"\"a \\\"\"\" b\"\"\"\n\
        depends: [ \"rocq-core\" {= \"9.1.1\"} ]\n");
  check_bool "unterminated triple-quoted string" true
    (raises_failure (fun () ->
         Pin.read (Pin.Opam_dep "rocq-core") "description: \"\"\"abc\" \"\n"))

(* Review fixes: mining *)

let lean_files = { lean_pin with files = [ "*/lean-toolchain" ] }

(* An upgrade over three pin files: the middle step leaves the values of the
   pin unchanged, but is still a bump, and joins the row. A pin file that
   appears without values is no bump. *)
let test_mine_three_files () =
  let tree a b c extra =
    [
      ("a/lean-toolchain", tc a);
      ("b/lean-toolchain", tc b);
      ("c/lean-toolchain", tc c);
    ]
    @ extra
  in
  let commits =
    [
      commit "c0" ~date:"2025-10-01" ~subject:"init"
        (tree "v4.24.0" "v4.24.0" "v4.24.0" [ ("b.lean", "x") ]);
      commit "c1" ~parent:"c0" ~date:"2025-11-20" ~subject:"a"
        (tree "v4.25.0" "v4.24.0" "v4.24.0" [ ("b.lean", "x") ]);
      commit "c2" ~parent:"c1" ~date:"2025-11-21" ~subject:"b"
        (tree "v4.25.0" "v4.25.0" "v4.24.0" [ ("b.lean", "y") ]);
      commit "c3" ~parent:"c2" ~date:"2025-11-22" ~subject:"c"
        (tree "v4.25.0" "v4.25.0" "v4.25.0" [ ("b.lean", "y") ]);
      commit "c4" ~parent:"c3" ~date:"2025-11-23" ~subject:"empty pin file"
        (tree "v4.25.0" "v4.25.0" "v4.25.0"
           [ ("b.lean", "y"); ("d/lean-toolchain", "") ]);
    ]
  in
  let rows = mine ~pins:[ lean_files ] commits in
  Alcotest.(check (list (list string)))
    "units"
    [ [ "c1"; "c2"; "c3" ] ]
    (units rows);
  Alcotest.(check (list int))
    "the middle step's changes are measured" [ 2 ]
    (List.map (fun (r : Mine.row) -> r.totals.added + r.totals.removed) rows)

(* A bump that moves one file to the new version and another back to a
   version that only an untouched file held does not complete the bump
   before it. *)
let test_mine_no_completion_backwards () =
  let tree a b c =
    [
      ("a/lean-toolchain", tc a);
      ("b/lean-toolchain", tc b);
      ("c/lean-toolchain", tc c);
    ]
  in
  let commits =
    [
      commit "c0" ~date:"2025-10-01" ~subject:"init"
        (tree "v4.24.0" "v4.24.0" "v4.25.0-rc1");
      commit "c1" ~parent:"c0" ~date:"2025-11-20" ~subject:"a"
        (tree "v4.25.1" "v4.24.0" "v4.25.0-rc1");
      commit "c2" ~parent:"c1" ~date:"2025-11-21" ~subject:"b, c back"
        (tree "v4.25.1" "v4.25.1" "v4.24.0");
    ]
  in
  Alcotest.(check (list (list string)))
    "units" [ [ "c1" ]; [ "c2" ] ]
    (units (mine ~pins:[ lean_files ] commits))

(* A bump of an opaque pin only reaches no series: its lines are not added to
   the series of the release reached before it. *)
let test_mine_attribution () =
  let pins =
    [
      {
        Pin.files = [ "ci.yml" ];
        format = Pin.Yaml_scalar "lean";
        strip = [];
        resolve = Pin.Release;
      };
      {
        Pin.files = [ "rust-toolchain.toml" ];
        format = Pin.Toml_string "channel";
        strip = [];
        resolve = Pin.Opaque;
      };
    ]
  in
  let tree lean channel extra =
    [
      ("ci.yml", "lean: " ^ lean);
      ("rust-toolchain.toml", "channel = \"" ^ channel ^ "\"");
    ]
    @ extra
  in
  let ten = String.concat "\n" (List.init 10 string_of_int) in
  let commits =
    [
      commit "c0" ~date:"2025-10-01" ~subject:"init"
        (tree "v4.24.0" "1.0" [ ("a.lean", "x") ]);
      commit "c1" ~parent:"c0" ~date:"2025-11-20" ~subject:"bump"
        (tree "v4.25.0" "1.0" [ ("a.lean", "y") ]);
      commit "c2" ~parent:"c1" ~date:"2025-12-30" ~subject:"rust"
        (tree "v4.25.0" "1.1" [ ("a.lean", "y"); ("b.lean", ten) ]);
    ]
  in
  let rows = mine ~pins commits in
  Alcotest.(check (list (option string)))
    "series" [ Some "4.25"; None ]
    (List.map (fun (r : Mine.row) -> r.to_series) rows);
  let result = { Report.project = "p"; tool = lean (); rows; missing = [] } in
  Alcotest.(check (list string))
    "per release"
    [
      "project,tool,series,units,date,reached,releases_spanned,files,added,removed,lines_per_release";
      "p,lean,4.25,c1,2025-11-20,v4.25.0,1,1,1,1,2.0";
    ]
    (csv_lines (Report.per_release_csv [ result ]));
  match
    List.rev
      (csv_lines
         (Report.summary_md ~since:"2025-11-19" ~until:"2025-12-31" [ result ]))
  with
  | _ :: _ :: line :: _ ->
      Alcotest.(check string)
        "ten unattributed lines"
        "| p | lean | 1 | 2 | 0 | 0 | 1 | 12 | 2.0 | 10 | c2 (10 lines, 1 \
         files) |"
        line
  | _ -> Alcotest.fail "summary"

(* A value read by two pins appears once in the rows. *)
let test_mine_dedup_values () =
  let scalar key =
    {
      Pin.files = [ "ci.yml" ];
      format = Pin.Yaml_scalar key;
      strip = [];
      resolve = Pin.Release;
    }
  in
  let tree v = [ ("ci.yml", "lean: " ^ v ^ "\nlean_version: " ^ v) ] in
  let commits =
    [
      commit "c0" ~date:"2025-10-01" ~subject:"init" (tree "v4.24.0");
      commit "c1" ~parent:"c0" ~date:"2025-11-20" ~subject:"bump"
        (tree "v4.25.0");
    ]
  in
  match mine ~pins:[ scalar "lean"; scalar "lean_version" ] commits with
  | [ r ] ->
      Alcotest.check strings "from" [ "v4.24.0" ] r.from_;
      Alcotest.check strings "to" [ "v4.25.0" ] r.to_
  | _ -> Alcotest.fail "one row expected"

let test_errors_located () =
  let opam =
    {
      Pin.files = [ "*.opam" ];
      format = Pin.Opam_dep "rocq-core";
      strip = [];
      resolve = Pin.Release;
    }
  in
  let commits =
    [
      commit "c0" ~date:"2025-10-01" ~subject:"init"
        [ ("x.opam", "depends: [ \"rocq-core\" ]") ];
      commit "c1" ~parent:"c0" ~date:"2025-11-20" ~subject:"broken"
        [ ("x.opam", "depends: [ \"rocq-core\"") ];
    ]
  in
  Alcotest.(check string)
    "pin error names the project and the commit"
    "p, commit c1: x.opam: opam: unterminated depends field"
    (match mine ~pins:[ opam ] commits with
    | _ -> ""
    | exception Failure msg -> msg);
  let file = Filename.temp_file "releases" ".tsv" in
  Fun.protect
    ~finally:(fun () -> Sys.remove file)
    (fun () ->
      Out_channel.with_open_bin file (fun oc ->
          Out_channel.output_string oc "tag\tdate\n");
      check_bool "release list error names the file" true
        (match Release.load file with
        | _ -> false
        | exception Failure msg -> String.starts_with ~prefix:(file ^ ": ") msg))

let test_tool_prefix_case () =
  let t =
    Tool.make ~name:"lean" ~scheme:Tool.Minor ~prefixes:[ "LeanProver/Lean4:" ]
      ~until:"2025-12-31"
      (Release.parse_tsv releases_tsv)
  in
  check_bool "prefixes ignore case" true
    (Tool.find t "leanprover/lean4:v4.25.0" <> None)

(* Measured directories: former paths and file patterns, and the check that
   they exist. *)

let moved_history =
  [
    commit "c0" ~date:"2025-10-01" ~subject:"init"
      [
        ("ci.yml", "lean: v4.24.0");
        ("src/x/A.fst", "a");
        ("src/x/notes.md", "n");
      ];
    commit "c1" ~parent:"c0" ~date:"2025-11-20" ~subject:"bump"
      [
        ("ci.yml", "lean: v4.25.0");
        ("src/x/A.fst", "b");
        ("src/x/notes.md", "m");
        ("other/B.fst", "z");
      ];
    commit "c2" ~parent:"c1" ~date:"2025-11-21" ~subject:"move"
      [
        ("ci.yml", "lean: v4.25.0");
        ("lib/x/A.fst", "b");
        ("lib/x/notes.md", "m");
        ("other/B.fst", "z");
      ];
    commit "c3" ~parent:"c2" ~date:"2025-12-14" ~subject:"bump again"
      [
        ("ci.yml", "lean: v4.26.0");
        ("lib/x/A.fst", "c");
        ("lib/x/A.fsti", "i");
        ("lib/x/notes.md", "o");
        ("other/B.fst", "z");
      ];
  ]

let ci_pin =
  {
    Pin.files = [ "ci.yml" ];
    format = Pin.Yaml_scalar "lean";
    strip = [];
    resolve = Pin.Release;
  }

let test_mine_moved_dirs () =
  let rows =
    mine ~pins:[ ci_pin ]
      ~under:[ Project.dir "lib/x" ~formerly:[ "src/x" ] ]
      ~only:[ "**/*.fst"; "**/*.fsti" ]
      moved_history
  in
  Alcotest.(check (list (list int)))
    "F* files under the old and the new path"
    [ [ 1; 1; 1 ]; [ 2; 2; 1 ] ]
    (List.map
       (fun (r : Mine.row) ->
         [ r.totals.files; r.totals.added; r.totals.removed ])
       rows)

let test_missing_paths () =
  let missing ?only ?(since = "2025-11-19") ?(until = "2025-12-31") under =
    Mine.missing_paths
      (project (history ~head:"c3" ~under ?only [ ci_pin ]))
      ~clones:(fun _ -> fake moved_history)
      ~since ~until
    |> List.map (fun (m : Mine.missing) -> (m.path, m.where, m.commit))
  in
  let triples = Alcotest.(list (triple string string string)) in
  Alcotest.check triples "former path at the start" []
    (missing [ Project.dir "lib/x" ~formerly:[ "src/x" ] ]);
  Alcotest.check triples "new path only"
    [ ("lib/x", "window start", "c0") ]
    (missing [ Project.dir "lib/x" ]);
  Alcotest.check triples "wrong path at the head"
    [ ("lib/y", "head", "c3") ]
    (missing [ Project.dir "lib/y" ~formerly:[ "src/x" ] ]);
  Alcotest.check triples "each former path is checked"
    [ ("src/typo", "window start", "c0") ]
    (missing [ Project.dir "lib/x" ~formerly:[ "src/x"; "src/typo" ] ]);
  Alcotest.check triples "a path without measured files"
    [ ("src/x", "window start", "c0"); ("lib/x", "head", "c3") ]
    (missing ~only:[ "**/*.v" ] [ Project.dir "lib/x" ~formerly:[ "src/x" ] ]);
  Alcotest.check triples "measured files at the head only"
    [ ("src/x", "window start", "c0") ]
    (missing ~only:[ "**/*.fsti" ]
       [ Project.dir "lib/x" ~formerly:[ "src/x" ] ]);
  Alcotest.check triples "no commit in the window" []
    (missing ~since:"2026-01-01" ~until:"2026-12-31" [ Project.dir "lib/y" ]);
  Alcotest.check triples "a root commit starts the window"
    [ ("lib/x", "window start", "c0") ]
    (missing ~since:"2025-01-01" ~until:"2025-10-31" [ Project.dir "lib/x" ]);
  Alcotest.check triples "whole repository" [] (missing []);
  let snapshot_commits =
    [
      commit "r1" ~date:"2025-10-14" ~subject:""
        [ ("thys/A/a.thy", "x"); ("thys/C/c.thy", "y") ];
      commit "r2" ~date:"2025-11-14" ~subject:"" [ ("thys/A/a.thy", "x") ];
    ]
  in
  let snapshot_missing =
    Mine.missing_paths
      (project
         (Project.Snapshots
            {
              refs = [ ("v4.24.0", "r1"); ("v4.25.0", "r2") ];
              paths = [ "thys/A"; "thys/C" ];
              exclude_snapshot = [];
              authors_from = None;
            }))
      ~clones:(fun _ -> fake snapshot_commits)
      ~since:"2025-01-01" ~until:"2025-12-31"
  in
  Alcotest.check triples "snapshot path missing in the last release"
    [ ("thys/C", "v4.25.0", "r2") ]
    (List.map
       (fun (m : Mine.missing) -> (m.path, m.where, m.commit))
       snapshot_missing);
  let summary =
    Report.summary_md ~since:"2025-11-19" ~until:"2025-12-31"
      [
        {
          Report.project = "q";
          tool = lean ();
          rows = [];
          missing = snapshot_missing;
        };
      ]
  in
  check_bool "the summary lists it" true
    (List.mem "- q: thys/C missing at v4.25.0 (r2)" (csv_lines summary))

(* Repo, on a real repository built with git *)

let git_available () =
  match
    Unix.create_process "git" [| "git"; "--version" |] Unix.stdin Unix.stdout
      Unix.stderr
  with
  | pid -> (
      match Unix.waitpid [] pid with _, Unix.WEXITED 0 -> true | _ -> false)
  | exception Unix.Unix_error (Unix.ENOENT, _, _) -> false

let is_git_variable binding = String.starts_with ~prefix:"GIT_" binding

(* Runs git in [dir], with a fixed identity and date and without the user's
   configuration. *)
let git_in ?(author = "New") ~date dir args =
  let env =
    Array.of_list
      ([
         "GIT_CONFIG_GLOBAL=/dev/null";
         "GIT_CONFIG_NOSYSTEM=1";
         "GIT_AUTHOR_NAME=" ^ author;
         "GIT_AUTHOR_EMAIL=author@example.org";
         "GIT_COMMITTER_NAME=" ^ author;
         "GIT_COMMITTER_EMAIL=author@example.org";
         "GIT_AUTHOR_DATE=" ^ date ^ "T12:00:00+00:00";
         "GIT_COMMITTER_DATE=" ^ date ^ "T12:00:00+00:00";
       ]
      @ List.filter
          (fun b -> not (is_git_variable b))
          (Array.to_list (Unix.environment ())))
  in
  let null = Unix.openfile "/dev/null" [ Unix.O_WRONLY ] 0 in
  let pid =
    Fun.protect
      ~finally:(fun () -> Unix.close null)
      (fun () ->
        Unix.create_process_env "git"
          (Array.of_list ("git" :: "-C" :: dir :: args))
          env Unix.stdin null null)
  in
  match Unix.waitpid [] pid with
  | _, Unix.WEXITED 0 -> ()
  | _ -> Alcotest.failf "git %s failed" (String.concat " " args)

let write_file dir path contents =
  Out_channel.with_open_bin (Filename.concat dir path) (fun oc ->
      Out_channel.output_string oc contents)

let rec remove_tree path =
  if Sys.is_directory path then (
    Array.iter
      (fun f -> remove_tree (Filename.concat path f))
      (Sys.readdir path);
    Sys.rmdir path)
  else Sys.remove path

let raises_git_error f =
  match f () with _ -> false | exception Repo.Git_error _ -> true

let test_environment () =
  Alcotest.check strings "repository variables and overridden keys dropped"
    [ "HOME=/home/u"; "GIT_AUTHOR_NAME=A"; "GIT_NO_LAZY_FETCH=1" ]
    (Array.to_list
       (Repo.environment
          ~inherited:
            [|
              "HOME=/home/u";
              "GIT_DIR=/elsewhere";
              "GIT_WORK_TREE=/elsewhere";
              "GIT_AUTHOR_NAME=A";
              "GIT_NO_LAZY_FETCH=0";
            |]
          [ "GIT_NO_LAZY_FETCH=1" ]))

let test_git_repo () =
  if not (git_available ()) then Alcotest.skip ();
  let dir = Filename.temp_dir "upgrade-mining" "" in
  Fun.protect
    ~finally:(fun () -> remove_tree dir)
    (fun () ->
      let commit ?author ~date msg =
        git_in ?author ~date dir [ "add"; "." ];
        git_in ?author ~date dir [ "commit"; "-q"; "-m"; msg ]
      in
      git_in ~date:"2025-01-01" dir
        [ "-c"; "init.defaultBranch=main"; "init"; "-q" ];
      write_file dir "lean-toolchain" "v4.24.0\n";
      write_file dir "a.lean" "x\n";
      commit ~author:"Old" ~date:"2025-01-01" "old";
      write_file dir "tab\tname.lean" "t\n";
      commit ~date:"2025-11-20" "tab file";
      git_in ~date:"2025-11-20" dir [ "tag"; "v1" ];
      git_in ~date:"2025-11-20" dir [ "checkout"; "-q"; "-b"; "feature" ];
      write_file dir "lean-toolchain" "v4.25.0\n";
      commit ~date:"2025-11-21" "bump";
      git_in ~date:"2025-11-21" dir [ "checkout"; "-q"; "main" ];
      write_file dir "a.lean" "y\n";
      commit ~date:"2025-11-22" "main work";
      git_in ~date:"2025-11-23" dir
        [ "merge"; "-q"; "--no-ff"; "-m"; "Merge feature"; "feature" ];
      git_in ~date:"2025-11-23" dir [ "tag"; "v2" ];
      let repo = Repo.git dir in
      let log paths =
        repo.first_parent_log ~head:"main" ~since:"2025-11-19"
          ~until:"2025-12-31" ~paths
      in
      let subjects l = List.map (fun (c : Repo.commit) -> c.subject) l in
      Alcotest.check strings "first-parent line in the window"
        [ "tab file"; "main work"; "Merge feature" ]
        (subjects (log []));
      Alcotest.check strings "a merge that touches a pin file"
        [ "Merge feature" ]
        (subjects (log [ "lean-toolchain" ]));
      Alcotest.check strings "glob pathspec"
        [ "tab file"; "main work" ]
        (subjects (log [ "**/*.lean" ]));
      Alcotest.check strings "window end included" [ "tab file" ]
        (subjects
           (repo.first_parent_log ~head:"main" ~since:"2025-11-20"
              ~until:"2025-11-20" ~paths:[]));
      let tab_commit =
        match log [] with c :: _ -> c.hash | [] -> Alcotest.fail "no commit"
      in
      check_bool "file with a tab" true
        (List.mem "tab\tname.lean" (repo.files tab_commit));
      Alcotest.(check string)
        "show" "t\n"
        (repo.show tab_commit "tab\tname.lean");
      check_bool "show a missing file" true
        (raises_git_error (fun () -> repo.show tab_commit "missing"));
      Alcotest.(check (list string))
        "numstat" [ "tab\tname.lean" ]
        (List.map
           (fun (e : Numstat.entry) -> e.path)
           (repo.numstat (tab_commit ^ "^") tab_commit));
      Alcotest.(check (option strings))
        "tags containing"
        (Some [ "v1"; "v2" ])
        (Option.map (List.sort compare) (repo.tags_containing tab_commit));
      Alcotest.(check (option strings))
        "unknown commit" None
        (repo.tags_containing "0123456789abcdef0123456789abcdef01234567");
      Alcotest.(check (option strings))
        "a value that looks like an option" None
        (repo.tags_containing "--all");
      check_bool "other git failures raise" true
        (raises_git_error (fun () ->
             (Repo.git (Filename.concat dir "absent")).tags_containing "v1"));
      Alcotest.check strings "authors in the window" [ "New" ]
        (repo.authors ~since:"2025-11-19" ~until:"2025-12-31" "a.lean");
      Alcotest.check strings "authors before the window" [ "Old" ]
        (repo.authors ~since:"2025-01-01" ~until:"2025-01-01" "a.lean"))

(* Configuration of the experiment *)

let test_projects () =
  let names = List.map (fun (p : Project.t) -> p.name) Projects.all in
  Alcotest.(check int)
    "unique names" (List.length names)
    (List.length (List.sort_uniq compare names));
  List.iter
    (fun (p : Project.t) ->
      check_bool
        (p.name ^ " has a known tool")
        true
        (List.exists (fun (n, _, _) -> n = p.tool) Projects.tools))
    Projects.all

let () =
  Alcotest.run "upgrade_mining"
    [
      ("glob", [ Alcotest.test_case "patterns" `Quick test_glob ]);
      ("numstat", [ Alcotest.test_case "parse and filter" `Quick test_numstat ]);
      ( "repo",
        [
          Alcotest.test_case "log parsing" `Quick test_parse_log;
          Alcotest.test_case "git environment" `Quick test_environment;
          Alcotest.test_case "git repository" `Quick test_git_repo;
        ] );
      ( "tool",
        [
          Alcotest.test_case "release list" `Quick test_release_parse;
          Alcotest.test_case "minor series" `Quick test_tool;
          Alcotest.test_case "exact series" `Quick test_tool_exact;
          Alcotest.test_case "prefix case" `Quick test_tool_prefix_case;
        ] );
      ( "pin",
        [
          Alcotest.test_case "formats" `Quick test_pin_formats;
          Alcotest.test_case "values" `Quick test_pin_values;
          Alcotest.test_case "comments" `Quick test_pin_comments;
          Alcotest.test_case "opam triple quotes" `Quick test_opam_triple_quotes;
        ] );
      ( "mine",
        [
          Alcotest.test_case "grouping" `Quick test_mine_grouping;
          Alcotest.test_case "keywords" `Quick test_mine_keywords;
          Alcotest.test_case "unit in between" `Quick test_mine_unit_between;
          Alcotest.test_case "opaque bump after a release bump" `Quick
            test_mine_opaque_after_release;
          Alcotest.test_case "matrix shrink" `Quick test_mine_matrix_shrink;
          Alcotest.test_case "no change, unpin" `Quick test_mine_no_change;
          Alcotest.test_case "commit pins" `Quick test_mine_commit_pin;
          Alcotest.test_case "snapshots" `Quick test_mine_snapshots;
          Alcotest.test_case "three pin files" `Quick test_mine_three_files;
          Alcotest.test_case "no completion backwards" `Quick
            test_mine_no_completion_backwards;
          Alcotest.test_case "attribution" `Quick test_mine_attribution;
          Alcotest.test_case "values without repeats" `Quick
            test_mine_dedup_values;
          Alcotest.test_case "errors located" `Quick test_errors_located;
          Alcotest.test_case "moved directories" `Quick test_mine_moved_dirs;
          Alcotest.test_case "missing directories" `Quick test_missing_paths;
        ] );
      ( "report",
        [
          Alcotest.test_case "csv quoting" `Quick test_csv;
          Alcotest.test_case "bump rows" `Quick test_rows_csv;
          Alcotest.test_case "per release" `Quick test_per_release;
          Alcotest.test_case "series groups" `Quick test_series_groups;
          Alcotest.test_case "summary" `Quick test_summary;
        ] );
      ("projects", [ Alcotest.test_case "configuration" `Quick test_projects ]);
    ]
