(** A prover or verification tool, with its releases up to the snapshot date.

    Versions found in projects (pins) and release tags are compared after
    normalisation: lower case, the tool's prefixes removed (for example
    [leanprover/lean4:] or [release/]), then a leading [v].

    Releases are grouped into series. With the [Minor] scheme, a series is a
    [major.minor] version, and its release candidates, stable and patch releases
    count as one release (Lean, Rocq, Why3). With the [Exact] scheme, every
    stable release is its own series and pre-releases are not counted (F*,
    Verus, Isabelle). *)

type scheme = Minor | Exact
type t

val make :
  name:string ->
  scheme:scheme ->
  prefixes:string list ->
  until:string ->
  Release.t list ->
  t
(** [make ~name ~scheme ~prefixes ~until releases] is the tool [name] with the
    releases of [releases] published on or before the date [until]. The
    [prefixes] are compared ignoring case, like versions. *)

val name : t -> string
(** [name t] is the name given to {!make}. *)

val normalise : t -> string -> string
(** [normalise t v] is [v] normalised as described above. *)

val find : t -> string -> Release.t option
(** [find t v] is the release whose normalised tag equals [normalise t v]. *)

val earliest : t -> string list -> Release.t option
(** [earliest t tags] is the earliest release among those found by {!find} for
    [tags], if any. Used to map a pinned commit to the first release that
    contains it. *)

val series : t -> Release.t -> string option
(** [series t r] is the series of [r], or [None] if [r] is not counted (a
    pre-release with the [Exact] scheme). *)

val newest_series : t -> Release.t list -> string option
(** [newest_series t rs] is the newest series of the releases [rs] that belongs
    to [t]'s counted series, if any. *)

val spanned : t -> from:Release.t list -> to_:Release.t list -> int option
(** [spanned t ~from ~to_] is the number of series between the newest series of
    [from] (excluded) and the newest series of [to_] (included); it is negative
    for a downgrade. It is [None] if [from] or [to_] has no counted series. *)

val cadence : t -> since:string -> int
(** [cadence t ~since] is the number of series whose first stable release is
    dated on or after [since] (and on or before the snapshot date). A series
    that only has pre-releases is not counted. *)
