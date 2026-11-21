(** External commands, as argument lists.

    A command is never a shell string: its program and arguments reach [execve]
    as they are, so no value is ever interpreted by a shell. Some arguments are
    file lists found when the command runs (the [.vo] files a build produced).
*)

type files = {
  dir : string;  (** Directory searched, relative to the command's [cwd]. *)
  suffix : string;  (** Suffix of the file names kept (for example [.vo]). *)
  depth : int option;
      (** [Some d]: only the files exactly [d] levels below [dir] (1 for the
          files of [dir] itself); [None]: at any depth. Symbolic links to
          directories are not followed. *)
}

type arg =
  | Lit of string
  | Files of files
      (** The matching files, as paths [dir/...] in increasing order. *)

type env =
  | Set of string * string  (** Sets a variable. *)
  | Unset of string  (** Removes a variable. *)
  | Prepend_path of string  (** Puts a directory in front of [PATH]. *)

type t = {
  prog : string;  (** Program, searched in the command's [PATH]. *)
  args : arg list;
  cwd : string;  (** Directory the command runs in. *)
  env : env list;  (** Changes to the driver's environment, in order. *)
}

val lits : string list -> arg list
(** [lits l] is the literal arguments [l]. *)

val v : ?env:env list -> cwd:string -> string -> string list -> t
(** [v ~env ~cwd prog args] is the command [prog] with literal arguments [args].
    [env] defaults to no change. *)

val prefixed : string list -> t -> t
(** [prefixed prefix t] is [t] run by the command line [prefix]: for
    [prefix = p :: args], the program [p] with arguments [args], [t.prog] and
    [t]'s arguments. It is [t] if [prefix] is empty. *)

val find_files : cwd:string -> files -> (string list, string) result
(** [find_files ~cwd f] is the files of [f], searched from [cwd]. It is an error
    if [f.dir] does not exist or no file matches. *)

val argv : t -> (string list, string) result
(** [argv t] is [t.prog] followed by its arguments, with {!Files} arguments
    expanded by {!find_files}. *)

val environment : env list -> string array -> string array
(** [environment changes base] is [base] (entries [NAME=VALUE]) with [changes]
    applied in order. A variable keeps its position when it is changed; a new
    one goes at the end. *)

val path_of : string array -> string
(** [path_of env] is the value of [PATH] in [env], or [""]. *)

val resolve : path:string -> string -> string option
(** [resolve ~path prog] is [prog] if it contains a [/], otherwise the first
    executable regular file [d/prog] for [d] in the colon-separated [path] (an
    empty entry is the current directory), if any. A file found through a
    relative entry is made absolute against the current directory, since the
    command later runs from its own [cwd]. *)

val quote : string -> string
(** [quote s] is [s] written for display in a POSIX shell: unchanged when made
    only of letters, digits and [_ . / = : , + @ % -], single-quoted otherwise.
    Displayed commands are never executed. *)

val to_string : t -> string
(** [to_string t] is [t] for logs and dry runs: its directory, the variables its
    environment removes ([unset]) and sets, with their final values ([PATH]
    written from ["$PATH"] when it keeps the inherited one), and its arguments,
    with {!Files} arguments shown as a description. *)
