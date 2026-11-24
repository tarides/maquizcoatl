(** What to mine in one project. *)

type dir = {
  path : string;  (** Path at the head. *)
  formerly : string list;
      (** Earlier paths of the same files, before a move; they are measured too,
          at any commit. *)
}
(** A directory whose changes are measured. *)

type history = {
  head : string;  (** Commit at the snapshot date. *)
  pins : Pin.t list;  (** Where the project records the tool version. *)
  under : dir list;
      (** Directories whose changes are measured; [[]] for the whole repository.
      *)
  only : string list;
      (** Patterns; when non-empty, only the files that match one of them are
          measured (for example the F* sources). *)
  exclude : string list;
      (** Patterns of files not measured (lockfiles, generated files). Pin files
          are never measured. *)
  keywords : string list;
      (** Lower-case strings; a unit whose message contains one of them, as a
          substring and ignoring case, is also selected for manual
          classification. *)
  keyword_periods : (string * string) list;
      (** Date ranges, both ends included, where keywords apply; [[]] for the
          whole window. *)
}
(** Commit mode: the project's history, unit by unit. *)

type snapshots = {
  refs : (string * string) list;
      (** Release tags (as in the tool's release list) and the git refs of their
          trees, oldest first. *)
  paths : string list;  (** Directories measured, one row each. *)
  exclude_snapshot : string list;  (** Patterns of files not measured. *)
  authors_from : string option;
      (** Clone whose history gives the authors of each change. *)
}
(** Snapshot mode: diffs between the trees of consecutive releases. *)

type mode = History of history | Snapshots of snapshots

type t = {
  name : string;  (** Label in the results. *)
  tool : string;  (** Name of the tool, as in [releases/<tool>.tsv]. *)
  clone : string;  (** Directory of the clone, under the clones directory. *)
  mode : mode;
}

val dir : ?formerly:string list -> string -> dir
(** [dir ?formerly path] is the directory [path], with its earlier paths
    [formerly] (none by default). *)

val measured_dirs : dir list -> string list
(** [measured_dirs dirs] is every path of [dirs], current and former. *)
