(** Sets of CPUs, written as [taskset --cpu-list] reads them. *)

type t
(** A non-empty set of CPU indices. *)

val max_cpu : int
(** [max_cpu] is the largest CPU index accepted. *)

val of_string : string -> (t, string) result
(** [of_string s] is the set written [s]: comma-separated items, each a CPU
    index [n] or an inclusive range [a-b] with [a <= b], for example
    [8-15,40-47]. Spaces, empty items and indices above {!max_cpu} are errors.
*)

val to_string : t -> string
(** [to_string t] is [t] in canonical form: increasing ranges, merged when
    adjacent, a single index written alone ([0-3,8]). *)

val cardinal : t -> int
(** [cardinal t] is the number of CPUs in [t]. *)
