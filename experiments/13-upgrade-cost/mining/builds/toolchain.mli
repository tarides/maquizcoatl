(** The toolchains of Part A, how to install them under {!Layout.switches}, and
    how to run a program with each.

    - Rocq: a local opam switch per version ([switches/rocq-<v>]), OCaml 4.14.2
      (the version both Warblre's and Linden's CI test), the [rocq-released]
      repository, [rocq-core] pinned to the version, and [rocq-stdlib].
    - Lean: elan v4.2.4 in [switches/elan] ([ELAN_HOME]), then one toolchain
      [leanprover/lean4:<v>] per version. mathlib caches are per project (see
      {!Target}).
    - F*: the Linux x86_64 binary release, checked against its published SHA-256
      digest, unpacked in [switches/fstar-<v>]. It ships its own Z3.
    - Why3: a local opam switch per version ([switches/why3-<v>]), OCaml 4.14.2,
      [why3.<v>] and Alt-Ergo 2.6.2, plus Z3 4.13.4 and CVC5 1.2.1 binaries
      (checked against digests recorded here, since these releases publish none)
      shared by both versions ([switches/provers]); the prover configuration is
      [switches/why3-<v>/why3.conf] ([WHY3CONFIG]). These prover versions are
      the newest that both Why3 1.8.2 and 1.9.0 accept
      ([share/provers-detection-data.conf]), so both sides replay with the same
      provers.
    - Verus: rustup 1.29.3 in [switches/rust] ([RUSTUP_HOME]
      [switches/rust/rustup], [CARGO_HOME] [switches/rust/cargo]), shared by the
      releases, then the release's Rust toolchain (default profile, as Anvil's
      CI), then the release's x86-linux zip, checked against a digest recorded
      here, unpacked in [switches/verus-<v>]. It ships its own Z3.
    - Isabelle: Isabelle2025-2's Linux tarball, checked against a digest
      recorded here, unpacked in [switches/isabelle-Isabelle2025-2], tarball
      removed; Isabelle2026 is the shared toolchain cache's unpacked release,
      named by the variable [UPGRADE_BUILDS_ISABELLE2026] and linked (read only)
      as [switches/isabelle-Isabelle2026]. Both use [USER_HOME]
      [switches/isabelle-home], so heaps never go into the shared cache.

    Every opam command uses the root {!Layout.opam_root}, with system
    dependencies (depexts) disabled: a missing system library makes the install
    fail instead of calling [sudo]. *)

type t =
  | Rocq of string
  | Lean of string
  | Fstar of string
  | Why3 of string
  | Verus of string
  | Isabelle of string

val all : t list
(** [all] is the toolchains of the plan: Rocq 9.2.0 and 9.3.0, Lean v4.34.0-rc1
    and v4.36.0, F* v2026.10.25 and v2026.11.15, Why3 1.8.2 and 1.9.0, Verus
    0.2026.07.12.0b42f4c and 0.2026.11.22.1ce6a59, Isabelle2025-2 and
    Isabelle2026. Only these can be installed. *)

val name : t -> string
(** [name t] is [t]'s name on the command line: [rocq-9.2.0], [lean-v4.36.0],
    [fstar-v2026.11.15], [why3-1.9.0], [verus-0.2026.11.22.1ce6a59],
    [isabelle-Isabelle2026]. *)

val of_name : string -> t option
(** [of_name s] is the toolchain of {!all} named [s], if any. *)

val home : Layout.t -> t -> string
(** [home l t] is the directory where [t] is installed: its opam switch, the
    elan home (shared by the Lean toolchains), or the unpacked F* release. *)

val install : Layout.t -> Limits.t -> t -> (Step.t list, string) result
(** [install l lim t] is the steps installing [t], with [lim.jobs] parallel
    jobs. Steps whose result exists are skipped, so installing again only redoes
    what is missing. It is an error if [t] is not in {!all}. *)

val opam : Layout.t -> cwd:string -> string list -> Command.t
(** [opam l ~cwd args] is [opam args] on the opam root of [l]. *)

val command :
  Layout.t ->
  t ->
  ?env:Command.env list ->
  cwd:string ->
  string ->
  Command.arg list ->
  Command.t
(** [command l t ~env ~cwd prog args] is [prog args] run with [t]: through
    [opam exec] in its switch for Rocq and Why3, with elan's or F*'s [bin]
    directory in front of [PATH] for Lean and F*, and [FSTAR_EXE] set to
    {!fstar_exe} for F*; with [RUSTUP_HOME], [CARGO_HOME], the cargo [bin]
    directory and the Verus directory in front of [PATH] for Verus; with
    [USER_HOME] set and Isabelle's [bin] in front of [PATH] for Isabelle. [env]
    is applied last. *)

val lean_toolchain : string -> string
(** [lean_toolchain v] is the elan toolchain name of Lean [v]
    ([leanprover/lean4:v]). *)

val verus_rust : string -> string option
(** [verus_rust v] is the Rust toolchain of Verus release [v], if known. *)

val fstar_exe : Layout.t -> string -> string
(** [fstar_exe l v] is the F* executable of release [v]. *)

val probes : Layout.t -> t -> cwd:string -> Command.t list
(** [probes l t ~cwd] is the commands whose output records the versions of [t]
    and of its provers, run from [cwd]. *)
