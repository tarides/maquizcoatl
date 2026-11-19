(** Path patterns.

    A pattern is matched against a whole repository-relative path. [*] matches
    any sequence of characters without [/], [?] matches one character other than
    [/], [**] matches any sequence of characters, [/] included, and [**/]
    matches zero or more leading directories. Other characters match themselves.
*)

val matches : string -> string -> bool
(** [matches pattern path] is [true] iff [path] matches [pattern]. *)

val under : string -> string -> bool
(** [under dir path] is [true] iff [path] is [dir] or lies below it. *)
