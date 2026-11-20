(* Experiment #6, stack G: plain OCaml reference interpreter for
   experiment #9's subset of Oniguruma f95747b (concatenation,
   alternation, greedy star, capture groups, character classes; UTF-8;
   ONIG_SYNTAX_ONIGURUMA; forward search).

   The parser is experiment #12's (lab/12-ffi-vs-native/vm/vm.ml),
   narrowed to the subset: it doubles as the subset classifier (any
   other construct raises [Out reason]; a subset pattern that Oniguruma
   rejects raises [Invalid onigerr_code]).

   The interpreter is a semantics, not a VM: a backtracking search over
   a list of pending items, in Oniguruma's priority order (left
   alternative first, greedy star tries one more iteration first),
   captures keep the last iteration, and the empty-iteration rule is
   experiment #2 run 2's plain check (no capture in the subset is the
   target of a backreference, so no OP_EMPTY_CHECK_END_MEMST:
   upstream/src/regcomp.c:980-990): an iteration that ends where it
   started leaves the loop.  Fuel bounds the number of steps per start
   position (10,000,000, the C retry limit of upstream/src/regint.h:111,
   counted in steps rather than retries).

   The subject is bytes; UTF-8 is decoded as upstream/src/utf8.c does
   (EncLen_UTF8 under USE_RFC3629_RANGE, mbc_to_code, no validation of
   trailing bytes), and positions are byte offsets. *)

exception Out of string
exception Invalid of int

let err_end_pattern_at_escape = -104
let err_premature_end_cc = -103
let err_target_of_repeat_not_specified = -113
let err_unmatched_close_paren = -116
let err_end_pattern_unmatched_paren = -117
let err_too_big_repeat = -201
let err_empty_range_cc = -203

(* ---------------------------------------------------------------- *)
(* Abstract syntax (the one the provers transcribe) *)

type node =
  | Eps
  | Lit of string                       (* bytes of one code point *)
  | Cls of bool * (int * int) list      (* negated, sorted disjoint ranges *)
  | Cat of node * node
  | Alt of node * node
  | Star of node                        (* greedy *)
  | Group of int * node

(* ---------------------------------------------------------------- *)
(* UTF-8, as upstream/src/utf8.c *)

let enc_len c =
  if c < 0xc2 then 1 else if c < 0xe0 then 2 else if c < 0xf0 then 3
  else if c < 0xf5 then 4 else 1

let cp_string cp =
  let b = Buffer.create 4 in
  let add i = Buffer.add_char b (Char.chr i) in
  if cp < 0x80 then add cp
  else if cp < 0x800 then (add (0xc0 lor (cp lsr 6)); add (0x80 lor (cp land 0x3f)))
  else if cp < 0x10000 then begin
    add (0xe0 lor (cp lsr 12)); add (0x80 lor ((cp lsr 6) land 0x3f));
    add (0x80 lor (cp land 0x3f))
  end else begin
    add (0xf0 lor (cp lsr 18)); add (0x80 lor ((cp lsr 12) land 0x3f));
    add (0x80 lor ((cp lsr 6) land 0x3f)); add (0x80 lor (cp land 0x3f))
  end;
  Buffer.contents b

(* ---------------------------------------------------------------- *)
(* Parser (narrowed from experiment #12's) *)

let is_digit c = c >= 48 && c <= 57

let norm_ranges rs =
  let rs = List.sort compare rs in
  let rec merge = function
    | (a, b) :: (c, d) :: t when c <= b + 1 -> merge ((a, max b d) :: t)
    | x :: t -> x :: merge t
    | [] -> [] in
  merge rs

(* informational only (plan step 2): with G_EXTENDED set, '+', '?' and
   '(?:...)' are accepted (desugared), to count the cases they would add *)
let extended = Sys.getenv_opt "G_EXTENDED" <> None

let parse (pat : string) : node * int =
  let n = String.length pat in
  let pos = ref 0 and ncap = ref 0 in
  let peek () = if !pos < n then Char.code pat.[!pos] else -1 in
  let eof () = !pos >= n in
  let read_cp () =
    let c = Char.code pat.[!pos] in
    if c < 0x80 then (incr pos; c)
    else begin
      let l = enc_len c in
      if l = 1 || !pos + l > n then raise (Out "invalid-utf8-in-pattern");
      let v = ref (c land ((1 lsl (7 - l)) - 1)) in
      for i = 1 to l - 1 do
        let d = Char.code pat.[!pos + i] in
        if d land 0xc0 <> 0x80 then raise (Out "invalid-utf8-in-pattern");
        v := (!v lsl 6) lor (d land 0x3f)
      done;
      pos := !pos + l; !v
    end in
  let hexval c =
    if c >= 48 && c <= 57 then c - 48
    else if c >= 97 && c <= 102 then c - 87
    else if c >= 65 && c <= 70 then c - 55 else -1 in
  let parse_hex () =
    if peek () = Char.code '{' then begin
      incr pos;
      let v = ref 0 and k = ref 0 in
      while not (eof ()) && hexval (peek ()) >= 0 do
        v := !v * 16 + hexval (peek ()); incr k; incr pos;
        if !k > 8 then raise (Out "\\x{} too long")
      done;
      if !k = 0 || peek () <> Char.code '}' then raise (Out "\\x{} form");
      incr pos;
      if !v > 0x10ffff || (!v >= 0xd800 && !v <= 0xdfff) then
        raise (Out "\\x{} code point");
      !v
    end else begin
      let v = ref 0 and k = ref 0 in
      while !k < 2 && not (eof ()) && hexval (peek ()) >= 0 do
        v := !v * 16 + hexval (peek ()); incr k; incr pos
      done;
      if !k = 0 then raise (Out "\\x without digits");
      if !v >= 0x80 then raise (Out "\\xHH >= 0x80 (raw byte)");
      !v
    end in
  let parse_escape ~in_cc =
    if eof () then raise (Invalid err_end_pattern_at_escape);
    let c = peek () in
    if c >= 0x80 then raise (Out "escaped non-ASCII");
    incr pos;
    match Char.chr c with
    | 't' -> 9 | 'n' -> 10 | 'r' -> 13 | 'f' -> 12 | 'e' -> 27 | 'a' -> 7
    | 'v' -> 11
    | 'x' -> parse_hex ()
    | 'd' | 'D' | 'w' | 'W' | 's' | 'S' ->
      raise (Out "ctype escape (Unicode tables)")
    | ch when (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')
              || (ch >= '0' && ch <= '9') ->
      raise (Out (if in_cc then Printf.sprintf "\\%c in class" ch
                  else Printf.sprintf "\\%c" ch))
    | _ -> c in
  let parse_cc () =
    let rs = ref [] in
    let add lo hi = rs := (lo, hi) :: !rs in
    let neg = if peek () = Char.code '^' then (incr pos; true) else false in
    let first = ref true and prev = ref `None and fin = ref false in
    while not !fin do
      if eof () then raise (Invalid err_premature_end_cc);
      let c = peek () in
      if c = Char.code ']' && not !first then (incr pos; fin := true)
      else begin
        let item =
          if c = Char.code ']' then (incr pos; `Ch c)
          else if c = Char.code '[' then raise (Out "nested class / posix bracket")
          else if c = Char.code '&' && !pos + 1 < n && pat.[!pos + 1] = '&' then
            raise (Out "class intersection")
          else if c = Char.code '\\' then (incr pos; `Ch (parse_escape ~in_cc:true))
          else if c = Char.code '-' then begin
            incr pos;
            if !first || peek () = Char.code ']' then `Ch c
            else match !prev with
              | `Ch lo ->
                if eof () then raise (Invalid err_premature_end_cc);
                let d = peek () in
                let hi =
                  if d = Char.code '&' && !pos + 1 < n && pat.[!pos + 1] = '&' then
                    raise (Out "class intersection")
                  else if d = Char.code '[' then raise (Out "nested class")
                  else if d = Char.code '\\' then (incr pos; parse_escape ~in_cc:true)
                  else read_cp () in
                if hi < lo then raise (Invalid err_empty_range_cc);
                add lo hi; `Range
              | `Range -> raise (Out "'-' after range")
              | `None -> `Ch c
          end
          else `Ch (read_cp ()) in
        (match item with
         | `Ch v -> (match !prev with `Ch p -> add p p | _ -> ()); prev := `Ch v
         | `Range -> prev := `Range);
        first := false
      end
    done;
    (match !prev with `Ch p -> add p p | _ -> ());
    Cls (neg, norm_ranges !rs) in
  (* is '{' at !pos the start of a valid interval?  (pos unchanged) *)
  let interval_here () =
    let save = !pos in
    incr pos;
    let scan () =
      let st = !pos and v = ref 0 and big = ref false in
      while not (eof ()) && is_digit (peek ()) do
        v := !v * 10 + (peek () - 48); if !v > 100000 then big := true; incr pos
      done;
      if !big then (pos := save; raise (Invalid err_too_big_repeat));
      !pos > st in
    let r =
      if eof () then false
      else if not (scan ()) then
        (if peek () = Char.code ',' then (pos := save; raise (Out "{,n}")); false)
      else if eof () then false
      else if peek () = Char.code ',' then begin
        incr pos; ignore (scan ()); not (eof ()) && peek () = Char.code '}'
      end
      else peek () = Char.code '}' in
    pos := save; r in
  let cat a b = match a, b with Eps, x | x, Eps -> x | _ -> Cat (a, b) in
  let rec parse_alt () =
    let first = parse_seq () in
    if peek () = Char.code '|' then (incr pos; Alt (first, parse_alt ()))
    else first
  and parse_seq () =
    let items = ref [] and stop = ref false in
    while not !stop do
      if eof () then stop := true
      else begin
        let c = peek () in
        if c = Char.code '|' || c = Char.code ')' then stop := true
        else if c = Char.code '*' || c = Char.code '+' || c = Char.code '?' then
          raise (Invalid err_target_of_repeat_not_specified)
        else if c = Char.code '{' && interval_here () then
          raise (Invalid err_target_of_repeat_not_specified)
        else items := parse_quant (parse_atom ()) :: !items
      end
    done;
    List.fold_left (fun acc x -> cat x acc) Eps !items
  and parse_quant atom =
    let c = peek () in
    if extended && (c = Char.code '+' || c = Char.code '?') then begin
      incr pos;
      let c2 = peek () in
      if c2 = Char.code '?' || c2 = Char.code '+' || c2 = Char.code '*'
      then raise (Out "lazy/possessive/nested");
      if c = Char.code '+' then Cat (atom, Star atom) else Alt (atom, Eps)
    end
    else if c = Char.code '+' then raise (Out "+")
    else if c = Char.code '?' then raise (Out "?")
    else if c = Char.code '{' && interval_here () then raise (Out "interval")
    else if c = Char.code '*' then begin
      incr pos;
      let c = peek () in
      if c = Char.code '?' then raise (Out "lazy star")
      else if c = Char.code '+' then raise (Out "possessive")
      else if c = Char.code '*' then raise (Out "nested quantifier")
      else if c = Char.code '{' && interval_here () then raise (Out "nested quantifier");
      Star atom
    end
    else atom
  and parse_atom () =
    let c = peek () in
    if c = Char.code '(' then begin
      incr pos;
      if extended && peek () = Char.code '?' && !pos + 1 < n && pat.[!pos + 1] = ':'
      then begin
        pos := !pos + 2;
        let body = parse_alt () in
        if eof () then raise (Invalid err_end_pattern_unmatched_paren);
        incr pos; body
      end else begin
        if peek () = Char.code '?' then raise (Out "(? group")
        else if peek () = Char.code '*' then raise (Out "(* verb");
        incr ncap;
        let k = !ncap in
        let body = parse_alt () in
        if eof () then raise (Invalid err_end_pattern_unmatched_paren);
        incr pos;
        Group (k, body)
      end
    end
    else if c = Char.code '[' then (incr pos; parse_cc ())
    else if c = Char.code '.' then (incr pos; Cls (true, [ (10, 10) ]))
    else if c = Char.code '^' || c = Char.code '$' then raise (Out "anchor")
    else if c = Char.code '\\' then begin
      incr pos;
      if not (eof ()) && List.mem (Char.chr (peek ())) [ 'A'; 'z'; 'Z'; 'b'; 'B'; 'G' ]
      then raise (Out "anchor");
      Lit (cp_string (parse_escape ~in_cc:false))
    end
    else Lit (cp_string (read_cp ())) in
  let ast = parse_alt () in
  if not (eof ()) then raise (Invalid err_unmatched_close_paren);
  (ast, !ncap)

(* ---------------------------------------------------------------- *)
(* Serialisation of ASTs for the provers' case modules *)

let rec to_sexp = function
  | Eps -> "E"
  | Lit s -> "L" ^ String.concat "" (List.init (String.length s)
                                         (fun i -> Printf.sprintf "%02x" (Char.code s.[i])))
  | Cls (ng, rs) ->
    Printf.sprintf "C%c%s" (if ng then 'n' else 'p')
      (String.concat "," (List.map (fun (a, b) -> Printf.sprintf "%x-%x" a b) rs))
  | Cat (a, b) -> Printf.sprintf "(. %s %s)" (to_sexp a) (to_sexp b)
  | Alt (a, b) -> Printf.sprintf "(| %s %s)" (to_sexp a) (to_sexp b)
  | Star a -> Printf.sprintf "(* %s)" (to_sexp a)
  | Group (k, a) -> Printf.sprintf "(g %d %s)" k (to_sexp a)

(* ---------------------------------------------------------------- *)
(* The semantics *)

type item =
  | Node of node
  | Close of int * int      (* group, start position *)
  | Loop of node * int      (* star body, position at iteration start *)

type caps = (int * (int * int)) list   (* group -> region, last write wins *)

type result =
  | Matched of int * caps
  | Failed of int           (* remaining fuel *)
  | NoFuel

let rec set_cap k v = function
  | [] -> [ (k, v) ]
  | (k', _) :: t when k' = k -> (k, v) :: t
  | x :: t -> x :: set_cap k v t

let in_ranges c rs = List.exists (fun (lo, hi) -> lo <= c && c <= hi) rs

(* code point at [pos] and its length, or None when the encoded
   length runs past the end (DATA_ENSURE in regexec.c) *)
let decode (s : string) pos =
  let len = String.length s in
  if pos >= len then None
  else begin
    let c = Char.code s.[pos] in
    let l = enc_len c in
    if pos + l > len then None
    else if l = 1 then Some (c, 1)
    else begin
      let v = ref (c land ((1 lsl (7 - l)) - 1)) in
      for i = 1 to l - 1 do v := (!v lsl 6) lor (Char.code s.[pos + i] land 0x3f) done;
      Some (!v, l)
    end
  end

let has_prefix (s : string) pos (lit : string) =
  let l = String.length lit in
  pos + l <= String.length s
  && (let ok = ref true in
      for i = 0 to l - 1 do if s.[pos + i] <> lit.[i] then ok := false done;
      !ok)

let rec step s fuel items pos (caps : caps) =
  if fuel = 0 then NoFuel
  else
    let fuel = fuel - 1 in
    match items with
    | [] -> Matched (pos, caps)
    | Node Eps :: k -> step s fuel k pos caps
    | Node (Lit l) :: k ->
      if has_prefix s pos l then step s fuel k (pos + String.length l) caps
      else Failed fuel
    | Node (Cls (ng, rs)) :: k ->
      (match decode s pos with
       | Some (c, l) when in_ranges c rs <> ng -> step s fuel k (pos + l) caps
       | _ -> Failed fuel)
    | Node (Cat (a, b)) :: k -> step s fuel (Node a :: Node b :: k) pos caps
    | Node (Alt (a, b)) :: k ->
      (match step s fuel (Node a :: k) pos caps with
       | Failed fuel -> step s fuel (Node b :: k) pos caps
       | r -> r)
    | Node (Star a) :: k ->
      (match step s fuel (Node a :: Loop (a, pos) :: k) pos caps with
       | Failed fuel -> step s fuel k pos caps
       | r -> r)
    | Loop (a, p0) :: k ->
      if pos = p0 then step s fuel k pos caps
      else step s fuel (Node (Star a) :: k) pos caps
    | Node (Group (i, a)) :: k -> step s fuel (Node a :: Close (i, pos) :: k) pos caps
    | Close (i, p0) :: k -> step s fuel k pos (set_cap i (p0, pos) caps)

let fuel0 = 10_000_000

(* forward search over every start position (byte offsets, advanced by
   the encoded length of the byte at the position, as onig_search).
   Returns `Match (start, end, caps) | `Mismatch | `Retry_limit *)
let search re (s : string) =
  let len = String.length s in
  let rec go start =
    if start > len then `Mismatch else
    match step s fuel0 [ Node re ] start [] with
    | Matched (e, caps) -> `Match (start, e, caps)
    | NoFuel -> `Retry_limit
    | Failed _ ->
      if start >= len then `Mismatch
      else go (start + enc_len (Char.code s.[start])) in
  go 0

(* ---------------------------------------------------------------- *)
(* Case files.  Input (from extract.py), tab-separated:
     suite line kind enc syntax options dir pat_hex sub_hex a b c *)

let of_hex h =
  String.init (String.length h / 2) (fun i -> Char.chr (int_of_string ("0x" ^ String.sub h (2 * i) 2)))

let read_lines f =
  let ic = open_in f in
  let rec go acc = match input_line ic with
    | l -> go (l :: acc) | exception End_of_file -> close_in ic; List.rev acc in
  go []

(* classify: in-subset cases to stdout (id kind pat sub a b c ncap ast),
   every case's verdict to stderr-file given as second argument *)
let classify file outfile =
  let oc = open_out outfile in
  List.iteri (fun i l ->
      match String.split_on_char '\t' l with
      | [ suite; line; kind; enc; syn; opt; dir; pat; sub; a; b; c ] ->
        let id = Printf.sprintf "%s:%s" suite line in
        let out r = Printf.fprintf oc "%d\t%s\t%s\tout\t%s\n" i id kind r in
        if String.length kind > 0 && kind.[0] = 'r' then out "regset API"
        else if enc <> "UTF8" then out ("encoding " ^ enc)
        else if syn <> "ONIGURUMA" then out ("syntax " ^ syn)
        else if opt <> "0" then out "options"
        else if dir <> "fwd" then out "backward search"
        else begin
          match parse (of_hex pat) with
          | exception Out r -> out r
          | exception Invalid e ->
            Printf.fprintf oc "%d\t%s\t%s\tin\terror %d\n" i id kind e;
            Printf.printf "%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%s\n" i id kind pat sub a b c (-1) "!"
          | ast, ncap ->
            Printf.fprintf oc "%d\t%s\t%s\tin\t\n" i id kind;
            Printf.printf "%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%s\n" i id kind pat sub a b c ncap
              (to_sexp ast)
        end
      | _ -> failwith ("bad line: " ^ l))
    (read_lines file);
  close_out oc

(* run: in-subset file (from classify); prints one verdict per case:
     id ERR code | id MISMATCH | id LIMIT | id MATCH s0 e0 s1 e1 ...
   then times [reps] passes (parse and search separately) on stderr *)
let verdict pat sub =
  match parse pat with
  | exception Invalid e -> Printf.sprintf "ERR %d" e
  | exception Out r -> "OUT " ^ r
  | re, ncap ->
    match search re sub with
    | `Mismatch -> "MISMATCH"
    | `Retry_limit -> "LIMIT"
    | `Match (st, e, caps) ->
      let b = Buffer.create 32 in
      Buffer.add_string b (Printf.sprintf "MATCH %d %d" st e);
      for k = 1 to ncap do
        match List.assoc_opt k caps with
        | Some (x, y) -> Buffer.add_string b (Printf.sprintf " %d %d" x y)
        | None -> Buffer.add_string b " -1 -1"
      done;
      Buffer.contents b

let run file reps =
  let cases = List.map (fun l ->
      match String.split_on_char '\t' l with
      | _ :: id :: _ :: pat :: sub :: _ -> (id, of_hex pat, of_hex sub)
      | _ -> failwith l) (read_lines file) in
  List.iter (fun (id, p, s) -> Printf.printf "%s\t%s\n" id (verdict p s)) cases;
  let n = List.length cases in
  (* parse only *)
  let t0 = Unix.gettimeofday () in
  let parsed = ref [] in
  for _ = 1 to reps do
    parsed := List.map (fun (_, p, s) ->
        match parse p with r -> Some (fst r, s) | exception _ -> None) cases
  done;
  let t1 = Unix.gettimeofday () in
  let sink = ref 0 in
  for _ = 1 to reps do
    List.iter (function
        | Some (re, s) -> (match search re s with `Match (a, _, _) -> sink := !sink + a | _ -> ())
        | None -> ()) !parsed
  done;
  let t2 = Unix.gettimeofday () in
  for _ = 1 to reps do
    List.iter (fun (_, p, s) -> ignore (verdict p s)) cases
  done;
  let t3 = Unix.gettimeofday () in
  let tot = float (n * reps) in
  Printf.eprintf "cases=%d reps=%d parse_s=%.3f search_s=%.3f e2e_s=%.3f parse_cps=%.0f search_cps=%.0f e2e_cps=%.0f sink=%d\n"
    n reps (t1 -. t0) (t2 -. t1) (t3 -. t2) (tot /. (t1 -. t0)) (tot /. (t2 -. t1))
    (tot /. (t3 -. t2)) !sink

let () =
  match Array.to_list Sys.argv with
  | [ _; "classify"; f; o ] -> classify f o
  | [ _; "run"; f; reps ] -> run f (int_of_string reps)
  | _ -> prerr_endline "usage: g classify ALL.tsv VERDICTS | g run IN.tsv REPS"; exit 2
