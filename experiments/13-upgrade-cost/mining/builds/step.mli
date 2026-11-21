(** One step of an install, a preparation or a measured build. *)

type on_failure =
  | Stop  (** The steps after a failed one are not run. *)
  | Continue  (** The next steps run anyway (independent replays). *)

type t =
  | Run of {
      label : string;
      command : Command.t;
      creates : string option;
          (** A path that exists once the step has succeeded: the step is
              skipped when it exists (a download, a new opam switch). *)
      clears : string option;
          (** A directory emptied (deleted, then created again) before the step
              runs, when it is not skipped: what an interrupted earlier attempt
              may have left there. *)
      on_failure : on_failure;
    }
  | Edit of { label : string; dir : string; edits : Edit.t list }
      (** Applies [edits] to the files under [dir], in order. *)
  | Mkdir of string  (** Creates a directory and its parents if needed. *)
  | Touch of string
      (** Creates an empty file if it does not exist: the mark that the steps
          before it succeeded. *)
  | Rename of { src : string; dst : string }
      (** Renames [src] to [dst]; skipped when [src] does not exist and [dst]
          does (the download it completes was already done). *)
  | Sha256 of { file : string; expected : string }
      (** Computes the SHA-256 digest of [file] with [sha256sum]; fails, and
          deletes [file], if it differs from [expected]. *)
  | Remove of string
      (** Deletes a file or a directory tree, without following symbolic links;
          nothing to do if it does not exist. *)

val run :
  ?creates:string ->
  ?clears:string ->
  ?on_failure:on_failure ->
  string ->
  Command.t ->
  t
(** [run ~creates ~clears ~on_failure label command] is a [Run] step.
    [on_failure] defaults to [Stop]. *)

val label : t -> string
(** [label s] names [s] in logs and result rows. *)

val describe : prefix:string list -> t -> string
(** [describe ~prefix s] is [s] for a dry run, with the command of a [Run] step
    run under [prefix] (see {!Command.prefixed} and {!Limits.prefix}). *)
