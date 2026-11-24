(** Changes to a project's files before a build: the toolchain bump of the
    latest side, or a dependency moved to another commit.

    Edits are idempotent, so that preparing a directory twice gives the same
    files. *)

type t =
  | Write of { file : string; contents : string }
      (** Replaces the whole contents of [file]. *)
  | Replace of { file : string; old : string; by : string }
      (** Replaces the only occurrence of [old] in [file] by [by]. Neither
          string may contain the other. *)

val file : t -> string
(** [file e] is the path, relative to the project directory, that [e] changes.
*)

val apply_string : t -> string -> (string, string) result
(** [apply_string e s] is [s] changed by [e]. A [Replace] whose [old] does not
    occur in [s] while [by] occurs exactly once is already applied: the result
    is [s]. Any other number of occurrences of [old] is an error. *)

val apply : dir:string -> t -> (unit, string) result
(** [apply ~dir e] changes the file [dir/(file e)] by {!apply_string}. *)

val contains : sub:string -> string -> bool
(** [contains ~sub s] is [true] if [sub] is a non-empty substring of [s]. *)

val describe : t -> string
(** [describe e] is a one-line description of [e]. *)
