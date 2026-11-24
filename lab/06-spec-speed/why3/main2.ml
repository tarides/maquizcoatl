(* Experiment #6 milestone 2: driver for the Why3 extraction of the S2
   semantics (integers are Z.t).  Prints one verdict per case, then times
   REPS passes of [passes] (search only). *)
open Full
let rec to_list = function BNil -> [] | BCons (x, t) -> Z.to_string x :: to_list t
let () =
  let reps = int_of_string Sys.argv.(1) in
  let nc = Z.to_int ncases in
  for i = 0 to nc - 1 do
    let Case (ncap, refs, re, s, _) = get (Z.of_int i) in
    print_endline (String.concat " " (to_list (run_case fuel0 ncap refs re s)))
  done;
  if reps > 0 then begin
    let t0 = Unix.gettimeofday () in
    let n = passes (Z.of_int reps) Z.zero in
    let t1 = Unix.gettimeofday () in
    Printf.printf "cases=%d reps=%d agree=%s search_s=%.3f search_cps=%.0f\n" nc reps
      (Z.to_string n) (t1 -. t0) (float (nc * reps) /. (t1 -. t0))
  end
