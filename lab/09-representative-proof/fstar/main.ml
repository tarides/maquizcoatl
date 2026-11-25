(* Experiment #9, F* driver (the extraction's integers are Z.t).  Reads
   a case file (index id kind pat_hex sub_hex a b c ncap ast; the AST as
   an s-expression written by experiment #6's parser) and prints, for
   each case:
     id TAB p TAB vm|sem|e06 TAB verdict    for every start position p
     id TAB search TAB vm|sem|e06 TAB verdict
   in the C oracle's format (MATCH s0 e0 s1 e1 ..., unset -1 -1;
   MISMATCH; LIMIT for out of fuel); the same format as rocq/main.ml.
   vm: Compile.compile then Vm.vm; sem: Sem.sem; e06: experiment #6
   milestone 2's F* semantics (Spec2.fst), with Star as Rep 0 (-1) greedy
   and no backreferenced group.
   usage: fstar_e09 CASES.tsv *)
open Custard

let fuel = Z.of_int 10_000_000
let z = Z.of_int

(* s-expressions *)
let tokens s =
  let b = Buffer.create 16 and l = ref [] in
  let flush () = if Buffer.length b > 0 then (l := Buffer.contents b :: !l; Buffer.clear b) in
  String.iter (fun c -> match c with
      | '(' | ')' -> flush (); l := String.make 1 c :: !l
      | ' ' -> flush ()
      | c -> Buffer.add_char b c) s;
  flush (); List.rev !l

type sx = A of string | L of sx list

let parse s =
  let rec go = function
    | "(" :: t -> let xs, t = items [] t in L xs, t
    | a :: t -> A a, t
    | [] -> failwith "eof"
  and items acc = function
    | ")" :: t -> List.rev acc, t
    | t -> let x, t = go t in items (x :: acc) t in
  fst (go (tokens s))

let bytes_of_hex h =
  List.init (String.length h / 2) (fun i -> int_of_string ("0x" ^ String.sub h (2 * i) 2))

let lit l = List.map z (bytes_of_hex (String.sub l 1 (String.length l - 1)))

let rec frag = function
  | A "E" -> Syntax_Eps
  | A l when l.[0] = 'L' -> Syntax_Lit (lit l)
  | L [A "."; a; b] -> Syntax_Cat (frag a, frag b)
  | L [A "|"; a; b] -> Syntax_Alt (frag a, frag b)
  | L [A "*"; a] -> Syntax_Star (frag a)
  | L [A "g"; A k; a] -> Syntax_Group (z (int_of_string k), frag a)
  | _ -> failwith "not a fragment AST"

let rec e06 = function
  | A "E" -> Spec2_Eps
  | A l when l.[0] = 'L' -> Spec2_Lit (lit l)
  | L [A "."; a; b] -> Spec2_Cat (e06 a, e06 b)
  | L [A "|"; a; b] -> Spec2_Alt (e06 a, e06 b)
  | L [A "*"; a] -> Spec2_Rep (Z.zero, Z.minus_one, true, e06 a)
  | L [A "g"; A k; a] -> Spec2_Group (z (int_of_string k), e06 a)
  | _ -> failwith "not a fragment AST"

let show_frag p = function
  | Syntax_Match (e, caps) ->
    "MATCH " ^ String.concat " " (List.map Z.to_string
      (p :: e :: List.concat_map (function Some (a, b) -> [a; b] | None -> [Z.minus_one; Z.minus_one]) caps))
  | Syntax_NoMatch -> "MISMATCH"
  | Syntax_OutOfFuel -> "LIMIT"

let show_e06 n = function
  | Spec2_RMatch (s, e, cs) ->
    "MATCH " ^ String.concat " " (List.map Z.to_string
      (s :: e :: List.concat_map (fun k -> match spec2_lookup (z k) cs with
         | Some (a, b) -> [a; b] | None -> [Z.minus_one; Z.minus_one]) (List.init n (fun i -> i + 1))))
  | Spec2_RMismatch -> "MISMATCH"
  | Spec2_RLimit -> "LIMIT"

let rec drop n l = if n = 0 then l else match l with [] -> [] | _ :: t -> drop (n - 1) t

let () =
  let ic = open_in Sys.argv.(1) in
  (try while true do
       let f = Array.of_list (String.split_on_char '\t' (input_line ic)) in
       let id = f.(1) and ast = parse f.(9) in
       let s = List.map z (bytes_of_hex f.(4)) in
       let ln = List.length s in
       let r = frag ast and r6 = e06 ast in
       let n = syntax_ncap r in
       let code = compile_compile r in
       let vm p = vm_vm fuel code n s p and sem p = sem_sem fuel r s p in
       let ni = Z.to_int n in
       for p = 0 to ln do
         let zp = z p in
         Printf.printf "%s\t%d\tvm\t%s\n" id p (show_frag zp (vm zp));
         Printf.printf "%s\t%d\tsem\t%s\n" id p (show_frag zp (sem zp));
         Printf.printf "%s\t%d\te06\t%s\n" id p
           (show_e06 ni (spec2_search_from s (z ln) [] Z.one spec2_fuel0 r6 zp (drop p s)))
       done;
       let srch m = match syntax_search m s with
         | None -> "MISMATCH" | Some (p, res) -> show_frag p res in
       Printf.printf "%s\tsearch\tvm\t%s\n" id (srch vm);
       Printf.printf "%s\tsearch\tsem\t%s\n" id (srch sem);
       Printf.printf "%s\tsearch\te06\t%s\n" id (show_e06 ni (spec2_search spec2_fuel0 [] r6 s))
     done with End_of_file -> ());
  close_in ic
