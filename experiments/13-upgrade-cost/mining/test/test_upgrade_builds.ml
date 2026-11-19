(* Tests of the Part A driver: command construction, result parsing and
   process handling, on fixtures. No test runs a build or an install; the
   tests of the "exec" group start small processes (sh, sleep, true) under
   GNU timeout and taskset, and are skipped where those are missing. *)

open Upgrade_builds

let strings = Alcotest.(list string)
let ( / ) = Filename.concat

let ok = function
  | Ok x -> x
  | Error msg -> Alcotest.fail ("unexpected error: " ^ msg)

let is_error = function Ok _ -> false | Error _ -> true
let check_error msg r = Alcotest.(check bool) msg true (is_error r)

(* Fixture directories, removed at the end of each test. *)
let with_temp_dir f =
  let dir = Filename.temp_dir "upgrade-builds-test" "" in
  Fun.protect ~finally:(fun () -> Exec.remove_tree dir) (fun () -> f dir)

let write path contents =
  Exec.mkdir_p (Filename.dirname path);
  Out_channel.with_open_bin path (fun oc ->
      Out_channel.output_string oc contents)

let read path = In_channel.with_open_bin path In_channel.input_all
let argv c = ok (Command.argv c)

let runs steps =
  List.filter_map
    (function
      | Step.Run { label; command; on_failure; _ } ->
          Some (label, command, on_failure)
      | _ -> None)
    steps

let run_labelled label steps =
  match List.find_opt (fun (l, _, _) -> l = label) (runs steps) with
  | Some (_, c, _) -> c
  | None -> Alcotest.fail ("no step " ^ label)

let env_has (c : Command.t) name value =
  Array.mem
    (name ^ "=" ^ value)
    (Command.environment c.env [| "PATH=/usr/bin" |])

let cpus s = ok (Cpuset.of_string s)

let limits ?(jobs = 4) ?(set = "8-11") () =
  ok (Limits.make ~jobs ~cpus:(cpus set) ~nice:10 ~timeout:3600)

(* Cpuset *)

let test_cpuset () =
  let canonical s = Cpuset.to_string (cpus s) in
  Alcotest.(check string) "ranges" "8-15,40-47" (canonical "8-15,40-47");
  Alcotest.(check string) "merged" "1-3" (canonical "3,1-2,2");
  Alcotest.(check string) "single" "0" (canonical "0");
  Alcotest.(check string) "separate" "0,2" (canonical "2,0");
  Alcotest.(check int) "cardinal" 16 (Cpuset.cardinal (cpus "8-15,40-47"));
  List.iter
    (fun s -> check_error ("rejects " ^ s) (Cpuset.of_string s))
    [ ""; "1-"; "-1"; "5-3"; "a"; "1,,2"; " 1"; "1 "; "4096"; "1-2-3" ]

(* Limits *)

let test_limits () =
  let l = limits ~jobs:8 ~set:"8-15" () in
  Alcotest.check strings "prefix"
    [
      "timeout";
      "--kill-after=60";
      "3600";
      "taskset";
      "--cpu-list";
      "8-15";
      "nice";
      "-n";
      "10";
    ]
    (Limits.prefix l);
  Alcotest.check strings "no warning" [] (Limits.warnings l);
  Alcotest.(check int)
    "more jobs than CPUs" 1
    (List.length (Limits.warnings (limits ~jobs:8 ~set:"0-3" ())));
  let make ~jobs ~nice ~timeout =
    Limits.make ~jobs ~cpus:(cpus "0") ~nice ~timeout
  in
  check_error "no job" (make ~jobs:0 ~nice:0 ~timeout:1);
  check_error "nice above 19" (make ~jobs:1 ~nice:20 ~timeout:1);
  check_error "negative nice" (make ~jobs:1 ~nice:(-1) ~timeout:1);
  check_error "no time" (make ~jobs:1 ~nice:0 ~timeout:0)

let test_duration () =
  List.iter
    (fun (s, n) -> Alcotest.(check int) s n (ok (Limits.duration_of_string s)))
    [ ("90s", 90); ("30m", 1800); ("6h", 21600); ("45", 45) ];
  List.iter
    (fun s -> check_error ("rejects " ^ s) (Limits.duration_of_string s))
    [ ""; "h"; "0"; "0h"; "1.5h"; "-3"; "10d"; "3 h" ]

(* Command *)

let test_environment () =
  let env =
    Command.environment
      [
        Command.Set ("A", "x");
        Prepend_path "/p";
        Set ("C", "3");
        Prepend_path "/q";
      ]
      [| "A=1"; "PATH=/bin"; "B=2=3" |]
  in
  Alcotest.check strings "changed in place"
    [ "A=x"; "PATH=/q:/p:/bin"; "B=2=3"; "C=3" ]
    (Array.to_list env);
  Alcotest.(check string) "path" "/q:/p:/bin" (Command.path_of env);
  Alcotest.check strings "no PATH yet" [ "PATH=/p" ]
    (Array.to_list (Command.environment [ Prepend_path "/p" ] [||]))

let test_quote () =
  Alcotest.(check string) "plain" "a/b-c.d=e" (Command.quote "a/b-c.d=e");
  Alcotest.(check string) "space" "'a b'" (Command.quote "a b");
  Alcotest.(check string) "quote" "'it'\\''s'" (Command.quote "it's");
  Alcotest.(check string) "empty" "''" (Command.quote "");
  Alcotest.(check string) "dollar" "'$HOME'" (Command.quote "$HOME");
  let c =
    Command.v
      ~env:[ Set ("X", "1"); Prepend_path "/a"; Prepend_path "/b" ]
      ~cwd:"/w" "make" [ "-C"; "a b" ]
  in
  Alcotest.(check string)
    "display" "(cd /w && X=1 PATH=/b:/a:\"$PATH\" make -C 'a b')"
    (Command.to_string c);
  Alcotest.(check string)
    "display unset" "(cd /w && unset X && Y=1 make)"
    (Command.to_string
       (Command.v ~env:[ Unset "X"; Set ("Y", "1") ] ~cwd:"/w" "make" []));
  let shown env = Command.to_string (Command.v ~env ~cwd:"/w" "make" []) in
  Alcotest.(check string)
    "set then unset" "(cd /w && unset X && make)"
    (shown [ Set ("X", "1"); Unset "X" ]);
  Alcotest.(check string)
    "unset then set" "(cd /w && X=2 make)"
    (shown [ Unset "X"; Set ("X", "2") ]);
  Alcotest.(check string)
    "PATH replaced" "(cd /w && PATH=/d make)"
    (shown [ Unset "PATH"; Prepend_path "/d" ]);
  Alcotest.(check (array string))
    "unset" [| "B=2" |]
    (Command.environment [ Unset "A" ] [| "A=1"; "B=2" |])

let test_prefixed () =
  let c = Command.v ~cwd:"/w" "ls" [ "-l" ] in
  Alcotest.check strings "prefixed"
    [ "timeout"; "5"; "ls"; "-l" ]
    (argv (Command.prefixed [ "timeout"; "5" ] c));
  Alcotest.check strings "no prefix" [ "ls"; "-l" ]
    (argv (Command.prefixed [] c))

let test_find_files () =
  with_temp_dir (fun dir ->
      List.iter
        (fun f -> write (dir / f) "")
        [
          "_build/default/A/x.vo";
          "_build/default/A/B/y.vo";
          "_build/default/top.vo";
          "_build/default/A/z.glob";
        ];
      Unix.symlink "A" (dir / "_build/default/L");
      let files depth =
        Command.find_files ~cwd:dir
          { dir = "_build/default"; suffix = ".vo"; depth }
      in
      Alcotest.check strings "depth 2"
        [ "_build/default/A/x.vo" ]
        (ok (files (Some 2)));
      Alcotest.check strings "any depth, no symbolic link followed"
        [
          "_build/default/A/B/y.vo";
          "_build/default/A/x.vo";
          "_build/default/top.vo";
        ]
        (ok (files None));
      check_error "missing directory"
        (Command.find_files ~cwd:dir
           { dir = "nothing"; suffix = ".vo"; depth = None });
      check_error "no match"
        (Command.find_files ~cwd:dir
           { dir = "_build"; suffix = ".vok"; depth = None });
      let c =
        {
          Command.prog = "rocqchk";
          args =
            [
              Lit "-Q";
              Files { dir = "_build/default/A"; suffix = ".vo"; depth = None };
              Lit "end";
            ];
          cwd = dir;
          env = [];
        }
      in
      Alcotest.check strings "expanded in place"
        [
          "rocqchk";
          "-Q";
          "_build/default/A/B/y.vo";
          "_build/default/A/x.vo";
          "end";
        ]
        (argv c))

let test_resolve () =
  with_temp_dir (fun dir ->
      write (dir / "prog") "";
      Unix.chmod (dir / "prog") 0o755;
      write (dir / "data") "";
      let path = "/nonexistent:" ^ dir in
      Alcotest.(check (option string))
        "in PATH"
        (Some (dir / "prog"))
        (Command.resolve ~path "prog");
      Alcotest.(check (option string))
        "not executable" None
        (Command.resolve ~path "data");
      Alcotest.(check (option string))
        "with a slash" (Some "./x")
        (Command.resolve ~path "./x");
      let cwd = Sys.getcwd () in
      Fun.protect
        ~finally:(fun () -> Sys.chdir cwd)
        (fun () ->
          Sys.chdir (Filename.dirname dir);
          Alcotest.(check (option string))
            "relative entry made absolute"
            (Some (Unix.realpath dir / "prog"))
            (Option.map Unix.realpath
               (Command.resolve ~path:(Filename.basename dir) "prog"));
          Alcotest.(check bool)
            "absolute" false
            (Filename.is_relative
               (Option.get
                  (Command.resolve ~path:(Filename.basename dir) "prog")))))

(* Edit *)

let test_edit () =
  let r = Edit.Replace { file = "f"; old = "v1"; by = "v2" } in
  Alcotest.(check string)
    "replaced" "a v2 b"
    (ok (Edit.apply_string r "a v1 b"));
  Alcotest.(check string)
    "already applied" "a v2 b"
    (ok (Edit.apply_string r "a v2 b"));
  check_error "absent" (Edit.apply_string r "a b");
  check_error "twice" (Edit.apply_string r "v1 v1");
  check_error "overlap"
    (Edit.apply_string
       (Edit.Replace { file = "f"; old = "v1"; by = "v1x" })
       "v1");
  Alcotest.(check string)
    "write" "new"
    (ok (Edit.apply_string (Edit.Write { file = "f"; contents = "new" }) "old"));
  with_temp_dir (fun dir ->
      write (dir / "sub/f") "x v1\n";
      let r = Edit.Replace { file = "sub/f"; old = "v1"; by = "v2" } in
      ok (Edit.apply ~dir r);
      ok (Edit.apply ~dir r);
      Alcotest.(check string) "idempotent" "x v2\n" (read (dir / "sub/f"));
      check_error "missing file"
        (Edit.apply ~dir (Edit.Replace { file = "g"; old = "a"; by = "b" })))

(* Failures *)

let dune_log =
  {|File "Engine/Foo.v", line 12, characters 0-10:
12 | Lemma x.
Error: The reference y was not found in the current environment.

File "./Semantics/Bar.v", line 3, characters 2-5:
Warning: Notation x is deprecated.
Error: a rule failed, without location
File "./Semantics/Baz.v", line 1, characters 0-1:
Error:
Syntax error
Error: another message without location
File "Engine/Foo.v", line 20, characters 0-1:
Error: again
|}

let lake_log =
  {|✖ [123/456] Building RegexCorrectness.Foo
error: ././././RegexCorrectness/Foo.lean:12:4: unknown identifier 'x'
error: RegexCorrectness/Bar.lean:1:0: unexpected token
warning: RegexCorrectness/Baz.lean:3:0: declaration uses 'sorry'
error: Lean exited with code 1
error: build failed
|}

let fstar_log =
  {|* Error 19 at Quicksort.Base.fst(12,3-14,5):
  - Assertion failed
* Warning 328 at Foo.fst(1,0-1,10):
Bar.fst(3,0-3,5): (Error 189) Expected type
  * Error 72 at /abs/path/Baz.fsti(7,1-7,4):
make[1]: *** [Makefile:12: _cache/Bar.fst.checked] Error 1
|}

let test_failures () =
  Alcotest.check strings "dune and Rocq"
    [ "Engine/Foo.v"; "Semantics/Baz.v" ]
    (Failures.files Failures.Dune_rocq dune_log);
  Alcotest.check strings "lake"
    [ "RegexCorrectness/Bar.lean"; "RegexCorrectness/Foo.lean" ]
    (Failures.files Failures.Lake lake_log);
  Alcotest.check strings "F*"
    [ "/abs/path/Baz.fsti"; "Bar.fst"; "Quicksort.Base.fst" ]
    (Failures.files Failures.Fstar fstar_log);
  Alcotest.check strings "failed steps" []
    (Failures.files Failures.Failed_steps dune_log)

(* Host *)

let cpuinfo =
  "processor\t: 0\n\
   vendor_id\t: AuthenticAMD\n\
   model name\t: AMD EPYC 7543 32-Core Processor\n\n\
   processor\t: 1\n\
   model name\t: AMD EPYC 7543 32-Core Processor\n"

let test_host () =
  Alcotest.(check (option (float 1e-9)))
    "load" (Some 0.52)
    (Host.loadavg "0.52 0.58 0.59 1/1234 5678\n");
  Alcotest.(check (option (float 1e-9))) "no load" None (Host.loadavg "");
  Alcotest.(check (option string))
    "model" (Some "AMD EPYC 7543 32-Core Processor") (Host.cpu_model cpuinfo);
  Alcotest.(check int) "processors" 2 (Host.processors cpuinfo);
  let digest = String.make 64 'a' in
  Alcotest.(check (option string))
    "digest" (Some digest)
    (Exec.sha256sum (digest ^ "  file.tar.gz\n"));
  Alcotest.(check (option string)) "short" None (Exec.sha256sum "abc  file");
  Alcotest.(check (option string))
    "upper case" None
    (Exec.sha256sum (String.make 64 'A' ^ "  f"))

(* Exec *)

let outcome =
  Alcotest.testable
    (fun ppf o -> Format.pp_print_string ppf (Exec.outcome_to_string o))
    ( = )

let test_classify () =
  let classify ?(wall = 10.) status =
    Exec.classify ~timeout:3600 ~wall status
  in
  Alcotest.check outcome "success" Exec.Success (classify (Unix.WEXITED 0));
  Alcotest.check outcome "TERM" Exec.Timed_out (classify (Unix.WEXITED 124));
  Alcotest.check outcome "KILL after the timeout" Exec.Timed_out
    (classify ~wall:3660. (Unix.WEXITED 137));
  Alcotest.check outcome "killed before the timeout" (Exec.Signal 9)
    (classify (Unix.WEXITED 137));
  Alcotest.check outcome "exit code" (Exec.Exit 2) (classify (Unix.WEXITED 2));
  Alcotest.check outcome "signal" (Exec.Signal 15)
    (classify (Unix.WSIGNALED 15));
  Alcotest.check outcome "OCaml's KILL" (Exec.Signal 9)
    (classify (Unix.WSIGNALED Sys.sigkill));
  Alcotest.check outcome "127 is the command's" (Exec.Exit 127)
    (classify (Unix.WEXITED 127));
  Alcotest.(check bool) "skipped is no failure" false (Exec.failed Exec.Skipped)

let test_names () =
  Alcotest.(check string)
    "log name" "03-lake_build_regex.log"
    (Exec.log_name 3 "lake build regex");
  Alcotest.(check string)
    "session" "12-avl_foo.log"
    (Exec.log_name 12 "avl/foo");
  Alcotest.(check string)
    "timestamp" "2023-11-14T22:13:20Z"
    (Exec.timestamp 1700000000.)

(* Steps that start no process: directories, edits, renames, skips. *)
let test_run_without_process () =
  with_temp_dir (fun dir ->
      write (dir / "f") "v1";
      write (dir / "done") "";
      write (dir / "logs/.keep") "";
      write (dir / "kept/x") "";
      write (dir / "tree/sub/y") "";
      Unix.symlink (dir / "kept") (dir / "tree/link");
      let steps =
        [
          Step.Mkdir (dir / "a/b");
          Step.Remove (dir / "tree");
          Step.Remove (dir / "absent");
          Step.Edit
            {
              label = "bump";
              dir;
              edits = [ Edit.Replace { file = "f"; old = "v1"; by = "v2" } ];
            };
          Step.Rename { src = dir / "absent.part"; dst = dir / "done" };
          Step.run ~creates:(dir / "done") "download"
            (Command.v ~cwd:dir "no-such-program" []);
          Step.Edit
            {
              label = "broken";
              dir;
              edits = [ Edit.Replace { file = "f"; old = "v9"; by = "v8" } ];
            };
          Step.Mkdir (dir / "never");
        ]
      in
      let results =
        Exec.run ~limits:(limits ()) ~env:[] ~log_dir:(dir / "logs") steps
      in
      Alcotest.(check (list string))
        "outcomes"
        [ "ok"; "ok"; "ok"; "ok"; "skipped"; "skipped"; "error" ]
        (List.map
           (fun (r : Exec.step_result) ->
             match r.outcome with
             | Exec.Driver_error _ -> "error"
             | o -> Exec.outcome_to_string o)
           results);
      Alcotest.(check bool) "directory" true (Sys.is_directory (dir / "a/b"));
      Alcotest.(check string) "edited" "v2" (read (dir / "f"));
      Alcotest.(check bool) "stopped" false (Sys.file_exists (dir / "never"));
      Alcotest.(check bool) "removed" false (Sys.file_exists (dir / "tree"));
      Alcotest.(check bool)
        "link not followed" true
        (Sys.file_exists (dir / "kept/x")))

(* Toolchain *)

let layout dir = Layout.make dir

let test_toolchain_names () =
  List.iter
    (fun t ->
      Alcotest.(check bool)
        (Toolchain.name t) true
        (Toolchain.of_name (Toolchain.name t) = Some t))
    Toolchain.all;
  Alcotest.(check bool) "unknown" true (Toolchain.of_name "rocq-8.0" = None);
  let l = layout "/w" in
  check_error "unsupported version"
    (Toolchain.install l (limits ()) (Toolchain.Rocq "8.0"));
  check_error "F* without digest"
    (Toolchain.install l (limits ()) (Toolchain.Fstar "v2025.01.01"))

let shells = [ "sh"; "bash"; "dash"; "zsh" ]

let test_toolchain_install () =
  let l = layout "/w" in
  List.iter
    (fun t ->
      let steps = ok (Toolchain.install l (limits ()) t) in
      List.iter
        (fun (label, (c : Command.t), _) ->
          Alcotest.(check bool)
            (Toolchain.name t ^ ": no shell in " ^ label)
            false
            (List.mem (Filename.basename c.prog) shells))
        (runs steps))
    Toolchain.all;
  let rocq = Toolchain.Rocq "9.2.0" in
  let steps = ok (Toolchain.install l (limits ()) rocq) in
  let pin = run_labelled "pin rocq-core" steps in
  Alcotest.check strings "pin"
    [
      "opam";
      "pin";
      "add";
      "--switch";
      "/w/switches/rocq-9.2.0";
      "--no-action";
      "--yes";
      "--kind=version";
      "rocq-core";
      "9.2.0";
    ]
    (argv pin);
  Alcotest.(check bool) "opam root" true (env_has pin "OPAMROOT" "/w/opam");
  Alcotest.(check bool) "no depexts" true (env_has pin "OPAMNODEPEXTS" "1");
  Alcotest.check strings "switch"
    [
      "opam";
      "switch";
      "create";
      "/w/switches/rocq-9.2.0";
      "ocaml-base-compiler.4.14.2";
      "--no-switch";
      "--yes";
      "--jobs=4";
      "--repositories=default,rocq-released=https://rocq-prover.org/opam/released";
    ]
    (argv (run_labelled "opam switch create rocq-9.2.0" steps));
  let digests t =
    List.filter_map
      (function Step.Sha256 { expected; _ } -> Some expected | _ -> None)
      (ok (Toolchain.install l (limits ()) t))
  in
  Alcotest.check strings "F* digest"
    [ "375b811af042d36c38641995799c4d4146a521b1db4014efc9d018c713e5177b" ]
    (digests (Toolchain.Fstar "v2026.11.15"));
  Alcotest.check strings "Z3 and CVC5 digests recorded here"
    [
      "93f91f9c6f4a00a041c19fc7a74adc1f441c8244ce70d486e19abcd89c6a014b";
      "6d44abc233980a14d72cc5809287d27c3335b1d6ee863381d0b5ffcbd0d8de56";
    ]
    (digests (Toolchain.Why3 "1.9.0"));
  let switch =
    steps
    |> List.filter_map (function
      | Step.Run { label = "opam switch create rocq-9.2.0"; creates; clears; _ }
        ->
          Some (creates, clears)
      | _ -> None)
  in
  Alcotest.(check (list (pair (option string) (option string))))
    "half-made switch emptied"
    [
      ( Some "/w/switches/rocq-9.2.0/.upgrade_builds-done",
        Some "/w/switches/rocq-9.2.0" );
    ]
    switch;
  Alcotest.(check bool)
    "marker written" true
    (List.mem (Step.Touch "/w/switches/rocq-9.2.0/.upgrade_builds-done") steps);
  let lean = ok (Toolchain.install l (limits ()) (Toolchain.Lean "v4.36.0")) in
  Alcotest.check strings "elan toolchain"
    [ "elan"; "toolchain"; "install"; "leanprover/lean4:v4.36.0" ]
    (argv (run_labelled "elan toolchain install v4.36.0" lean))

let test_toolchain_command () =
  let l = layout "/w" in
  let c =
    Toolchain.command l (Toolchain.Why3 "1.8.2") ~cwd:"/x" "why3"
      [ Command.Lit "--version" ]
  in
  Alcotest.check strings "through opam exec"
    [
      "opam";
      "exec";
      "--switch";
      "/w/switches/why3-1.8.2";
      "--";
      "why3";
      "--version";
    ]
    (argv c);
  Alcotest.(check bool)
    "why3 configuration" true
    (env_has c "WHY3CONFIG" "/w/switches/why3-1.8.2/why3.conf");
  let f =
    Toolchain.command l (Toolchain.Fstar "v2026.10.25") ~cwd:"/x" "make" []
  in
  Alcotest.(check bool)
    "FSTAR_EXE" true
    (env_has f "FSTAR_EXE" "/w/switches/fstar-v2026.10.25/bin/fstar.exe")

(* Target *)

let target name =
  match Target.find name with
  | Some t -> t
  | None -> Alcotest.fail ("no project " ^ name)

let test_targets () =
  Alcotest.check strings "projects"
    [ "warblre"; "linden"; "lean-regex"; "pulse-examples"; "why3-gallery" ]
    (List.map Target.name Target.all);
  List.iter
    (fun t ->
      List.iter
        (fun side ->
          Alcotest.(check bool)
            (Target.name t ^ " toolchain installable")
            true
            (List.mem (Target.toolchain t side) Toolchain.all))
        [ Target.Pinned; Target.Latest ])
    Target.all;
  check_error "unknown variant" (Target.variant (target "warblre") (Some "x"));
  let l = layout "/w" in
  let linden = target "linden" in
  let v = ok (Target.variant linden (Some "warblre-d4b0e22")) in
  Alcotest.(check string)
    "variant directory" "/w/build/linden-latest-warblre-d4b0e22"
    (Target.dir l linden Target.Latest v);
  let gallery = target "why3-gallery" in
  let reduced = ok (Target.variant gallery (Some "reduced")) in
  Alcotest.(check string)
    "same checkout for a session selection" "/w/build/why3-gallery-pinned"
    (Target.dir l gallery Target.Pinned reduced)

let edits_of steps =
  List.concat_map
    (function Step.Edit { label = "edits"; edits; _ } -> edits | _ -> [])
    steps

let apply_all edits file contents =
  List.fold_left
    (fun s e -> if Edit.file e = file then ok (Edit.apply_string e s) else s)
    contents edits

let lakefile =
  {|[[require]]
name = "mathlib"
scope = "leanprover-community"
rev = "v4.34.0-rc1"
|}

let test_lean_regex () =
  let l = layout "/w" and t = target "lean-regex" in
  let latest = Target.prepare l (limits ()) t Target.Latest None in
  let edits = edits_of latest in
  Alcotest.(check string)
    "toolchain" "leanprover/lean4:v4.36.0\n"
    (apply_all edits "regex/lean-toolchain" "leanprover/lean4:v4.34.0-rc1\n");
  Alcotest.(check string)
    "correctness toolchain" "leanprover/lean4:v4.36.0\n"
    (apply_all edits "correctness/lean-toolchain"
       "leanprover/lean4:v4.34.0-rc1\n");
  Alcotest.(check bool)
    "mathlib revision" true
    (String.ends_with ~suffix:"rev = \"v4.36.0\"\n"
       (apply_all edits "correctness/lakefile.toml" lakefile));
  let update = run_labelled "lake update" latest in
  Alcotest.(check string)
    "update in correctness" "/w/build/lean-regex-latest/correctness" update.cwd;
  let pinned = Target.prepare l (limits ()) t Target.Pinned None in
  Alcotest.(check int) "no edit when pinned" 0 (List.length (edits_of pinned));
  Alcotest.(check bool)
    "no update when pinned" false
    (List.exists (fun (label, _, _) -> label = "lake update") (runs pinned));
  let measured = ok (Target.measured l (limits ()) t Target.Pinned None) in
  let build = run_labelled "lake build correctness" measured in
  Alcotest.check strings "lake build" [ "lake"; "build" ] (argv build);
  Alcotest.(check bool) "threads" true (env_has build "LEAN_NUM_THREADS" "4");
  Alcotest.(check bool)
    "elan" true
    (env_has build "ELAN_HOME" "/w/switches/elan")

let linden_opam =
  {|pin-depends: [
  ["warblre.0.1.0" "git+https://github.com/LindenRegex/Warblre.git#4321379b887d590a42759818f6d9b1fd2351688e"]
]
|}

let test_linden () =
  let l = layout "/w" and t = target "linden" in
  let v = ok (Target.variant t (Some "warblre-d4b0e22")) in
  let edits = edits_of (Target.prepare l (limits ()) t Target.Latest v) in
  let moved file =
    apply_all edits file linden_opam
    |> String.split_on_char '#'
    |> List.exists
         (String.starts_with
            ~prefix:"d4b0e226464650d6854987f6d64364a301659ea0\"]")
  in
  Alcotest.(check bool) "Warblre moved" true (moved "linden.opam");
  Alcotest.(check bool)
    "and in the template" true
    (moved "linden.opam.template");
  let deps =
    run_labelled "opam dependencies"
      (Target.prepare l (limits ()) t Target.Pinned None)
  in
  Alcotest.check strings "opam dependencies"
    [
      "opam";
      "install";
      "--switch";
      "/w/switches/rocq-9.2.0";
      "--deps-only";
      "--yes";
      "--jobs=4";
      ".";
    ]
    (argv deps);
  Alcotest.(check string) "from the checkout" "/w/build/linden-pinned" deps.cwd

let test_warblre () =
  with_temp_dir (fun dir ->
      let l = layout dir and t = target "warblre" in
      let checkout = Target.dir l t Target.Pinned None in
      List.iter
        (fun f -> write (checkout / "_build/default/mechanization" / f) "")
        [ "A.vo"; "B/C.vo"; "A.glob" ];
      let measured = ok (Target.measured l (limits ()) t Target.Pinned None) in
      let switch = dir / "switches/rocq-9.2.0" in
      let dune = run_labelled "dune build" measured in
      Alcotest.check strings "dune"
        [ "opam"; "exec"; "--switch"; switch; "--"; "dune"; "build"; "-j"; "4" ]
        (argv dune);
      Alcotest.(check bool)
        "no dune cache" true
        (env_has dune "DUNE_CACHE" "disabled");
      Alcotest.check strings "rocqchk"
        [
          "opam";
          "exec";
          "--switch";
          switch;
          "--";
          "rocqchk";
          "-silent";
          "--output-context";
          "-Q";
          "_build/default/mechanization";
          "Warblre";
          "_build/default/mechanization/A.vo";
          "_build/default/mechanization/B/C.vo";
        ]
        (argv (run_labelled "rocqchk" measured));
      Alcotest.(check bool)
        "failures read from dune output" true
        (Target.failure_format t = Failures.Dune_rocq);
      Alcotest.check strings "stale outputs" [ "_build" ]
        (Target.stale l t Target.Pinned None);
      let c = { Driver.layout = l; limits = limits (); dry_run = false } in
      check_error "no incremental build"
        (Driver.run c Driver.Build ~out:dir ~date:"2026-11-19" t Target.Pinned
           ~variant:None);
      Alcotest.(check bool)
        "nothing run" false
        (Sys.file_exists (Layout.logs l));
      let prepare = Target.prepare l (limits ()) t Target.Pinned None in
      Alcotest.(check bool)
        "prepare removes them" true
        (List.mem (Step.Remove (checkout / "_build")) prepare))

let test_clean () =
  let l = layout "/w" in
  let removed name =
    List.filter_map
      (function Step.Remove p -> Some p | _ -> None)
      (Target.prepare l (limits ()) (target name) Target.Latest None)
  in
  Alcotest.check strings "lean-regex's own build directories"
    [
      "/w/build/lean-regex-latest/regex/.lake/build";
      "/w/build/lean-regex-latest/correctness/.lake/build";
    ]
    (removed "lean-regex");
  let pulse =
    Target.prepare l (limits ()) (target "pulse-examples") Target.Latest None
  in
  Alcotest.check strings "make clean"
    [ "make"; "-C"; "pulse/share/pulse/examples"; "clean" ]
    (argv (run_labelled "make clean" pulse))

let test_pulse () =
  let l = layout "/w" and t = target "pulse-examples" in
  let make =
    run_labelled "make verify"
      (ok (Target.measured l (limits ()) t Target.Latest None))
  in
  Alcotest.check strings "make"
    [ "make"; "-C"; "pulse/share/pulse/examples"; "-j"; "4"; "verify" ]
    (argv make);
  Alcotest.(check bool)
    "latest F*" true
    (env_has make "FSTAR_EXE" "/w/switches/fstar-v2026.11.15/bin/fstar.exe");
  let prepare = Target.prepare l (limits ()) t Target.Pinned None in
  Alcotest.check strings "shallow clone of the tag"
    [
      "git";
      "clone";
      "--filter=blob:none";
      "--no-checkout";
      "--depth";
      "1";
      "--branch";
      "v2026.10.25";
      "https://github.com/FStarLang/FStar.git";
      "/w/build/pulse-examples-pinned";
    ]
    (argv (run_labelled "clone" prepare));
  Alcotest.check strings "sparse checkout"
    [ "git"; "sparse-checkout"; "set"; "--cone"; "pulse"; "mk" ]
    (argv (run_labelled "sparse checkout" prepare));
  Alcotest.(check bool)
    "KaRaMeL commit recorded" true
    (List.exists
       (fun c -> argv c = [ "git"; "rev-parse"; "HEAD:karamel" ])
       (Target.probes l t Target.Pinned None))

let reduced_list =
  "binary_sort\n\
   conjugate\n\
   # counting_sort # randomly fails\n\
  \  indented\n\
   dfs # comment\n\
   foo bar\n\n"

let test_parse_reduced () =
  Alcotest.check strings "reduced list"
    [ "binary_sort"; "conjugate"; "dfs"; "foo" ]
    (Why3_sessions.parse_reduced reduced_list)

let test_why3_gallery () =
  with_temp_dir (fun dir ->
      let l = layout dir and t = target "why3-gallery" in
      check_error "not prepared"
        (Target.measured l (limits ()) t Target.Latest None);
      let examples = Target.dir l t Target.Latest None / "examples" in
      List.iter
        (fun f -> write (examples / f) "")
        [
          "foo/why3session.xml";
          "bar/why3session.xml";
          "notasession/x.mlw";
          "avl/t/why3session.xml";
          "avl/u/why3session.xml";
          "prover/p/why3session.xml";
          "unlisted/q/why3session.xml";
        ];
      write (examples / "avl/reduced_regtests.list") "t\n# u\n";
      let steps = ok (Target.measured l (limits ()) t Target.Latest None) in
      Alcotest.check strings "sessions"
        [ "bar"; "foo"; "avl/t"; "avl/u"; "prover/p" ]
        (List.map (fun (label, _, _) -> label) (runs steps));
      Alcotest.(check bool)
        "independent replays" true
        (List.for_all (fun (_, _, f) -> f = Step.Continue) (runs steps));
      let conf =
        Target.dir l t Target.Latest None / "upgrade_builds.why3.conf"
      in
      Alcotest.check strings "replay with options"
        [
          "opam";
          "exec";
          "--switch";
          dir / "switches/why3-1.9.0";
          "--";
          "why3";
          "replay";
          "-q";
          "--extra-config";
          conf;
          "-L";
          "prover";
          "--warn-off=unused_variable";
          "prover/p";
        ]
        (argv (run_labelled "prover/p" steps));
      Alcotest.(check string)
        "from examples" examples (run_labelled "foo" steps).cwd;
      let reduced = ok (Target.variant t (Some "reduced")) in
      Alcotest.check strings "reduced" [ "avl/t" ]
        (List.map
           (fun (label, _, _) -> label)
           (runs (ok (Target.measured l (limits ()) t Target.Latest reduced))));
      let config =
        List.concat_map
          (function
            | Step.Edit { label = "why3 extra configuration"; edits; _ } ->
                edits
            | _ -> [])
          (ok (Target.measured l (limits ~jobs:6 ()) t Target.Latest None))
      in
      Alcotest.(check (list string))
        "provers in parallel, from the run's jobs"
        [ "[main]\nrunning_provers_max = 6\n" ]
        (List.map (fun e -> ok (Edit.apply_string e "")) config);
      Alcotest.(check bool)
        "not at preparation" false
        (List.exists
           (function Step.Edit _ -> true | _ -> false)
           (Target.prepare l (limits ()) t Target.Latest None));
      write (examples / "reduced_regtests.list") "-L\n";
      check_error "option as a session"
        (Target.measured l (limits ()) t Target.Latest reduced);
      Exec.remove_tree (examples / "reduced_regtests.list");
      write (examples / "avl/reduced_regtests.list") "../../x\n";
      check_error "session outside examples"
        (Target.measured l (limits ()) t Target.Latest reduced))

(* Row and driver *)

let result ?(wall = 1.) index label outcome =
  {
    Exec.index;
    label;
    command = "c";
    start = 0.;
    wall;
    user = 0.5;
    sys = 0.25;
    outcome;
    log = None;
  }

let test_row () =
  Alcotest.(check string) "ok" "ok" (Row.outcome [ result 1 "a" Exec.Success ]);
  Alcotest.(check string)
    "timeout first" "timeout"
    (Row.outcome [ result 1 "a" (Exec.Exit 1); result 2 "b" Exec.Timed_out ]);
  Alcotest.(check string)
    "error" "error"
    (Row.outcome
       [ result 1 "a" (Exec.Exit 1); result 2 "b" (Exec.Driver_error "x") ]);
  Alcotest.(check string)
    "failed" "failed"
    (Row.outcome [ result 1 "a" (Exec.Exit 1) ]);
  let row =
    {
      Row.project = "warblre";
      side = "latest";
      variant = "";
      phase = "build";
      toolchain = "rocq-9.3.0";
      limits = limits ~set:"11,8-10" ();
      host = { Host.hostname = "h"; cpu_model = None; processors = Some 64 };
      load_before = Some 1.5;
      load_after = None;
      start = 1700000000.;
      results =
        [
          result ~wall:100.25 1 "dune build" (Exec.Exit 1);
          result ~wall:2. 2 "rocqchk" Exec.Success;
        ];
      failing_files = [ "A.v"; "B.v" ];
      log_dir = "/w/logs/x";
    }
  in
  let fields = Row.fields row in
  Alcotest.(check int) "columns" (List.length Row.header) (List.length fields);
  let column name = List.assoc name (List.combine Row.header fields) in
  Alcotest.(check string) "outcome" "failed" (column "outcome");
  Alcotest.(check string) "first failure" "dune build" (column "first_failure");
  Alcotest.(check string) "failing files" "2" (column "failing_files");
  Alcotest.(check string) "failing list" "A.v;B.v" (column "failing_list");
  Alcotest.(check string) "wall" "102.2" (column "wall_s");
  Alcotest.(check string) "cpus" "8-11" (column "cpus");
  Alcotest.(check string) "load" "1.50" (column "load_before");
  Alcotest.(check string) "no load" "" (column "load_after");
  Alcotest.(check string) "start" "2023-11-14T22:13:20Z" (column "start");
  Alcotest.(check int)
    "step columns"
    (List.length Row.step_header)
    (List.length (Row.step_fields (result 1 "a" Exec.Success)))

let test_append () =
  with_temp_dir (fun dir ->
      let file = dir / "builds.csv" in
      ok (Row.append ~file ~header:[ "a"; "b" ] [ "1"; "x,y" ]);
      ok (Row.append ~file ~header:[ "a"; "b" ] [ "2"; "z" ]);
      Alcotest.(check string) "table" "a,b\n1,\"x,y\"\n2,z\n" (read file);
      check_error "other header"
        (Row.append ~file ~header:[ "a"; "c" ] [ "3"; "w" ]))

let test_dry_run () =
  with_temp_dir (fun dir ->
      let c =
        { Driver.layout = layout dir; limits = limits (); dry_run = true }
      in
      Alcotest.(check bool)
        "dry run" true
        (ok
           (Driver.run c Driver.Prepare ~out:(dir / "out") ~date:"2026-11-19"
              (target "warblre") Target.Pinned ~variant:None));
      ok (Driver.install c [ Toolchain.Lean "v4.36.0" ]);
      Alcotest.(check (list string))
        "nothing written" []
        (Array.to_list (Sys.readdir dir));
      check_error "unknown variant"
        (Driver.run c Driver.Build ~out:dir ~date:"2026-11-19"
           (target "warblre") Target.Pinned ~variant:(Some "x"));
      Alcotest.(check string)
        "builds file" "/r/2026-11-19-exp-13-builds.csv"
        (Driver.builds_file ~out:"/r" ~date:"2026-11-19"))

let test_check () =
  with_temp_dir (fun dir ->
      check_error "missing directory"
        (Row.check ~file:(dir / "missing/builds.csv") ~header:[ "a" ]);
      check_error "missing directory, append"
        (Row.append ~file:(dir / "missing/builds.csv") ~header:[ "a" ] [ "1" ]);
      ok (Row.check ~file:(dir / "builds.csv") ~header:[ "a" ]);
      write (dir / "other.csv") "b\n";
      check_error "other header"
        (Row.check ~file:(dir / "other.csv") ~header:[ "a" ]))

let linden_pins =
  "warblre.0.1.0  git  \
   git+https://github.com/LindenRegex/Warblre.git#4321379b887d590a42759818f6d9b1fd2351688e\n"

let test_pins () =
  let l = layout "/w" and linden = target "linden" in
  let variant = ok (Target.variant linden (Some "warblre-d4b0e22")) in
  Alcotest.(check (list (pair string string)))
    "linden"
    [ ("warblre", "4321379b887d590a42759818f6d9b1fd2351688e") ]
    (Target.pins linden None);
  Alcotest.(check (list (pair string string)))
    "variant"
    [ ("warblre", "d4b0e226464650d6854987f6d64364a301659ea0") ]
    (Target.pins linden variant);
  ok (Target.check_pins linden None linden_pins);
  check_error "pinned by the variant"
    (Target.check_pins linden variant linden_pins);
  check_error "not pinned" (Target.check_pins linden None "");
  ok (Target.check_pins (target "warblre") None "");
  Alcotest.(check bool)
    "warblre pins nothing" true
    (Target.pin_list l (target "warblre") Target.Pinned = None);
  match Target.pin_list l linden Target.Latest with
  | None -> Alcotest.fail "no pin list for linden"
  | Some c ->
      Alcotest.check strings "pin list"
        [ "opam"; "pin"; "list"; "--switch"; "/w/switches/rocq-9.3.0" ]
        (argv c)

(* The driver checks what it can before running anything. *)
let test_driver_checks () =
  with_temp_dir (fun dir ->
      let c =
        { Driver.layout = layout dir; limits = limits (); dry_run = false }
      in
      let build ~out =
        Driver.run c Driver.Build ~out ~date:"2026-11-19" (target "warblre")
          Target.Pinned ~variant:None
      in
      check_error "no output directory" (build ~out:(dir / "missing"));
      check_error "not prepared" (build ~out:dir);
      let unusable = { c with Driver.limits = limits ~jobs:1 ~set:"4000" () } in
      check_error "CPU set rejected by taskset"
        (Driver.install unusable [ Toolchain.Lean "v4.36.0" ]);
      Alcotest.(check (list string))
        "nothing run" []
        (Array.to_list (Sys.readdir dir)))

(* Tests that run processes: they need GNU timeout and taskset. *)

let process_tools () =
  let path = Option.value ~default:"" (Sys.getenv_opt "PATH") in
  if
    not
      (List.for_all
         (fun p -> Command.resolve ~path p <> None)
         [ "timeout"; "taskset"; "nice"; "sh"; "sleep"; "sha256sum" ])
  then Alcotest.skip ()

(* Every CPU of the machine, so that taskset accepts the set. *)
let process_limits ~timeout =
  let n = Option.value ~default:1 (Host.current ()).processors in
  ok
    (Limits.make ~jobs:1
       ~cpus:(cpus (Printf.sprintf "0-%d" (n - 1)))
       ~nice:0 ~timeout)

let outcomes results =
  List.map
    (fun (r : Exec.step_result) ->
      match r.outcome with
      | Exec.Driver_error _ -> "error"
      | o -> Exec.outcome_to_string o)
    results

let contains ~sub s = Edit.contains ~sub s

let test_processes () =
  process_tools ();
  with_temp_dir (fun dir ->
      let logs = dir / "logs" in
      Exec.mkdir_p logs;
      let sh label script =
        Step.run ~on_failure:Step.Continue label
          (Command.v
             ~env:[ Set ("GREETING", "hello") ]
             ~cwd:dir "sh" [ "-c"; script ])
      in
      let results =
        Exec.run
          ~limits:(process_limits ~timeout:1)
          ~env:[ Set ("BASE", "base"); Unset "HOME" ]
          ~log_dir:logs
          [
            sh "ok" "echo \"$GREETING $BASE ${HOME-unset}\"; pwd -P";
            sh "exit" "exit 3";
            sh "killed" "kill -9 $$";
            sh "slow" "exec sleep 30";
            Step.run ~on_failure:Step.Continue "missing"
              (Command.v ~cwd:dir "no-such-program-upgrade-builds" []);
            sh "last" "true";
          ]
      in
      Alcotest.check strings "outcomes"
        [ "ok"; "exit 3"; "signal 9"; "timeout"; "error"; "ok" ]
        (outcomes results);
      let first = List.hd results in
      let log = read (Option.get first.log) in
      Alcotest.(check bool)
        "environment" true
        (contains ~sub:"hello base unset" log);
      Alcotest.(check bool)
        "directory" true
        (contains ~sub:(Unix.realpath dir ^ "\n") log);
      Alcotest.(check bool)
        "under the limits" true
        (contains ~sub:"timeout --kill-after=60 1 taskset" log);
      Alcotest.(check bool)
        "missing program not started" true
        ((List.nth results 4).log = None))

let test_files () =
  process_tools ();
  with_temp_dir (fun dir ->
      let logs = dir / "logs" in
      Exec.mkdir_p logs;
      write (dir / "a.part") "abc";
      write (dir / "stale/x") "";
      let file = dir / "a" in
      let results =
        Exec.run
          ~limits:(process_limits ~timeout:60)
          ~env:[] ~log_dir:logs
          [
            Step.Rename { src = dir / "a.part"; dst = file };
            Step.Sha256
              {
                file;
                expected =
                  "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
              };
            Step.Touch (dir / "mark");
            Step.run ~clears:(dir / "stale") "clears"
              (Command.v ~cwd:dir "true" []);
            Step.Sha256 { file; expected = String.make 64 '0' };
          ]
      in
      Alcotest.check strings "outcomes"
        [ "ok"; "ok"; "ok"; "ok"; "error" ]
        (outcomes results);
      Alcotest.(check bool) "marked" true (Sys.file_exists (dir / "mark"));
      Alcotest.(check (array string))
        "emptied" [||]
        (Sys.readdir (dir / "stale"));
      Alcotest.(check bool) "bad file deleted" false (Sys.file_exists file))

let test_probe_capture () =
  process_tools ();
  with_temp_dir (fun dir ->
      let limits = process_limits ~timeout:60 in
      let file = dir / "versions.txt" in
      Exec.probe ~limits ~env:[] ~file
        [
          Command.v ~cwd:dir "sh" [ "-c"; "echo v1.2" ];
          Command.v ~cwd:dir "no-such-program-upgrade-builds" [];
        ];
      let probes = read file in
      Alcotest.(check bool)
        "output" true
        (contains ~sub:"v1.2\n# exit 0" probes);
      Alcotest.(check bool)
        "missing program" true
        (contains ~sub:"# error: no-such-program-upgrade-builds" probes);
      Exec.probe ~limits ~env:[] ~file:(dir / "missing/versions.txt") [];
      Alcotest.(check string)
        "capture" "out\nerr\n"
        (ok
           (Exec.capture ~limits ~env:[]
              (Command.v ~cwd:dir "sh" [ "-c"; "echo out; echo err >&2" ])));
      check_error "capture of a missing program"
        (Exec.capture ~limits ~env:[]
           (Command.v ~cwd:dir "no-such-program-upgrade-builds" []));
      check_error "capture failure"
        (Exec.capture ~limits ~env:[]
           (Command.v ~cwd:dir "sh" [ "-c"; "exit 2" ])))

(* A TERM sent to the driver stops the command and the run, which still
   returns its results. *)
let test_interrupt () =
  process_tools ();
  with_temp_dir (fun dir ->
      let logs = dir / "logs" in
      Exec.mkdir_p logs;
      let self = Unix.getpid () in
      flush_all ();
      let helper =
        match Unix.fork () with
        | 0 ->
            Unix.sleepf 0.5;
            (try Unix.kill self Sys.sigterm with Unix.Unix_error _ -> ());
            Unix._exit 0
        | pid -> pid
      in
      let t0 = Unix.gettimeofday () in
      let results =
        Exec.with_interrupts (fun () ->
            Exec.run
              ~limits:(process_limits ~timeout:60)
              ~env:[] ~log_dir:logs
              [
                Step.run "slow" (Command.v ~cwd:dir "sleep" [ "30" ]);
                Step.Mkdir (dir / "after");
              ])
      in
      ignore (Unix.waitpid [] helper);
      Alcotest.check strings "outcomes" [ "interrupted TERM" ]
        (outcomes results);
      Alcotest.(check bool) "flag" true (Exec.interrupted ());
      Alcotest.(check bool) "stopped" false (Sys.file_exists (dir / "after"));
      Alcotest.(check bool) "promptly" true (Unix.gettimeofday () -. t0 < 20.);
      Alcotest.(check string) "row outcome" "interrupted" (Row.outcome results))

let () =
  Alcotest.run "upgrade_builds"
    [
      ( "limits",
        [
          Alcotest.test_case "CPU sets" `Quick test_cpuset;
          Alcotest.test_case "wrapper" `Quick test_limits;
          Alcotest.test_case "durations" `Quick test_duration;
        ] );
      ( "command",
        [
          Alcotest.test_case "environment" `Quick test_environment;
          Alcotest.test_case "display" `Quick test_quote;
          Alcotest.test_case "prefix" `Quick test_prefixed;
          Alcotest.test_case "file lists" `Quick test_find_files;
          Alcotest.test_case "program lookup" `Quick test_resolve;
        ] );
      ("edit", [ Alcotest.test_case "replace and write" `Quick test_edit ]);
      ( "parsing",
        [
          Alcotest.test_case "failing files" `Quick test_failures;
          Alcotest.test_case "host" `Quick test_host;
          Alcotest.test_case "reduced session list" `Quick test_parse_reduced;
        ] );
      ( "exec",
        [
          Alcotest.test_case "outcomes" `Quick test_classify;
          Alcotest.test_case "names" `Quick test_names;
          Alcotest.test_case "steps without process" `Quick
            test_run_without_process;
          Alcotest.test_case "processes" `Quick test_processes;
          Alcotest.test_case "files and digests" `Quick test_files;
          Alcotest.test_case "probes and capture" `Quick test_probe_capture;
          Alcotest.test_case "interruption" `Quick test_interrupt;
        ] );
      ( "toolchain",
        [
          Alcotest.test_case "names" `Quick test_toolchain_names;
          Alcotest.test_case "install" `Quick test_toolchain_install;
          Alcotest.test_case "commands" `Quick test_toolchain_command;
        ] );
      ( "target",
        [
          Alcotest.test_case "projects" `Quick test_targets;
          Alcotest.test_case "lean-regex" `Quick test_lean_regex;
          Alcotest.test_case "linden" `Quick test_linden;
          Alcotest.test_case "warblre" `Quick test_warblre;
          Alcotest.test_case "clean builds" `Quick test_clean;
          Alcotest.test_case "pulse examples" `Quick test_pulse;
          Alcotest.test_case "why3 gallery" `Quick test_why3_gallery;
          Alcotest.test_case "pins" `Quick test_pins;
        ] );
      ( "results",
        [
          Alcotest.test_case "rows" `Quick test_row;
          Alcotest.test_case "append" `Quick test_append;
          Alcotest.test_case "dry run" `Quick test_dry_run;
          Alcotest.test_case "row checks" `Quick test_check;
          Alcotest.test_case "driver checks" `Quick test_driver_checks;
        ] );
    ]
