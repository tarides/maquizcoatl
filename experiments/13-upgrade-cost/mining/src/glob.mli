(** Path patterns.

    A pattern is matched against a whole repository-relative path, with the
    subset of git's wildmatch rules that git applies to [:(glob)] pathspecs, so
    that a pattern selects the same files here and in git. [*] matches any
    sequence of characters without [/], and [?] one character other than [/].
    [**] is special only between slashes or at an end of the pattern: a leading
    [**/] or an inner [/**/] matches zero or more whole directories, a trailing
    [/**] everything below a directory, and [**] alone any path. Elsewhere [**]
    is the same as [*]. Other characters match themselves: bracket expressions
    and backslash escapes are not supported, so patterns must not use [\[] or
    [\\]. *)

val matches : string -> string -> bool
(** [matches pattern path] is [true] iff [path] matches [pattern]. *)

val under : string -> string -> bool
(** [under dir path] is [true] iff [path] is [dir] or lies below it. *)
