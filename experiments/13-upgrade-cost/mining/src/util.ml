let drop n s = String.sub s n (String.length s - n)
let after ~prefix s = drop (String.length prefix) s

let lines s =
  String.split_on_char '\n' s |> List.filter (fun l -> String.trim l <> "")
