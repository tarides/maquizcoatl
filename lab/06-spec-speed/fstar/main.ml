(* Experiment #6: driver for the F* OCaml extraction (integers are
   Z.t).  Prints one verdict per case, then times REPS passes of
   [passes] (search only: the cases are ASTs built by the case module). *)
open Custard
let () =
  let reps = int_of_string Sys.argv.(1) in
  List.iter (fun (ncap, re, s, _) ->
      print_endline (String.concat " " (List.map Z.to_string (spec_run_case spec_fuel0 ncap re s))))
    cases_cases;
  if reps > 0 then begin
    let nc = List.length cases_cases in
    let t0 = Unix.gettimeofday () in
    let n = spec_passes (Z.of_int reps) cases_cases Z.zero in
    let t1 = Unix.gettimeofday () in
    Printf.printf "cases=%d reps=%d agree=%s search_s=%.3f search_cps=%.0f\n" nc reps
      (Z.to_string n) (t1 -. t0) (float (nc * reps) /. (t1 -. t0))
  end
