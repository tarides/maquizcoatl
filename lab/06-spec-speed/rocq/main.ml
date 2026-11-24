(* Experiment #6: driver for the Rocq extraction.  Prints one verdict
   per case, then times REPS passes of [passes] (search only: the cases
   are ASTs built by the case module). *)
let () =
  let reps = int_of_string Sys.argv.(1) in
  List.iter (fun (((ncap, re), s), _) ->
      print_endline (String.concat " " (List.map string_of_int (Full.run_case Full.fuel0 ncap re s))))
    Full.cases;
  if reps > 0 then begin
    let nc = List.length Full.cases in
    let t0 = Unix.gettimeofday () in
    let n = Full.passes reps Full.cases 0 in
    let t1 = Unix.gettimeofday () in
    Printf.printf "cases=%d reps=%d agree=%d search_s=%.3f search_cps=%.0f\n" nc reps n (t1 -. t0)
      (float (nc * reps) /. (t1 -. t0))
  end
