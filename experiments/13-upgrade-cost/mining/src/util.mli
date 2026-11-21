(** Helpers shared by the library's modules and the tools. *)

val drop : int -> string -> string
(** [drop n s] is [s] without its first [n] characters. [n] must be at most
    [String.length s]. *)

val after : prefix:string -> string -> string
(** [after ~prefix s] is [s] without [prefix]; [s] must start with [prefix]. *)

val lines : string -> string list
(** [lines s] is the lines of [s] that are not blank, untrimmed. *)

val memo : ('a -> 'b) -> 'a -> 'b
(** [memo f] is [f], computing its result once per argument (compared with
    structural equality). *)

val dedup : 'a list -> 'a list
(** [dedup l] is [l] without the repeated elements, each kept at its first
    position. *)
