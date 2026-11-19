(* Experiment #12: a small backtracking VM for the regular subset of
   Oniguruma f95747b (UTF-8; syntaxes ONIGURUMA, RUBY, PERL_NG).

   The parser doubles as the subset classifier (strict mode): anything
   outside the subset raises [Out reason]; a pattern made only of subset
   constructs that Oniguruma rejects raises [Invalid onigerr_code].

   References to upstream are to commit f95747b. *)

exception Out of string
exception Invalid of int

(* Syntaxes *)
let syn_oniguruma = 0
let syn_ruby = 1
let syn_perl_ng = 2

(* Options (upstream/src/oniguruma.h:375-396) *)
let opt_extend = 2
let opt_multiline = 4
let opt_singleline = 8
let opt_negate_singleline = 64
let opt_capture_group = 256
let opt_notbol = 512
let opt_noteol = 1024
let opt_word_ascii = 65536
let opt_digit_ascii = 131072
let opt_space_ascii = 262144

let allowed_options =
  opt_multiline lor opt_singleline lor opt_negate_singleline
  lor opt_capture_group lor opt_word_ascii lor opt_digit_ascii
  lor opt_space_ascii

let allowed_search_options = opt_notbol lor opt_noteol
let _ = opt_extend

(* Error codes *)
let err_retry_limit = -17
let err_end_pattern_at_escape = -104
let err_premature_end_cc = -103
let err_target_of_repeat_not_specified = -113
let err_unmatched_close_paren = -116
let err_end_pattern_unmatched_paren = -117
let err_too_big_repeat = -201
let err_upper_smaller_than_lower = -202
let err_empty_range_cc = -203

(* ---------------------------------------------------------------- *)
(* Character classes: ASCII bitmap (bytes 0..127) + sorted ranges of
   code points >= 128, then negation. *)

type cls = {
  ascii : Bytes.t;            (* 128 entries, '\001' = member *)
  ranges : int array;         (* lo0 hi0 lo1 hi1 ... (>= 128) *)
  neg : bool;
}

(* AST *)
type node =
  | Str of string               (* bytes of one code point *)
  | Any
  | Cls of cls
  | Anchor of int               (* opcode *)
  | Group of int * node         (* capture number, body *)
  | Cat of node list
  | Alt of node list
  | Rep of node * int * int * bool   (* body, lower, upper (-1 = inf), greedy *)

(* Opcodes *)
let op_char = 0
let op_str = 1
let op_any = 2
let op_anyml = 3
let op_cls = 4
let op_bol = 5
let op_eol = 6
let op_bos = 7
let op_eos = 8
let op_semi_eos = 9
let op_split = 10
let op_jmp = 11
let op_save_start = 12
let op_save_end = 13
let op_empty_start = 14
let op_empty_end = 15
let op_match = 16

type prog = {
  code : int array;
  strs : string array;
  clss : cls array;
  ncap : int;            (* number of capture groups *)
  nempty : int;          (* number of empty-check slots *)
  uses_w : bool; uses_d : bool; uses_s : bool;
  (* mutable matcher state, preallocated *)
  mutable stack : int array;
  caps : int array;      (* 2 * (ncap + 1) *)
  empty : int array;
}

(* ---------------------------------------------------------------- *)
(* UTF-8 helpers, as upstream/src/utf8.c (USE_RFC3629_RANGE) *)

let enc_len c =
  if c < 0xc2 then 1
  else if c < 0xe0 then 2
  else if c < 0xf0 then 3
  else if c < 0xf5 then 4
  else 1
[@@inline]

let encode_cp b cp =
  if cp < 0x80 then Buffer.add_char b (Char.chr cp)
  else if cp < 0x800 then begin
    Buffer.add_char b (Char.chr (0xc0 lor (cp lsr 6)));
    Buffer.add_char b (Char.chr (0x80 lor (cp land 0x3f)))
  end else if cp < 0x10000 then begin
    Buffer.add_char b (Char.chr (0xe0 lor (cp lsr 12)));
    Buffer.add_char b (Char.chr (0x80 lor ((cp lsr 6) land 0x3f)));
    Buffer.add_char b (Char.chr (0x80 lor (cp land 0x3f)))
  end else begin
    Buffer.add_char b (Char.chr (0xf0 lor (cp lsr 18)));
    Buffer.add_char b (Char.chr (0x80 lor ((cp lsr 12) land 0x3f)));
    Buffer.add_char b (Char.chr (0x80 lor ((cp lsr 6) land 0x3f)));
    Buffer.add_char b (Char.chr (0x80 lor (cp land 0x3f)))
  end

let cp_string cp = let b = Buffer.create 4 in encode_cp b cp; Buffer.contents b

(* ---------------------------------------------------------------- *)
(* Parser *)

type cset = { mutable a : bool array; mutable r : (int * int) list }

let new_cset () = { a = Array.make 128 false; r = [] }

let add_range cs lo hi =
  for c = lo to min hi 127 do cs.a.(c) <- true done;
  if hi >= 128 then cs.r <- (max lo 128, hi) :: cs.r

let is_word c = (c >= 48 && c <= 57) || (c >= 65 && c <= 90)
                || (c >= 97 && c <= 122) || c = 95
let is_digit c = c >= 48 && c <= 57
let is_space c = (c >= 9 && c <= 13) || c = 32

(* add ASCII ctype (possibly negated: complement over all code points) *)
let add_ctype cs pred neg =
  for c = 0 to 127 do if pred c <> neg then cs.a.(c) <- true done;
  if neg then cs.r <- (128, 0x7fffffff) :: cs.r

let finish_cset cs neg =
  let ascii = Bytes.make 128 '\000' in
  Array.iteri (fun i b -> if b then Bytes.set ascii i '\001') cs.a;
  let rs = List.sort compare cs.r in
  let rec merge = function
    | (a, b) :: (c, d) :: t when c <= b + 1 -> merge ((a, max b d) :: t)
    | x :: t -> x :: merge t
    | [] -> [] in
  let rs = merge rs in
  let ranges = Array.of_list (List.concat_map (fun (a, b) -> [a; b]) rs) in
  { ascii; ranges; neg }

let parse ~syntax ~options (pat : string) =
  if syntax = 8 then raise (Out "encoding");
  if syntax < 0 || syntax > 2 then raise (Out "syntax");
  if options land (lnot allowed_options) <> 0 then
    raise (Out (Printf.sprintf "option:0x%x" (options land lnot allowed_options)));
  let eff = options lor (if syntax = syn_perl_ng then opt_singleline else 0) in
  let eff = if options land opt_negate_singleline <> 0
    then eff land lnot opt_singleline else eff in
  let singleline = eff land opt_singleline <> 0 in
  let multiline = eff land opt_multiline <> 0 in
  let n = String.length pat in
  let pos = ref 0 in
  let ncap = ref 0 in
  let uses_w = ref false and uses_d = ref false and uses_s = ref false in
  let peek () = if !pos < n then Char.code pat.[!pos] else -1 in
  let eof () = !pos >= n in
  (* read one UTF-8 code point from the pattern (literal) *)
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
  (* after a backslash and an 'x' *)
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
  (* escape outside or inside a class; returns `C cp or `T (pred, neg, kind) *)
  let parse_escape ~in_cc =
    if eof () then raise (Invalid err_end_pattern_at_escape);
    let c = peek () in
    if c >= 0x80 then raise (Out "escaped non-ASCII");
    incr pos;
    match Char.chr c with
    | 't' -> `C 9 | 'n' -> `C 10 | 'r' -> `C 13 | 'f' -> `C 12
    | 'e' -> `C 27 | 'a' -> `C 7
    | 'v' -> if syntax = syn_perl_ng then `C (Char.code 'v') else `C 11
    | 'x' -> `C (parse_hex ())
    | 'd' -> uses_d := true; `T (is_digit, false)
    | 'D' -> uses_d := true; `T (is_digit, true)
    | 'w' -> uses_w := true; `T (is_word, false)
    | 'W' -> uses_w := true; `T (is_word, true)
    | 's' -> uses_s := true; `T (is_space, false)
    | 'S' -> uses_s := true; `T (is_space, true)
    | 'A' when not in_cc -> `A op_bos
    | 'z' when not in_cc -> `A op_eos
    | ch when (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')
              || (ch >= '0' && ch <= '9') ->
      raise (Out (Printf.sprintf "\\%c" ch))
    | _ -> `C c in
  (* bracket class; '[' already consumed *)
  let parse_cc () =
    let cs = new_cset () in
    let neg = if peek () = Char.code '^' then (incr pos; true) else false in
    let first = ref true in
    (* item: `Ch cp | `Ty *)
    let prev = ref `None in
    let fin = ref false in
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
          else if c = Char.code '\\' then begin
            incr pos;
            match parse_escape ~in_cc:true with
            | `C v -> `Ch v
            | `T (p, ng) -> add_ctype cs p ng; `Ty
            | `A _ -> assert false
          end
          else if c = Char.code '-' then begin
            incr pos;
            if !first || peek () = Char.code ']' then `Ch c
            else match !prev with
              | `Ch lo ->
                (* range lo - hi *)
                if eof () then raise (Invalid err_premature_end_cc);
                let hi =
                  let d = peek () in
                  if d = Char.code '&' && !pos + 1 < n && pat.[!pos + 1] = '&' then
                    raise (Out "class intersection")
                  else if d = Char.code '[' then raise (Out "nested class")
                  else if d = Char.code '\\' then begin
                    incr pos;
                    match parse_escape ~in_cc:true with
                    | `C v -> v
                    | _ -> raise (Out "range to char type")
                  end else read_cp () in
                if hi < lo then raise (Invalid err_empty_range_cc);
                add_range cs lo hi; `Range
              | `Range -> raise (Out "'-' after range")
              | `Ty -> raise (Out "'-' after char type")
              | `None -> `Ch c
          end
          else `Ch (read_cp ()) in
        (match item with
         | `Ch v -> (match !prev with `Ch p -> add_range cs p p | _ -> ());
           prev := `Ch v
         | `Ty -> (match !prev with `Ch p -> add_range cs p p | _ -> ());
           prev := `Ty
         | `Range -> prev := `Range);
        first := false
      end
    done;
    (match !prev with `Ch p -> add_range cs p p | _ -> ());
    Cls (finish_cset cs neg) in
  (* interval after '{' was seen at !pos (pos points at '{').  Returns
     Some (lo, up, fixed) and advances, or None (literal '{'). *)
  let parse_interval () =
    let save = !pos in
    incr pos;
    let scan () =
      let st = !pos and v = ref 0 and big = ref false in
      while not (eof ()) && is_digit (peek ()) do
        v := !v * 10 + (peek () - 48); if !v > 100000 then big := true; incr pos
      done;
      if !big then raise (Invalid err_too_big_repeat);
      if !pos = st then None else Some !v in
    let invalid () = pos := save; None in
    if eof () then invalid ()
    else match scan () with
      | None ->
        if peek () = Char.code ',' && (syntax <> syn_perl_ng) then
          raise (Out "{,n}")
        else if peek () = Char.code ',' then begin
          (* Perl_NG: {,n} is not an interval; literal '{' *)
          invalid ()
        end else invalid ()
      | Some lo ->
        if eof () then invalid ()
        else if peek () = Char.code ',' then begin
          incr pos;
          let up = match scan () with None -> -1 | Some u -> u in
          if eof () || peek () <> Char.code '}' then invalid ()
          else begin
            incr pos;
            if up >= 0 && lo > up then begin
              if syntax = syn_perl_ng then raise (Invalid err_upper_smaller_than_lower)
              else raise (Out "{n,m} with n>m (possessive)")
            end;
            Some (lo, up, false)
          end
        end
        else if peek () = Char.code '}' then (incr pos; Some (lo, lo, true))
        else invalid () in
  let is_anchorish nd =
    let rec f = function
      | Anchor _ -> true
      | Cat l -> l <> [] && List.for_all f l
      | Alt l -> List.for_all f l
      | _ -> false in f nd in
  let rec parse_alt () =
    let first = parse_seq () in
    if peek () = Char.code '|' then begin
      let l = ref [first] in
      while peek () = Char.code '|' do incr pos; l := parse_seq () :: !l done;
      Alt (List.rev !l)
    end else first
  and parse_seq () =
    let items = ref [] in
    let stop = ref false in
    while not !stop do
      if eof () then stop := true
      else begin
        let c = peek () in
        if c = Char.code '|' || c = Char.code ')' then stop := true
        else if c = Char.code '*' || c = Char.code '+' || c = Char.code '?' then
          raise (Invalid err_target_of_repeat_not_specified)
        else if c = Char.code '{' && (match (let s = !pos in let r = (try parse_interval () with e -> pos := s; raise e) in pos := s; r) with Some _ -> true | None -> false) then
          raise (Invalid err_target_of_repeat_not_specified)
        else begin
          let atom = parse_atom () in
          items := parse_quant atom :: !items
        end
      end
    done;
    match !items with [x] -> x | l -> Cat (List.rev l)
  and parse_quant atom =
    let quant () =
      let c = peek () in
      if c = Char.code '*' then (incr pos; Some (0, -1, false))
      else if c = Char.code '+' then (incr pos; Some (1, -1, false))
      else if c = Char.code '?' then (incr pos; Some (0, 1, false))
      else if c = Char.code '{' then parse_interval ()
      else None in
    match quant () with
    | None -> atom
    | Some (lo, up, fixed) ->
      if is_anchorish atom then raise (Out "quantified anchor");
      let interval = (lo, up) <> (0, -1) && (lo, up) <> (1, -1) && (lo, up) <> (0, 1)
                     || fixed in
      let greedy, node =
        if fixed && syntax <> syn_perl_ng then begin
          (* FIXED_INTERVAL_IS_GREEDY_ONLY: x{n}? is (?:x{n})? *)
          let r = Rep (atom, lo, up, true) in
          if peek () = Char.code '?' then (incr pos; true, Rep (r, 0, 1, true))
          else true, r
        end else begin
          let lazy_ = peek () = Char.code '?' in
          if lazy_ then incr pos
          else if peek () = Char.code '+' then
            raise (Out (if interval then "nested quantifier" else "possessive"));
          (not lazy_, Rep (atom, lo, up, not lazy_))
        end in
      ignore greedy;
      (* any further quantifier: nested repeat, out of subset *)
      let c = peek () in
      if c = Char.code '*' || c = Char.code '+' || c = Char.code '?' then
        raise (Out "nested quantifier");
      if c = Char.code '{' then begin
        let s = !pos in
        match parse_interval () with
        | Some _ -> raise (Out "nested quantifier")
        | None -> pos := s
      end;
      node
  and parse_atom () =
    let c = peek () in
    if c = Char.code '(' then begin
      incr pos;
      let cap =
        if peek () = Char.code '?' then begin
          if !pos + 1 < n && pat.[!pos + 1] = ':' then (pos := !pos + 2; None)
          else raise (Out "(? group")
        end else if peek () = Char.code '*' then raise (Out "(* verb")
        else (incr ncap; Some !ncap) in
      let body = parse_alt () in
      if eof () then raise (Invalid err_end_pattern_unmatched_paren);
      incr pos; (* ')' *)
      match cap with Some k -> Group (k, body) | None -> body
    end
    else if c = Char.code '[' then (incr pos; parse_cc ())
    else if c = Char.code '.' then (incr pos; Any)
    else if c = Char.code '^' then
      (incr pos; Anchor (if singleline then op_bos else op_bol))
    else if c = Char.code '$' then
      (incr pos; Anchor (if singleline then op_semi_eos else op_eol))
    else if c = Char.code '\\' then begin
      incr pos;
      match parse_escape ~in_cc:false with
      | `C v -> Str (cp_string v)
      | `T (p, ng) -> let cs = new_cset () in add_ctype cs p ng; Cls (finish_cset cs false)
      | `A op -> Anchor op
    end
    else Str (cp_string (read_cp ())) in
  let ast = parse_alt () in
  if not (eof ()) then begin
    (* stopped at ')' at top level *)
    raise (Invalid err_unmatched_close_paren)
  end;
  (ast, !ncap, multiline, !uses_w, !uses_d, !uses_s)

(* ---------------------------------------------------------------- *)
(* Compiler *)

let rec nullable = function
  | Str _ | Any | Cls _ -> false
  | Anchor _ -> true
  | Group (_, b) -> nullable b
  | Cat l -> List.for_all nullable l
  | Alt l -> List.exists nullable l
  | Rep (b, lo, _, _) -> lo = 0 || nullable b

let max_code = 200_000

let compile ~syntax ~options pat =
  let ast, ncap, multiline, uses_w, uses_d, uses_s = parse ~syntax ~options pat in
  let code = ref (Array.make 64 0) and len = ref 0 in
  let emit x =
    if !len >= Array.length !code then begin
      if !len >= max_code then raise (Out "expansion too large");
      let a = Array.make (2 * !len) 0 in Array.blit !code 0 a 0 !len; code := a
    end;
    !code.(!len) <- x; incr len in
  let patch at v = !code.(at) <- v in
  let strs = ref [] and nstr = ref 0 in
  let clss = ref [] and ncls = ref 0 in
  let nempty = ref 0 in
  let add_str s = strs := s :: !strs; incr nstr; !nstr - 1 in
  let add_cls c = clss := c :: !clss; incr ncls; !ncls - 1 in
  (* flatten literal runs *)
  let rec comp = function
    | Str s ->
      if String.length s = 1 then (emit op_char; emit (Char.code s.[0]))
      else (emit op_str; emit (add_str s))
    | Any -> emit (if multiline then op_anyml else op_any)
    | Cls c -> emit op_cls; emit (add_cls c)
    | Anchor op -> emit op
    | Group (k, b) -> emit op_save_start; emit k; comp b; emit op_save_end; emit k
    | Cat l -> comp_cat l
    | Alt l ->
      (* SPLIT L2; b1; JMP end; L2: SPLIT L3; b2; JMP end; ... ; bn; end: *)
      let jumps = ref [] in
      let rec go = function
        | [] -> ()
        | [b] -> comp b
        | b :: t ->
          emit op_split; let at = !len in emit 0;
          comp b;
          emit op_jmp; jumps := !len :: !jumps; emit 0;
          patch at !len;
          go t in
      go l;
      List.iter (fun j -> patch j !len) !jumps
    | Rep (b, lo, up, greedy) ->
      let start_len = !len in
      for _ = 1 to lo do comp b done;
      ignore start_len;
      if up < 0 then begin
        let chk = nullable b in
        if greedy then begin
          (* L: SPLIT exit; [ES s] b [EE s]; JMP L; exit: *)
          let l = !len in
          emit op_split; let at = !len in emit 0;
          if chk then (emit op_empty_start; emit !nempty);
          let slot = !nempty in
          if chk then incr nempty;
          comp b;
          if chk then (emit op_empty_end; emit slot);
          emit op_jmp; emit l;
          patch at !len
        end else begin
          (* JMP L2; L1: [ES] b [EE]; L2: SPLIT L1 *)
          emit op_jmp; let at = !len in emit 0;
          let l1 = !len in
          if chk then (emit op_empty_start; emit !nempty);
          let slot = !nempty in
          if chk then incr nempty;
          comp b;
          if chk then (emit op_empty_end; emit slot);
          patch at !len;
          emit op_split; emit l1
        end
      end else begin
        let k = up - lo in
        if greedy then begin
          (* SPLIT exit; b; SPLIT exit; b; ... exit: *)
          let ats = ref [] in
          for _ = 1 to k do
            emit op_split; ats := !len :: !ats; emit 0; comp b
          done;
          List.iter (fun a -> patch a !len) !ats
        end else begin
          (* SPLIT B; JMP exit; B: b; SPLIT B'; JMP exit; B': b ... exit: *)
          let jmps = ref [] in
          for _ = 1 to k do
            emit op_split; let at = !len in emit 0;
            emit op_jmp; jmps := !len :: !jmps; emit 0;
            patch at !len; comp b
          done;
          List.iter (fun a -> patch a !len) !jmps
        end
      end
  and comp_cat l =
    (* merge adjacent Str *)
    let rec go = function
      | Str a :: Str b :: t -> go (Str (a ^ b) :: t)
      | x :: t -> comp x; go t
      | [] -> () in
    go l in
  comp ast;
  emit op_match;
  let code = Array.sub !code 0 !len in
  { code; strs = Array.of_list (List.rev !strs); clss = Array.of_list (List.rev !clss);
    ncap; nempty = !nempty; uses_w; uses_d; uses_s;
    stack = Array.make 1024 0; caps = Array.make (2 * (ncap + 1)) (-1);
    empty = Array.make (max 1 !nempty) (-1) }

(* classification of a (prog, options, subject) case: the ASCII rule *)
let is_ascii s =
  let r = ref true in
  String.iter (fun c -> if Char.code c >= 0x80 then r := false) s; !r

let ascii_ok p ~options subject =
  let need = (p.uses_w && options land opt_word_ascii = 0)
             || (p.uses_d && options land opt_digit_ascii = 0)
             || (p.uses_s && options land opt_space_ascii = 0) in
  (not need) || is_ascii subject

(* ---------------------------------------------------------------- *)
(* Matcher *)

let cls_match c cp =
  let m =
    if cp < 128 then Bytes.unsafe_get c.ascii cp <> '\000'
    else begin
      let r = c.ranges in
      let n = Array.length r in
      let i = ref 0 and found = ref false in
      while not !found && !i < n do
        if cp >= Array.unsafe_get r !i && cp <= Array.unsafe_get r (!i + 1) then found := true;
        i := !i + 2
      done;
      !found
    end in
  m <> c.neg

let grow p =
  let s = p.stack in
  let a = Array.make (2 * Array.length s) 0 in
  Array.blit s 0 a 0 (Array.length s);
  p.stack <- a

(* Stack entries are 4 ints: tag, x, y, z.
   tag 0: alternative (x = pc, y = pos)
   tag 1: capture restore (x = group, y = old start, z = old end)
   tag 2: empty-check restore (x = slot, y = old value) *)

(* Run at position [s]; returns end position, -1 (no match), or -17.
   [retries] is the per-match counter; limit 0 = unlimited. *)
let match_at p (str : string) ~notbol ~noteol ~limit s0 =
  let code = p.code and caps = p.caps and empty = p.empty in
  let endp = String.length str in
  Array.fill caps 0 (Array.length caps) (-1);
  caps.(0) <- s0;
  let sp = ref 0 in
  let retries = ref 0 in
  let pc = ref 0 and s = ref s0 in
  let result = ref (-2) in
  while !result = -2 do
    let op = Array.unsafe_get code !pc in
    let ok =
      if op = op_char then begin
        if !s < endp && Char.code (String.unsafe_get str !s) = Array.unsafe_get code (!pc + 1)
        then (incr s; pc := !pc + 2; true) else false
      end
      else if op = op_str then begin
        let lit = Array.unsafe_get p.strs (Array.unsafe_get code (!pc + 1)) in
        let l = String.length lit in
        if !s + l <= endp then begin
          let i = ref 0 in
          while !i < l && String.unsafe_get str (!s + !i) = String.unsafe_get lit !i do incr i done;
          if !i = l then (s := !s + l; pc := !pc + 2; true) else false
        end else false
      end
      else if op = op_cls then begin
        if !s < endp then begin
          let c = Char.code (String.unsafe_get str !s) in
          let l = enc_len c in
          if !s + l > endp then false
          else begin
            let cp =
              if l = 1 then c
              else begin
                let v = ref (c land ((1 lsl (7 - l)) - 1)) in
                for i = 1 to l - 1 do
                  v := (!v lsl 6) lor (Char.code (String.unsafe_get str (!s + i)) land 0x3f)
                done; !v
              end in
            if cls_match (Array.unsafe_get p.clss (Array.unsafe_get code (!pc + 1))) cp
            then (s := !s + l; pc := !pc + 2; true) else false
          end
        end else false
      end
      else if op = op_split then begin
        if !sp + 4 > Array.length p.stack then grow p;
        let st = p.stack in
        Array.unsafe_set st !sp 0;
        Array.unsafe_set st (!sp + 1) (Array.unsafe_get code (!pc + 1));
        Array.unsafe_set st (!sp + 2) !s;
        sp := !sp + 4;
        pc := !pc + 2; true
      end
      else if op = op_jmp then (pc := Array.unsafe_get code (!pc + 1); true)
      else if op = op_any || op = op_anyml then begin
        if !s < endp then begin
          let c = Char.code (String.unsafe_get str !s) in
          let l = enc_len c in
          if !s + l > endp || (op = op_any && c = 10) then false
          else (s := !s + l; incr pc; true)
        end else false
      end
      else if op = op_save_start then begin
        let k = Array.unsafe_get code (!pc + 1) in
        if !sp + 4 > Array.length p.stack then grow p;
        let st = p.stack in
        Array.unsafe_set st !sp 1;
        Array.unsafe_set st (!sp + 1) k;
        Array.unsafe_set st (!sp + 2) caps.(2 * k);
        Array.unsafe_set st (!sp + 3) caps.(2 * k + 1);
        sp := !sp + 4;
        caps.(2 * k) <- !s; caps.(2 * k + 1) <- -1;
        pc := !pc + 2; true
      end
      else if op = op_save_end then begin
        caps.(2 * Array.unsafe_get code (!pc + 1) + 1) <- !s; pc := !pc + 2; true
      end
      else if op = op_empty_start then begin
        let k = Array.unsafe_get code (!pc + 1) in
        if !sp + 4 > Array.length p.stack then grow p;
        let st = p.stack in
        Array.unsafe_set st !sp 2;
        Array.unsafe_set st (!sp + 1) k;
        Array.unsafe_set st (!sp + 2) empty.(k);
        sp := !sp + 4;
        empty.(k) <- !s; pc := !pc + 2; true
      end
      else if op = op_empty_end then begin
        let k = Array.unsafe_get code (!pc + 1) in
        if empty.(k) = !s then pc := !pc + 4 (* skip JMP/SPLIT *)
        else pc := !pc + 2;
        true
      end
      else if op = op_bol then begin
        if !s = 0 then (if notbol then false else (incr pc; true))
        else if !s < endp && String.unsafe_get str (!s - 1) = '\n' then (incr pc; true)
        else false
      end
      else if op = op_eol then begin
        if !s = endp then (if noteol then false else (incr pc; true))
        else if String.unsafe_get str !s = '\n' then (incr pc; true)
        else false
      end
      else if op = op_bos then
        (if !s = 0 && not notbol then (incr pc; true) else false)
      else if op = op_eos then
        (if !s = endp && not noteol then (incr pc; true) else false)
      else if op = op_semi_eos then begin
        if !s = endp then (if noteol then false else (incr pc; true))
        else if String.unsafe_get str !s = '\n' && !s + 1 = endp then
          (if noteol then false else (incr pc; true))
        else false
      end
      else if op = op_match then begin
        caps.(1) <- !s; result := !s; true
      end
      else assert false in
    if not ok then begin
      (* backtrack: pop until an alternative *)
      let st = p.stack in
      let found = ref false in
      while not !found && !sp > 0 do
        sp := !sp - 4;
        let tag = Array.unsafe_get st !sp in
        if tag = 0 then begin
          pc := Array.unsafe_get st (!sp + 1);
          s := Array.unsafe_get st (!sp + 2);
          found := true
        end else if tag = 1 then begin
          let k = Array.unsafe_get st (!sp + 1) in
          caps.(2 * k) <- Array.unsafe_get st (!sp + 2);
          caps.(2 * k + 1) <- Array.unsafe_get st (!sp + 3)
        end else
          empty.(Array.unsafe_get st (!sp + 1)) <- Array.unsafe_get st (!sp + 2)
      done;
      if not !found then result := -1
      else begin
        incr retries;
        if limit <> 0 && !retries >= limit then result := err_retry_limit
      end
    end
  done;
  !result

(* Search like onig_search: forward when range >= start (positions
   start..range inclusive), backward otherwise.  Returns the match start,
   -1 (ONIG_MISMATCH) or -17.  On a match, caps holds the region. *)
let search p str ~start ~range ~sopt ~limit =
  let notbol = sopt land opt_notbol <> 0 and noteol = sopt land opt_noteol <> 0 in
  let endp = String.length str in
  if start > endp || start < 0 then -1
  else if range >= start then begin
    let range = min range endp in
    let s = ref start and r = ref (-1) and fin = ref false in
    while not !fin do
      let e = match_at p str ~notbol ~noteol ~limit !s in
      if e >= 0 then (r := !s; fin := true)
      else if e <> -1 then (r := e; fin := true)
      else if !s >= range then fin := true
      else s := !s + enc_len (Char.code (String.unsafe_get str !s))
    done;
    !r
  end else begin
    let s = ref start and r = ref (-1) and fin = ref false in
    while not !fin do
      let e = match_at p str ~notbol ~noteol ~limit !s in
      if e >= 0 then (r := !s; fin := true)
      else if e <> -1 then (r := e; fin := true)
      else if !s <= range || !s = 0 then fin := true
      else begin
        (* previous character head *)
        let t = ref (!s - 1) in
        while !t > 0 && Char.code (String.unsafe_get str !t) land 0xc0 = 0x80 do decr t done;
        s := !t
      end
    done;
    !r
  end

(* onig_match: returns the match length, -1 or -17 *)
let match_ p str ~at ~sopt ~limit =
  let notbol = sopt land opt_notbol <> 0 and noteol = sopt land opt_noteol <> 0 in
  if at < 0 || at > String.length str then -1
  else
    let e = match_at p str ~notbol ~noteol ~limit at in
    if e >= 0 then e - at else e

let ncap p = p.ncap
let cap_beg p k = if p.caps.(2 * k + 1) < 0 then -1 else p.caps.(2 * k)
let cap_end p k = if p.caps.(2 * k + 1) < 0 then -1 else p.caps.(2 * k + 1)
