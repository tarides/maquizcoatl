(** Directories of the work directory ([<workdir>/exp13] in the plan).

    - [opam/]: the opam root used by every opam command ([OPAMROOT]), so that
      the host's own opam state is never changed;
    - [downloads/]: release archives;
    - [switches/]: toolchains (opam switches, elan, F* releases, provers);
    - [build/]: one directory per project, side and variant;
    - [cache/]: the caches of the tools ([XDG_CACHE_HOME]: the mathlib and dune
      caches);
    - [logs/]: one directory per install, preparation or run. *)

type t

val make : string -> t
(** [make dir] is the layout under [dir], made absolute against the current
    directory if it is relative. *)

val workdir : t -> string
val opam_root : t -> string
val downloads : t -> string
val switches : t -> string
val build : t -> string
val cache : t -> string
val logs : t -> string

val environment : t -> Command.env list
(** [environment l] is the changes made to the driver's environment for every
    command, so that the tools keep their state under [l] and the user's
    settings do not change the runs: [XDG_CACHE_HOME] is {!cache}, the user's
    git configuration is ignored ([GIT_CONFIG_GLOBAL=/dev/null]), and the
    variables naming an opam switch or OCaml libraries ([OPAMSWITCH],
    [OPAM_SWITCH_PREFIX], [OCAMLPATH], [OCAMLFIND_CONF], [CAML_LD_LIBRARY_PATH])
    are removed. *)
