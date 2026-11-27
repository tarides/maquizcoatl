(* Issue #22: experiment #9's Rocq-extracted VM (module Frag, extracted
   with ExtrOcamlBasic and ExtrOcamlNatInt: bytes, positions and group
   numbers are OCaml ints).  Subject representation: int list, one
   element per byte. *)

type elt = int
type code = Frag.instr list * int

let convert s from =
  let rec go i acc =
    if i < from then acc else go (i - 1) (Char.code (String.unsafe_get s i) :: acc) in
  go (String.length s - 1) []

let rec to_frag : Frag_parse.ast -> Frag.regex = function
  | E -> Frag.Eps
  | L b -> Frag.Lit [b]
  | Cat (a, b) -> Frag.Cat (to_frag a, to_frag b)
  | Alt (a, b) -> Frag.Alt (to_frag a, to_frag b)
  | Star a -> Frag.Star (to_frag a)
  | G (k, a) -> Frag.Group (k, to_frag a)

let compile ast =
  let r = to_frag ast in
  let n = Frag.ncap r in
  ((Frag.compile r, n), n)

let vm ~fuel (code, n) l regs =
  match Frag.vm fuel code n l 0 with
  | Frag.Match (e, caps) ->
    List.iteri (fun i sp ->
        let k = i + 1 in
        match sp with
        | Some (a, b) -> regs.(2 * k) <- a; regs.(2 * k + 1) <- b
        | None -> regs.(2 * k) <- -1; regs.(2 * k + 1) <- -1) caps;
    e
  | Frag.NoMatch -> -1
  | Frag.OutOfFuel -> -2
