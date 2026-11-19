(** Result files: CSV tables and a Markdown summary.

    Per-release figures group the bump and snapshot rows of a project by the
    tool series they reach ({!Mine.row.to_series}), since several rows can reach
    one series: a release candidate, then the stable release, or several pinned
    commits of one release. A group's lines are the sum of its rows, and it
    spans the largest span of its rows ({!Mine.row.spanned}). Rows that go back
    to an older series, and rows that reach no series (for example a bump of an
    opaque pin only), belong to no group.

    In the tables, a field that lists several values separates them with [; ],
    since values can contain blanks. *)

type result = {
  project : string;  (** Label of the project. *)
  tool : Tool.t;
  rows : Mine.row list;  (** The project's rows, in history order. *)
  missing : Mine.missing list;
      (** Measured directories missing where they must exist (see
          {!Mine.missing_paths}). *)
}

val csv_field : string -> string
(** [csv_field s] is [s] quoted as a CSV field when it contains a comma, a
    double quote or a line break (RFC 4180), [s] otherwise. *)

val rows_csv : Mine.row list -> string
(** [rows_csv rows] is one line per row, with a header and an empty [class]
    column for the manual classification. *)

val per_release_csv : result list -> string
(** [per_release_csv results] is one line per project and tool series reached,
    in the order the series are first reached: its units, latest date, releases
    reached, releases spanned, summed files and lines, and lines per release
    spanned (empty when the group spans no release). *)

val summary_md : since:string -> until:string -> result list -> string
(** [summary_md ~since ~until results] is a Markdown table with one line per
    project: tool, tool cadence in the window (see {!Tool.cadence}), rows per
    kind, releases reached (summed over the groups that span at least one
    release), lines changed in bumps and snapshots, median of the groups' lines
    per release, unattributed lines (bump and snapshot lines outside those
    groups), largest row. After the table, the measured directories that are
    missing where they must exist, or a line saying that none is. *)
