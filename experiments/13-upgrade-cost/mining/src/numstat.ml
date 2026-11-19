type entry = { added : int option; removed : int option; path : string }
type totals = { files : int; added : int; removed : int }

let count = function
  | "-" -> None
  | s -> (
      match int_of_string_opt s with
      | Some n when n >= 0 -> Some n
      | _ -> failwith (Printf.sprintf "numstat: bad line count %S" s))

(* The path is everything after the second tab: it may contain tabs. *)
let parse_record record =
  let bad () = failwith (Printf.sprintf "numstat: bad record %S" record) in
  match String.index_opt record '\t' with
  | None -> bad ()
  | Some i -> (
      match String.index_from_opt record (i + 1) '\t' with
      | Some j when j + 1 < String.length record ->
          {
            added = count (String.sub record 0 i);
            removed = count (String.sub record (i + 1) (j - i - 1));
            path = Util.drop (j + 1) record;
          }
      | _ -> bad ())

let parse output =
  String.split_on_char '\000' output
  |> List.filter (fun r -> String.trim r <> "")
  |> List.map parse_record

let keep ~under ~exclude e =
  (under = [] || List.exists (fun d -> Glob.under d e.path) under)
  && not (List.exists (fun p -> Glob.matches p e.path) exclude)

let zero = { files = 0; added = 0; removed = 0 }

let add a b =
  {
    files = a.files + b.files;
    added = a.added + b.added;
    removed = a.removed + b.removed;
  }

let totals entries =
  List.fold_left
    (fun t (e : entry) ->
      add t
        {
          files = 1;
          added = Option.value e.added ~default:0;
          removed = Option.value e.removed ~default:0;
        })
    zero entries
