(** The tools and projects of experiment #13, as frozen at the snapshot date
    (see [plans/13-upgrade-cost.md]). *)

val tools : (string * Tool.scheme * string list) list
(** [tools] is, per tool: its name (as in [releases/<name>.tsv]), its series
    scheme and its version prefixes (see {!Tool.make}). *)

val all : Project.t list
(** [all] is the projects, in the order of the result tables. *)
