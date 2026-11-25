(* Experiment #6 milestone 2: driver for Isabelle's export_code of the S2
   semantics (nat as Z.t).  Prints one verdict per case, then times REPS
   passes of [passes] (search only: the cases are ASTs built by the case
   module). *)
open Full.Full
let z n = Z.to_string (integer_of_nat n)
let () =
  let reps = int_of_string Sys.argv.(1) in
  List.iter (fun (ncap, (refs, (re, (s, _)))) ->
      print_endline (String.concat " " (List.map z (run_case fuel0 ncap refs re s))))
    cases;
  if reps > 0 then begin
    let nc = List.length cases in
    let t0 = Unix.gettimeofday () in
    let n = passes (nat_of_integer (Z.of_int reps)) cases (nat_of_integer Z.zero) in
    let t1 = Unix.gettimeofday () in
    Printf.printf "cases=%d reps=%d agree=%s search_s=%.3f search_cps=%.0f\n" nc reps
      (z n) (t1 -. t0) (float (nc * reps) /. (t1 -. t0))
  end
