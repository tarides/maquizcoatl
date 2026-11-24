type t = int list (* Sorted, distinct, non-empty. *)

let max_cpu = 4095

let index s =
  if Text.is_digits s && String.length s <= 4 then
    let n = int_of_string s in
    if n <= max_cpu then Ok n
    else Error (Printf.sprintf "CPU index %d is above %d" n max_cpu)
  else Error (Printf.sprintf "%S is not a CPU index" s)

let item s =
  let open Result.Syntax in
  match String.split_on_char '-' s with
  | [ n ] ->
      let+ n = index n in
      [ n ]
  | [ a; b ] ->
      let* a = index a in
      let* b = index b in
      if a <= b then Ok (List.init (b - a + 1) (fun i -> a + i))
      else Error (Printf.sprintf "range %S is decreasing" s)
  | _ -> Error (Printf.sprintf "%S is not a CPU index or range" s)

let of_string s =
  let rec collect acc = function
    | [] -> Ok (List.sort_uniq Int.compare acc)
    | it :: rest -> (
        match item it with
        | Ok cpus -> collect (List.rev_append cpus acc) rest
        | Error e -> Error ("CPU list " ^ s ^ ": " ^ e))
  in
  collect [] (String.split_on_char ',' s)

let to_string t =
  let rec ranges acc = function
    | [] -> List.rev acc
    | first :: rest ->
        let rec extend last = function
          | n :: rest when n = last + 1 -> extend n rest
          | rest -> (last, rest)
        in
        let last, rest = extend first rest in
        ranges ((first, last) :: acc) rest
  in
  ranges [] t
  |> List.map (fun (a, b) ->
      if a = b then string_of_int a else Printf.sprintf "%d-%d" a b)
  |> String.concat ","

let cardinal = List.length
