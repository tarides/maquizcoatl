(* Experiment #6 milestone 2: driver for the Rocq extraction of the S2
   semantics.  Prints one verdict per case, then times REPS passes of
   [passes] (search only: the cases are ASTs built by the case module). *)
let () =
  let reps = int_of_string Sys.argv.(1) in
  List.iter (fun ((((ncap, refs), re), s), _) ->
      print_endline (String.concat " "
                       (List.map string_of_int (Full2.run_case Full2.fuel0 ncap refs re s))))
    Full2.cases;
  if reps > 0 then begin
    let nc = List.length Full2.cases in
    let t0 = Unix.gettimeofday () in
    let n = Full2.passes reps Full2.cases 0 in
    let t1 = Unix.gettimeofday () in
    Printf.printf "cases=%d reps=%d agree=%d search_s=%.3f search_cps=%.0f\n" nc reps n (t1 -. t0)
      (float (nc * reps) /. (t1 -. t0))
  end
