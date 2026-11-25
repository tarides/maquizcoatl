(* Experiment #9, Rocq driver.  Reads a case file (index id kind pat_hex
   sub_hex a b c ncap ast; the AST as an s-expression written by
   experiment #6's parser) and prints, for each case:
     id TAB p TAB vm|sem|e06 TAB verdict    for every start position p
     id TAB search TAB vm|sem|e06 TAB verdict
   in the C oracle's format (MATCH s0 e0 s1 e1 ..., unset -1 -1;
   MISMATCH; LIMIT for out of fuel).  vm: compile then Vm.vm; sem:
   Sem.sem; e06: experiment #6 milestone 2's Rocq semantics (Spec2.v),
   with Star as Rep 0 None greedy and no backreferenced group.
   usage: rocq_e09 CASES.tsv *)

let fuel = 10_000_000

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

let bytes_of_hex h = List.init (String.length h / 2) (fun i -> int_of_string ("0x" ^ String.sub h (2 * i) 2))

let rec frag = function
  | A "E" -> Frag.Eps
  | A l when l.[0] = 'L' -> Frag.Lit (bytes_of_hex (String.sub l 1 (String.length l - 1)))
  | L [A "."; a; b] -> Frag.Cat (frag a, frag b)
  | L [A "|"; a; b] -> Frag.Alt (frag a, frag b)
  | L [A "*"; a] -> Frag.Star (frag a)
  | L [A "g"; A k; a] -> Frag.Group (int_of_string k, frag a)
  | _ -> failwith "not a fragment AST"

let rec e06 = function
  | A "E" -> Spec2.Eps
  | A l when l.[0] = 'L' -> Spec2.Lit (bytes_of_hex (String.sub l 1 (String.length l - 1)))
  | L [A "."; a; b] -> Spec2.Cat (e06 a, e06 b)
  | L [A "|"; a; b] -> Spec2.Alt (e06 a, e06 b)
  | L [A "*"; a] -> Spec2.Rep (0, None, true, e06 a)
  | L [A "g"; A k; a] -> Spec2.Group (int_of_string k, e06 a)
  | _ -> failwith "not a fragment AST"

let show_frag p = function
  | Frag.Match (e, caps) ->
    "MATCH " ^ String.concat " " (List.map string_of_int
      (p :: e :: List.concat_map (function Some (a, b) -> [a; b] | None -> [-1; -1]) caps))
  | Frag.NoMatch -> "MISMATCH"
  | Frag.OutOfFuel -> "LIMIT"

let show_e06 n = function
  | Spec2.RMatch (s, e, cs) ->
    "MATCH " ^ String.concat " " (List.map string_of_int
      (s :: e :: List.concat_map (fun k -> match Spec2.lookup k cs with
         | Some (a, b) -> [a; b] | None -> [-1; -1]) (List.init n (fun i -> i + 1))))
  | Spec2.RMismatch -> "MISMATCH"
  | Spec2.RLimit -> "LIMIT"

let rec drop n l = if n = 0 then l else match l with [] -> [] | _ :: t -> drop (n - 1) t

let () =
  let ic = open_in Sys.argv.(1) in
  (try while true do
       let f = Array.of_list (String.split_on_char '\t' (input_line ic)) in
       let id = f.(1) and ast = parse f.(9) in
       let s = bytes_of_hex f.(4) in
       let ln = List.length s in
       let r = frag ast and r6 = e06 ast in
       let n = Frag.ncap r in
       let code = Frag.compile r in
       let vm p = Frag.vm fuel code n s p and sem p = Frag.sem fuel r s p in
       for p = 0 to ln do
         Printf.printf "%s\t%d\tvm\t%s\n" id p (show_frag p (vm p));
         Printf.printf "%s\t%d\tsem\t%s\n" id p (show_frag p (sem p));
         Printf.printf "%s\t%d\te06\t%s\n" id p
           (show_e06 n (Spec2.search_from s ln [] 1 Spec2.fuel0 r6 p (drop p s)))
       done;
       let srch m = match Frag.search m s with
         | None -> "MISMATCH" | Some (p, res) -> show_frag p res in
       Printf.printf "%s\tsearch\tvm\t%s\n" id (srch vm);
       Printf.printf "%s\tsearch\tsem\t%s\n" id (srch sem);
       Printf.printf "%s\tsearch\te06\t%s\n" id (show_e06 n (Spec2.search Spec2.fuel0 [] r6 s))
     done with End_of_file -> ());
  close_in ic
