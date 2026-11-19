type t = { jobs : int; cpus : Cpuset.t; nice : int; timeout : int }

let kill_after = 60

let make ~jobs ~cpus ~nice ~timeout =
  if jobs < 1 then Error "the number of jobs must be at least 1"
  else if nice < 0 || nice > 19 then Error "the niceness must be in 0..19"
  else if timeout < 1 then Error "the timeout must be at least one second"
  else Ok { jobs; cpus; nice; timeout }

let warnings t =
  let n = Cpuset.cardinal t.cpus in
  if t.jobs > n then
    [
      Printf.sprintf "%d jobs on %d CPU%s (%s)" t.jobs n
        (if n = 1 then "" else "s")
        (Cpuset.to_string t.cpus);
    ]
  else []

let prefix t =
  [
    "timeout";
    Printf.sprintf "--kill-after=%d" kill_after;
    string_of_int t.timeout;
    "taskset";
    "--cpu-list";
    Cpuset.to_string t.cpus;
    "nice";
    "-n";
    string_of_int t.nice;
  ]

let duration_of_string s =
  let error () =
    Error (Printf.sprintf "%S is not a duration (90s, 30m, 6h)" s)
  in
  let number, unit =
    match String.length s with
    | 0 -> ("", 1)
    | n -> (
        match s.[n - 1] with
        | 's' -> (String.sub s 0 (n - 1), 1)
        | 'm' -> (String.sub s 0 (n - 1), 60)
        | 'h' -> (String.sub s 0 (n - 1), 3600)
        | _ -> (s, 1))
  in
  if Text.is_digits number && String.length number <= 6 then
    match int_of_string number * unit with 0 -> error () | n -> Ok n
  else error ()

let with_timeout timeout t =
  if timeout < 1 then invalid_arg "Limits.with_timeout" else { t with timeout }
