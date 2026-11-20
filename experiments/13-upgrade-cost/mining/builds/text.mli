(** Small string predicates shared by the parsers of the driver. *)

val is_digits : string -> bool
(** [is_digits s] is [true] if [s] is non-empty and made only of the digits [0]
    to [9]. *)
