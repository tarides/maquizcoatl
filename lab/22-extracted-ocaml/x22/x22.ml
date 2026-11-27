(* Issue #22: checks and measurements that experiment #12's harness has
   no subcommand for.  Output is free of paths and host names.

     astcheck CASES.tsv...          parser port = column 10 (AST) and
                                    column 9 (ncap) of experiment #9's
                                    case files
     astwork WORK AST.tsv           parser port = prep22.py's s-expression
                                    (select.py's recognise) per pattern
     verdicts rocq|fstar CASES.tsv  per-position and search verdicts
                                    through the adapters' match_ and
                                    search, in experiment #9's format
                                    (vm lines only)
     conv rocq|fstar WORK MINSEC    short shape: the per-call conversion
                                    alone, protocol of the harness's time
     conv-subject rocq|fstar SUBJECT   one whole-subject conversion: time,
                                    words, GC settings, heap after it
     cata-fuel rocq|fstar SYNTAX OPTIONS HEXPAT N FUEL
                                    "a"*N "!" searched with a stated fuel
                                    per start position: time until the
                                    first result that is not NoMatch *)

open Extracted22

let unhex h =
  let n = String.length h / 2 in
  String.init n (fun i -> Char.chr (int_of_string ("0x" ^ String.sub h (2 * i) 2)))

let lines file =
  let ic = open_in_bin file in
  let rec go acc = match input_line ic with
    | l -> go (l :: acc)
    | exception End_of_file -> close_in ic; List.rev acc in
  go []

(* ---------------------------------------------------------------- *)

let astcheck files =
  let pass = ref 0 and total = ref 0 in
  List.iter (fun f ->
      List.iter (fun l ->
          let c = Array.of_list (String.split_on_char '\t' l) in
          incr total;
          let id = c.(1) and pat = unhex c.(3) and ncap = int_of_string c.(8) and ast = c.(9) in
          let v = match Frag_parse.recognise pat with
            | exception Frag_parse.Out r -> "FAIL out " ^ r
            | (a, k) ->
              let s = Frag_parse.sexp a in
              if s = ast && k = ncap then "ok"
              else Printf.sprintf "FAIL got %s ncap %d, expected %s ncap %d" s k ast ncap in
          if v = "ok" then incr pass;
          Printf.printf "%s\t%s\n" id v) (lines f)) files;
  Printf.printf "RESULT astcheck passed=%d total=%d\n" !pass !total;
  if !pass <> !total then exit 1

let astwork work astf =
  let pats = Hashtbl.create 97 in
  List.iter (fun l ->
      match String.split_on_char ' ' l with
      | "P" :: pid :: _ :: _ :: _ :: _ :: rest ->
        Hashtbl.replace pats pid (match rest with [h] -> unhex h | _ -> "")
      | _ -> ()) (lines work);
  let pass = ref 0 and total = ref 0 in
  List.iter (fun l ->
      match String.split_on_char '\t' l with
      | [pid; ast] ->
        incr total;
        let v = match Frag_parse.recognise (Hashtbl.find pats pid) with
          | exception Frag_parse.Out r -> "FAIL out " ^ r
          | (a, _) -> let s = Frag_parse.sexp a in
            if s = ast then "ok" else Printf.sprintf "FAIL got %s expected %s" s ast in
        if v = "ok" then incr pass else Printf.printf "%s\t%s\n" pid v
      | _ -> failwith ("bad ast line: " ^ l)) (lines astf);
  Printf.printf "RESULT astwork passed=%d total=%d\n" !pass !total;
  if !pass <> !total then exit 1

(* ---------------------------------------------------------------- *)

module type E = sig
  type t
  val name : string
  val compile : syntax:int -> options:int -> limit:int -> stack_limit:int ->
    string -> (t, int) result
  val search : t -> string -> start:int -> range:int -> sopt:int -> int
  val search_fuel : fuel:int -> t -> string -> start:int -> range:int -> int
  val match_ : t -> string -> at:int -> sopt:int -> int
  val nregs : t -> int
  val beg : t -> int -> int
  val end_ : t -> int -> int
end

let engine = function
  | "rocq" -> (module Rocq : E)
  | "fstar" -> (module Fstar : E)
  | e -> failwith ("unknown engine " ^ e)

let verdicts eng file =
  let module X = (val engine eng) in
  List.iter (fun l ->
      let c = Array.of_list (String.split_on_char '\t' l) in
      let id = c.(1) and pat = unhex c.(3) and s = unhex c.(4) in
      match X.compile ~syntax:0 ~options:0 ~limit:0 ~stack_limit:0 pat with
      | Error code -> Printf.printf "%s\tcompile\tvm\tCERR %d\n" id code
      | Ok t ->
        let caps () =
          String.concat "" (List.init (X.nregs t - 1) (fun i ->
              Printf.sprintf " %d %d" (X.beg t (i + 1)) (X.end_ t (i + 1)))) in
        let show r = if r >= 0 then Printf.sprintf "MATCH %d %d%s" (X.beg t 0) (X.end_ t 0) (caps ())
          else if r = -1 then "MISMATCH"
          else if r = Engine22.err_out_of_fuel then "LIMIT"
          else Printf.sprintf "ERROR %d" r in
        let n = String.length s in
        for p = 0 to n do
          Printf.printf "%s\t%d\tvm\t%s\n" id p (show (X.match_ t s ~at:p ~sopt:0))
        done;
        Printf.printf "%s\tsearch\tvm\t%s\n" id (show (X.search t s ~start:0 ~range:n ~sopt:0)))
    (lines file)

(* ---------------------------------------------------------------- *)
(* work files (experiment #12's format) *)

type case = { start : int; subj : string; weight : int }

let read_cases work =
  let subs = Hashtbl.create 97 and cs = ref [] in
  List.iter (fun l ->
      match String.split_on_char ' ' l with
      | ["S"; sid; hx] -> Hashtbl.replace subs sid (unhex hx)
      | ["S"; sid] -> Hashtbl.replace subs sid ""
      | ["C"; _; _; sid; _; st; _; _; w] ->
        cs := (sid, int_of_string st, int_of_string w) :: !cs
      | _ -> ()) (lines work);
  Array.of_list (List.rev_map (fun (sid, start, weight) ->
      { start; subj = Hashtbl.find subs sid; weight }) !cs)

let now () = Mtime_clock.now_ns ()

let conv eng work minsec =
  let cases = read_cases work in
  let calls_per_pass = Array.fold_left (fun a c -> a + c.weight) 0 cases in
  let bytes_per_pass = Array.fold_left (fun a c ->
      a + c.weight * (max 0 (String.length c.subj - c.start))) 0 cases in
  let sink = ref 0 in
  let pass =
    match eng with
    | "rocq" -> fun () ->
      Array.iter (fun c -> for _ = 1 to c.weight do
          let l = Rocq22.convert c.subj c.start in
          sink := !sink + (match Sys.opaque_identity l with [] -> 0 | _ -> 1) done) cases
    | "fstar" -> fun () ->
      Array.iter (fun c -> for _ = 1 to c.weight do
          let l = Fstar22.convert c.subj c.start in
          sink := !sink + (match Sys.opaque_identity l with [] -> 0 | _ -> 1) done) cases
    | e -> failwith ("unknown engine " ^ e) in
  pass ();
  let minor0 = Gc.minor_words () and major0 = (Gc.quick_stat ()).Gc.major_words in
  let t0 = now () in
  let passes = ref 0 in
  let limit = Int64.of_float (minsec *. 1e9) in
  while Int64.sub (now ()) t0 < limit do pass (); incr passes done;
  let t1 = now () in
  let minor1 = Gc.minor_words () and major1 = (Gc.quick_stat ()).Gc.major_words in
  let calls = !passes * calls_per_pass and bytes = !passes * bytes_per_pass in
  let ns = Int64.to_float (Int64.sub t1 t0) in
  Printf.printf "engine=%s cases=%d calls_per_pass=%d bytes_per_pass=%d passes=%d sec=%.6f ns_per_call=%.3f ns_per_byte=%.4f minor_per_call=%.4f major_per_call=%.4f sink=%d\n"
    eng (Array.length cases) calls_per_pass bytes_per_pass !passes (ns /. 1e9)
    (ns /. float calls) (if bytes = 0 then 0. else ns /. float bytes)
    ((minor1 -. minor0) /. float calls) ((major1 -. major0) /. float calls) (!sink land 1)

let read_file f =
  let ic = open_in_bin f in
  let n = in_channel_length ic in
  let s = really_input_string ic n in close_in ic; s

let conv_subject eng file =
  let s = read_file file in
  let n = String.length s in
  let g = Gc.get () in
  let minor0 = Gc.minor_words () and st0 = Gc.quick_stat () in
  let t0 = now () in
  let keep = match eng with
    | "rocq" -> Obj.repr (Rocq22.convert s 0)
    | "fstar" -> Obj.repr (Fstar22.convert s 0)
    | e -> failwith ("unknown engine " ^ e) in
  let t1 = now () in
  let minor1 = Gc.minor_words () and st1 = Gc.quick_stat () in
  let ns = Int64.to_float (Int64.sub t1 t0) in
  Printf.printf "engine=%s bytes=%d sec=%.6f ns_per_byte=%.3f minor_words=%.0f major_words=%.0f promoted_words=%.0f heap_words_after=%d heap_mb_after=%.1f top_heap_words=%d minor_collections=%d major_collections=%d gc_minor_heap_size=%d gc_space_overhead=%d gc_max_overhead=%d gc_window_size=%d gc_custom_major_ratio=%d ocamlrunparam=%s\n"
    eng n (ns /. 1e9) (ns /. float n) (minor1 -. minor0)
    (st1.Gc.major_words -. st0.Gc.major_words) (st1.Gc.promoted_words -. st0.Gc.promoted_words)
    st1.Gc.heap_words (float st1.Gc.heap_words *. 8. /. 1e6) st1.Gc.top_heap_words
    (st1.Gc.minor_collections - st0.Gc.minor_collections)
    (st1.Gc.major_collections - st0.Gc.major_collections)
    g.Gc.minor_heap_size g.Gc.space_overhead g.Gc.max_overhead g.Gc.window_size
    g.Gc.custom_major_ratio
    (match Sys.getenv_opt "OCAMLRUNPARAM" with None -> "unset" | Some _ -> "set");
  ignore (Sys.opaque_identity keep)

let cata_fuel eng syntax options hexpat len fuel =
  let module X = (val engine eng) in
  let subj = String.make len 'a' ^ "!" in
  match X.compile ~syntax ~options ~limit:0 ~stack_limit:0 (unhex hexpat) with
  | Error code -> Printf.printf "engine=%s n=%d CERR %d\n" eng len code
  | Ok t ->
    let t0 = now () in
    let r = X.search_fuel ~fuel t subj ~start:0 ~range:(String.length subj) in
    let t1 = now () in
    let outcome = if r >= 0 then "match" else if r = -1 then "nomatch"
      else if r = Engine22.err_out_of_fuel then "fuel" else string_of_int r in
    Printf.printf "engine=%s n=%d fuel=%d result=%d outcome=%s sec=%.6f\n" eng len fuel r outcome
      (Int64.to_float (Int64.sub t1 t0) /. 1e9)

let () =
  match Array.to_list Sys.argv |> List.tl with
  | "astcheck" :: fs -> astcheck fs
  | ["astwork"; w; a] -> astwork w a
  | ["verdicts"; e; f] -> verdicts e f
  | ["conv"; e; w; m] -> conv e w (float_of_string m)
  | ["conv-subject"; e; s] -> conv_subject e s
  | ["cata-fuel"; e; sy; op; hp; n; fu] ->
    cata_fuel e (int_of_string sy) (int_of_string op) hp (int_of_string n) (int_of_string fu)
  | _ -> prerr_endline "usage: see header"; exit 2
