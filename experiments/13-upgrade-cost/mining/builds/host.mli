(** The machine a run happens on, as the lab notebook records it. On a system
    without [/proc] (macOS), the fields read from it are absent, with a warning
    on standard error. *)

val loadavg : string -> float option
(** [loadavg contents] is the one-minute load average of [contents], in the
    format of [/proc/loadavg]. *)

val cpu_model : string -> string option
(** [cpu_model contents] is the first [model name] of [contents], in the format
    of [/proc/cpuinfo]. *)

val processors : string -> int
(** [processors contents] is the number of [processor] entries of [contents], in
    the format of [/proc/cpuinfo]: the CPUs online. *)

type t = {
  hostname : string;
  cpu_model : string option;
  processors : int option;
}

val current : unit -> t
(** [current ()] is the machine the driver runs on. *)

val load : unit -> float option
(** [load ()] is the current one-minute load average. *)
