(* Experiment #7 driver for the extracted OCaml targets.
   main <queries> <names> <answers>; M is bound by -open-free aliasing in
   each tool's build (module M = <extracted module>). *)
let () =
  let ic = open_in Sys.argv.(1) and oc = open_out Sys.argv.(3) in
  (try
     while true do
       Scanf.sscanf (input_line ic) "%d %d" (fun a b ->
           output_string oc (if M.ctype_mem a b then "1\n" else "0\n"))
     done
   with End_of_file -> ());
  let ic = open_in Sys.argv.(2) in
  (try
     while true do
       Printf.fprintf oc "%d\n" (M.lookup_name (input_line ic))
     done
   with End_of_file -> ());
  close_out oc
