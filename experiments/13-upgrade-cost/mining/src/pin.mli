(** Pins: where a project records the version of a tool it builds with.

    A pin reads values from the files matching its patterns. A value is a
    version, a commit, or an opaque constraint, depending on how the pin
    {!resolve}s. A project's tool version changes when the values read by one of
    its pins change (see {!Mine}). *)

(** How to read values from one file. Lines are trimmed. In the line-based
    formats, lines starting with [#] are ignored, and so is a comment after the
    key: a [#] that starts the value or follows a blank, outside a quoted
    string. A quote opens a quoted string only where a scalar starts: at the
    start of the value, or after a blank, [\[] or [,]. A key whose value is
    empty, or only a comment, has no value. *)
type format =
  | Whole_file  (** The trimmed contents, e.g. [lean-toolchain]. *)
  | Make_var of string
      (** [NAME := value], [NAME = value] or [NAME ?= value], optionally after
          [export]. *)
  | Yaml_list of string
      (** [key: [a, "b"]] on one line, or [key:] followed by [- a] lines. Only
          this subset of YAML is read: a flow list spread over several lines,
          and matrix [include:] entries such as [- key: a], are not. *)
  | Yaml_scalar of string  (** [key: value] or [key: "value"]. *)
  | Opam_dep of string
      (** The constraint of a package in an opam [depends] field: its tokens
          joined by single spaces, quotes removed. For the package [rocq-core],
          [{>= "9.0.0"}] reads as [>= 9.0.0], a constraint
          [{>= "9.0" & < "9.2"}] (possibly over several lines) as
          [>= 9.0 & < 9.2], and a package without constraint as the empty
          string. Comments and the other fields ([conflicts], [depopts], ...)
          are ignored. Strings are ["..."] or ["""..."""], with backslash
          escapes, as in opam. *)
  | Toml_string of string
      (** [key = "value"]; an inline table [key = { ... }] reads as its whole
          text. *)

(** How values relate to the tool's releases. *)
type resolve =
  | Release  (** A value is a release tag (see {!Tool.find}). *)
  | Commit of string
      (** A value is a commit of the tool's repository, cloned under the given
          name; it maps to the first release that contains it. *)
  | Opaque  (** Values only show that something changed. *)

type t = {
  files : string list;  (** Patterns, see {!Glob.matches}. *)
  format : format;
  strip : string list;
      (** Prefixes removed from each value, in order, e.g. [["= git-"]]. *)
  resolve : resolve;
}

val read : format -> string -> string list
(** [read format contents] is the values found in [contents].

    @raise Failure
      on an [Opam_dep] file whose string, comment, constraint or [depends] list
      is not terminated. *)

val file_values : t -> (string * string) list -> (string * string list) list
(** [file_values pin files] is, for each file [(path, contents)] of [files]
    whose path matches one of [pin.files], sorted by path, the sorted,
    deduplicated values read by [pin], with [pin.strip] applied.

    @raise Failure as {!read} does, with the file's path in the message. *)

val union : (string * string list) list -> string list
(** [union file_values] is the sorted, deduplicated values of all the files of
    [file_values]. *)

val values : t -> (string * string) list -> string list
(** [values pin files] is [union (file_values pin files)]. *)

val matches_file : t -> string -> bool
(** [matches_file pin path] is [true] iff [path] matches one of [pin.files]. *)
