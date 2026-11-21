(* Experiment #12: [@@noalloc] stubs for libonig. *)
type h

external init : unit -> unit = "e12_init"
external compile_raw : int -> int -> string -> int -> int -> h = "e12_compile"
external search :
  h -> string -> (int [@untagged]) -> (int [@untagged]) -> (int [@untagged]) ->
  (int [@untagged]) = "e12_search_byte" "e12_search" [@@noalloc]
external match_ :
  h -> string -> (int [@untagged]) -> (int [@untagged]) -> (int [@untagged])
  = "e12_match_byte" "e12_match" [@@noalloc]
external nregs : h -> (int [@untagged]) = "e12_nregs_byte" "e12_nregs" [@@noalloc]
external region_beg : h -> (int [@untagged]) -> (int [@untagged])
  = "e12_beg_byte" "e12_beg" [@@noalloc]
external region_end : h -> (int [@untagged]) -> (int [@untagged])
  = "e12_end_byte" "e12_end" [@@noalloc]
external raw : h -> nativeint * nativeint * nativeint = "e12_raw"

(* Error (Some code) on compile failure *)
let compile ~syntax ~options ~limit ~stack_limit pat =
  match compile_raw syntax options pat limit stack_limit with
  | h -> Ok h
  | exception Failure m when String.length m > 5 && String.sub m 0 5 = "onig:" ->
    Error (int_of_string (String.sub m 5 (String.length m - 5)))
