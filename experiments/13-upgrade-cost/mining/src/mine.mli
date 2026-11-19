(** Finds and measures the changes that adapted a project to new tool versions.

    In commit mode, a unit is a commit on the first-parent line of the project's
    head: a merge stands for its whole pull request (diff against its first
    parent), any other commit for itself. A unit is a {e bump} when the values
    read by one of the project's pins differ between its first parent and
    itself. Units whose message contains a keyword are selected too, as
    {e keyword} rows.

    A bump completes the bump just before it, and joins its row, when all of the
    following hold: no other selected unit lies in between; it reaches no new
    release (see [reached]); it moves at least one file of a resolvable pin (see
    {!Pin.resolve}) to a version that the previous bump introduced; and every
    file of a resolvable pin that it changes ends on versions that the previous
    bump reached. This is the second half of an upgrade split over several pin
    files. A bump that only removes a pin, only changes opaque pins, or only
    shrinks a CI matrix keeps its own row. Versions are compared by the release
    they name for {!Pin.Release} pins, as written otherwise.

    In snapshot mode, each row is the diff of one directory between the trees of
    two consecutive releases. *)

type kind = Bump | Keyword | Snapshot

type row = {
  project : string;
  kind : kind;
  units : string list;
      (** Abbreviated commit hashes, or [from..to] release tags. *)
  date : string;  (** Date of the last unit, or of the newer release. *)
  subject : string;  (** First line of the last unit, or the directory. *)
  from_ : string list;  (** Pin values before; empty for a keyword row. *)
  to_ : string list;  (** Pin values after; empty for a keyword row. *)
  reached : string list;
      (** What the pin values that are new in the row resolve to, except the
          releases that the values before already resolved to: a release,
          [unreleased] for a pinned commit that no release contains,
          [unknown-commit] for one missing from the tool's clone, [unresolved:v]
          for a value [v] that is no known release (for example a range such as
          [>= 9.0.0]). *)
  to_series : string option;
      (** For a bump or snapshot row, the newest series (see {!Tool.series})
          that the pin values after the row resolve to, if any. *)
  spanned : int option;  (** For a bump or snapshot row, see {!Tool.spanned}. *)
  totals : Numstat.totals;
  authors : string list;  (** Snapshot mode only. *)
}

val run :
  Project.t ->
  tool:Tool.t ->
  clones:(string -> Repo.t) ->
  since:string ->
  until:string ->
  row list
(** [run project ~tool ~clones ~since ~until] is the rows of [project] for the
    window from [since] to [until] (dates, both included), in history order.
    [clones name] is the repository cloned under [name]: the project itself, the
    tool for {!Pin.Commit} pins, the authors' history. In snapshot mode, the
    window is not used: the rows cover the configured release pairs.

    @raise Failure
      if a snapshot release is missing from the tool's list, or a pin file
      cannot be read (see {!Pin.file_values}).
    @raise Repo.Git_error if a git command fails. *)

val kind_to_string : kind -> string
