(** Finds and measures the changes that adapted a project to new tool versions.

    In commit mode, a unit is a commit on the first-parent line of the project's
    head: a merge stands for its whole pull request (diff against its first
    parent), any other commit for itself. A unit is a {e bump} when the values
    read by one of the project's pins differ between its first parent and
    itself, or when a pin file that holds values before and after it changes
    them (the middle step of an upgrade split over three files changes no pin's
    values). A pin file that appears or disappears without values is no change.
    Units whose message contains a keyword are selected too, as {e keyword}
    rows.

    A bump completes the bump just before it, and joins its row, when all of the
    following hold: no other selected unit lies in between; it reaches no new
    release (see [reached]); it moves at least one file of a resolvable pin (see
    {!Pin.resolve}) to a version that the previous bump introduced; and every
    file of a resolvable pin that it changes ends on versions that the files
    changed by the previous bump hold after it. This is the second half of an
    upgrade split over several pin files. A bump that only removes a pin, only
    changes opaque pins, or only shrinks a CI matrix keeps its own row. Versions
    are compared by the release they name for {!Pin.Release} pins, as written
    otherwise.

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
  from_ : string list;
      (** Pin values before, without repeats; empty for a keyword row. *)
  to_ : string list;
      (** Pin values after, without repeats; empty for a keyword row. *)
  reached : string list;
      (** What the pin values that are new in the row resolve to, except the
          releases that the values before already resolved to: a release,
          [unreleased] for a pinned commit that no release contains,
          [unknown-commit] for one missing from the tool's clone (or an
          ambiguous abbreviation), [unresolved:v] for a value [v] that is no
          known release (for example a range such as [>= 9.0.0]). *)
  to_series : string option;
      (** For a snapshot row, the series (see {!Tool.series}) of the newer
          release. For a bump row that moves some file of a resolvable pin to a
          value that resolves to a release, the newest series that the pin
          values after the row resolve to. [None] otherwise: a bump that only
          changes opaque pins, removes a pin, drops versions from a matrix or
          moves to unresolved values reaches no series. *)
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
      if a snapshot release is missing from the tool's list, a pin file cannot
      be read (see {!Pin.file_values}) or a diff cannot be parsed, with the
      project and the commit in the message.
    @raise Repo.Git_error if a git command fails. *)

type missing = {
  path : string;  (** A path of a measured directory. *)
  where : string;
      (** Where it is missing: [window start], [head], or a release tag. *)
  commit : string;
      (** The commit checked, abbreviated to 7 characters in commit mode, or the
          git ref of the release. *)
}
(** A measured directory path that holds no measured file in a tree where it
    must hold some. *)

val missing_to_string : missing -> string
(** [missing_to_string m] describes [m] in one line, for example
    [src/x missing at window start (4a249d7)]. *)

val missing_paths :
  Project.t ->
  clones:(string -> Repo.t) ->
  since:string ->
  until:string ->
  missing list
(** [missing_paths project ~clones ~since ~until] is the paths of the measured
    directories of [project] that hold no measured file where they must hold
    some, so that no change is silently left unmeasured. A measured file is one
    that the rows count: in commit mode, it matches {!Project.history.only} and
    none of the excluded patterns, pin files included; in snapshot mode, it
    matches none of {!Project.snapshots.exclude_snapshot}.

    In commit mode, the trees checked are the start of the window (the first
    parent of the first commit of the window on the first-parent line, or that
    commit if it has none) and the head; nothing is checked when the window has
    no commit or {!Project.history.under} is empty. At the start, a directory
    whose current path holds measured files is fine; otherwise each of its
    former paths must hold some (its current path, if it has none), and each one
    that does not is reported. At the head, its current path must hold measured
    files.

    In snapshot mode, each path must hold measured files in the trees of the
    first and the last release.

    @raise Repo.Git_error if a git command fails. *)

val kind_to_string : kind -> string
(** [kind_to_string k] is [bump], [keyword] or [snapshot], as in the result
    tables. *)
