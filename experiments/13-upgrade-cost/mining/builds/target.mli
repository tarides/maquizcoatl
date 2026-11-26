(** The projects of Part A (five) and of its follow-up for Verus and Isabelle
    (issue #25, two), their two sides, and the steps preparing, building and
    checking them (plan, "Part A: builds").

    Each project is checked out at its commit at the snapshot date in
    [build/<project>-<side>] (with the variant's name appended when the variant
    changes files), then:

    - [warblre], [linden] (Rocq 9.2.0, 9.3.0): preparation installs the opam
      dependencies of the checkout in the toolchain's switch
      ([opam install --deps-only .], which builds Linden's [pin-depends]
      Warblre); the measured steps are [dune build] (dune cache disabled) and
      [rocqchk] on the [.vo] files, with the arguments of each project's CI;
    - [lean-regex] (v4.34.0-rc1, v4.36.0): the latest side bumps
      [regex/lean-toolchain], [correctness/lean-toolchain] and the mathlib
      revision of [correctness/lakefile.toml], then runs [lake update];
      preparation fetches the mathlib cache ([lake exe cache get]); the measured
      steps are [lake build] in [regex/] then [correctness/], with
      [LEAN_NUM_THREADS] set to the number of jobs;
    - [pulse-examples] (F* v2026.10.25, v2026.11.15): the Pulse examples of F*
      v2026.10.25 ([pulse/share/pulse/examples], sparse checkout of [pulse/] and
      [mk/]); the measured step is their [verify] target, with the side's
      [fstar.exe];
    - [why3-gallery] (Why3 1.8.2, 1.9.0): the sessions of tag 1.8.2 (sparse
      checkout of [examples/]); one measured [why3 replay] per session (see
      {!Why3_sessions}), each one run whatever the previous ones gave, with
      [running_provers_max] set to the run's number of jobs;
    - [anvil] (Verus 0.2026.07.12.0b42f4c, 0.2026.11.22.1ce6a59): Anvil at
      [3c95bbb]; the latest side moves [rust-toolchain.toml] to Rust 1.100.0 and
      [vstd] to the release's version, and replaces the git dependency
      [verus_temporal_logic] by a path dependency on a checkout of verus-tla
      [8bb157b] next to it ([build/anvil-latest-verus-tla]) with the same [vstd]
      move; preparation runs [cargo fetch], then [cargo verus verify --lib] with
      [--no-verify] forwarded to Anvil's crate only
      ([--fwd-verus-args-to roots]), so that the dependencies are built and
      verified, then [cargo clean -p verifiable-controllers]; the measured step
      is [cargo verus verify --lib -j N] with [--num-threads N --time-expanded]
      forwarded to Anvil's crate only;
    - [afp-regex] (Isabelle2025-2, Isabelle2026): the six AFP regex entries of
      AFP 2025-2 and the entries they require (sparse checkout of
      [isabelle-prover/mirror-afp-2025-2] at [fa30b560ab75]), one [-d] per
      entry; preparation builds the requirements of the seven sessions that do
      not descend from them ([isabelle build -R -x ...], listed first with
      [isabelle sessions]); the measured step is
      [isabelle build -b -o document=false -c] of the seven sessions and
      [Coinductive_Languages], with [-j N/4] and [-o threads=4] (from 8 jobs:
      [-j 2 -o threads=4]). *)

type side = Pinned | Latest

val side_to_string : side -> string
(** [side_to_string s] is [pinned] or [latest]. *)

type t

val all : t list
(** [all] is the seven projects, in the plans' order. *)

val name : t -> string
(** [name t] is [t]'s name on the command line ([warblre], [lean-regex]...). *)

val find : string -> t option
(** [find n] is the project of {!all} named [n], if any. *)

val toolchain : t -> side -> Toolchain.t
(** [toolchain t s] is the toolchain of side [s] of [t]. *)

type variant
(** A change to a side, named on the command line: Linden with Warblre moved to
    [d4b0e22] ([warblre-d4b0e22]), the reduced Why3 session list ([reduced]). *)

val variants : t -> (string * string) list
(** [variants t] is the names and descriptions of [t]'s variants. *)

val variant : t -> string option -> (variant option, string) result
(** [variant t name] is [t]'s variant [name] ([None] for none). It is an error
    if [t] has no such variant. *)

val variant_name : variant -> string
(** [variant_name v] is [v]'s name on the command line. *)

val pins : t -> variant option -> (string * string) list
(** [pins t v] is the opam packages that the checkout of [t] with variant [v]
    pins ([pin-depends]), with their commit: Warblre for Linden. *)

val pin_list : Layout.t -> t -> side -> Command.t option
(** [pin_list l t s] is the command listing the pins of the opam switch of side
    [s] of [t], if [t] has {!pins}. The switch of a Rocq version is shared by
    every project, side and variant on it, so preparing one can re-pin a package
    another one needs. *)

val check_pins : t -> variant option -> string -> (unit, string) result
(** [check_pins t v output] checks that [output] of {!pin_list} pins each
    package of [pins t v] to its commit. *)

val dir : Layout.t -> t -> side -> variant option -> string
(** [dir l t s v] is the checkout of side [s] of [t] with variant [v]. *)

val prepare : Layout.t -> Limits.t -> t -> side -> variant option -> Step.t list
(** [prepare l lim t s v] is the steps checking out [t], installing what its
    build needs, and removing the outputs of an earlier build (see {!stale}).
    They are not timed for criterion 4. *)

val stale : Layout.t -> t -> side -> variant option -> string list
(** [stale l t s v] is the build outputs of an earlier build found in the
    checkout (relative paths): [_build] for Rocq, [regex/.lake/build] and
    [correctness/.lake/build] for lean-regex (not the packages), the top
    [_cache] and [_output] of the Pulse examples. A measured build must start
    without them, or it would be incremental. For [anvil], the cargo
    fingerprints of [verifiable-controllers] under [target/]. The Why3 gallery
    and [afp-regex] ([-c] cleans the measured sessions) have none. *)

val measured :
  Layout.t ->
  Limits.t ->
  t ->
  side ->
  variant option ->
  (Step.t list, string) result
(** [measured l lim t s v] is the build and check steps whose time is measured.
    For [why3-gallery] it lists the sessions of the checkout: it is an error if
    the checkout is missing or has no session. *)

val failure_format : t -> Failures.format
(** [failure_format t] is how the failing files are read from the logs of [t]'s
    failed steps. *)

val probes : Layout.t -> t -> side -> variant option -> Command.t list
(** [probes l t s v] is the commands recording the toolchain's and provers'
    versions, and the checkout's commit, status and changes ([git diff --stat]);
    for [pulse-examples], also the KaRaMeL commit F* pins (its [karamel]
    submodule). *)
