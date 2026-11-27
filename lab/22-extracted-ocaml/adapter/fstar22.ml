(* Issue #22: experiment #9's F*-extracted VM (module Custard, extracted
   with --codegen OCaml; F*'s int is Prims.int = Z.t).  Subject
   representation: Z.t list, one element per byte, as
   lab/09-representative-proof/fstar/main.ml:85. *)

type elt = Z.t
type code = Custard.syntax_instr list * Z.t

let convert s from =
  let rec go i acc =
    if i < from then acc
    else go (i - 1) (Z.of_int (Char.code (String.unsafe_get s i)) :: acc) in
  go (String.length s - 1) []

let rec to_custard : Frag_parse.ast -> Custard.syntax_regex = function
  | E -> Custard.Syntax_Eps
  | L b -> Custard.Syntax_Lit [Z.of_int b]
  | Cat (a, b) -> Custard.Syntax_Cat (to_custard a, to_custard b)
  | Alt (a, b) -> Custard.Syntax_Alt (to_custard a, to_custard b)
  | Star a -> Custard.Syntax_Star (to_custard a)
  | G (k, a) -> Custard.Syntax_Group (Z.of_int k, to_custard a)

let compile ast =
  let r = to_custard ast in
  let n = Custard.syntax_ncap r in
  ((Custard.compile_compile r, n), Z.to_int n)

let vm ~fuel (code, n) l regs =
  match Custard.vm_vm (Z.of_int fuel) code n l Z.zero with
  | Custard.Syntax_Match (e, caps) ->
    List.iteri (fun i sp ->
        let k = i + 1 in
        match sp with
        | Some (a, b) -> regs.(2 * k) <- Z.to_int a; regs.(2 * k + 1) <- Z.to_int b
        | None -> regs.(2 * k) <- -1; regs.(2 * k + 1) <- -1) caps;
    Z.to_int e
  | Custard.Syntax_NoMatch -> -1
  | Custard.Syntax_OutOfFuel -> -2
