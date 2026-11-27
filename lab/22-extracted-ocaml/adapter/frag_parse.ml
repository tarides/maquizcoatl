(* Issue #22 (experiment #12 follow-up): OCaml port of [recognise] from
   lab/09-representative-proof/cases/select.py, unverified.  It reads
   pattern bytes as experiment #9's fragment syntax (literals,
   concatenation, |, greedy *, plain capture groups) and returns the
   AST and the number of groups, or raises [Out reason] with the same
   reason strings as the Python original.  Runs in ENGINE.compile, never
   inside a timed region.  Checked against the original by x22.exe
   astcheck (experiment #9's case files) and astwork (every admitted
   workload pattern). *)

type ast =
  | E                       (* empty *)
  | L of int                (* one ASCII byte *)
  | Cat of ast * ast        (* right-nested *)
  | Alt of ast * ast        (* right-nested *)
  | Star of ast             (* greedy *)
  | G of int * ast          (* capture group k >= 1 *)

exception Out of string

let is_meta c = String.contains "\\()|*+?{}[].^$" (Char.chr c)
let is_hex c = String.contains "0123456789abcdefABCDEF" (Char.chr c)
let is_oct c = c >= 0x30 && c <= 0x37
let is_alnum c =
  (c >= 0x30 && c <= 0x39) || (c >= 0x41 && c <= 0x5a) || (c >= 0x61 && c <= 0x7a)

(* items of a concatenation: one atom, or several literals (\x{..} with
   several code points) *)
type item = One of ast | Seq of ast list

let recognise (p : string) : ast * int =
  let n = String.length p in
  let at k = Char.code (String.unsafe_get p k) in
  let i = ref 0 and ncap = ref 0 in
  let rec atom () =
    let c = at !i in
    if c = 0x28 then begin
      if !i + 1 < n && at (!i + 1) = 0x3f then raise (Out "(? group");
      if !i + 1 < n && at (!i + 1) = 0x2a then raise (Out "(* verb");
      incr i;
      incr ncap;
      let k = !ncap in
      let body = alt () in
      if !i >= n || at !i <> 0x29 then raise (Out "unbalanced parenthesis");
      incr i;
      One (G (k, body))
    end else if c = 0x5c then begin
      if !i + 1 >= n then raise (Out "trailing backslash");
      let e = at (!i + 1) in
      if is_meta e || String.contains "/-&<>" (Char.chr e) then begin
        i := !i + 2; One (L e)
      end else if (e = 0x78 || e = 0x6f) && !i + 2 < n && at (!i + 2) = 0x7b then begin
        (* \x{H ...}, \o{O ...} (upstream/src/regparse.c:5855-5903) *)
        let digit, width, base = if e = 0x78 then is_hex, 8, 16 else is_oct, 11, 8 in
        let ce = Char.chr e in
        let j = ref (!i + 3) in
        let vs = ref [] in
        let fin = ref false in
        while not !fin do
          let k = !j in
          while !j < n && digit (at !j) do incr j done;
          if !j = k || !j - k > width then raise (Out (Printf.sprintf "malformed \\%c{}" ce));
          let v = int_of_string ((if base = 16 then "0x" else "0o") ^ String.sub p k (!j - k)) in
          vs := v :: !vs;
          if !j < n && at !j = 0x7d then fin := true
          else begin
            if !j >= n || (at !j <> 0x20 && at !j <> 0x0a) then
              raise (Out (Printf.sprintf "malformed \\%c{}" ce));
            while !j < n && (at !j = 0x20 || at !j = 0x0a) do incr j done;
            if !j < n && at !j = 0x7d then fin := true
          end
        done;
        i := !j + 1;
        let vs = List.rev !vs in
        if List.exists (fun v -> v >= 0x80) vs then raise (Out (Printf.sprintf "\\%c{} >= 0x80" ce));
        (match vs with [v] -> One (L v) | _ -> Seq (List.map (fun v -> L v) vs))
      end else if e = 0x78 then begin
        (* \xHH, at most 2 digits *)
        let j = ref (!i + 2) in
        while !j < n && !j < !i + 4 && is_hex (at !j) do incr j done;
        if !j = !i + 2 then raise (Out "malformed \\x");
        let v = int_of_string ("0x" ^ String.sub p (!i + 2) (!j - !i - 2)) in
        i := !j;
        if v >= 0x80 then raise (Out "\\x >= 0x80");
        One (L v)
      end else if e = 0x75 then begin
        (* \uHHHH, exactly 4 digits (regparse.c:5917-5927) *)
        let h = String.sub p (!i + 2) (min 4 (n - !i - 2)) in
        if String.length h <> 4 || not (String.for_all (fun ch -> is_hex (Char.code ch)) h) then
          raise (Out "malformed \\u");
        let v = int_of_string ("0x" ^ h) in
        if v >= 0x80 then raise (Out "\\u >= 0x80");
        i := !i + 6;
        One (L v)
      end else if e = 0x63 || (e = 0x43 && !i + 2 < n && at (!i + 2) = 0x2d) then begin
        (* \cX, \C-X (regparse.c:4772-4801) *)
        let j = ref (if e = 0x63 then !i + 2 else !i + 3) in
        if !j >= n then raise (Out "malformed control escape");
        let x = ref (at !j) in
        if !x = 0x5c then begin
          if !j + 1 >= n || at (!j + 1) >= 0x80 || is_alnum (at (!j + 1)) then
            raise (Out "control escape over an escape");
          incr j;
          x := at !j
        end else if !x >= 0x80 then raise (Out "non-ASCII control escape");
        i := !j + 1;
        One (L (if !x = 0x3f then 0x7f else !x land 0x9f))
      end else raise (Out ("escape \\" ^ String.make 1 (Char.chr e)))
    end else begin
      if c >= 0x80 then raise (Out "non-ASCII byte");
      if c = 0x2b || c = 0x3f || c = 0x7b then raise (Out (String.make 1 (Char.chr c)));
      if c = 0x7d || c = 0x5d then
        raise (Out (String.make 1 (Char.chr c) ^ " (literal, left out conservatively)"));
      if c = 0x5b then raise (Out "character class");
      if c = 0x2e then raise (Out "anychar");
      if c = 0x5e || c = 0x24 then raise (Out "anchor");
      incr i;
      One (L c)
    end
  and cat () =
    (* items in reverse order *)
    let items = ref [] in
    while !i < n && at !i <> 0x7c && at !i <> 0x29 do
      if at !i = 0x2a then begin
        match !items with
        | [] -> raise (Out "syntax error")
        | Star _ :: _ -> raise (Out "nested quantifier **")
        | x :: t -> items := Star x :: t; incr i
      end else
        match atom () with
        | One a -> items := a :: !items
        | Seq l ->
          if !i < n && String.contains "*+?{" (Char.chr (at !i)) then
            raise (Out "quantifier after a code point sequence");
          items := List.rev_append l !items
    done;
    match !items with
    | [] -> E
    | last :: before -> List.fold_left (fun r x -> Cat (x, r)) last before
  and alt () =
    let a = cat () in
    if !i < n && at !i = 0x7c then (incr i; Alt (a, alt ())) else a
  in
  let ast = alt () in
  if !i <> n then raise (Out "unbalanced parenthesis");
  (ast, !ncap)

(* experiment #9's s-expression (select.py's sexp) *)
let rec sexp = function
  | E -> "E"
  | L b -> Printf.sprintf "L%02x" b
  | G (k, a) -> Printf.sprintf "(g %d %s)" k (sexp a)
  | Star a -> Printf.sprintf "(* %s)" (sexp a)
  | Cat (a, b) -> Printf.sprintf "(. %s %s)" (sexp a) (sexp b)
  | Alt (a, b) -> Printf.sprintf "(| %s %s)" (sexp a) (sexp b)

(* Fragment context of a workload call (decision 2): syntax ONIGURUMA (0),
   RUBY (1) or PERL_NG (2) under UTF-8 (prep.py writes 8 for any other
   encoding); compile options within the set below; search options
   within NOTBOL | NOTEOL. *)
let allowed_options =
  4 lor 8 lor 64 lor 256 lor 32768 lor 65536 lor 131072 lor 262144 lor 524288
let allowed_search_options = 512 lor 1024
let context_ok ~syntax ~options =
  (syntax = 0 || syntax = 1 || syntax = 2) && options land lnot allowed_options = 0
