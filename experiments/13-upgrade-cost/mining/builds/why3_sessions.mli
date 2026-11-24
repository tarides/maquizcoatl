(** The Why3 gallery sessions replayed by Part A.

    The selection and the options follow Why3's own regression script,
    [examples/regtests.sh] at tag 1.8.2: for each directory it lists, every
    sub-directory holding a [why3session.xml] is a session, replayed from
    [examples/] with the directory's options. The script replays [c_cursor]
    twice; it is replayed once here. In reduced mode, a directory's sessions are
    the ones named in its [reduced_regtests.list], if any. *)

type selection =
  | Regtests  (** Every session of the directories of [regtests.sh]. *)
  | Reduced  (** The sessions of [reduced_regtests.list] files. *)

val dirs : (string * string list) list
(** [dirs] is the directories of [regtests.sh], relative to [examples/] ([.] for
    [examples/] itself), with their [why3 replay] options, in the script's
    order. *)

val parse_reduced : string -> string list
(** [parse_reduced contents] is the session names of a [reduced_regtests.list]:
    the first word of each line that starts with neither a space nor [#], a word
    ending at a space or a [#], as the script's [sed] command reads it. *)

val sessions :
  examples:string -> selection -> ((string * string list) list, string) result
(** [sessions ~examples sel] is the sessions under the directory [examples] with
    their options, in replay order: by directory as in {!dirs}, then by name. A
    session is written relative to [examples] ([foo], [avl/bar]). It is an error
    if [examples] cannot be read, or if a name is empty, absolute, starts with
    [-] (it would be read as an option) or has a [..] component. A directory of
    {!dirs} that is missing has no session. *)
