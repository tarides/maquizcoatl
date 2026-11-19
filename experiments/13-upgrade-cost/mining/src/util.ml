let drop n s = String.sub s n (String.length s - n)
let after ~prefix s = drop (String.length prefix) s

let lines s =
  String.split_on_char '\n' s |> List.filter (fun l -> String.trim l <> "")

let memo f =
  let table = Hashtbl.create 16 in
  fun x ->
    match Hashtbl.find_opt table x with
    | Some y -> y
    | None ->
        let y = f x in
        Hashtbl.add table x y;
        y

let dedup l =
  List.fold_left (fun acc x -> if List.mem x acc then acc else x :: acc) [] l
  |> List.rev
