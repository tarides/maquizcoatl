(** Read access to a git repository.

    The mining logic only sees this record, so that tests can provide an
    in-memory repository. {!git} reads a local clone; it needs no working tree.
    Dates are committer dates in the committer's own time zone, [YYYY-MM-DD], so
    results do not depend on the time zone of the machine. *)

type commit = {
  hash : string;
  parents : string list;  (** First parent first. *)
  date : string;  (** Committer date, [YYYY-MM-DD]. *)
  subject : string;
  body : string;
}

type t = {
  first_parent_log :
    head:string ->
    since:string ->
    until:string ->
    paths:string list ->
    commit list;
      (** Commits on the first-parent line of [head], committed between the
          dates [since] and [until] (both included), oldest first. With
          non-empty [paths] (patterns, see {!Glob.matches}), only the commits
          whose diff against their first parent touches one of them. *)
  files : string -> string list;  (** [files c] is the paths at commit [c]. *)
  show : string -> string -> string;
      (** [show c path] is the contents of [path] at commit [c], which must
          exist. *)
  numstat : string -> string -> Numstat.entry list;
      (** [numstat a b] is the diff from [a] to [b], without rename detection.
      *)
  tags_containing : string -> string list option;
      (** [tags_containing c] is the tags whose history contains the commit [c],
          or [None] if the repository has no commit [c] (the tool's clone is not
          fetched from its remote for that) or [c] is an ambiguous abbreviation.
      *)
  authors : since:string -> until:string -> string -> string list;
      (** [authors ~since ~until path] is the distinct author names of the
          commits of the current branch that touch [path], committed between the
          dates [since] and [until] (both included). *)
}

exception Git_error of string
(** Raised by {!git}'s functions when [git] cannot be run, fails, or prints
    output of an unexpected shape, with its command line and error output. *)

val git : string -> t
(** [git dir] reads the repository at [dir]. Git runs with [core.quotePath] and
    [log.showSignature] turned off, whatever the user's configuration, and
    without the inherited variables that would select another repository
    ([GIT_DIR], [GIT_WORK_TREE], ...: see [git rev-parse --local-env-vars]). *)

val environment : inherited:string array -> string list -> string array
(** [environment ~inherited env] is the environment git runs with: [inherited]
    without the variables that would select another repository (see {!git}) and
    without the variables that [env] sets, followed by the bindings [env] (each
    [NAME=value]). *)

val parse_log : string -> commit list
(** [parse_log output] is the commits of [output], printed by [git log] with the
    format [%H%x1f%P%x1f%cs%x1f%s%x1f%b%x1e], in the same order.

    @raise Git_error on a record of another shape. *)
