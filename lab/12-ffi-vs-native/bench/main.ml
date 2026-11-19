(* Experiment #12 harness.  One executable; the engine is chosen on the
   command line.  Every engine is a module of signature ENGINE, so an
   extracted VM (issue #22) is one more column.

   Commands (all output is free of paths and host names):
     classify WORK OUT COVERAGE     run the subset classifier on a work file
     agree ENGINE WORK               result, span and captures per case
     time ENGINE WORK MINSEC         short-subject timing (one run)
     scan ENGINE SUBJECT WORK PID MINSEC   large-subject find-all scan timing
     cata ENGINE SYNTAX OPTIONS HEXPAT N LIMIT   catastrophic pattern, one run
     alloc ENGINE N                  allocation check around N bare searches
     tests CASES                     VM on the selected test_utf8.c cases *)

module type ENGINE = sig
  type t
  val name : string
  (* Error code: Oniguruma's compile error, or 1 = out of subset /
     unsupported by this engine *)
  val compile : syntax:int -> options:int -> limit:int -> stack_limit:int ->
    string -> (t, int) result
  val search : t -> string -> start:int -> range:int -> sopt:int -> int
  val match_ : t -> string -> at:int -> sopt:int -> int
  val nregs : t -> int
  val beg : t -> int -> int
  val end_ : t -> int -> int
end

module Vm_engine : ENGINE = struct
  type t = { p : Vm.prog; limit : int }
  let name = "vm"
  let compile ~syntax ~options ~limit ~stack_limit:_ pat =
    match Vm.compile ~syntax ~options pat with
    | p -> Ok { p; limit }
    | exception Vm.Out _ -> Error 1
    | exception Vm.Invalid c -> Error c
  let search t s ~start ~range ~sopt = Vm.search t.p s ~start ~range ~sopt ~limit:t.limit
  let match_ t s ~at ~sopt = Vm.match_ t.p s ~at ~sopt ~limit:t.limit
  let nregs t = Vm.ncap t.p + 1
  let beg t k = Vm.cap_beg t.p k
  let end_ t k = Vm.cap_end t.p k
end

module Stubs_engine : ENGINE = struct
  type t = Onig.h
  let name = "stubs"
  let compile ~syntax ~options ~limit ~stack_limit pat =
    Onig.compile ~syntax ~options ~limit ~stack_limit pat
  let search h s ~start ~range ~sopt = Onig.search h s start range sopt
  let match_ h s ~at ~sopt = Onig.match_ h s at sopt
  let nregs = Onig.nregs
  let beg = Onig.region_beg
  let end_ = Onig.region_end
end

module Ctypes_engine : ENGINE = struct
  type t = Onig_ctypes.t
  let name = "ctypes"
  let compile ~syntax ~options ~limit ~stack_limit pat =
    Result.map Onig_ctypes.of_onig (Onig.compile ~syntax ~options ~limit ~stack_limit pat)
  let search t s ~start ~range ~sopt = Onig_ctypes.search t s ~start ~range ~opt:sopt
  let match_ t s ~at ~sopt = Onig_ctypes.match_ t s ~at ~opt:sopt
  let nregs = Onig_ctypes.nregs
  let beg = Onig_ctypes.beg
  let end_ = Onig_ctypes.end_
end

(* ocaml-re: reference only, on the cases it can express (Re.Perl syntax,
   byte semantics: '.' and classes match bytes, not UTF-8 characters;
   leftmost-first; no retry budget). *)
module Re_engine : ENGINE = struct
  type t = { re : Re.re; mutable g : Re.Group.t option }
  let name = "re"
  let compile ~syntax:_ ~options ~limit:_ ~stack_limit:_ pat =
    try
      let opts = (if options land Vm.opt_multiline = 0 then [] else [`Dotall])
                 @ [`Multiline] in
      Ok { re = Re.compile (Re.Perl.re ~opts pat); g = None }
    with _ -> Error 1
  let search t s ~start ~range ~sopt:_ =
    if range < start then -1
    else match Re.exec_opt ~pos:start t.re s with
      | Some g when Re.Group.start g 0 <= range ->
        t.g <- Some g; Re.Group.start g 0
      | _ -> -1
  let match_ t s ~at ~sopt:_ =
    match Re.exec_opt ~pos:at t.re s with
    | Some g when Re.Group.start g 0 = at -> t.g <- Some g; Re.Group.stop g 0 - at
    | _ -> -1
  let nregs t = match t.g with Some g -> Re.Group.nb_groups g | None -> 0
  let beg t k = match t.g with
    | Some g -> (match Re.Group.offset g k with (a, _) -> a | exception Not_found -> -1)
    | None -> -1
  let end_ t k = match t.g with
    | Some g -> (match Re.Group.offset g k with (_, b) -> b | exception Not_found -> -1)
    | None -> -1
end

let engine_of = function
  | "vm" -> (module Vm_engine : ENGINE)
  | "stubs" -> (module Stubs_engine : ENGINE)
  | "ctypes" -> (module Ctypes_engine : ENGINE)
  | "re" -> (module Re_engine : ENGINE)
  | e -> failwith ("unknown engine " ^ e)

(* ---------------------------------------------------------------- *)
(* Work files *)

let unhex h =
  let n = String.length h / 2 in
  String.init n (fun i -> Char.chr (int_of_string ("0x" ^ String.sub h (2 * i) 2)))

type pat = { pid : int; syntax : int; options : int; limit : int; stack_limit : int;
             pattern : string }
type case = { cid : int; cpid : int; sid : int; kind : int; start : int; range : int;
              sopt : int; weight : int }

let read_work file =
  let pats = Hashtbl.create 97 and subs = Hashtbl.create 97 and cases = ref [] in
  let ic = open_in_bin file in
  (try while true do
       let l = input_line ic in
       match String.split_on_char ' ' l with
       | ["P"; pid; sy; op; li; sl; hx] ->
         let pid = int_of_string pid in
         Hashtbl.replace pats pid
           { pid; syntax = int_of_string sy; options = int_of_string op;
             limit = int_of_string li; stack_limit = int_of_string sl; pattern = unhex hx }
       | ["P"; pid; sy; op; li; sl] ->
         let pid = int_of_string pid in
         Hashtbl.replace pats pid
           { pid; syntax = int_of_string sy; options = int_of_string op;
             limit = int_of_string li; stack_limit = int_of_string sl; pattern = "" }
       | ["S"; sid; hx] -> Hashtbl.replace subs (int_of_string sid) (unhex hx)
       | ["S"; sid] -> Hashtbl.replace subs (int_of_string sid) ""
       | ["C"; cid; pid; sid; k; st; rg; so; w] ->
         cases := { cid = int_of_string cid; cpid = int_of_string pid;
                    sid = int_of_string sid; kind = int_of_string k;
                    start = int_of_string st; range = int_of_string rg;
                    sopt = int_of_string so; weight = int_of_string w } :: !cases
       | _ -> if l <> "" && l.[0] <> '#' then failwith ("bad line: " ^ l)
     done with End_of_file -> ());
  close_in ic;
  (pats, subs, Array.of_list (List.rev !cases))

let hex s = String.concat "" (List.init (String.length s) (fun i -> Printf.sprintf "%02x" (Char.code s.[i])))

(* ---------------------------------------------------------------- *)
(* classify *)

let classify work out cov =
  let pats, subs, cases = read_work work in
  let oc = open_out_bin out and cc = open_out_bin cov in
  let status = Hashtbl.create 97 in
  Hashtbl.iter (fun pid p ->
      let st =
        match Vm.compile ~syntax:p.syntax ~options:p.options p.pattern with
        | pr -> `Valid pr
        | exception Vm.Out r -> `Out r
        | exception Vm.Invalid c -> `Invalid c in
      Hashtbl.replace status pid st) pats;
  let used_p = Hashtbl.create 97 and used_s = Hashtbl.create 97 in
  let kept = ref [] in
  Array.iter (fun c ->
      let p = Hashtbl.find pats c.cpid in
      let s = Hashtbl.find subs c.sid in
      let st, reason = match Hashtbl.find status c.cpid with
        | `Valid pr ->
          if c.sopt land lnot Vm.allowed_search_options <> 0 then "out", "search-option"
          else if not (Vm.ascii_ok pr ~options:p.options s) then "out", "unicode-ctype-on-non-ascii-subject"
          else "valid", "-"
        | `Out r -> "out", String.map (fun ch -> if ch = ' ' then '_' else ch) r
        | `Invalid code -> "invalid", string_of_int code in
      Printf.fprintf cc "%d %d %s %s\n" c.cid c.cpid st reason;
      if st = "valid" then begin
        Hashtbl.replace used_p c.cpid (); Hashtbl.replace used_s c.sid ();
        kept := c :: !kept
      end) cases;
  let ps = List.sort compare (Hashtbl.fold (fun k () a -> k :: a) used_p []) in
  List.iter (fun pid -> let p = Hashtbl.find pats pid in
              Printf.fprintf oc "P %d %d %d %d %d %s\n" pid p.syntax p.options p.limit
                p.stack_limit (hex p.pattern)) ps;
  let ss = List.sort compare (Hashtbl.fold (fun k () a -> k :: a) used_s []) in
  List.iter (fun sid -> Printf.fprintf oc "S %d %s\n" sid (hex (Hashtbl.find subs sid))) ss;
  List.iter (fun c -> Printf.fprintf oc "C %d %d %d %d %d %d %d %d\n" c.cid c.cpid c.sid
                c.kind c.start c.range c.sopt c.weight) (List.rev !kept);
  close_out oc; close_out cc

(* ---------------------------------------------------------------- *)
(* Compiled workload *)

type 'a ccase = { e : 'a; subj : string; c : case }

let load (type a) (module E : ENGINE with type t = a) work =
  let pats, subs, cases = read_work work in
  let compiled = Hashtbl.create 97 in
  let get pid =
    match Hashtbl.find_opt compiled pid with
    | Some r -> r
    | None ->
      let p = Hashtbl.find pats pid in
      let r = E.compile ~syntax:p.syntax ~options:p.options ~limit:p.limit
          ~stack_limit:p.stack_limit p.pattern in
      Hashtbl.replace compiled pid r; r in
  Array.map (fun c -> (get c.cpid, Hashtbl.find subs c.sid, c)) cases

let agree eng work =
  let module E = (val engine_of eng) in
  let cases = load (module E) work in
  Array.iter (fun (r, subj, c) ->
      match r with
      | Error code -> Printf.printf "%d CERR %d\n" c.cid code
      | Ok e ->
        let res = if c.kind = 0 then E.search e subj ~start:c.start ~range:c.range ~sopt:c.sopt
          else E.match_ e subj ~at:c.start ~sopt:c.sopt in
        if res >= 0 then begin
          let n = E.nregs e in
          let b = Buffer.create 64 in
          for k = 0 to n - 1 do Printf.bprintf b " %d %d" (E.beg e k) (E.end_ e k) done;
          Printf.printf "%d %d %d%s\n" c.cid res n (Buffer.contents b)
        end else Printf.printf "%d %d\n" c.cid res) cases

let now () = Mtime_clock.now_ns ()

let time eng work minsec =
  let module E = (val engine_of eng) in
  let cases = load (module E) work in
  let ok = Array.of_list (List.filter_map (fun (r, s, c) ->
      match r with Ok e -> Some { e; subj = s; c } | Error _ -> None) (Array.to_list cases)) in
  let skipped = Array.length cases - Array.length ok in
  let sink = ref 0 in
  let pass () =
    for i = 0 to Array.length ok - 1 do
      let x = Array.unsafe_get ok i in
      let c = x.c in
      for _ = 1 to c.weight do
        let r = if c.kind = 0 then E.search x.e x.subj ~start:c.start ~range:c.range ~sopt:c.sopt
          else E.match_ x.e x.subj ~at:c.start ~sopt:c.sopt in
        sink := !sink + r
      done
    done in
  let calls_per_pass = Array.fold_left (fun a x -> a + x.c.weight) 0 ok in
  pass ();                                    (* warm-up, untimed *)
  let minor0 = Gc.minor_words () and major0 = (Gc.quick_stat ()).Gc.major_words in
  let t0 = now () in
  let passes = ref 0 in
  let limit = Int64.of_float (minsec *. 1e9) in
  while Int64.sub (now ()) t0 < limit do pass (); incr passes done;
  let t1 = now () in
  let minor1 = Gc.minor_words () and major1 = (Gc.quick_stat ()).Gc.major_words in
  let calls = !passes * calls_per_pass in
  let ns = Int64.to_float (Int64.sub t1 t0) in
  Printf.printf "engine=%s cases=%d skipped=%d calls_per_pass=%d passes=%d sec=%.6f ns_per_call=%.3f minor_per_call=%.4f major_per_call=%.4f sink=%d\n"
    E.name (Array.length ok) skipped calls_per_pass !passes (ns /. 1e9)
    (ns /. float calls) ((minor1 -. minor0) /. float calls)
    ((major1 -. major0) /. float calls) (!sink land 1)

let read_file f =
  let ic = open_in_bin f in
  let n = in_channel_length ic in
  let s = really_input_string ic n in close_in ic; s

(* find-all: search, restart at the match end, or one character further
   after an empty match *)
let scan eng subj_file work pid minsec =
  let module E = (val engine_of eng) in
  let pats, _, _ = read_work work in
  let p = Hashtbl.find pats pid in
  let subj = read_file subj_file in
  let n = String.length subj in
  match E.compile ~syntax:p.syntax ~options:p.options ~limit:p.limit
          ~stack_limit:p.stack_limit p.pattern with
  | Error code -> Printf.printf "engine=%s pid=%d CERR %d\n" E.name pid code
  | Ok e ->
    let one () =
      let s = ref 0 and m = ref 0 and err = ref 0 in
      while !s <= n do
        let r = E.search e subj ~start:!s ~range:n ~sopt:0 in
        if r >= 0 then begin
          incr m;
          let fin = E.end_ e 0 in
          s := if fin > r then fin
            else if r < n then r + Vm.enc_len (Char.code subj.[r]) else n + 1
        end else begin
          if r <> -1 then err := r;
          s := n + 1
        end
      done;
      (!m, !err) in
    let (m, err) = one () in            (* warm-up, untimed *)
    let minor0 = Gc.minor_words () and major0 = (Gc.quick_stat ()).Gc.major_words in
    let t0 = now () in
    let scans = ref 0 in
    let limit = Int64.of_float (minsec *. 1e9) in
    while !scans = 0 || Int64.sub (now ()) t0 < limit do ignore (one ()); incr scans done;
    let t1 = now () in
    let minor1 = Gc.minor_words () and major1 = (Gc.quick_stat ()).Gc.major_words in
    let sec = Int64.to_float (Int64.sub t1 t0) /. 1e9 /. float !scans in
    Printf.printf "engine=%s pid=%d bytes=%d matches=%d err=%d scans=%d sec_per_scan=%.6f bytes_per_sec=%.1f minor_per_match=%.4f major_per_match=%.4f\n"
      E.name pid n m err !scans sec (float n /. sec)
      ((minor1 -. minor0) /. float (max 1 (m * !scans)))
      ((major1 -. major0) /. float (max 1 (m * !scans)))

let cata eng syntax options hexpat len limit =
  let module E = (val engine_of eng) in
  let subj = String.make len 'a' ^ "!" in
  match E.compile ~syntax ~options ~limit ~stack_limit:0 (unhex hexpat) with
  | Error code -> Printf.printf "engine=%s n=%d CERR %d\n" E.name len code
  | Ok e ->
    let t0 = now () in
    let r = E.search e subj ~start:0 ~range:(String.length subj) ~sopt:0 in
    let t1 = now () in
    let outcome = if r >= 0 then "match" else if r = -1 then "nomatch"
      else if r = -17 then "limit" else string_of_int r in
    Printf.printf "engine=%s n=%d result=%d outcome=%s sec=%.6f\n" E.name len r outcome
      (Int64.to_float (Int64.sub t1 t0) /. 1e9)

(* criterion 1: allocation around N bare calls, minus an empty loop *)
let alloc eng n =
  let module E = (val engine_of eng) in
  let subj = "xxxxxxxx foo123 bar" in
  match E.compile ~syntax:1 ~options:0 ~limit:10_000_000 ~stack_limit:0 "([a-z]+)(\\d+)" with
  | Error _ -> print_endline "compile error"
  | Ok e ->
    let len = String.length subj in
    let measure f =
      let m0 = Gc.minor_words () and j0 = (Gc.quick_stat ()).Gc.major_words in
      f ();
      let m1 = Gc.minor_words () and j1 = (Gc.quick_stat ()).Gc.major_words in
      (m1 -. m0, j1 -. j0) in
    let sink = ref 0 in
    ignore (E.search e subj ~start:0 ~range:len ~sopt:0);   (* warm-up: stack sized *)
    let em, ej = measure (fun () -> for _ = 1 to n do sink := !sink + 1 done) in
    let fm, fj = measure (fun () ->
        for _ = 1 to n do sink := !sink + E.search e subj ~start:0 ~range:len ~sopt:0 done) in
    Printf.printf "engine=%s n=%d minor_delta=%.0f major_delta=%.0f empty_minor=%.0f empty_major=%.0f minor_per_call=%.4f major_per_call=%.4f result=%d span=%d-%d\n"
      E.name n (fm -. em) (fj -. ej) em ej ((fm -. em) /. float n) ((fj -. ej) /. float n)
      (E.search e subj ~start:0 ~range:len ~sopt:0) (E.beg e 0) (E.end_ e 0)

(* test_utf8.c cases: lines "line kind hexpat hexsubj a b c" with kind
   x2 (a=from b=to), x3 (a=from b=to c=mem), n, e (a=error) *)
let tests file =
  let ic = open_in_bin file in
  let pass = ref 0 and total = ref 0 in
  (try while true do
       let l = input_line ic in
       match String.split_on_char ' ' l with
       | [line; kind; hp; hs; a; b; c] ->
         incr total;
         let pat = unhex hp and s = unhex hs in
         let a = int_of_string a and b = int_of_string b and c = int_of_string c in
         let verdict =
           match Vm.compile ~syntax:0 ~options:0 pat with
           | exception Vm.Out r -> Printf.sprintf "FAIL out-of-subset %s" r
           | exception Vm.Invalid code ->
             if kind = "e" && code = a then "ok"
             else Printf.sprintf "FAIL compile-error %d" code
           | p when not (Vm.ascii_ok p ~options:0 s) ->
             "FAIL out-of-subset unicode-ctype-on-non-ascii-subject"
           | p ->
             if kind = "e" then Printf.sprintf "FAIL expected-error %d" a
             else begin
               let r = Vm.search p s ~start:0 ~range:(String.length s) ~sopt:0 ~limit:0 in
               match kind with
               | "n" -> if r = -1 then "ok" else Printf.sprintf "FAIL matched %d" r
               | "x2" | "x3" ->
                 let k = if kind = "x3" then c else 0 in
                 if r < 0 then Printf.sprintf "FAIL nomatch %d" r
                 else if k > Vm.ncap p then "FAIL no-such-group"
                 else let bb = Vm.cap_beg p k and ee = Vm.cap_end p k in
                   if bb = a && ee = b then "ok"
                   else Printf.sprintf "FAIL got %d-%d" bb ee
               | _ -> "FAIL kind"
             end in
         if verdict = "ok" then incr pass;
         Printf.printf "%s %s %s\n" line kind verdict
       | _ -> ()
     done with End_of_file -> ());
  Printf.printf "RESULT passed=%d total=%d\n" !pass !total

(* large-subject candidates: per pattern, is it in the subset for this
   subject (ASCII rule), and is it anchored at the start (\\A, or ^ under
   SINGLELINE), which cannot scan *)
let largeok subj_file work =
  let pats, _, _ = read_work work in
  let subj = read_file subj_file in
  let l = List.sort compare (Hashtbl.fold (fun k _ a -> k :: a) pats []) in
  List.iter (fun pid ->
      let p = Hashtbl.find pats pid in
      let st = match Vm.compile ~syntax:p.syntax ~options:p.options p.pattern with
        | exception _ -> "out"
        | pr ->
          if pr.Vm.code.(0) = Vm.op_bos then "anchored"
          else if Vm.ascii_ok pr ~options:p.options subj then "valid" else "out-ascii" in
      Printf.printf "%d %s\n" pid st) l

let () =
  match Array.to_list Sys.argv |> List.tl with
  | ["largeok"; s; w] -> largeok s w
  | ["classify"; w; o; c] -> classify w o c
  | ["agree"; e; w] -> Onig.init (); agree e w
  | ["time"; e; w; m] -> Onig.init (); time e w (float_of_string m)
  | ["scan"; e; s; w; p; m] -> Onig.init (); scan e s w (int_of_string p) (float_of_string m)
  | ["cata"; e; sy; op; hp; n; li] ->
    Onig.init ();
    cata e (int_of_string sy) (int_of_string op) hp (int_of_string n) (int_of_string li)
  | ["alloc"; e; n] -> Onig.init (); alloc e (int_of_string n)
  | ["tests"; f] -> tests f
  | _ -> prerr_endline "usage: see header"; exit 2
