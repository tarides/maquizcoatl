(** Running steps: processes, logs and timings.

    Each [Run] step runs under the {!Limits}, from its directory, with its
    standard input from [/dev/null] and its standard output and error in its own
    log file. Its environment is the driver's, changed first by the run's base
    changes, then by the command's own. Its wall-clock time is measured by the
    driver; its user and system times are those of its process tree (the
    children the driver waited for, as [times] reports them). *)

type outcome =
  | Success
  | Skipped  (** The step's result already existed. *)
  | Exit of int  (** Non-zero exit code. *)
  | Timed_out
  | Signal of int
      (** Killed by this signal, in Linux's numbering (9 for [KILL]). *)
  | Interrupted of string
      (** The driver received this signal ([INT], [TERM] or [HUP]) and stopped
          the step (see {!with_interrupts}). *)
  | Driver_error of string
      (** The driver could not run the step: a program not found in [PATH] (the
          program run through [opam exec] is not checked: its absence is the
          command's failure), a file list without a match, an edit that does not
          apply, a digest mismatch. *)

val classify : timeout:int -> wall:float -> Unix.process_status -> outcome
(** [classify ~timeout ~wall status] is the outcome of a command run under
    [timeout] (see {!Limits}) that ended with [status] after [wall] seconds.
    [timeout] exits with 124 when it stopped the command with [TERM], and with
    128 plus the signal number when the command died of a signal, which is how
    [KILL] after {!Limits.kill_after} shows: such a code is a timeout when
    [wall] reached [timeout], the signal otherwise. Other codes are the
    command's own. *)

val failed : outcome -> bool
(** [failed o] is [false] for [Success] and [Skipped] only. *)

val outcome_to_string : outcome -> string
(** [outcome_to_string o] is [ok], [skipped], [exit N], [timeout], [signal N],
    [interrupted SIG] or [error: MESSAGE]. *)

type step_result = {
  index : int;  (** Position in the run, from 1. *)
  label : string;
  command : string;  (** As {!Command.to_string} shows it, or a description. *)
  start : float;  (** Unix time. *)
  wall : float;  (** Seconds. *)
  user : float;
  sys : float;
  outcome : outcome;
  log : string option;  (** Log file of a [Run] step that was started. *)
}

val log_name : int -> string -> string
(** [log_name index label] is the log file name of a step: the index on two
    digits, then the label with every character other than a letter, a digit,
    [.] or [-] replaced by [_], then [.log]. *)

val timestamp : float -> string
(** [timestamp t] is the Unix time [t] in UTC, [YYYY-MM-DDTHH:MM:SSZ]. *)

val sha256sum : string -> string option
(** [sha256sum output] is the digest printed by [sha256sum FILE]: the first word
    of [output] when it is 64 lower-case hexadecimal digits. *)

val mkdir_p : string -> unit
(** [mkdir_p dir] creates [dir] and its missing parents.

    @raise Sys_error if one cannot be created. *)

val remove_tree : string -> unit
(** [remove_tree path] deletes the file or directory tree [path], without
    following symbolic links. It does nothing if [path] does not exist.

    @raise Sys_error or [Unix.Unix_error] if an entry cannot be deleted. *)

val with_interrupts : (unit -> 'a) -> 'a
(** [with_interrupts f] is [f ()], during which [INT], [TERM] and [HUP] do not
    kill the driver: they send [TERM] to the command running, if any ([timeout]
    passes it on to the whole command), and make {!run} stop after it, with an
    [Interrupted] result, so that what ran can still be recorded. The previous
    signal behaviours are restored afterwards. *)

val interrupted : unit -> bool
(** [interrupted ()] is [true] if a signal was received in the current or the
    last {!with_interrupts}. *)

val run :
  limits:Limits.t ->
  env:Command.env list ->
  log_dir:string ->
  Step.t list ->
  step_result list
(** [run ~limits ~env ~log_dir steps] runs [steps] in order, with the base
    environment changes [env], printing one progress line per step, and is their
    results. After a failed step whose [on_failure] is [Stop] (every step but
    [Continue] runs), or an interruption, the remaining steps are not run and
    have no result. [log_dir] must exist. *)

val probe_timeout : int
(** [probe_timeout] is the time, in seconds, allowed to each command of {!probe}
    and {!capture}. *)

val probe :
  limits:Limits.t ->
  env:Command.env list ->
  file:string ->
  Command.t list ->
  unit
(** [probe ~limits ~env ~file commands] runs [commands] one after the other,
    under [limits] with {!probe_timeout}, and appends their command lines,
    output and exit status to [file]. A command that cannot run is recorded as
    such; if [file] cannot be written, the error is printed on standard error.
    Nothing is run after an interruption. *)

val capture :
  limits:Limits.t ->
  env:Command.env list ->
  Command.t ->
  (string, string) result
(** [capture ~limits ~env command] is the standard output and error of
    [command], run under [limits] with {!probe_timeout}. It is an error if the
    command cannot run or does not exit with 0. *)
