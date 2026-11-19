(** Output of [git diff --numstat -z --no-renames]. *)

type entry = {
  added : int option;  (** [None] for a binary file. *)
  removed : int option;  (** [None] for a binary file. *)
  path : string;  (** Unquoted; it may contain any character but NUL. *)
}

type totals = { files : int; added : int; removed : int }
(** Binary files count as files, with no lines. *)

val parse : string -> entry list
(** [parse output] is the entries of [output]: NUL-terminated records
    [added<TAB>removed<TAB>path], as printed with [-z]. Blank records are
    skipped.

    @raise Failure on a record of another shape. *)

val keep : under:string list -> exclude:string list -> entry -> bool
(** [keep ~under ~exclude e] is [true] iff [e.path] lies below one of the
    directories [under] (any path if [under] is empty) and matches none of the
    patterns [exclude] (see {!Glob.matches}). *)

val totals : entry list -> totals
(** [totals entries] sums [entries]. *)

val zero : totals
(** [zero] is the totals of no entry. *)

val add : totals -> totals -> totals
(** [add a b] is the sum of [a] and [b]. *)
