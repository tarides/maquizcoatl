type t = Rocq of string | Lean of string | Fstar of string | Why3 of string

let all =
  [
    Rocq "9.2.0";
    Rocq "9.3.0";
    Lean "v4.34.0-rc1";
    Lean "v4.36.0";
    Fstar "v2026.10.25";
    Fstar "v2026.11.15";
    Why3 "1.8.2";
    Why3 "1.9.0";
  ]

let name = function
  | Rocq v -> "rocq-" ^ v
  | Lean v -> "lean-" ^ v
  | Fstar v -> "fstar-" ^ v
  | Why3 v -> "why3-" ^ v

let of_name s = List.find_opt (fun t -> name t = s) all
let ( / ) = Filename.concat

(* A release archive and its SHA-256 digest. *)
type download = { url : string; file : string; sha256 : string }

let ocaml = "ocaml-base-compiler.4.14.2"
let rocq_repository = "rocq-released=https://rocq-prover.org/opam/released"
let alt_ergo = "alt-ergo.2.6.2"

let elan =
  {
    url =
      "https://github.com/leanprover/elan/releases/download/v4.2.4/elan-x86_64-unknown-linux-gnu.tar.gz";
    file = "elan-v4.2.4-x86_64-unknown-linux-gnu.tar.gz";
    sha256 = "42b94d4244e8353142c456ec0e4ca6528fd898a6c604d4059f494e706e431f63";
  }

(* Digests from the GitHub release metadata. *)
let fstar_release = function
  | "v2026.10.25" ->
      Some "a716153960545bc26b9d093f55614fedc716a202e4daa1665e5c63e4a2fb04e4"
  | "v2026.11.15" ->
      Some "375b811af042d36c38641995799c4d4146a521b1db4014efc9d018c713e5177b"
  | _ -> None

let fstar_download v sha256 =
  let file = Printf.sprintf "fstar-%s-Linux-x86_64.tar.gz" v in
  {
    url =
      Printf.sprintf
        "https://github.com/FStarLang/FStar/releases/download/%s/%s" v file;
    file;
    sha256;
  }

(* Z3 and CVC5 publish no digest for these releases. These digests were
   computed from the release assets downloaded on 2026-11-19 (their sizes
   match the release metadata). The directory names are the archives' top
   directories. *)
let z3 =
  {
    url =
      "https://github.com/Z3Prover/z3/releases/download/z3-4.13.4/z3-4.13.4-x64-glibc-2.35.zip";
    file = "z3-4.13.4-x64-glibc-2.35.zip";
    sha256 = "93f91f9c6f4a00a041c19fc7a74adc1f441c8244ce70d486e19abcd89c6a014b";
  }

let cvc5 =
  {
    url =
      "https://github.com/cvc5/cvc5/releases/download/cvc5-1.2.1/cvc5-Linux-x86_64-static.zip";
    file = "cvc5-1.2.1-Linux-x86_64-static.zip";
    sha256 = "6d44abc233980a14d72cc5809287d27c3335b1d6ee863381d0b5ffcbd0d8de56";
  }

let provers l = Layout.switches l / "provers"
let z3_dir l = provers l / "z3-4.13.4"
let cvc5_dir l = provers l / "cvc5-1.2.1"
let z3_bin l = z3_dir l / "z3-4.13.4-x64-glibc-2.35" / "bin"
let cvc5_bin l = cvc5_dir l / "cvc5-Linux-x86_64-static" / "bin"
let elan_home l = Layout.switches l / "elan"

let home l t =
  match t with Lean _ -> elan_home l | _ -> Layout.switches l / name t

let lean_toolchain v = "leanprover/lean4:" ^ v
let fstar_exe l v = home l (Fstar v) / "bin" / "fstar.exe"

let opam_env l =
  [
    Command.Set ("OPAMROOT", Layout.opam_root l);
    Command.Set ("OPAMCOLOR", "never");
    Command.Set ("OPAMNODEPEXTS", "1");
  ]

let opam l ~cwd args = Command.v ~env:(opam_env l) ~cwd "opam" args

let lean_env l =
  [ Command.Set ("ELAN_HOME", elan_home l); Prepend_path (elan_home l / "bin") ]

let why3_env l v =
  [
    Command.Set ("WHY3CONFIG", home l (Why3 v) / "why3.conf");
    Prepend_path (z3_bin l);
    Prepend_path (cvc5_bin l);
  ]

let command l t ?(env = []) ~cwd prog args =
  let in_switch extra =
    {
      Command.prog = "opam";
      args = Command.lits [ "exec"; "--switch"; home l t; "--"; prog ] @ args;
      cwd;
      env = opam_env l @ extra @ env;
    }
  in
  match t with
  | Rocq _ -> in_switch []
  | Why3 v -> in_switch (why3_env l v)
  | Lean _ -> { Command.prog; args; cwd; env = lean_env l @ env }
  | Fstar v ->
      {
        Command.prog;
        args;
        cwd;
        env =
          Command.Prepend_path (home l (Fstar v) / "bin")
          :: Command.Set ("FSTAR_EXE", fstar_exe l v)
          :: env;
      }

let download l d =
  let dir = Layout.downloads l in
  let file = dir / d.file in
  let part = file ^ ".part" in
  [
    Step.Mkdir dir;
    Step.run ~creates:file ("download " ^ d.file)
      (Command.v ~cwd:dir "curl"
         [
           "--fail";
           "--location";
           "--silent";
           "--show-error";
           "--output";
           part;
           d.url;
         ]);
    Step.Rename { src = part; dst = file };
    Step.Sha256 { file; expected = d.sha256 };
  ]

let jobs (lim : Limits.t) = Printf.sprintf "--jobs=%d" lim.jobs

(* [once ~dir label command] is [command] run unless an earlier run of it
   succeeded: a marker in [dir] is written after it succeeds, and [dir] is
   emptied before it runs, so that what an interrupted run left (a half-made
   opam root or switch, a partly unpacked archive) is never taken as done. *)
let once ~dir label command =
  let marker = dir / ".upgrade_builds-done" in
  [ Step.run ~creates:marker ~clears:dir label command; Step.Touch marker ]

let opam_init l =
  once ~dir:(Layout.opam_root l) "opam init"
    (opam l ~cwd:(Layout.workdir l)
       [
         "init";
         "--bare";
         "--no-setup";
         "--yes";
         "default";
         "https://opam.ocaml.org";
       ])

let switch_create l lim t repos =
  let dir = home l t in
  Step.Mkdir (Layout.switches l)
  :: once ~dir
       ("opam switch create " ^ name t)
       (opam l ~cwd:(Layout.switches l)
          ([ "switch"; "create"; dir; ocaml; "--no-switch"; "--yes"; jobs lim ]
          @ repos))

let opam_install l lim t packages =
  Step.run
    ("opam install " ^ String.concat " " packages)
    (opam l ~cwd:(home l t)
       ([ "install"; "--switch"; home l t; "--yes"; jobs lim ] @ packages))

let tar_x l ~archive ~into ~strip =
  once ~dir:into ("unpack " ^ archive)
    (Command.v ~cwd:into "tar"
       ([ "-xzf"; Layout.downloads l / archive; "-C"; into ]
       @ if strip > 0 then [ Printf.sprintf "--strip-components=%d" strip ]
         else []))

let unzip l ~archive ~into =
  once ~dir:into ("unpack " ^ archive)
    (Command.v ~cwd:into "unzip"
       [ "-q"; "-o"; Layout.downloads l / archive; "-d"; into ])

let install l lim t =
  match t with
  | _ when not (List.mem t all) -> Error ("unsupported toolchain " ^ name t)
  | Rocq v ->
      Ok
        (opam_init l
        @ switch_create l lim t [ "--repositories=default," ^ rocq_repository ]
        @ [
            Step.run "pin rocq-core"
              (opam l ~cwd:(home l t)
                 [
                   "pin";
                   "add";
                   "--switch";
                   home l t;
                   "--no-action";
                   "--yes";
                   "--kind=version";
                   "rocq-core";
                   v;
                 ]);
            opam_install l lim t [ "rocq-core"; "rocq-stdlib" ];
          ])
  | Lean v ->
      let init_dir = Layout.switches l / "elan-init-v4.2.4" in
      Ok
        (download l elan
        @ tar_x l ~archive:elan.file ~into:init_dir ~strip:0
        @ once ~dir:(elan_home l) "elan-init"
            (Command.v ~env:(lean_env l) ~cwd:init_dir (init_dir / "elan-init")
               [ "-y"; "--no-modify-path"; "--default-toolchain"; "none" ])
        @ [
            Step.run
              ("elan toolchain install " ^ v)
              (Command.v ~env:(lean_env l) ~cwd:(elan_home l) "elan"
                 [ "toolchain"; "install"; lean_toolchain v ]);
          ])
  | Fstar v -> (
      match fstar_release v with
      | None -> Error ("no digest known for F* " ^ v)
      | Some sha256 ->
          let d = fstar_download v sha256 in
          Ok
            (* The archive's entries are ./fstar/...: two components. *)
            (download l d @ tar_x l ~archive:d.file ~into:(home l t) ~strip:2)
      )
  | Why3 v ->
      Ok
        (opam_init l @ switch_create l lim t []
        @ [ opam_install l lim t [ "why3." ^ v; alt_ergo ] ]
        @ download l z3
        @ unzip l ~archive:z3.file ~into:(z3_dir l)
        @ download l cvc5
        @ unzip l ~archive:cvc5.file ~into:(cvc5_dir l)
        @ [
            Step.run "why3 config detect"
              (command l t ~cwd:(home l t) "why3"
                 (Command.lits [ "config"; "detect" ]));
          ])

let probes l t ~cwd =
  let run prog args = command l t ~cwd prog (Command.lits args) in
  match t with
  | Rocq _ ->
      [
        run "rocq" [ "--version" ]; opam l ~cwd [ "list"; "--switch"; home l t ];
      ]
  | Lean v ->
      let plus = "+" ^ lean_toolchain v in
      [ run "lean" [ plus; "--version" ]; run "lake" [ plus; "--version" ] ]
  | Fstar _ ->
      [
        run "fstar.exe" [ "--version" ];
        run "fstar.exe" [ "--locate_z3"; "4.13.3" ];
      ]
  | Why3 _ ->
      [
        run "why3" [ "--version" ];
        run "why3" [ "config"; "list-provers" ];
        run "alt-ergo" [ "--version" ];
        run "z3" [ "--version" ];
        run "cvc5" [ "--version" ];
      ]
