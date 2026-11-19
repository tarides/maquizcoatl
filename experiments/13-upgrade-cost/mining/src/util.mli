(** String helpers shared by the library's modules. *)

val drop : int -> string -> string
(** [drop n s] is [s] without its first [n] characters. [n] must be at most
    [String.length s]. *)

val after : prefix:string -> string -> string
(** [after ~prefix s] is [s] without [prefix]; [s] must start with [prefix]. *)

val lines : string -> string list
(** [lines s] is the lines of [s] that are not blank, untrimmed. *)
