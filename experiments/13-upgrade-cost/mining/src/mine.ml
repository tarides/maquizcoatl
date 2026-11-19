type kind = Bump | Keyword | Snapshot

type row = {
  project : string;
  kind : kind;
  units : string list;
  date : string;
  subject : string;
  from_ : string list;
  to_ : string list;
  reached : string list;
  to_series : string option;
  spanned : int option;
  totals : Numstat.totals;
  authors : string list;
}

let kind_to_string = function
  | Bump -> "bump"
  | Keyword -> "keyword"
  | Snapshot -> "snapshot"

let short hash = if String.length hash > 7 then String.sub hash 0 7 else hash

(* A pin value, resolved against the tool's releases. *)
type resolution =
  | Found of Release.t
  | Unreleased
  | Unknown_commit
  | Unresolved of string
  | Opaque_value

let label = function
  | Found (r : Release.t) -> Some r.version
  | Unreleased -> Some "unreleased"
  | Unknown_commit -> Some "unknown-commit"
  | Unresolved v -> Some ("unresolved:" ^ v)
  | Opaque_value -> None

let found = List.filter_map (function Found r -> Some r | _ -> None)
let minus a b = List.filter (fun v -> not (List.mem v b)) a

(* A selected unit before grouping. [before] and [after] hold, per pin, the
   values read from each of its files at the first parent and at the unit. *)
type unit_ = {
  kind : kind;
  commit : Repo.commit;
  before : (string * string list) list list;
  after : (string * string list) list list;
  totals : Numstat.totals;
}

(* A selected unit, or a group of units, with its pin values resolved. Keys
   identify a version across pins: the release a value names for a
   [Pin.Release] pin, the value itself otherwise. *)
type summary = {
  kind : kind;
  commits : Repo.commit list;  (** Oldest first. *)
  last : Repo.commit;
  from_ : string list;
  to_ : string list;
  reached : string list;  (** Labels of the newly reached values. *)
  new_release : bool;
      (** Whether a release that the values before did not reach, or a commit
          that no release contains, is reached. *)
  from_found : Release.t list;
  to_found : Release.t list;
  introduced : string list;
      (** Keys of the resolvable values that some file did not hold before. *)
  resolvable_after : string list;  (** Keys of the resolvable values after. *)
  moves : (string list * string list) list;
      (** For each file of a resolvable pin whose values change: the keys of its
          new values, and of all its values after. *)
  totals : Numstat.totals;
}

let in_periods periods date =
  periods = [] || List.exists (fun (a, b) -> a <= date && date <= b) periods

let contains_any ~words text =
  let text = String.lowercase_ascii text in
  let n = String.length text in
  List.exists
    (fun w ->
      let k = String.length w in
      let rec at i = i + k <= n && (String.sub text i k = w || at (i + 1)) in
      k > 0 && at 0)
    words

let history (p : Project.t) (h : Project.history) ~tool ~clones ~since ~until =
  let repo : Repo.t = clones p.clone in
  let pin_patterns = List.concat_map (fun (pin : Pin.t) -> pin.files) h.pins in
  let values_cache = Hashtbl.create 64 in
  let values_at commit =
    match Hashtbl.find_opt values_cache commit with
    | Some v -> v
    | None ->
        let files =
          repo.files commit
          |> List.filter (fun path ->
              List.exists (fun pin -> Pin.matches_file pin path) h.pins)
          |> List.map (fun path -> (path, repo.show commit path))
        in
        let v = List.map (fun pin -> Pin.file_values pin files) h.pins in
        Hashtbl.add values_cache commit v;
        v
  in
  let tags_cache = Hashtbl.create 64 in
  let tags_containing clone value =
    match Hashtbl.find_opt tags_cache (clone, value) with
    | Some tags -> tags
    | None ->
        let tags = (clones clone : Repo.t).tags_containing value in
        Hashtbl.add tags_cache (clone, value) tags;
        tags
  in
  let resolve (pin : Pin.t) value =
    match pin.resolve with
    | Pin.Opaque -> Opaque_value
    | Pin.Release -> (
        match Tool.find tool value with
        | Some r -> Found r
        | None -> Unresolved value)
    | Pin.Commit clone -> (
        match tags_containing clone value with
        | None -> Unknown_commit
        | Some tags -> (
            match Tool.earliest tool tags with
            | Some r -> Found r
            | None -> Unreleased))
  in
  let key (pin : Pin.t) value =
    match pin.resolve with
    | Pin.Release ->
        Option.fold ~none:value
          ~some:(fun (r : Release.t) -> r.version)
          (Tool.find tool value)
    | Pin.Commit _ | Pin.Opaque -> value
  in
  let measure (c : Repo.commit) parent =
    repo.numstat parent c.hash
    |> List.filter
         (Numstat.keep ~under:h.under ~exclude:(h.exclude @ pin_patterns))
    |> Numstat.totals
  in
  let all = repo.first_parent_log ~head:p.head ~since ~until ~paths:[] in
  let bumps =
    repo.first_parent_log ~head:p.head ~since ~until ~paths:pin_patterns
    |> List.filter_map (fun (c : Repo.commit) ->
        match c.parents with
        | [] -> None
        | parent :: _ ->
            let before = values_at parent and after = values_at c.hash in
            if List.map Pin.union before = List.map Pin.union after then None
            else
              Some
                {
                  kind = Bump;
                  commit = c;
                  before;
                  after;
                  totals = measure c parent;
                })
  in
  let is_bump (c : Repo.commit) =
    List.exists (fun (u : unit_) -> u.commit.hash = c.hash) bumps
  in
  (* Pin values are not read for keyword units: they did not change, and
     reading them costs a fetch per commit in a blob-less clone. *)
  let no_values = List.map (fun _ -> []) h.pins in
  let keyword_units =
    if h.keywords = [] then []
    else
      List.filter_map
        (fun (c : Repo.commit) ->
          match c.parents with
          | parent :: _
            when in_periods h.keyword_periods c.date
                 && contains_any ~words:h.keywords (c.subject ^ "\n" ^ c.body)
                 && not (is_bump c) ->
              Some
                {
                  kind = Keyword;
                  commit = c;
                  before = no_values;
                  after = no_values;
                  totals = measure c parent;
                }
          | _ -> None)
        all
  in
  let position = Hashtbl.create 256 in
  List.iteri (fun i (c : Repo.commit) -> Hashtbl.replace position c.hash i) all;
  let pos (u : unit_) =
    Option.value (Hashtbl.find_opt position u.commit.hash) ~default:max_int
  in
  let ordered =
    List.stable_sort (fun a b -> compare (pos a) (pos b)) (bumps @ keyword_units)
  in
  let resolutions values =
    List.concat
      (List.map2 (fun pin vs -> List.map (resolve pin) vs) h.pins values)
  in
  let per_resolvable_pin f before after =
    List.concat
      (List.map2
         (fun ((pin : Pin.t), before) after ->
           if pin.resolve = Pin.Opaque then [] else f pin before after)
         (List.combine h.pins before)
         after)
  in
  let summarise (u : unit_) =
    let before = List.map Pin.union u.before
    and after = List.map Pin.union u.after in
    let from_found = found (resolutions before) in
    let already (r : Release.t) =
      List.exists (fun (f : Release.t) -> f.version = r.version) from_found
    in
    let reached =
      resolutions (List.map2 minus after before)
      |> List.filter (function Found r -> not (already r) | _ -> true)
    in
    (* Per file of a resolvable pin: its values before and after. *)
    let file_changes =
      per_resolvable_pin
        (fun pin before after ->
          let paths =
            List.sort_uniq compare (List.map fst before @ List.map fst after)
          in
          List.filter_map
            (fun path ->
              let get l = Option.value (List.assoc_opt path l) ~default:[] in
              let b = get before and a = get after in
              if a = b then None
              else
                let keys = List.map (key pin) in
                Some (keys (minus a b), keys a))
            paths)
        u.before u.after
    in
    {
      kind = u.kind;
      commits = [ u.commit ];
      last = u.commit;
      from_ = List.concat before;
      to_ = List.concat after;
      reached = List.filter_map label reached;
      new_release =
        List.exists
          (function Found _ | Unreleased -> true | _ -> false)
          reached;
      from_found;
      to_found = found (resolutions after);
      introduced = List.concat_map fst file_changes;
      resolvable_after =
        List.combine h.pins after
        |> List.concat_map (fun ((pin : Pin.t), vs) ->
            if pin.resolve = Pin.Opaque then [] else List.map (key pin) vs);
      moves = file_changes;
      totals = u.totals;
    }
  in
  (* [u] completes the bump [prev] (an upgrade split over several pin files)
     when it reaches no new release, moves some file of a resolvable pin to a
     value that [prev] introduced, and every such file it changes ends on
     values that [prev] reached. *)
  let completes prev u =
    prev.kind = Bump && u.kind = Bump && (not u.new_release)
    && List.exists
         (fun (news, _) ->
           List.exists (fun k -> List.mem k prev.introduced) news)
         u.moves
    && List.for_all
         (fun (_, afters) ->
           afters <> []
           && List.for_all (fun k -> List.mem k prev.resolvable_after) afters)
         u.moves
  in
  let merge prev u =
    {
      prev with
      commits = prev.commits @ u.commits;
      last = u.last;
      to_ = u.to_;
      reached = prev.reached @ minus u.reached prev.reached;
      to_found = u.to_found;
      introduced = prev.introduced @ u.introduced;
      resolvable_after = u.resolvable_after;
      totals = Numstat.add prev.totals u.totals;
    }
  in
  let grouped =
    List.fold_left
      (fun acc u ->
        match acc with
        | prev :: rest when completes prev u -> merge prev u :: rest
        | _ -> u :: acc)
      []
      (List.map summarise ordered)
    |> List.rev
  in
  List.map
    (fun s ->
      let bump = s.kind = Bump in
      {
        project = p.name;
        kind = s.kind;
        units = List.map (fun (c : Repo.commit) -> short c.hash) s.commits;
        date = s.last.date;
        subject = s.last.subject;
        from_ = s.from_;
        to_ = s.to_;
        reached = s.reached;
        to_series = (if bump then Tool.newest_series tool s.to_found else None);
        spanned =
          (if bump then Tool.spanned tool ~from:s.from_found ~to_:s.to_found
           else None);
        totals = s.totals;
        authors = [];
      })
    grouped

let snapshots (p : Project.t) (s : Project.snapshots) ~tool ~clones =
  let repo : Repo.t = clones p.clone in
  let release tag =
    match Tool.find tool tag with
    | Some r -> r
    | None ->
        failwith
          (Printf.sprintf "%s: release %s missing from the %s release list"
             p.name tag (Tool.name tool))
  in
  let rec pairs = function
    | a :: (b :: _ as rest) -> (a, b) :: pairs rest
    | _ -> []
  in
  List.concat_map
    (fun ((tag_a, ref_a), (tag_b, ref_b)) ->
      let ra = release tag_a and rb = release tag_b in
      let entries = repo.numstat ref_a ref_b in
      List.map
        (fun path ->
          {
            project = p.name;
            kind = Snapshot;
            units = [ tag_a ^ ".." ^ tag_b ];
            date = rb.date;
            subject = path;
            from_ = [ tag_a ];
            to_ = [ tag_b ];
            reached = [ rb.version ];
            to_series = Tool.series tool rb;
            spanned = Tool.spanned tool ~from:[ ra ] ~to_:[ rb ];
            totals =
              List.filter
                (Numstat.keep ~under:[ path ] ~exclude:s.exclude_snapshot)
                entries
              |> Numstat.totals;
            authors =
              (match s.authors_from with
              | Some clone ->
                  (clones clone : Repo.t).authors ~since:ra.date ~until:rb.date
                    path
              | None -> []);
          })
        s.paths)
    (pairs s.refs)

let run (p : Project.t) ~tool ~clones ~since ~until =
  match p.mode with
  | Project.History h -> history p h ~tool ~clones ~since ~until
  | Project.Snapshots s -> snapshots p s ~tool ~clones
