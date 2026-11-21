(** Resource limits under which every command of a run is executed.

    A command [prog args] runs as
    [timeout --kill-after=60 T taskset --cpu-list C nice -n N prog args]:
    [timeout] stops it after [T] seconds (with [TERM], then [KILL] 60 seconds
    later), [taskset] pins it and its children to the CPU set [C], and [nice]
    lowers its priority. [timeout], [taskset] and [nice] are the GNU coreutils
    and util-linux programs, so runs need Linux. *)

type t = private {
  jobs : int;  (** Parallel jobs given to the build tools ([-j]). *)
  cpus : Cpuset.t;
  nice : int;  (** Niceness, from 0 to 19. *)
  timeout : int;  (** Seconds allowed to each command. *)
}

val kill_after : int
(** [kill_after] is the delay, in seconds, between [TERM] and [KILL] when a
    command times out. *)

val make :
  jobs:int -> cpus:Cpuset.t -> nice:int -> timeout:int -> (t, string) result
(** [make ~jobs ~cpus ~nice ~timeout] is the limits with these fields. It is an
    error if [jobs] or [timeout] is below 1, or [nice] is outside [0..19]. *)

val warnings : t -> string list
(** [warnings t] is the advisory messages about [t]: more jobs than CPUs. *)

val prefix : t -> string list
(** [prefix t] is the command line that runs a command under [t], as described
    above, without the command: [timeout] to [nice -n N]. *)

val duration_of_string : string -> (int, string) result
(** [duration_of_string s] is the number of seconds written [s]: a positive
    integer, optionally followed by [s], [m] or [h] (seconds, minutes, hours).
*)

val with_timeout : int -> t -> t
(** [with_timeout seconds t] is [t] with [seconds] allowed to each command.

    @raise Invalid_argument if [seconds] is below 1. *)
