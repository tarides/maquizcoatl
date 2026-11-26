type t =
  | Rocq of string
  | Lean of string
  | Fstar of string
  | Why3 of string
  | Verus of string
  | Isabelle of string

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
    Verus "0.2026.07.12.0b42f4c";
    Verus "0.2026.11.22.1ce6a59";
    Isabelle "Isabelle2025-2";
    Isabelle "Isabelle2026";
  ]

let name = function
  | Rocq v -> "rocq-" ^ v
  | Lean v -> "lean-" ^ v
  | Fstar v -> "fstar-" ^ v
  | Why3 v -> "why3-" ^ v
  | Verus v -> "verus-" ^ v
  | Isabelle v -> "isabelle-" ^ v

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

(* Verus releases: the digest of the x86-linux zip (none is published:
   computed from the assets downloaded on 2026-11-26, whose sizes match the
   release metadata) and the Rust toolchain of the release's
   rust-toolchain.toml. *)
let verus_release = function
  | "0.2026.07.12.0b42f4c" ->
      Some
        ( "f6f4f5d08e07d3e1ad721d775bda5ba96b9dd0c73b48fc17f2e071866fbd01c0",
          "1.96.0" )
  | "0.2026.11.22.1ce6a59" ->
      Some
        ( "c955d5958877f4f907cce80aa996d4239a481984829d82e325938c7bf242b0db",
          "1.100.0" )
  | _ -> None

let verus_rust v = Option.map snd (verus_release v)

let verus_download v sha256 =
  let file = Printf.sprintf "verus-%s-x86-linux.zip" v in
  {
    url =
      Printf.sprintf
        "https://github.com/verus-lang/verus/releases/download/release%%2F%s/%s"
        v file;
    file;
    sha256;
  }

(* rustup-init 1.29.3, with the digest rustup publishes next to it. *)
let rustup_init =
  {
    url =
      "https://static.rust-lang.org/rustup/archive/1.29.3/x86_64-unknown-linux-gnu/rustup-init";
    file = "rustup-init";
    sha256 = "b1c8cb14e30889e7e2999e6b69e62d9e9b9ffc0f4df8180564d306d9680e6c55";
  }

(* Isabelle2025-2 publishes no digest: computed from the tarball downloaded
   on 2026-11-26 (its size matches the server's). Isabelle2026 is not
   downloaded: the shared toolchain cache's unpacked distribution is used
   read-only (see [isabelle_shared]). *)
let isabelle_release = function
  | "Isabelle2025-2" ->
      Some
        {
          url =
            "https://isabelle.in.tum.de/website-Isabelle2025-2/dist/Isabelle2025-2_linux.tar.gz";
          file = "Isabelle2025-2_linux.tar.gz";
          sha256 =
            "a20a507bc7c1270d8be96a9f3fbec06345387789d2dc2c4d3df6260d47bfb33c";
        }
  | _ -> None

(* The variable naming the shared toolchain cache's unpacked Isabelle2026
   ([<cache>/isabelle/dist/Isabelle2026]), whose tarball has the SHA-256
   858c995b32216b3876bf395c3be843147d1f1eee404bc6c958d7534ee335e48d. *)
let isabelle_shared_var = "UPGRADE_BUILDS_ISABELLE2026"

let isabelle_shared = function
  | "Isabelle2026" -> Sys.getenv_opt isabelle_shared_var
  | _ -> None

let provers l = Layout.switches l / "provers"
let z3_dir l = provers l / "z3-4.13.4"
let cvc5_dir l = provers l / "cvc5-1.2.1"
let z3_bin l = z3_dir l / "z3-4.13.4-x64-glibc-2.35" / "bin"
let cvc5_bin l = cvc5_dir l / "cvc5-Linux-x86_64-static" / "bin"
let elan_home l = Layout.switches l / "elan"
let rust_dir l = Layout.switches l / "rust"
let rustup_home l = rust_dir l / "rustup"
let cargo_home l = rust_dir l / "cargo"
let isabelle_user_home l = Layout.switches l / "isabelle-home"

let home l t =
  match t with Lean _ -> elan_home l | _ -> Layout.switches l / name t

let lean_toolchain v = "leanprover/lean4:" ^ v
let fstar_exe l v = home l (Fstar v) / "bin" / "fstar.exe"

(* The zip's entries are verus-x86-linux/...: no strip option for unzip. *)
let verus_dir l v = home l (Verus v) / "verus-x86-linux"

let rust_env l =
  [
    Command.Set ("RUSTUP_HOME", rustup_home l);
    Command.Set ("CARGO_HOME", cargo_home l);
    Command.Prepend_path (cargo_home l / "bin");
  ]

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
  | Verus v ->
      {
        Command.prog;
        args;
        cwd;
        env = rust_env l @ [ Command.Prepend_path (verus_dir l v) ] @ env;
      }
  | Isabelle v ->
      {
        Command.prog;
        args;
        cwd;
        env =
          Command.Set ("USER_HOME", isabelle_user_home l)
          :: Command.Prepend_path (home l (Isabelle v) / "bin")
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
       @
       if strip > 0 then [ Printf.sprintf "--strip-components=%d" strip ]
       else []))

let unzip l ~archive ~into =
  once ~dir:into ("unpack " ^ archive)
    (Command.v ~cwd:into "unzip"
       [ "-q"; "-o"; Layout.downloads l / archive; "-d"; into ])

let rust_toolchain_dir l rust =
  rustup_home l / "toolchains" / (rust ^ "-x86_64-unknown-linux-gnu")

(* rustup in [switches/rust] ([RUSTUP_HOME], [CARGO_HOME]), shared by the
   Verus releases, then the release's Rust toolchain with the default
   profile, as Anvil's CI installs it ([rustup toolchain install]). *)
let rust l rust =
  let init = Layout.downloads l / rustup_init.file in
  download l rustup_init
  @ [
      Step.run "chmod rustup-init"
        (Command.v ~cwd:(Layout.downloads l) "chmod" [ "+x"; init ]);
    ]
  @ once ~dir:(rust_dir l) "rustup-init"
      (Command.v ~env:(rust_env l) ~cwd:(Layout.downloads l) init
         [ "-y"; "--no-modify-path"; "--default-toolchain"; "none" ])
  @ [
      Step.run
        ~creates:(rust_toolchain_dir l rust)
        ("rustup toolchain install " ^ rust)
        (Command.v ~env:(rust_env l) ~cwd:(rust_dir l) "rustup"
           [ "toolchain"; "install"; rust; "--profile"; "default" ]);
    ]

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
            (download l d @ tar_x l ~archive:d.file ~into:(home l t) ~strip:2))
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
  | Verus v -> (
      match verus_release v with
      | None -> Error ("no digest known for Verus " ^ v)
      | Some (sha256, rust_version) ->
          let d = verus_download v sha256 in
          Ok
            (rust l rust_version @ download l d
            @ unzip l ~archive:d.file ~into:(home l t)))
  | Isabelle v -> (
      let user_home = [ Step.Mkdir (isabelle_user_home l) ] in
      match (isabelle_release v, isabelle_shared v) with
      | Some d, _ ->
          let into = home l t in
          let archive = Layout.downloads l / d.file in
          (* The tarball (1.2 GB) is removed once unpacked; once the unpacked
             release is marked done, nothing is downloaded again. *)
          if Sys.file_exists (into / ".upgrade_builds-done") then Ok user_home
          else
            Ok
              (download l d
              @ tar_x l ~archive:d.file ~into ~strip:1
              @ [ Step.Remove archive ] @ user_home)
      | None, Some shared ->
          Ok
            (Step.Mkdir (Layout.switches l)
            :: Step.run ~creates:(home l t) "link the shared Isabelle2026"
                 (Command.v ~cwd:(Layout.switches l) "ln"
                    [ "-s"; shared; home l t ])
            :: user_home)
      | None, None ->
          Error
            (Printf.sprintf "%s needs %s (the shared cache's unpacked release)"
               (name t) isabelle_shared_var))

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
  | Verus v ->
      let rust = Option.value (verus_rust v) ~default:"none" in
      [
        Command.v ~cwd "cat" [ verus_dir l v / "version.json" ];
        run "z3" [ "--version" ];
        run "rustc" [ "+" ^ rust; "--version" ];
        run "cargo" [ "+" ^ rust; "--version" ];
        run "rustup" [ "--version" ];
        run "rustc" [ "--version" ];
      ]
  | Isabelle v ->
      [
        run "isabelle" [ "version"; "-i" ];
        run "isabelle"
          [ "getenv"; "ISABELLE_HOME_USER"; "ML_SYSTEM"; "ML_PLATFORM" ];
        Command.v ~cwd "ls" [ home l (Isabelle v) / "contrib" ];
        run "isabelle"
          [ "getenv"; "Z3_VERSION"; "CVC5_VERSION"; "VERIT_VERSION" ];
      ]
  | Why3 _ ->
      [
        run "why3" [ "--version" ];
        run "why3" [ "config"; "list-provers" ];
        run "alt-ergo" [ "--version" ];
        run "z3" [ "--version" ];
        run "cvc5" [ "--version" ];
      ]
