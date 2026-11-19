type result = { project : string; tool : Tool.t; rows : Mine.row list }

let csv_field s =
  if String.exists (function ',' | '"' | '\n' | '\r' -> true | _ -> false) s
  then "\"" ^ String.concat "\"\"" (String.split_on_char '"' s) ^ "\""
  else s

let csv_line fields = String.concat "," (List.map csv_field fields) ^ "\n"
let words = String.concat " "
let opt_int = function Some n -> string_of_int n | None -> ""
let lines (t : Numstat.totals) = t.added + t.removed

let rows_csv rows =
  csv_line
    [
      "project";
      "kind";
      "units";
      "date";
      "subject";
      "from";
      "to";
      "reached";
      "releases_spanned";
      "files";
      "added";
      "removed";
      "authors";
      "class";
    ]
  ^ String.concat ""
      (List.map
         (fun (r : Mine.row) ->
           csv_line
             [
               r.project;
               Mine.kind_to_string r.kind;
               words r.units;
               r.date;
               r.subject;
               words r.from_;
               words r.to_;
               words r.reached;
               opt_int r.spanned;
               string_of_int r.totals.files;
               string_of_int r.totals.added;
               string_of_int r.totals.removed;
               String.concat "; " r.authors;
               "";
             ])
         rows)

type series_group = {
  series : string;
  rows : Mine.row list;  (** History order. *)
  spanned : int option;
  totals : Numstat.totals;
}

let union l =
  List.fold_left (fun acc x -> if List.mem x acc then acc else x :: acc) [] l
  |> List.rev

(* Bump and snapshot rows that move the project to a series, not back, grouped
   by that series, in the order the series are first reached. *)
let series_groups rows =
  let attributable (r : Mine.row) =
    match (r.kind, r.to_series, r.spanned) with
    | Mine.Keyword, _, _ | _, None, _ -> None
    | _, Some _, Some n when n < 0 -> None
    | _, Some s, _ -> Some s
  in
  let series = union (List.filter_map attributable rows) in
  List.map
    (fun s ->
      let rows = List.filter (fun r -> attributable r = Some s) rows in
      {
        series = s;
        rows;
        spanned =
          List.fold_left
            (fun acc (r : Mine.row) ->
              match (acc, r.spanned) with
              | Some a, Some n -> Some (max a n)
              | None, n | n, None -> n)
            None rows;
        totals =
          List.fold_left
            (fun acc (r : Mine.row) -> Numstat.add acc r.totals)
            Numstat.zero rows;
      })
    series

let per_release g =
  match g.spanned with
  | Some n when n > 0 -> Some (float_of_int (lines g.totals) /. float_of_int n)
  | _ -> None

let per_release_csv results =
  csv_line
    [
      "project";
      "tool";
      "series";
      "units";
      "date";
      "reached";
      "releases_spanned";
      "files";
      "added";
      "removed";
      "lines_per_release";
    ]
  ^ String.concat ""
      (List.concat_map
         (fun { project; tool; rows } ->
           List.map
             (fun g ->
               let field f = words (union (List.concat_map f g.rows)) in
               csv_line
                 [
                   project;
                   Tool.name tool;
                   g.series;
                   field (fun (r : Mine.row) -> r.units);
                   List.fold_left
                     (fun acc (r : Mine.row) -> max acc r.date)
                     "" g.rows;
                   field (fun (r : Mine.row) -> r.reached);
                   opt_int g.spanned;
                   string_of_int g.totals.files;
                   string_of_int g.totals.added;
                   string_of_int g.totals.removed;
                   (match per_release g with
                   | Some x -> Printf.sprintf "%.1f" x
                   | None -> "");
                 ])
             (series_groups rows))
         results)

let median = function
  | [] -> None
  | l ->
      let a = Array.of_list (List.sort compare l) in
      let n = Array.length a in
      Some
        (if n mod 2 = 1 then a.(n / 2) else (a.((n / 2) - 1) +. a.(n / 2)) /. 2.)

let summary_md ~since ~until results =
  let header =
    Printf.sprintf
      "Window: %s to %s. Lines are added plus removed, pin files, lockfiles \
       and generated files excluded, before manual classification. Bump and \
       snapshot rows are summed per tool series they reach; a series' lines \
       are divided by the releases it spans. Unattributed lines are those of \
       rows that reach no release, go back to an older series, or belong to a \
       series that spans no release (for example a pinned commit that is \
       already in the latest release).\n\n\
       | Project | Tool | Tool series in window | Bumps | Keyword rows | \
       Snapshot rows | Releases reached | Lines (bumps, snapshots) | Median \
       lines per release | Unattributed lines | Largest row |\n\
       | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |\n"
      since until
  in
  let line { project; tool; rows } =
    let count k =
      List.length (List.filter (fun (r : Mine.row) -> r.kind = k) rows)
    in
    let measured =
      List.filter (fun (r : Mine.row) -> r.kind <> Mine.Keyword) rows
    in
    let sum_lines =
      List.fold_left (fun acc (r : Mine.row) -> acc + lines r.totals) 0
    in
    let groups =
      List.filter (fun g -> per_release g <> None) (series_groups rows)
    in
    let largest =
      List.fold_left
        (fun acc (r : Mine.row) ->
          match acc with
          | Some (b : Mine.row) when lines b.totals >= lines r.totals -> acc
          | _ -> Some r)
        None measured
    in
    Printf.sprintf "| %s | %s | %d | %d | %d | %d | %d | %d | %s | %d | %s |\n"
      project (Tool.name tool) (Tool.cadence tool ~since) (count Mine.Bump)
      (count Mine.Keyword) (count Mine.Snapshot)
      (List.fold_left
         (fun acc g -> acc + Option.value g.spanned ~default:0)
         0 groups)
      (sum_lines measured)
      (match median (List.filter_map per_release groups) with
      | Some m -> Printf.sprintf "%.1f" m
      | None -> "")
      (sum_lines measured
      - List.fold_left (fun acc g -> acc + lines g.totals) 0 groups)
      (match largest with
      | Some r ->
          Printf.sprintf "%s (%d lines, %d files)" (words r.units)
            (lines r.totals) r.totals.files
      | None -> "")
  in
  header ^ String.concat "" (List.map line results)
