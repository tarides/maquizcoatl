type scheme = Minor | Exact

type t = {
  name : string;
  scheme : scheme;
  prefixes : string list;
  releases : Release.t list;
      (** Published on or before the snapshot date, oldest first. *)
  series : string list;  (** Counted series, oldest first. *)
}

let normalise_with prefixes v =
  let v = String.lowercase_ascii (String.trim v) in
  let rec strip v =
    match
      List.find_opt (fun prefix -> String.starts_with ~prefix v) prefixes
    with
    | Some p when p <> "" -> strip (Util.drop (String.length p) v)
    | _ -> v
  in
  let v = strip v in
  if String.starts_with ~prefix:"v" v then Util.drop 1 v else v

(* [major.minor] prefix of a normalised version, e.g. "4.34.0-rc1" -> "4.34",
   "9.2+rc1" -> "9.2", "8.4pl5" -> "8.4". *)
let minor v =
  let digits_from i =
    let j = ref i in
    while !j < String.length v && v.[!j] >= '0' && v.[!j] <= '9' do
      incr j
    done;
    !j
  in
  let a = digits_from 0 in
  if a = 0 || a >= String.length v || v.[a] <> '.' then v
  else
    let b = digits_from (a + 1) in
    if b = a + 1 then v else String.sub v 0 b

let series_of scheme prefixes (r : Release.t) =
  let v = normalise_with prefixes r.version in
  match scheme with
  | Minor -> Some (minor v)
  | Exact -> if r.prerelease then None else Some v

let make ~name ~scheme ~prefixes ~until releases =
  let releases =
    List.filter (fun (r : Release.t) -> r.date <= until) releases
    |> List.stable_sort (fun (a : Release.t) b -> compare a.date b.date)
  in
  let series =
    List.fold_left
      (fun acc r ->
        match series_of scheme prefixes r with
        | Some s when not (List.mem s acc) -> s :: acc
        | _ -> acc)
      [] releases
    |> List.rev
  in
  { name; scheme; prefixes; releases; series }

let name t = t.name
let normalise t v = normalise_with t.prefixes v
let series t r = series_of t.scheme t.prefixes r

let find t v =
  let v = normalise t v in
  List.find_opt
    (fun (r : Release.t) -> normalise t r.version = v)
    (List.rev t.releases)

let earliest t tags =
  List.filter_map (find t) tags
  |> List.stable_sort (fun (a : Release.t) b -> compare a.date b.date)
  |> function
  | r :: _ -> Some r
  | [] -> None

let index t s =
  let rec go i = function
    | [] -> None
    | x :: _ when x = s -> Some i
    | _ :: l -> go (i + 1) l
  in
  go 0 t.series

let newest t rs =
  List.filter_map (fun r -> Option.bind (series t r) (index t)) rs
  |> List.fold_left
       (fun acc i -> Some (max i (Option.value acc ~default:i)))
       None

let newest_series t rs = Option.map (List.nth t.series) (newest t rs)

let spanned t ~from ~to_ =
  match (newest t from, newest t to_) with
  | Some a, Some b -> Some (b - a)
  | _ -> None

let cadence t ~since =
  List.filter
    (fun s ->
      match
        List.find_opt
          (fun (r : Release.t) -> (not r.prerelease) && series t r = Some s)
          t.releases
      with
      | Some r -> r.date >= since
      | None -> false)
    t.series
  |> List.length
