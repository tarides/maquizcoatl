(** The source files a failed build reports errors in (criterion 3 of the issue:
    "the number of failing files"), read from its log. *)

type format =
  | Dune_rocq
      (** Rocq through dune: a [File "p", line ...] location followed, before
          the next location or warning, by a line starting with [Error].
          Warnings are not counted. *)
  | Lake  (** Lake: lines [error: p.lean:l:c: ...]. *)
  | Fstar
      (** F*: [* Error n at p(l,c-l,c):] and the older [p(l,c-l,c): (Error n)].
      *)
  | Failed_steps
      (** No log parsing: the failing files are the labels of the failed steps
          (one Why3 session per step). *)

val files : format -> string -> string list
(** [files fmt log] is the distinct files with an error in [log], sorted, with
    leading [./] removed from Rocq and Lean paths. It is [[]] for
    [Failed_steps]. *)
