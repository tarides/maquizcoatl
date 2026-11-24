(** Result rows: the build table [<date>-exp-13-builds.csv] (one row per
    project, side, variant and phase) and the per-step table of a run. *)

type t = {
  project : string;
  side : string;
  variant : string;  (** [""] for none. *)
  phase : string;  (** [prepare] or [build]. *)
  toolchain : string;
  limits : Limits.t;
  host : Host.t;
  load_before : float option;
  load_after : float option;
  start : float;  (** Unix time. *)
  results : Exec.step_result list;
  failing_files : string list;
  log_dir : string;
}

val outcome : Exec.step_result list -> string
(** [outcome rs] is [ok] if no step failed, else [interrupted] if the driver was
    interrupted, else [timeout] if one timed out, else [error] if the driver
    could not run one, else [failed]. *)

val header : string list
(** [header] is the columns of the build table: project, side, variant, phase,
    toolchain, outcome, steps run, failed steps, first failed step, number and
    list ([;]-separated) of failing files, wall, user and system seconds summed
    over the steps run, jobs, CPU set, niceness, timeout per step, host name,
    CPU model, processors, one-minute load before and after, UTC start, log
    directory. *)

val fields : t -> string list
(** [fields r] is [r] in the columns of {!header}. *)

val step_header : string list
(** [step_header] is the columns of the per-step table: index, label, outcome,
    UTC start, wall, user and system seconds, log file, command. *)

val step_fields : Exec.step_result -> string list
(** [step_fields s] is [s] in the columns of {!step_header}. *)

val csv : string list -> string list list -> string
(** [csv header lines] is a CSV document (RFC 4180 quoting). *)

val check : file:string -> header:string list -> (unit, string) result
(** [check ~file ~header] checks that a line can be appended to the CSV file
    [file] with {!append}: its directory exists and is writable, and [file] is
    missing, empty, or starts with the line [header]. A run calls it before its
    first step, so that a long build is not lost to a wrong [--out]. *)

val append :
  file:string -> header:string list -> string list -> (unit, string) result
(** [append ~file ~header fields] appends the line [fields] to the CSV file
    [file], writing [header] first if [file] is missing or empty. It is an error
    if {!check} fails. *)
