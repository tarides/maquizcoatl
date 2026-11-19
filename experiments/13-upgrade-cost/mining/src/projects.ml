let tools =
  [
    ("rocq", Tool.Minor, []);
    ("lean", Tool.Minor, [ "leanprover/lean4:" ]);
    ("fstar", Tool.Exact, []);
    ("verus", Tool.Exact, [ "release/rolling/"; "release/" ]);
    ("why3", Tool.Minor, []);
    ("isabelle", Tool.Exact, [ "isabelle" ]);
  ]

let pin ?(strip = []) files format resolve =
  { Pin.files; format; strip; resolve }

let workflows = [ ".github/workflows/*.yml"; ".github/workflows/*.yaml" ]

(* Warblre and Linden declare an exact version ("= 9.1.1") or a range
   (">= 9.0.0") in their opam files, and test the versions of a CI matrix.
   An exact version resolves to its release; a range does not. rocq-stdlib
   has its own version numbers. *)
let rocq_pins =
  let exact pkg =
    pin ~strip:[ "= " ] [ "*.opam" ] (Pin.Opam_dep pkg) Pin.Release
  in
  [
    exact "rocq-core";
    exact "rocq-prover";
    exact "coq";
    pin [ "*.opam" ] (Pin.Opam_dep "rocq-stdlib") Pin.Opaque;
    pin workflows (Pin.Yaml_list "rocq") Pin.Release;
    pin workflows (Pin.Yaml_list "coq") Pin.Release;
  ]

let rocq_history head =
  {
    Project.head;
    pins = rocq_pins;
    under = [];
    only = [];
    exclude = [];
    (* The plan's pattern rocq|coq|9\.[0-9]|stdlib|compat, as substrings. *)
    keywords =
      [ "rocq"; "coq"; "stdlib"; "compat" ]
      @ List.init 10 (fun i -> Printf.sprintf "9.%d" i);
    keyword_periods = [];
  }

let warblre =
  {
    Project.name = "warblre";
    tool = "rocq";
    clone = "Warblre";
    mode =
      Project.History (rocq_history "d4b0e226464650d6854987f6d64364a301659ea0");
  }

let linden =
  {
    Project.name = "linden";
    tool = "rocq";
    clone = "Linden";
    mode =
      Project.History (rocq_history "3ef2cb4573f86e57a25245f84dd6a13402f418fd");
  }

let lean_regex =
  {
    Project.name = "lean-regex";
    tool = "lean";
    clone = "lean-regex";
    mode =
      Project.History
        {
          head = "32af6f33d80e1dad2b072da6981da58e92b08b9e";
          pins =
            [
              pin
                [
                  "lean-toolchain";
                  "regex/lean-toolchain";
                  "correctness/lean-toolchain";
                  "docbuild/lean-toolchain";
                ]
                Pin.Whole_file Pin.Release;
            ];
          under = [];
          only = [];
          (* The lakefiles only carry dependency revisions (mathlib). *)
          exclude =
            [ "**/lake-manifest.json"; "**/lakefile.toml"; "**/lakefile.lean" ];
          keywords = [];
          keyword_periods = [];
        };
  }

let everparse =
  {
    Project.name = "everparse-cbor";
    tool = "fstar";
    clone = "everparse";
    mode =
      Project.History
        {
          head = "270f5aab699ac284d8777d4f01be20a5d91ea47c";
          pins =
            [
              pin [ "opt/hashes.Makefile" ] (Pin.Make_var "FStar_hash")
                (Pin.Commit "FStar");
            ];
          (* EverParse PR 343 (3d13096c, 2026-10-18) moved the sources from src/ to
             lib/everparse/; four test modules stay in src/cbor/pulse. *)
          under =
            [
              Project.dir "lib/everparse/cbor"
                ~formerly:[ "src/cbor/spec"; "src/cbor/pulse" ];
              Project.dir "lib/everparse/lowparse" ~formerly:[ "src/lowparse" ];
            ];
          only = [ "**/*.fst"; "**/*.fsti" ];
          exclude = [];
          keywords = [];
          keyword_periods = [];
        };
  }

let creusot =
  {
    Project.name = "creusot";
    tool = "why3";
    clone = "creusot";
    mode =
      Project.History
        {
          head = "601d97891bb0bc0b569686cc946ef4980560b5d8";
          pins =
            [
              pin ~strip:[ "= git-"; "=" ] [ "creusot-deps.opam" ]
                (Pin.Opam_dep "why3") (Pin.Commit "why3");
              (* why3find has no release list: a change only selects the unit. *)
              pin ~strip:[ "= git-"; "=" ] [ "creusot-deps.opam" ]
                (Pin.Opam_dep "why3find") Pin.Opaque;
            ];
          under = [];
          only = [];
          exclude = [ "**/Cargo.lock" ];
          keywords = [];
          keyword_periods = [];
        };
  }

let anvil =
  {
    Project.name = "anvil";
    tool = "verus";
    clone = "anvil";
    mode =
      Project.History
        {
          head = "e83ea0f5516ce2ece26740266165180018741e66";
          pins =
            [
              pin workflows (Pin.Yaml_scalar "verus_release") Pin.Release;
              pin workflows (Pin.Yaml_scalar "VERUS_TAG") Pin.Release;
              pin workflows (Pin.Yaml_scalar "verus_commit") Pin.Opaque;
              pin [ "**/Cargo.toml" ] (Pin.Toml_string "vstd") Pin.Opaque;
              pin [ "rust-toolchain.toml" ] (Pin.Toml_string "channel")
                Pin.Opaque;
            ];
          under = [];
          only = [];
          exclude = [ "**/Cargo.lock" ];
          keywords =
            [
              "upgrade";
              "bump";
              "update";
              "stabiliz";
              "broken proofs";
              "fix proofs";
              "verus";
              "vstd";
              "z3";
            ];
          (* Anvil followed Verus HEAD or the latest release, without a pin,
             in these periods. *)
          keyword_periods =
            [ ("2026-04-16", "2026-07-22"); ("2026-07-28", "2026-11-19") ];
        };
  }

let why3_gallery =
  {
    Project.name = "why3-gallery";
    tool = "why3";
    clone = "why3";
    mode =
      Project.Snapshots
        {
          refs = [ ("1.8.2", "1.8.2"); ("1.9.0", "1.9.0") ];
          paths = [ "examples" ];
          exclude_snapshot = [];
          authors_from = None;
        };
  }

let afp =
  {
    Project.name = "afp-regex";
    tool = "isabelle";
    clone = "afp-releases";
    mode =
      Project.Snapshots
        {
          refs =
            [
              ("Isabelle2025", "afp-2025/master");
              ("Isabelle2025-1", "afp-2025-1/master");
              ("Isabelle2025-2", "afp-2025-2/master");
              ("Isabelle2026", "afp-2026/master");
            ];
          paths =
            [
              "thys/Regular-Sets";
              "thys/Regex_Equivalence";
              "thys/Posix-Lexing";
              "thys/Formula_Derivatives";
              "thys/MSO_Regex_Equivalence";
              "thys/Functional-Automata";
            ];
          exclude_snapshot = [];
          authors_from = Some "afp-devel";
        };
  }

let all =
  [ warblre; linden; lean_regex; everparse; why3_gallery; creusot; anvil; afp ]
