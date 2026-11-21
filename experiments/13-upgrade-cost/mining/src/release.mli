(** Tool releases, as recorded in [releases/<tool>.tsv]. *)

type t = {
  version : string;  (** The tag, as published (e.g. [V9.3.0], [v4.36.0]). *)
  date : string;  (** Publication date, [YYYY-MM-DD]. *)
  prerelease : bool;
}

val is_date : string -> bool
(** [is_date s] is [true] iff [s] has the shape [YYYY-MM-DD] (digits and dashes;
    the month and day ranges are not checked). Dates in this shape compare as
    strings. *)

val parse_tsv : string -> t list
(** [parse_tsv contents] is the releases listed in [contents]: a header line
    starting with [version], [date] and [prerelease], then one tab-separated
    line per release. Further columns are ignored.

    @raise Failure on a malformed header or line. *)

val load : string -> t list
(** [load file] is [parse_tsv] of the contents of [file].

    @raise Failure as {!parse_tsv} does, with [file] in the message.
    @raise Sys_error if [file] cannot be read. *)
