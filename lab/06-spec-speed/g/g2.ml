(* Experiment #6, milestone 2, stack G: plain OCaml reference
   interpreter for experiment #1's first subset S2 of Oniguruma f95747b
   (UTF-8; ONIG_SYNTAX_ONIGURUMA, ONIG_SYNTAX_PERL_NG and
   ONIG_SYNTAX_RUBY; forward search).

   Milestone 1's g.ml is kept unchanged so that it keeps reproducing
   milestone 1's figures; this file extends its parser, AST and
   interpreter (plans/06-spec-speed-m2.md, step 3).

   The parser doubles as the S2 classifier: a construct outside S2
   raises [Out reason]; a pattern that the specification rejects raises
   [Invalid onigerr_code].

   The interpreter is a semantics, not a VM: a backtracking search over
   a list of pending items in Oniguruma's priority order.  Captures keep
   the last iteration.  The empty-iteration rule is DEV-003's
   (spec/deviations.md): after an optional iteration of an unbounded
   loop that matched the empty string, the loop stops unless a capture
   changed during that iteration; only backreferenced groups are
   compared, the form DEV-003 lists as observably equal (it avoids an
   exponential search on loops such as (b|)+ whose groups are never
   referenced).  Atomic groups, possessive quantifiers
   and lookaround bodies commit to their first success.  Lookbehind
   tries, for each top-level alternative in order, the nearest start
   first (upstream/src/regexec.c:4481-4504).  Captures are allowed in a
   negative lookbehind and are unset after it (DEV-002).  \pX is a
   one-letter property only when X names one (DEV-004).  Fuel bounds the
   number of steps per start position (10,000,000).

   Case-insensitive matching is stated semantically: a literal string
   matches a subject segment whose full case fold (Unicode CaseFolding
   F+C, as in upstream/src/unicode_fold_data.c) equals the pattern's
   fold; a class matches a character whose fold-equivalence class
   meets it, or (not negated) a segment whose fold equals a
   multi-character fold of one of its members.

   The subject is bytes; UTF-8 is decoded as upstream/src/utf8.c does,
   and positions are byte offsets.

   Tables: the case-fold map and the property ranges are read at start
   from the file named by G_TABLES (default tables.txt next to the
   binary), produced by tables/gen_tables.py from the upstream sources. *)

exception Out of string
exception Invalid of int

(* ---------------------------------------------------------------- *)
(* Abstract syntax (the one the provers transcribe) *)

type cset =
  | CR of int * int              (* code point range *)
  | CP of int                    (* ctype / property (index in the table) *)
  | CNot of cset
  | COr of cset list
  | CAnd of cset * cset

type anchor =
  | BolA | EolA | BufBeg | BufEnd | SemiEnd | SearchStart | WordB | NotWordB

type node =
  | Eps
  | Lit of string                 (* bytes, case-sensitive *)
  | LitI of int list              (* full case fold of the pattern string *)
  | Cls of cset                   (* one character *)
  | ClsI of cset * int list list  (* one character, or one of the folded strings *)
  | Cat of node * node
  | Alt of node * node
  | Rep of int * int * bool * node   (* min, max (-1: infinite), greedy *)
  | Atomic of node
  | Ahead of bool * node          (* negative?, body *)
  | Behind of bool * node list    (* negative?, top-level alternatives *)
  | Group of int * node
  | Bref of int list * bool       (* groups, highest first; ignore case *)
  | Anc of anchor

(* ---------------------------------------------------------------- *)
(* Tables *)

let fold_tbl : (int, int list) Hashtbl.t = Hashtbl.create 2048
let prop_names : (string, int) Hashtbl.t = Hashtbl.create 1024
let prop_ranges : (int, (int * int) array) Hashtbl.t = Hashtbl.create 1024
(* fold-equivalence classes: fold string -> members *)
let equiv : (int list, int list) Hashtbl.t = Hashtbl.create 2048
let used_props : (int, unit) Hashtbl.t = Hashtbl.create 64

let load_tables f =
  let ic = open_in f in
  let hex s = int_of_string ("0x" ^ s) in
  (try while true do
       match String.split_on_char '\t' (input_line ic) with
       | [ "F"; u; fs ] -> Hashtbl.replace fold_tbl (hex u) (List.map hex (String.split_on_char ',' fs))
       | [ "N"; n; c ] -> Hashtbl.replace prop_names n (int_of_string c)
       | [ "R"; c; rs ] ->
         let rs = if rs = "" then [] else String.split_on_char ',' rs in
         Hashtbl.replace prop_ranges (int_of_string c)
           (Array.of_list (List.map (fun r -> match String.split_on_char '-' r with
                [ a; b ] -> (hex a, hex b) | _ -> failwith r) rs))
       | _ -> ()
     done with End_of_file -> ());
  close_in ic;
  Hashtbl.iter (fun u f ->
      let cur = try Hashtbl.find equiv f with Not_found -> [] in
      Hashtbl.replace equiv f (u :: cur)) fold_tbl;
  (* the fold target itself belongs to its class *)
  Hashtbl.iter (fun f us -> match f with
      | [ c ] when not (List.mem c us) -> Hashtbl.replace equiv f (c :: us)
      | _ -> ()) (Hashtbl.copy equiv)

let fold c = match Hashtbl.find_opt fold_tbl c with Some f -> f | None -> [ c ]

let ct_word = 12 and ct_digit = 4 and ct_space = 9 and ct_xdigit = 11

let in_prop p c =
  let a = Hashtbl.find prop_ranges p in
  let lo = ref 0 and hi = ref (Array.length a - 1) and r = ref false in
  while not !r && !lo <= !hi do
    let m = (!lo + !hi) / 2 in
    let (x, y) = a.(m) in
    if c < x then hi := m - 1 else if c > y then lo := m + 1 else r := true
  done; !r

let rec in_cset c = function
  | CR (a, b) -> a <= c && c <= b
  | CP p -> in_prop p c
  | CNot s -> not (in_cset c s)
  | COr l -> List.exists (in_cset c) l
  | CAnd (a, b) -> in_cset c a && in_cset c b

let is_word c = in_prop ct_word c

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

(* start of the character before [pos] (left_adjust_char_head) *)
let prev_pos (s : string) pos =
  if pos <= 0 then -1
  else begin
    let p = ref (pos - 1) in
    while !p > 0 && Char.code s.[!p] land 0xc0 = 0x80 do decr p done;
    !p
  end

(* ---------------------------------------------------------------- *)
(* Parser *)

type syntax = Onig | PerlNG | Ruby

let err_end_pattern_at_escape = -104
let err_premature_end_cc = -103
let err_target_of_repeat_not_specified = -113
let err_target_of_repeat_invalid = -114
let err_unmatched_close_paren = -116
let err_end_pattern_unmatched_paren = -117
let err_end_pattern_in_group = -118
let err_undefined_group_option = -119
let err_invalid_posix_bracket = -121
let err_invalid_look_behind = -122
let err_too_big_repeat = -201
let err_empty_range_cc = -203
let err_too_short_mb = -206
let err_invalid_backref = -208
let err_numbered_backref_not_allowed = -209
let err_empty_group_name = -214
let err_invalid_group_name = -215
let err_undefined_name_ref = -217
let err_invalid_prop_name = -223
let err_invalid_code_point = -400
let max_repeat = 100000
let look_behind_max = 65535

let is_digit c = c >= 48 && c <= 57

(* raw nodes before group numbering *)
type pre =
  | PNode of node
  | PCat of pre * pre
  | PAlt of pre * pre
  | PRep of int * int * bool * bool * pre   (* min max greedy possessive *)
  | PAtomic of pre
  | PAhead of bool * pre
  | PBehind of bool * pre
  | PGroup of int * string option * pre     (* provisional number, name *)
  | PBnum of int * bool
  | PBname of string * bool

type opts = { icase : bool; dotall : bool; single : bool; ext : bool }

let posix_names =
  [ "alnum", 13; "alpha", 1; "ascii", 14; "blank", 2; "cntrl", 3; "digit", 4;
    "graph", 5; "lower", 6; "print", 7; "punct", 8; "space", 9; "upper", 10;
    "xdigit", 11; "word", 12 ]

let one_letter_props = [ 'C'; 'L'; 'M'; 'N'; 'P'; 'S'; 'Z' ]

let prop_lookup name =
  let b = Buffer.create 16 in
  String.iter (fun ch ->
      if Char.code ch >= 0x80 then raise (Invalid err_invalid_prop_name);
      if ch <> ' ' && ch <> '-' && ch <> '_' then Buffer.add_char b (Char.lowercase_ascii ch))
    name;
  match Hashtbl.find_opt prop_names (Buffer.contents b) with
  | Some c -> Hashtbl.replace used_props c (); c
  | None -> raise (Invalid err_invalid_prop_name)

let fold_string (cps : int list) = List.concat_map fold cps

(* closure of a class under case-fold equivalence: the extra ranges,
   and the multi-character folds of its members *)
let icase_closure (cs : cset) =
  let extra = ref [] and multi = ref [] in
  Hashtbl.iter (fun f members ->
      let fin = List.filter (fun u -> in_cset u cs) members in
      let fin = match f with [ c ] when in_cset c cs && not (List.mem c fin) -> c :: fin | _ -> fin in
      if fin <> [] then begin
        List.iter (fun u -> if not (in_cset u cs) then extra := u :: !extra) members;
        (match f with [ c ] -> if not (in_cset c cs) then extra := c :: !extra
                    | _ -> multi := f :: !multi)
      end) equiv;
  (List.sort_uniq compare !extra, List.sort_uniq compare !multi)

let ranges_of_list l =
  let rec go acc = function
    | [] -> List.rev acc
    | c :: t -> (match acc with
        | (a, b) :: r when b + 1 = c -> go ((a, c) :: r) t
        | _ -> go ((c, c) :: acc) t) in
  List.map (fun (a, b) -> CR (a, b)) (go [] (List.sort_uniq compare l))

let parse (syn : syntax) (opt0 : opts) (pat : string) : node * int =
  let n = String.length pat in
  let pos = ref 0 and ncap = ref 0 in
  let names = ref [] in      (* (provisional number, name) *)
  let peek () = if !pos < n then Char.code pat.[!pos] else -1 in
  let peek_at k = if !pos + k < n then Char.code pat.[!pos + k] else -1 in
  let eof () = !pos >= n in
  let read_cp () =
    let c = Char.code pat.[!pos] in
    if c < 0x80 then (incr pos; c)
    else begin
      let l = enc_len c in
      if l = 1 then raise (Invalid err_invalid_code_point);
      if !pos + l > n then raise (Invalid err_too_short_mb);
      let v = ref (c land ((1 lsl (7 - l)) - 1)) in
      for i = 1 to l - 1 do
        let d = Char.code pat.[!pos + i] in
        if d land 0xc0 <> 0x80 then raise (Invalid err_invalid_code_point);
        v := (!v lsl 6) lor (d land 0x3f)
      done;
      pos := !pos + l; !v
    end in
  let hexval c =
    if c >= 48 && c <= 57 then c - 48
    else if c >= 97 && c <= 102 then c - 87
    else if c >= 65 && c <= 70 then c - 55 else -1 in
  let check_cp v =
    if v > 0x10ffff || (v >= 0xd800 && v <= 0xdfff) then raise (Invalid err_invalid_code_point);
    v in
  (* \x{...}, \o{...}: one code point; lists are outside S2 *)
  let no_check = ref false in
  let parse_brace base digitval maxd =
    incr pos;
    let v = ref 0 and k = ref 0 in
    while not (eof ()) && digitval (peek ()) >= 0 do
      v := !v * base + digitval (peek ()); incr k; incr pos;
      if !k > maxd then raise (Out "\\x{} too long")
    done;
    if !k = 0 then raise (Out "\\x{} form");
    if eof () then raise (Invalid err_invalid_code_point);
    if peek () <> Char.code '}' then raise (Out "\\x{..}/\\o{..} code point list");
    incr pos; if !no_check then !v else check_cp !v in
  (* raw bytes \xHH >= 0x80: collect consecutive ones into a character *)
  let raw_bytes first =
    let b = Buffer.create 4 in
    Buffer.add_char b (Char.chr first);
    let l = enc_len first in
    if l = 1 then raise (Invalid err_invalid_code_point);
    while Buffer.length b < l && !pos + 3 < n + 0 && pat.[!pos] = '\\' && pat.[!pos + 1] = 'x'
          && hexval (Char.code pat.[!pos + 2]) >= 0 && hexval (Char.code pat.[!pos + 3]) >= 0 do
      let v = hexval (Char.code pat.[!pos + 2]) * 16 + hexval (Char.code pat.[!pos + 3]) in
      Buffer.add_char b (Char.chr v); pos := !pos + 4
    done;
    if Buffer.length b < l then raise (Invalid err_too_short_mb);
    match decode (Buffer.contents b) 0 with Some (c, _) -> c | None -> raise (Invalid err_too_short_mb) in
  let parse_hex () =
    if peek () = Char.code '{' then parse_brace 16 hexval 8
    else begin
      let v = ref 0 and k = ref 0 in
      while !k < 2 && not (eof ()) && hexval (peek ()) >= 0 do
        v := !v * 16 + hexval (peek ()); incr k; incr pos
      done;
      if !k = 0 then 0
      else if !v >= 0x80 then raw_bytes !v
      else !v
    end in
  let octval c = if c >= 48 && c <= 55 then c - 48 else -1 in
  (* property after \p / \P (pos after the letter) *)
  let parse_prop neg_letter =
    if peek () = Char.code '{' then begin
      incr pos;
      let neg = if peek () = Char.code '^' then (incr pos; true) else false in
      let st = !pos in
      while not (eof ()) && peek () <> Char.code '}' do incr pos done;
      if eof () then raise (Invalid err_invalid_prop_name);
      let name = String.sub pat st (!pos - st) in
      incr pos;
      let p = CP (prop_lookup name) in
      Some (if neg <> neg_letter then CNot p else p)
    end
    else if (syn = Onig || syn = PerlNG) && not (eof ())
            && List.mem (Char.uppercase_ascii (Char.chr (peek ()))) one_letter_props
            && peek () < 0x80 then begin
      (* DEV-004: a one-letter property only when the letter names one *)
      let name = String.make 1 (Char.chr (peek ())) in incr pos;
      let p = CP (prop_lookup name) in
      Some (if neg_letter then CNot p else p)
    end
    else None in
  (* escapes common to both contexts; returns `C cp | `S cset *)
  let parse_escape ~in_cc =
    if eof () then raise (Invalid err_end_pattern_at_escape);
    let c = peek () in
    if c >= 0x80 then `C (read_cp ())
    else begin
      incr pos;
      match Char.chr c with
      | 't' -> `C 9 | 'n' -> `C 10 | 'r' -> `C 13 | 'f' -> `C 12 | 'e' -> `C 27
      | 'a' -> `C 7 | 'v' -> `C 11
      | 'x' -> `C (parse_hex ())
      | 'u' ->
        let v = ref 0 in
        for _ = 1 to 4 do
          if eof () || hexval (peek ()) < 0 then raise (Invalid err_invalid_code_point);
          v := !v * 16 + hexval (peek ()); incr pos
        done; `C (check_cp !v)
      | 'o' when peek () = Char.code '{' -> `C (parse_brace 8 octval 11)
      | '0' ->
        let v = ref 0 and k = ref 0 in
        while !k < 2 && octval (peek ()) >= 0 do v := !v * 8 + octval (peek ()); incr k; incr pos done;
        `C !v
      | 'w' -> `S (CP ct_word) | 'W' -> `S (CNot (CP ct_word))
      | 'd' -> `S (CP ct_digit) | 'D' -> `S (CNot (CP ct_digit))
      | 's' -> `S (CP ct_space) | 'S' -> `S (CNot (CP ct_space))
      | 'h' when syn = Onig -> `S (CP ct_xdigit) | 'H' when syn = Onig -> `S (CNot (CP ct_xdigit))
      | ('p' | 'P') as l ->
        (match parse_prop (l = 'P') with Some s -> `S s | None -> `C c)
      | ch when (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')
                || (ch >= '1' && ch <= '9') ->
        raise (Out (if in_cc then Printf.sprintf "\\%c in class" ch
                    else Printf.sprintf "\\%c" ch))
      | _ -> `C c
    end in
  (* character class; pos after '[' *)
  let rec parse_cc () =
    let neg = if peek () = Char.code '^' then (incr pos; true) else false in
    let segs = ref [] and items = ref [] in
    let first = ref true and prev = ref `None and fin = ref false in
    let add s = items := s :: !items in
    let flush () = (match !prev with `Ch p -> add (CR (p, p)) | _ -> ()); prev := `None in
    while not !fin do
      if eof () then raise (Invalid err_premature_end_cc);
      let c = peek () in
      if c = Char.code ']' && not !first then (incr pos; fin := true)
      else if c = Char.code '&' && peek_at 1 = Char.code '&' then begin
        pos := !pos + 2; flush ();
        segs := COr (List.rev !items) :: !segs; items := []; first := false
      end
      else begin
        let item =
          if c = Char.code ']' then (incr pos; `Ch c)
          else if c = Char.code '[' then begin
            if peek_at 1 = Char.code ':' then begin
              match posix_bracket () with
              | Some s -> `Set s
              | None -> incr pos; `Set (parse_cc ())
            end else (incr pos; `Set (parse_cc ()))
          end
          else if c = Char.code '\\' then begin
            incr pos;
            match parse_escape ~in_cc:true with `C v -> `Ch v | `S s -> `Set s
          end
          else if c = Char.code '-' then begin
            incr pos;
            if !first || peek () = Char.code ']' then `Ch c
            else match !prev with
              | `Ch lo ->
                if eof () then raise (Invalid err_premature_end_cc);
                let d = peek () in
                if d = Char.code '[' || (d = Char.code '&' && peek_at 1 = Char.code '&') then
                  (* '-' before a nested class or '&&': literal *)
                  (flush (); add (CR (45, 45)); `Skip)
                else begin
                  let hi =
                    if d = Char.code '\\' then begin
                      incr pos;
                      no_check := true;
                      let r = parse_escape ~in_cc:true in
                      no_check := false;
                      match r with
                      | `C v -> v | `S _ -> raise (Out "class range to a ctype")
                    end else read_cp () in
                  if hi < lo then raise (Invalid err_empty_range_cc);
                  add (CR (lo, hi)); prev := `None; `Range
                end
              | `Range | `None -> `Ch c
          end
          else `Ch (read_cp ()) in
        (match item with
         | `Ch v -> flush (); prev := `Ch v
         | `Set s -> flush (); add s
         | `Range | `Skip -> ());
        first := false
      end
    done;
    flush ();
    let last = COr (List.rev !items) in
    let body = List.fold_left (fun acc s -> CAnd (s, acc)) last !segs in
    if neg then CNot body else body
  (* pos at "[:" ; Some cset if a POSIX bracket, None if a nested class
     (is_posix_bracket_start and prs_posix_bracket,
     upstream/src/regparse.c:5246-5280 and :6718-6765) *)
  and posix_bracket () =
    let save = !pos in
    pos := !pos + 2;
    let k = ref 0 and res = ref None in
    (try while not (eof ()) do
         let x = read_cp () in
         if x = Char.code ':' then begin
           res := Some (not (eof ()) && peek () = Char.code ']' && !k > 0); raise Exit
         end
         else if x = Char.code '^' && !k = 0 then ()
         else if not (x < 0x110000 && in_prop 1 x) then (res := Some false; raise Exit);
         incr k
       done with Exit -> ());
    pos := save + 2;
    if !res <> Some true then (pos := save; None)
    else begin
      let neg = if peek () = Char.code '^' then (incr pos; true) else false in
      let rest = String.sub pat !pos (n - !pos) in
      match List.find_opt (fun (nm, _) ->
          String.length rest >= String.length nm && String.sub rest 0 (String.length nm) = nm)
          posix_names with
      | Some (nm, ct) when (let l = String.length nm in
                            String.length rest >= l + 2 && String.sub rest l 2 = ":]") ->
        pos := !pos + String.length nm + 2;
        let s = CP ct in Hashtbl.replace used_props ct ();
        Some (if neg then CNot s else s)
      | _ -> raise (Invalid err_invalid_posix_bracket)
    end in
  let skip_ext o =
    if o.ext then begin
      let go = ref true in
      while !go && not (eof ()) do
        let c = peek () in
        if c = 32 || c = 9 || c = 10 || c = 13 || c = 12 || c = 11 then incr pos
        else if c = Char.code '#' then
          (while not (eof ()) && peek () <> 10 do incr pos done)
        else go := false
      done
    end in
  (* interval at '{' : Some (lo, hi, possessive_reversed) with pos after '}' *)
  let interval () =
    let save = !pos in
    incr pos;
    let scan () =
      let st = !pos and v = ref 0 in
      while not (eof ()) && is_digit (peek ()) do
        v := !v * 10 + (peek () - 48);
        if !v > max_repeat then raise (Invalid err_too_big_repeat); incr pos
      done;
      if !pos > st then Some !v else None in
    let r =
      match scan () with
      | None ->
        if peek () = Char.code ',' && syn <> PerlNG then begin
          incr pos;
          match scan () with
          | Some m when peek () = Char.code '}' -> incr pos; Some (0, m, true)
          | _ -> None
        end else None
      | Some lo ->
        if peek () = Char.code '}' then (incr pos; Some (lo, lo, false))
        else if peek () = Char.code ',' then begin
          incr pos;
          match scan () with
          | Some m when peek () = Char.code '}' -> incr pos; Some (lo, m, true)
          | None when peek () = Char.code '}' -> incr pos; Some (lo, -1, true)
          | _ -> None
        end else None in
    (match r with None -> pos := save | Some _ -> ());
    r in
  let mk_rep mn mx greedy poss t =
    (* nested fixed repeats multiply (upstream's reduction) *)
    (match t with
     | PRep (a, b, _, _, _) when a = b && mn = mx && mn > 0 && a > 0 && a * mn > max_repeat ->
       raise (Invalid err_too_big_repeat)
     | PGroup (_, _, PRep (a, b, _, _, _)) when false && a = b -> ()
     | _ -> ());
    PRep (mn, mx, greedy, poss, t) in
  let rec parse_alt o =
    let first = parse_seq o in
    if peek () = Char.code '|' then (incr pos; PAlt (first, parse_alt o))
    else first
  and parse_seq o =
    let items = ref [] and stop = ref false and o = ref o in
    while not !stop do
      skip_ext !o;
      if eof () then stop := true
      else begin
        let c = peek () in
        if c = Char.code '|' || c = Char.code ')' then stop := true
        else if c = Char.code '*' || c = Char.code '+' || c = Char.code '?' then
          raise (Invalid err_target_of_repeat_not_specified)
        else if c = Char.code '{' && (let s = !pos in let r = interval () in pos := s; r <> None) then
          raise (Invalid err_target_of_repeat_not_specified)
        else begin
          match parse_atom !o with
          | `Opt o' ->
            (* isolated option: applies to the rest of the enclosing group *)
            if syn = PerlNG then o := o'
            else begin
              let rest = parse_alt o' in
              items := rest :: !items; stop := true
            end
          | `Comment -> ()
          | `Atom (a, quantifiable) ->
            let a = parse_quants !o a quantifiable in
            items := a :: !items
        end
      end
    done;
    match !items with
    | [] -> PNode Eps
    | x :: t -> List.fold_left (fun acc y -> PCat (y, acc)) x t
  and parse_quants o atom quantifiable =
    skip_ext o;
    let c = peek () in
    let q =
      if c = Char.code '*' then (incr pos; Some (0, -1, true))
      else if c = Char.code '+' then (incr pos; Some (1, -1, true))
      else if c = Char.code '?' then (incr pos; Some (0, 1, true))
      else if c = Char.code '{' then interval ()
      else None in
    match q with
    | None -> atom
    | Some (lo, hi, comma) ->
      if not quantifiable then raise (Invalid err_target_of_repeat_invalid);
      let interval = c = Char.code '{' in
      (* {n}? is greedy {n} then '?' (ONIG_SYN_FIXED_INTERVAL_IS_GREEDY_ONLY) *)
      let fixed = interval && not comma in
      let c2 = peek () in
      let node =
        if interval && hi >= 0 && lo > hi then
          (* reversed interval {n,m} (n > m): possessive {m,n} *)
          mk_rep hi lo true true atom
        else if c2 = Char.code '?' && not (fixed && syn <> PerlNG) then
          (incr pos; mk_rep lo hi false false atom)
        else if c2 = Char.code '+' && (not interval || syn = PerlNG) then
          (incr pos; mk_rep lo hi true true atom)
        else mk_rep lo hi true false atom in
      parse_quants o node true
  and group_name close =
    let st = !pos in
    while not (eof ()) && peek () <> Char.code close do incr pos done;
    if eof () then raise (Invalid err_invalid_group_name);
    let name = String.sub pat st (!pos - st) in
    incr pos;
    if name = "" then raise (Invalid err_empty_group_name);
    if is_digit (Char.code name.[0]) then raise (Invalid err_invalid_group_name);
    String.iter (fun ch -> if not (ch = '_' || Char.code ch >= 0x80
                                   || (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')
                                   || (ch >= '0' && ch <= '9')) then
                    raise (Invalid err_invalid_group_name)) name;
    name
  and close_group o body =
    skip_ext o;
    if eof () then raise (Invalid err_end_pattern_unmatched_paren);
    incr pos; body
  and parse_options o =
    (* pos after "(?" ; returns `Opt o' (isolated) or `Atom group *)
    let o = ref o and neg = ref false and fin = ref None in
    while !fin = None do
      if eof () then raise (Invalid err_end_pattern_in_group);
      let c = Char.chr (peek ()) in
      incr pos;
      match c with
      | '-' -> neg := true
      | 'i' -> o := { !o with icase = not !neg }
      | 'x' -> o := { !o with ext = not !neg }
      | 'm' when syn = PerlNG -> o := { !o with single = !neg }
      | 's' when syn = PerlNG -> o := { !o with dotall = not !neg }
      | 'm' -> o := { !o with dotall = not !neg }
      | ')' -> fin := Some `Iso
      | ':' -> fin := Some `Grp
      | 'W' | 'D' | 'S' | 'P' | 'y' | 'a' | 'u' | 'C' | 'I' | 'L' ->
        raise (Out (Printf.sprintf "(?%c) option" c))
      | _ -> raise (Invalid err_undefined_group_option)
    done;
    match !fin with
    | Some `Iso -> `Opt !o
    | _ -> let b = parse_alt !o in `Atom (close_group !o b, true)
  and parse_atom o : [ `Opt of opts | `Comment | `Atom of pre * bool ] =
    let c = peek () in
    if c = Char.code '(' then begin
      incr pos;
      if peek () = Char.code '*' then raise (Out "(* verb/callout");
      if peek () = Char.code '?' then begin
        incr pos;
        if eof () then raise (Invalid err_end_pattern_in_group);
        let d = Char.chr (peek ()) in
        match d with
        | ':' -> incr pos; let b = parse_alt o in `Atom (close_group o b, true)
        | '=' -> incr pos; let b = parse_alt o in `Atom (PAhead (false, close_group o b), false)
        | '!' -> incr pos; let b = parse_alt o in `Atom (PAhead (true, close_group o b), false)
        | '>' -> incr pos; let b = parse_alt o in `Atom (PAtomic (close_group o b), true)
        | '#' ->
          while not (eof ()) && peek () <> Char.code ')' do incr pos done;
          if eof () then raise (Invalid err_end_pattern_in_group);
          incr pos; `Comment
        | '<' when peek_at 1 = Char.code '=' || peek_at 1 = Char.code '!' ->
          let ng = peek_at 1 = Char.code '!' in
          pos := !pos + 2;
          let b = parse_alt o in `Atom (PBehind (ng, close_group o b), false)
        | '<' | '\'' ->
          incr pos;
          let name = group_name (if d = '<' then '>' else '\'') in
          incr ncap; let k = !ncap in
          names := (k, name) :: !names;
          let b = parse_alt o in `Atom (PGroup (k, Some name, close_group o b), true)
        | '~' -> raise (Out "absent operator")
        | '(' -> raise (Out "conditional")
        | '{' -> raise (Out "callout")
        | 'P' when syn = PerlNG -> raise (Out "(?P..)")
        | '&' | 'R' -> raise (Out "subexpression call")
        | ch when (ch >= '0' && ch <= '9') || ch = '+' || ch = '-' && syn = PerlNG
                  && (peek_at 1 >= 48 && peek_at 1 <= 57) ->
          raise (Out "subexpression call")
        | _ -> parse_options o
      end else begin
        incr ncap;
        let k = !ncap in
        let b = parse_alt o in
        `Atom (PGroup (k, None, close_group o b), true)
      end
    end
    else if c = Char.code '[' then (incr pos;
                                     let cs = parse_cc () in `Atom (PNode (cls_node o cs), true))
    else if c = Char.code '.' then begin
      incr pos;
      `Atom (PNode (Cls (if o.dotall then CR (0, 0x7fffffff) else CNot (CR (10, 10)))), true)
    end
    else if c = Char.code '^' then
      (incr pos; `Atom (PNode (Anc (if o.single then BufBeg else BolA)), false))
    else if c = Char.code '$' then
      (incr pos; `Atom (PNode (Anc (if o.single then SemiEnd else EolA)), false))
    else if c = Char.code '\\' then begin
      incr pos;
      if eof () then raise (Invalid err_end_pattern_at_escape);
      let d = Char.chr (peek ()) in
      let anc a = incr pos; `Atom (PNode (Anc a), false) in
      match d with
      | 'A' -> anc BufBeg | 'z' -> anc BufEnd | 'Z' -> anc SemiEnd
      | 'G' -> anc SearchStart | 'b' -> anc WordB | 'B' -> anc NotWordB
      | 'k' ->
        incr pos;
        let close = if peek () = Char.code '<' then '>' else if peek () = Char.code '\'' then '\''
          else raise (Out "\\k not followed by < or '") in
        incr pos;
        let st = !pos in
        while not (eof ()) && peek () <> Char.code close do incr pos done;
        if eof () then raise (Invalid err_invalid_group_name);
        let r = String.sub pat st (!pos - st) in
        incr pos;
        if r = "" then raise (Invalid err_empty_group_name);
        let ref_ =
          if String.contains r '+' && r.[0] <> '+' || String.contains r '-' && r.[0] <> '-' then
            raise (Out "backreference with level")
          else if r.[0] = '-' || r.[0] = '+' then begin
            match int_of_string_opt (String.sub r 1 (String.length r - 1)) with
            | Some k when r.[0] = '-' -> PBnum (!ncap + 1 - k, o.icase)
            | Some k -> PBnum (!ncap + k, o.icase)
            | None -> raise (Invalid err_invalid_group_name)
          end
          else match int_of_string_opt r with
            | Some k -> PBnum (k, o.icase)
            | None -> ignore (group_name_check r); PBname (r, o.icase) in
        `Atom (ref_, true)
      | '1' .. '9' ->
        let st = !pos in
        let v = ref 0 in
        while not (eof ()) && is_digit (peek ()) do v := !v * 10 + peek () - 48; incr pos done;
        if !v <= 9 || !v <= !ncap then `Atom (PBnum (!v, o.icase), true)
        else begin
          pos := st;
          if d = '8' || d = '9' then (incr pos; `Atom (PNode (lit_node o [ Char.code d ]), true))
          else begin
            let v = ref 0 and k = ref 0 in
            while !k < 3 && octval (peek ()) >= 0 do v := !v * 8 + octval (peek ()); incr k; incr pos done;
            `Atom (PNode (lit_node o [ !v ]), true)
          end
        end
      | 'g' -> raise (Out "subexpression call")
      | 'X' | 'y' | 'Y' -> raise (Out "text segment (\\X, \\y, \\Y)")
      | 'R' | 'N' | 'O' | 'K' -> raise (Out (Printf.sprintf "\\%c" d))
      | 'Q' when syn = PerlNG -> raise (Out "\\Q")
      | _ ->
        (match parse_escape ~in_cc:false with
         | `C v -> `Atom (PNode (lit_node o [ v ]), true)
         | `S s -> `Atom (PNode (cls_node o s), true))
    end
    else begin
      (* a run of plain characters: the quantifier binds the last one *)
      let cps = ref [ read_cp () ] in
      let plain c = not (List.mem c (List.map Char.code
                                       [ '('; ')'; '['; '.'; '^'; '$'; '\\'; '|'; '*'; '+'; '?'; '{' ])) in
      let continue_ () =
        skip_ext o;
        not (eof ()) && plain (peek ())
        && (let save = !pos in
            ignore (read_cp ());
            skip_ext o;
            let nxt = peek () in
            pos := save;
            not (nxt = Char.code '*' || nxt = Char.code '+' || nxt = Char.code '?'
                 || (nxt = Char.code '{'
                     && (let s = !pos in ignore (read_cp ()); skip_ext o;
                         let r = interval () in pos := s; r <> None)))) in
      while continue_ () do cps := read_cp () :: !cps done;
      `Atom (PNode (lit_node o (List.rev !cps)), true)
    end
  and group_name_check r = r
  and lit_node o cps =
    if o.icase then LitI (fold_string cps)
    else Lit (String.concat "" (List.map cp_string cps))
  and cls_node o cs =
    if not o.icase then Cls cs
    else begin
      let extra, multi = icase_closure (match cs with CNot c -> c | c -> c) in
      let neg, base = match cs with CNot c -> true, c | c -> false, c in
      let closed = if extra = [] then base else COr (base :: ranges_of_list extra) in
      if neg then Cls (CNot closed)
      else if multi = [] then Cls closed
      else ClsI (closed, multi)
    end in
  let pre = parse_alt opt0 in
  if not (eof ()) then raise (Invalid err_unmatched_close_paren);
  (* group numbering: only named groups capture when there are any
     (ONIG_SYN_CAPTURE_ONLY_NAMED_GROUP, as disable_noname_group_capture) *)
  let named = List.rev !names in
  let total = !ncap in
  let renum = Hashtbl.create 16 in
  if named <> [] then List.iteri (fun i (k, _) -> Hashtbl.replace renum k (i + 1)) named
  else for k = 1 to total do Hashtbl.replace renum k k done;
  let ncap_final = Hashtbl.length renum in
  let rec conv = function
    | PNode x -> x
    | PCat (a, b) -> (match conv a, conv b with Eps, x | x, Eps -> x | x, y -> Cat (x, y))
    | PAlt (a, b) -> Alt (conv a, conv b)
    | PRep (mn, mx, g, poss, a) ->
      let r = Rep (mn, mx, g, conv a) in if poss then Atomic r else r
    | PAtomic a -> Atomic (conv a)
    | PAhead (ng, a) -> Ahead (ng, conv a)
    | PBehind (ng, a) ->
      let rec alts = function PAlt (x, y) -> conv x :: alts y | x -> [ conv x ] in
      Behind (ng, alts a)
    | PGroup (k, _, a) ->
      (match Hashtbl.find_opt renum k with Some k' -> Group (k', conv a) | None -> conv a)
    | PBnum (k, ic) ->
      if named <> [] then raise (Invalid err_numbered_backref_not_allowed);
      if k < 1 || k > total then raise (Invalid err_invalid_backref);
      Bref ([ k ], ic)
    | PBname (nm, ic) ->
      let gs = List.filter_map (fun (k, nm') -> if nm = nm' then Hashtbl.find_opt renum k else None) named in
      if gs = [] then raise (Invalid err_undefined_name_ref);
      Bref (List.sort (fun a b -> compare b a) gs, ic) in
  let ast = conv pre in
  (* lookbehind checks: maximum length in characters *)
  let rec maxlen = function
    | Eps | Anc _ | Ahead _ | Behind _ -> Some 0
    | Lit s -> let k = ref 0 in String.iter (fun ch -> if Char.code ch land 0xc0 <> 0x80 then incr k) s; Some !k
    | LitI f -> Some (List.length f)
    | Cls _ -> Some 1
    | ClsI (_, ms) -> Some (List.fold_left (fun a m -> max a (List.length m)) 1 ms)
    | Cat (a, b) -> (match maxlen a, maxlen b with Some x, Some y -> Some (x + y) | _ -> None)
    | Alt (a, b) -> (match maxlen a, maxlen b with Some x, Some y -> Some (max x y) | _ -> None)
    | Rep (_, mx, _, a) -> if mx < 0 then None else
        (match maxlen a with Some x -> Some (min (x * mx) max_int) | None -> None)
    | Atomic a | Group (_, a) -> maxlen a
    | Bref _ -> None in
  let rec check = function
    | Behind (_, alts) ->
      List.iter (fun a ->
          (match maxlen a with
           | Some m when m > look_behind_max -> raise (Invalid err_invalid_look_behind)
           | None when syn = PerlNG -> raise (Invalid err_invalid_look_behind)
           | _ -> ());
          check a) alts
    | Cat (a, b) | Alt (a, b) -> check a; check b
    | Rep (_, _, _, a) | Atomic a | Ahead (_, a) | Group (_, a) -> check a
    | _ -> () in
  check ast;
  (ast, ncap_final)

(* ---------------------------------------------------------------- *)
(* Serialisation of ASTs for the provers' case modules *)

let rec cs_sexp = function
  | CR (a, b) -> Printf.sprintf "r%x-%x" a b
  | CP p -> Printf.sprintf "p%d" p
  | CNot s -> Printf.sprintf "(! %s)" (cs_sexp s)
  | COr l -> Printf.sprintf "(+%s)" (String.concat "" (List.map (fun s -> " " ^ cs_sexp s) l))
  | CAnd (a, b) -> Printf.sprintf "(& %s %s)" (cs_sexp a) (cs_sexp b)

let cps_hex l = String.concat "," (List.map (Printf.sprintf "%x") l)

let anc_name = function
  | BolA -> "bol" | EolA -> "eol" | BufBeg -> "A" | BufEnd -> "z" | SemiEnd -> "Z"
  | SearchStart -> "G" | WordB -> "b" | NotWordB -> "B"

let rec to_sexp = function
  | Eps -> "E"
  | Lit s -> "L" ^ String.concat "" (List.init (String.length s)
                                         (fun i -> Printf.sprintf "%02x" (Char.code s.[i])))
  | LitI f -> "I" ^ cps_hex f
  | Cls s -> Printf.sprintf "(c %s)" (cs_sexp s)
  | ClsI (s, ms) -> Printf.sprintf "(ci %s%s)" (cs_sexp s)
                      (String.concat "" (List.map (fun m -> " " ^ cps_hex m) ms))
  | Cat (a, b) -> Printf.sprintf "(. %s %s)" (to_sexp a) (to_sexp b)
  | Alt (a, b) -> Printf.sprintf "(| %s %s)" (to_sexp a) (to_sexp b)
  | Rep (mn, mx, g, a) -> Printf.sprintf "(%s %d %d %s)" (if g then "*" else "*?") mn mx (to_sexp a)
  | Atomic a -> Printf.sprintf "(> %s)" (to_sexp a)
  | Ahead (ng, a) -> Printf.sprintf "(%s %s)" (if ng then "?!" else "?=") (to_sexp a)
  | Behind (ng, l) -> Printf.sprintf "(%s%s)" (if ng then "?<!" else "?<=")
                        (String.concat "" (List.map (fun a -> " " ^ to_sexp a) l))
  | Group (k, a) -> Printf.sprintf "(g %d %s)" k (to_sexp a)
  | Bref (gs, ic) -> Printf.sprintf "(k%s %s)" (if ic then "i" else "")
                       (String.concat "," (List.map string_of_int gs))
  | Anc a -> "^" ^ anc_name a

(* ---------------------------------------------------------------- *)
(* The semantics *)

type caps = (int * (int * int)) list   (* group -> region, last write wins *)

type item =
  | Node of node
  | Close of int * int                    (* group, start position *)
  | Iter of int * int * bool * node * int * int * caps
  (* loop min, max, greedy, body; iterations done; position and captures
     at the start of the last iteration *)
  | AtEnd of int                          (* lookbehind: must end here *)

type result =
  | Matched of int * caps * int           (* end, captures, remaining fuel *)
  | Failed of int                         (* remaining fuel *)
  | NoFuel

let rec set_cap k v = function
  | [] -> [ (k, v) ]
  | (k', _) :: t when k' = k -> (k, v) :: t
  | x :: t -> x :: set_cap k v t

let has_prefix (s : string) pos (lit : string) =
  let l = String.length lit in
  pos + l <= String.length s
  && (let ok = ref true in
      for i = 0 to l - 1 do if s.[pos + i] <> lit.[i] then ok := false done;
      !ok)

(* a subject segment from [pos] whose fold is exactly [f]: its end *)
let rec match_fold (s : string) pos (f : int list) =
  match f with
  | [] -> Some pos
  | _ ->
    match decode s pos with
    | None -> None
    | Some (c, l) ->
      let rec strip a b = match a, b with
        | [], rest -> Some rest
        | x :: a', y :: b' when x = y -> strip a' b'
        | _ -> None in
      match strip (fold c) f with
      | Some rest -> match_fold s (pos + l) rest
      | None -> None

let word_at s pos = match decode s pos with Some (c, _) -> is_word c | None -> false
let word_before s pos = let p = prev_pos s pos in p >= 0 && word_at s p

let anchor_ok s a pos =
  let len = String.length s in
  match a with
  | BolA -> pos = 0 || s.[pos - 1] = '\n'
  | EolA -> pos = len || s.[pos] = '\n'
  | BufBeg | SearchStart -> pos = 0
  | BufEnd -> pos = len
  | SemiEnd -> pos = len || (pos = len - 1 && s.[pos] = '\n')
  | WordB -> word_before s pos <> word_at s pos
  | NotWordB -> word_before s pos = word_at s pos

(* DEV-003, in its observably equal form ("select only groups referenced
   by some backreference, inside or outside the loop"): an empty
   iteration stops the loop unless a backreferenced group changed in it.
   [cur_refs] holds the backreferenced groups of the current pattern. *)
let cur_refs : int list ref = ref []

let same_refs (a : caps) (b : caps) =
  List.for_all (fun g -> List.assoc_opt g a = List.assoc_opt g b) !cur_refs

let rec brefs = function
  | Bref (gs, _) -> gs
  | Cat (a, b) | Alt (a, b) -> brefs a @ brefs b
  | Rep (_, _, _, a) | Atomic a | Ahead (_, a) | Group (_, a) -> brefs a
  | Behind (_, l) -> List.concat_map brefs l
  | _ -> []

let rec step s fuel items pos (caps : caps) =
  if fuel = 0 then NoFuel
  else
    let fuel = fuel - 1 in
    match items with
    | [] -> Matched (pos, caps, fuel)
    | Node Eps :: k -> step s fuel k pos caps
    | Node (Lit l) :: k ->
      if has_prefix s pos l then step s fuel k (pos + String.length l) caps
      else Failed fuel
    | Node (LitI f) :: k ->
      (match match_fold s pos f with Some e -> step s fuel k e caps | None -> Failed fuel)
    | Node (Cls cs) :: k ->
      (match decode s pos with
       | Some (c, l) when in_cset c cs -> step s fuel k (pos + l) caps
       | _ -> Failed fuel)
    | Node (ClsI (cs, ms)) :: k ->
      let r = match decode s pos with
        | Some (c, l) when in_cset c cs -> step s fuel k (pos + l) caps
        | _ -> Failed fuel in
      (match r with
       | Failed fuel ->
         let rec try_m fuel = function
           | [] -> Failed fuel
           | m :: t -> (match match_fold s pos m with
               | Some e -> (match step s fuel k e caps with Failed fuel -> try_m fuel t | r -> r)
               | None -> try_m fuel t) in
         try_m fuel ms
       | r -> r)
    | Node (Cat (a, b)) :: k -> step s fuel (Node a :: Node b :: k) pos caps
    | Node (Alt (a, b)) :: k ->
      (match step s fuel (Node a :: k) pos caps with
       | Failed fuel -> step s fuel (Node b :: k) pos caps
       | r -> r)
    | Node (Rep (mn, mx, g, a)) :: k -> rep s fuel mn mx g a 0 k pos caps
    | Iter (mn, mx, g, a, c, p0, c0) :: k ->
      if c > mn && mx < 0 && pos = p0 && same_refs caps c0 then step s fuel k pos caps
      else rep s fuel mn mx g a c k pos caps
    | Node (Atomic a) :: k ->
      (match step s fuel [ Node a ] pos caps with
       | Matched (e, caps', fuel) -> step s fuel k e caps'
       | r -> r)
    | Node (Ahead (ng, a)) :: k ->
      (match step s fuel [ Node a ] pos caps with
       | Matched (_, caps', fuel) -> if ng then Failed fuel else step s fuel k pos caps'
       | Failed fuel -> if ng then step s fuel k pos caps else Failed fuel
       | NoFuel -> NoFuel)
    | Node (Behind (ng, alts)) :: k ->
      (match behind s fuel alts pos caps with
       | Matched (_, caps', fuel) -> if ng then Failed fuel else step s fuel k pos caps'
       | Failed fuel -> if ng then step s fuel k pos caps else Failed fuel
       | NoFuel -> NoFuel)
    | AtEnd i :: k -> if pos = i then step s fuel k pos caps else Failed fuel
    | Node (Group (i, a)) :: k -> step s fuel (Node a :: Close (i, pos) :: k) pos caps
    | Close (i, p0) :: k -> step s fuel k pos (set_cap i (p0, pos) caps)
    | Node (Bref (gs, ic)) :: k ->
      let rec go = function
        | [] -> Failed fuel
        | g :: t ->
          match List.assoc_opt g caps with
          | None -> go t
          | Some (x, y) ->
            let txt = String.sub s x (y - x) in
            let e =
              if ic then begin
                let cps = ref [] and p = ref 0 in
                (try while !p < String.length txt do
                     match decode txt !p with
                     | Some (c, l) -> cps := c :: !cps; p := !p + l
                     | None -> raise Exit
                   done with Exit -> ());
                match_fold s pos (fold_string (List.rev !cps))
              end
              else if has_prefix s pos txt then Some (pos + String.length txt) else None in
            match e with Some e -> step s fuel k e caps | None -> go t in
      go gs
    | Node (Anc a) :: k -> if anchor_ok s a pos then step s fuel k pos caps else Failed fuel

and rep s fuel mn mx g a c k pos caps =
  let again = Node a :: Iter (mn, mx, g, a, c + 1, pos, caps) :: k in
  if c < mn then step s fuel again pos caps
  else if mx >= 0 && c >= mx then step s fuel k pos caps
  else if g then
    (match step s fuel again pos caps with Failed fuel -> step s fuel k pos caps | r -> r)
  else
    (match step s fuel k pos caps with Failed fuel -> step s fuel again pos caps | r -> r)

(* lookbehind: for each alternative in order, the nearest start first *)
and behind s fuel alts i caps =
  match alts with
  | [] -> Failed fuel
  | a :: t ->
    let rec from j fuel =
      if j < 0 then Failed fuel
      else match step s fuel [ Node a; AtEnd i ] j caps with
        | Failed fuel -> from (prev_pos s j) fuel
        | r -> r in
    match from i fuel with
    | Failed fuel -> behind s fuel t i caps
    | r -> r

let fuel0 = 10_000_000

let search re (s : string) =
  cur_refs := List.sort_uniq compare (brefs re);
  let len = String.length s in
  let rec go start =
    if start > len then `Mismatch else
    match step s fuel0 [ Node re ] start [] with
    | Matched (e, caps, _) -> `Match (start, e, caps)
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

let syntax_of = function
  | "ONIGURUMA" -> Some Onig | "PERL_NG" -> Some PerlNG | "RUBY" -> Some Ruby | _ -> None

(* API options in S2 (plan, "Scope"): IGNORECASE 1, EXTEND 2,
   MULTILINE 4, SINGLELINE 8, NEGATE_SINGLELINE 64 *)
let opts_of syn o =
  let s0 = syn = PerlNG in
  if o land (lnot (1 lor 2 lor 4 lor 8 lor 64)) <> 0 then None
  else Some { icase = o land 1 <> 0; ext = o land 2 <> 0; dotall = o land 4 <> 0;
              single = (s0 || o land 8 <> 0) && o land 64 = 0 }

(* classify: in-S2 cases to stdout
     idx id kind pat sub a b c syntax options ncap ast
   every case's verdict to the file given as second argument *)
let classify file outfile =
  let oc = open_out outfile in
  List.iteri (fun i l ->
      match String.split_on_char '\t' l with
      | [ suite; line; kind; enc; syn; opt; dir; pat; sub; a; b; c ] ->
        let id = Printf.sprintf "%s:%s" suite line in
        let out r = Printf.fprintf oc "%d\t%s\t%s\tout\t%s\n" i id kind r in
        if String.length kind > 0 && kind.[0] = 'r' then out "regset API"
        else if enc <> "UTF8" then out ("encoding " ^ enc)
        else if dir <> "fwd" then out "backward search"
        else begin
          match syntax_of syn with
          | None -> out ("syntax " ^ syn)
          | Some sy ->
            match opts_of sy (int_of_string opt) with
            | None -> out ("API option " ^ opt)
            | Some o ->
              let emit ncap ast =
                Printf.printf "%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%s\n"
                  i id kind pat sub a b c syn opt ncap ast in
              match parse sy o (of_hex pat) with
              | exception Out r -> out r
              | exception Invalid e ->
                Printf.fprintf oc "%d\t%s\t%s\tin\terror %d\n" i id kind e; emit (-1) "!"
              | ast, ncap ->
                Printf.fprintf oc "%d\t%s\t%s\tin\t\n" i id kind; emit ncap (to_sexp ast)
        end
      | _ -> failwith ("bad line: " ^ l))
    (read_lines file);
  close_out oc;
  let ps = Hashtbl.fold (fun k () acc -> k :: acc) used_props [] in
  Printf.eprintf "used ctypes/properties: %s\n"
    (String.concat " " (List.map string_of_int (List.sort compare ps)))

let verdict sy o pat sub =
  match parse sy o pat with
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
      | _ :: id :: _ :: pat :: sub :: _ :: _ :: _ :: syn :: opt :: _ ->
        let sy = Option.get (syntax_of syn) in
        (id, sy, Option.get (opts_of sy (int_of_string opt)), of_hex pat, of_hex sub)
      | _ -> failwith l) (read_lines file) in
  List.iter (fun (id, sy, o, p, s) -> Printf.printf "%s\t%s\n" id (verdict sy o p s)) cases;
  let n = List.length cases in
  let t0 = Unix.gettimeofday () in
  let parsed = ref [] in
  for _ = 1 to reps do
    parsed := List.map (fun (_, sy, o, p, s) ->
        match parse sy o p with r -> Some (fst r, s) | exception _ -> None) cases
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
    List.iter (fun (_, sy, o, p, s) -> ignore (verdict sy o p s)) cases
  done;
  let t3 = Unix.gettimeofday () in
  let tot = float (n * reps) in
  Printf.eprintf "cases=%d reps=%d parse_s=%.3f search_s=%.3f e2e_s=%.3f parse_cps=%.0f search_cps=%.0f e2e_cps=%.0f sink=%d\n"
    n reps (t1 -. t0) (t2 -. t1) (t3 -. t2) (tot /. (t1 -. t0)) (tot /. (t2 -. t1))
    (tot /. (t3 -. t2)) !sink

let () =
  let tables = match Sys.getenv_opt "G_TABLES" with
    | Some f -> f | None -> Filename.concat (Filename.dirname Sys.executable_name) "tables.txt" in
  load_tables tables;
  match Array.to_list Sys.argv with
  | [ _; "classify"; f; o ] -> classify f o
  | [ _; "run"; f; reps ] -> run f (int_of_string reps)
  | _ -> prerr_endline "usage: g2 classify ALL.tsv VERDICTS | g2 run IN.tsv REPS"; exit 2
