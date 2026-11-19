(* Experiment #11: ocaml-re harness. Same modes, output format and
   enumeration loop as driver.h (see there). ocaml-re works on bytes:
   a UTF-8 pattern is parsed byte by byte (Re.Perl). *)

let o_ignorecase = 1 and o_extend = 2 and o_multiline = 4 and o_singleline = 8
and o_negate_singleline = 64 and o_capture_group_bits = 128 lor 256

type pat = { syntax : string; options : int; encoding : string; pat : string }

let unhex h =
  String.init (String.length h / 2) (fun i -> Char.chr (int_of_string ("0x" ^ String.sub h (2 * i) 2)))

let lines_of path =
  let ic = open_in_bin path in
  let rec go acc = match input_line ic with l -> go (l :: acc) | exception End_of_file -> close_in ic; List.rev acc in
  go []

let lines dir name = lines_of (Filename.concat dir name)

let perl_like s = List.mem s [ "ONIGURUMA"; "RUBY"; "PERL_NG"; "PERL"; "JAVA"; "PYTHON" ]

let singleline p =
  if p.options land o_negate_singleline <> 0 then false
  else p.options land o_singleline <> 0 || List.mem p.syntax [ "PERL_NG"; "PERL"; "JAVA"; "PYTHON" ]

(* Ok re | Error (status, why); status 1 err, 2 unsup, 3 limit *)
let compile p =
  if p.encoding <> "UTF-8" || not (perl_like p.syntax) then Error (2, "syntax or encoding")
  else if p.options land lnot (o_ignorecase lor o_multiline lor o_singleline lor o_capture_group_bits) <> 0 then
    Error (2, Printf.sprintf "option %d" p.options) (* no extended mode in Re.Perl *)
  else
    let opts =
      (if p.options land o_ignorecase <> 0 then [ `Caseless ] else [])
      @ (if p.options land o_multiline <> 0 then [ `Dotall ] else [])
      @ if singleline p then [] else [ `Multiline ]
    in
    match Re.compile (Re.Perl.re ~opts p.pat) with
    | re -> Ok re
    | exception Re.Perl.Parse_error -> Error (1, "parse_error")
    | exception Re.Perl.Not_supported -> Error (1, "not_supported")

let utf8_advance s at =
  let len = String.length s in
  if at >= len then 1
  else
    let c = Char.code s.[at] in
    let n = if c < 0x80 then 1 else if c < 0xC2 then 1 else if c < 0xE0 then 2 else if c < 0xF0 then 3 else if c < 0xF5 then 4 else 1 in
    if at + n > len then len - at else n

let enum_pair re s out =
  let len = String.length s in
  let rec go pos n =
    if pos > len then n
    else
      match Re.exec_opt ~pos re s with
      | None -> n
      | Some g ->
          let ms, me = Re.Group.offset g 0 in
          (match out with Some b -> Printf.bprintf b " %d-%d" ms me | None -> ());
          if me > ms then go me (n + 1)
          else if me >= len then n + 1
          else go (me + utf8_advance s me) (n + 1)
  in
  go 0 0

let now () = Mtime.Span.to_float_ns (Mtime_clock.elapsed ()) *. 1e-9

let env_f k d = match Sys.getenv_opt k with Some v -> float_of_string v | None -> d

let () =
  let a = Sys.argv in
  let mode = if Array.length a > 1 then a.(1) else "" in
  if mode = "worst" then begin
    let p = { syntax = a.(3); options = int_of_string a.(4); encoding = "UTF-8"; pat = a.(2) } in
    let n = int_of_string a.(5) in
    match compile p with
    | Error (c, why) -> Printf.printf "compile\t%d\t%s\n" c why
    | Ok re ->
        let s = String.make n 'a' ^ "!" in
        let t0 = now () in
        let r = Re.execp re s in
        Printf.printf "result\t%d\t%.6f\n" (Bool.to_int r) (now () -. t0)
  end
  else if mode <> "check" && mode <> "time" then (prerr_endline "usage: ocaml_bench check|time|worst ..."; exit 2)
  else begin
    let dir = a.(2) in
    let pats =
      Array.of_list
        (List.map
           (fun l ->
             match String.split_on_char '\t' l with
             | _ :: _ :: syn :: opt :: enc :: hex :: _ -> { syntax = syn; options = int_of_string opt; encoding = enc; pat = unhex hex }
             | _ -> failwith "patterns.tsv")
           (lines dir "patterns.tsv"))
    in
    let subs = Array.of_list (List.map (fun l -> unhex (List.nth (String.split_on_char '\t' l) 1)) (lines dir "subjects.tsv")) in
    let pairs =
      Array.of_list
        (List.map (fun l -> match String.split_on_char '\t' l with [ p; s ] -> (int_of_string p, int_of_string s) | _ -> failwith "pairs")
           (lines dir "pairs.tsv"))
    in
    let res = Array.map compile pats in
    let incl = Array.map Result.is_ok res in
    if mode = "time" && Array.length a > 3 then begin
      Array.fill incl 0 (Array.length incl) false;
      List.iter
        (fun l -> match int_of_string_opt (String.trim l) with
          | Some p when p >= 0 && p < Array.length pats && Result.is_ok res.(p) -> incl.(p) <- true
          | _ -> ())
        (lines_of a.(3))
    end;
    let pass () =
      let t0 = now () in
      let m = ref 0 and b = ref 0. in
      Array.iter
        (fun (p, s) ->
          if incl.(p) then
            match res.(p) with Ok re -> m := !m + enum_pair re subs.(s) None; b := !b +. float (String.length subs.(s)) | Error _ -> ())
        pairs;
      (now () -. t0, !m, !b)
    in
    if mode = "check" then begin
      Array.iteri
        (fun i r ->
          match r with
          | Ok _ -> Printf.printf "P\t%d\tok\t\n" i
          | Error (c, why) -> Printf.printf "P\t%d\t%s\t%s\n" i [| "ok"; "err"; "unsup"; "limit" |].(c) why)
        res;
      Array.iter
        (fun (p, s) ->
          match res.(p) with
          | Ok re ->
              let b = Buffer.create 64 in
              ignore (enum_pair re subs.(s) (Some b));
              Printf.printf "M\t%d\t%d\t%s\n" p s (Buffer.contents b)
          | Error _ -> ())
        pairs;
      let t, _, _ = pass () in
      Printf.printf "PASS\t%.6f\n" t
    end
    else begin
      let cmin_n = int_of_float (env_f "E11_COMPILE_N" 1000.) and cmin_t = env_f "E11_COMPILE_MIN" 0.010
      and ccap = env_f "E11_COMPILE_CAP" 1.0 and rep_min = env_f "E11_REP_MIN" 0.5
      and nrep = int_of_float (env_f "E11_REPS" 5.) in
      if Sys.getenv_opt "E11_NO_COMPILE" = None then
        Array.iteri
          (fun i p ->
            if incl.(i) then begin
              let start = now () in
              let ct = ref [] and n = ref 0 in
              let continue = ref true in
              while !continue do
                let a0 = now () in
                ignore (Sys.opaque_identity (compile p));
                ct := (now () -. a0) :: !ct;
                incr n;
                let el = now () -. start in
                if (!n >= cmin_n && el >= cmin_t) || el >= ccap then continue := false
              done;
              let arr = Array.of_list !ct in
              Array.sort compare arr;
              Printf.printf "C\t%d\t%.1f\t%d\n" i (arr.(!n / 2) *. 1e9) !n
            end)
          pats;
      let t, matches, bytes = pass () in
      let npass = if t >= rep_min then 1 else int_of_float (rep_min /. Float.max t 1e-6) + 1 in
      Printf.printf "W\t%.6f\t%d\n" t npass;
      for rep = 0 to nrep - 1 do
        let t0 = now () in
        for _ = 1 to npass do ignore (pass ()) done;
        Printf.printf "T\t%d\t%.9f\t%d\n%!" rep ((now () -. t0) /. float npass) npass
      done;
      Printf.printf "S\tbytes_per_pass=%.0f\tmatches_per_pass=%d\tincluded_patterns=%d\n" bytes matches
        (Array.fold_left (fun k b -> if b then k + 1 else k) 0 incl)
    end
  end
