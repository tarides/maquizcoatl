(** The driver's commands: installing toolchains, preparing a side of a project,
    and running its measured build.

    Each real (not dry) install, preparation or run gets a log directory
    [logs/<what>-<UTC time>/] holding one log per step, [steps.csv] (see
    {!Row.step_header}) and [versions.txt] (see {!Target.probes}). A preparation
    or a run also appends one row to [<out>/<date>-exp-13-builds.csv]. *)

type config = {
  layout : Layout.t;
  limits : Limits.t;
  dry_run : bool;  (** Print the steps; run and write nothing. *)
}

type phase =
  | Prepare  (** {!Target.prepare}: not timed for criterion 4. *)
  | Build  (** {!Target.measured}. *)

val phase_to_string : phase -> string
(** [phase_to_string p] is [prepare] or [build]. *)

val builds_file : out:string -> date:string -> string
(** [builds_file ~out ~date] is [out/<date>-exp-13-builds.csv]. *)

val plan : config -> Step.t list -> string
(** [plan c steps] is [steps] numbered and described as they would run under
    [c.limits]. *)

val install : config -> Toolchain.t list -> (unit, string) result
(** [install c ts] installs [ts] in order, stopping at the first one that fails
    or is interrupted (an error naming its log directory). It is an error,
    before any step runs, if [taskset] rejects the CPU set of [c.limits]. *)

val run :
  config ->
  phase ->
  out:string ->
  date:string ->
  Target.t ->
  Target.side ->
  variant:string option ->
  (bool, string) result
(** [run c phase ~out ~date t side ~variant] runs [phase] of the side [side] of
    [t], records its row, and is [Ok true] if every step succeeded, [Ok false]
    if one failed or the driver was interrupted (see {!Exec.with_interrupts}):
    the failure is a result, recorded in the row. It is an error, found before
    any step runs, if the variant is unknown, the steps cannot be listed,
    [taskset] rejects the CPU set, the row could not be written ({!Row.check}),
    or, for a [Build], the checkout is missing, holds outputs of an earlier
    build ({!Target.stale}) or does not find its pins in the switch
    ({!Target.check_pins}). It is also an error if the row cannot be written
    after all. A dry run is [Ok true]. *)
