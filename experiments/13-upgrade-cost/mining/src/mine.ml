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
  to_release : bool;
      (** Whether some file of a resolvable pin moves to a value that resolves
          to a release. *)
  introduced : string list;
      (** Keys of the resolvable values that some file did not hold before. *)
  landed : string list;
      (** Keys of all the values that the changed files of resolvable pins hold
          after the unit. *)
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

(* Whether the values read by the pins differ between [before] and [after]
   (per pin, per file): the values of a pin change, or a file that holds
   values both before and after changes them. The second case is an upgrade
   split over three or more files, whose middle steps leave the values of the
   pin unchanged. A pin file that appears or disappears without values is no
   change. *)
let pins_changed before after =
  List.map Pin.union before <> List.map Pin.union after
  || List.exists2
       (fun before after ->
         List.exists
           (fun (path, b) ->
             match List.assoc_opt path after with
             | Some a -> b <> [] && a <> [] && a <> b
             | None -> false)
           before)
       before after

(* [summarise ~resolve ~key pins u] resolves the values of [u]. *)
let summarise ~resolve ~key pins (u : unit_) =
  let resolutions values =
    List.concat
      (List.map2 (fun pin vs -> List.map (resolve pin) vs) pins values)
  in
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
  (* Per file of a resolvable pin whose values change: the pin, the file's
     new values and all its values after. *)
  let changed_files =
    List.combine pins (List.combine u.before u.after)
    |> List.concat_map (fun ((pin : Pin.t), (before, after)) ->
        if pin.resolve = Pin.Opaque then []
        else
          let paths =
            List.sort_uniq compare (List.map fst before @ List.map fst after)
          in
          List.filter_map
            (fun path ->
              let get l = Option.value (List.assoc_opt path l) ~default:[] in
              let b = get before and a = get after in
              if a = b then None else Some (pin, minus a b, a))
            paths)
  in
  let moves =
    List.map
      (fun (pin, news, afters) ->
        (List.map (key pin) news, List.map (key pin) afters))
      changed_files
  in
  {
    kind = u.kind;
    commits = [ u.commit ];
    last = u.commit;
    from_ = Util.dedup (List.concat before);
    to_ = Util.dedup (List.concat after);
    reached = List.filter_map label reached;
    new_release =
      List.exists (function Found _ | Unreleased -> true | _ -> false) reached;
    from_found;
    to_found = found (resolutions after);
    to_release =
      List.exists
        (fun (pin, news, _) ->
          List.exists
            (fun v -> match resolve pin v with Found _ -> true | _ -> false)
            news)
        changed_files;
    introduced = List.concat_map fst moves;
    landed = List.concat_map snd moves;
    moves;
    totals = u.totals;
  }

(* [completes prev u]: [u] is the second half of the bump [prev], an upgrade
   split over several pin files. It reaches no new release, moves some file of
   a resolvable pin to a value that [prev] introduced, and every such file it
   changes ends on values that the files changed by [prev] hold after it. *)
let completes prev u =
  prev.kind = Bump && u.kind = Bump && (not u.new_release)
  && List.exists
       (fun (news, _) -> List.exists (fun k -> List.mem k prev.introduced) news)
       u.moves
  && List.for_all
       (fun (_, afters) ->
         afters <> [] && List.for_all (fun k -> List.mem k prev.landed) afters)
       u.moves

let merge prev u =
  {
    prev with
    commits = prev.commits @ u.commits;
    last = u.last;
    to_ = u.to_;
    reached = prev.reached @ minus u.reached prev.reached;
    to_found = u.to_found;
    to_release = prev.to_release || u.to_release;
    introduced = prev.introduced @ u.introduced;
    landed = prev.landed @ u.landed;
    totals = Numstat.add prev.totals u.totals;
  }

let group summaries =
  List.fold_left
    (fun acc u ->
      match acc with
      | prev :: rest when completes prev u -> merge prev u :: rest
      | _ -> u :: acc)
    [] summaries
  |> List.rev

let pin_patterns (h : Project.history) =
  List.concat_map (fun (pin : Pin.t) -> pin.files) h.pins

(* Patterns of the files that commit mode does not measure. *)
let history_exclude (h : Project.history) = h.exclude @ pin_patterns h

let history (p : Project.t) (h : Project.history) ~tool ~clones ~since ~until =
  let repo : Repo.t = clones p.clone in
  let pin_patterns = pin_patterns h in
  let values_at =
    Util.memo (fun commit ->
        let files =
          repo.files commit
          |> List.filter (fun path ->
              List.exists (fun pin -> Pin.matches_file pin path) h.pins)
          |> List.map (fun path -> (path, repo.show commit path))
        in
        try List.map (fun pin -> Pin.file_values pin files) h.pins
        with Failure msg ->
          failwith
            (Printf.sprintf "%s, commit %s: %s" p.name (short commit) msg))
  in
  let tags_containing =
    Util.memo (fun (clone, value) ->
        (clones clone : Repo.t).tags_containing value)
  in
  let resolve (pin : Pin.t) value =
    match pin.resolve with
    | Pin.Opaque -> Opaque_value
    | Pin.Release -> (
        match Tool.find tool value with
        | Some r -> Found r
        | None -> Unresolved value)
    | Pin.Commit clone -> (
        match tags_containing (clone, value) with
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
  let keep =
    Numstat.keep
      ~under:(Project.measured_dirs h.under)
      ~only:h.only ~exclude:(history_exclude h)
  in
  let measure (c : Repo.commit) parent =
    match repo.numstat parent c.hash with
    | entries -> List.filter keep entries |> Numstat.totals
    | exception Failure msg ->
        failwith
          (Printf.sprintf "%s, diff %s..%s: %s" p.name (short parent)
             (short c.hash) msg)
  in
  let all = repo.first_parent_log ~head:h.head ~since ~until ~paths:[] in
  let bumps =
    repo.first_parent_log ~head:h.head ~since ~until ~paths:pin_patterns
    |> List.filter_map (fun (c : Repo.commit) ->
        match c.parents with
        | [] -> None
        | parent :: _ ->
            let before = values_at parent and after = values_at c.hash in
            if pins_changed before after then
              Some
                {
                  kind = Bump;
                  commit = c;
                  before;
                  after;
                  totals = measure c parent;
                }
            else None)
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
  List.stable_sort (fun a b -> compare (pos a) (pos b)) (bumps @ keyword_units)
  |> List.map (summarise ~resolve ~key h.pins)
  |> group
  |> List.map (fun s ->
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
        to_series =
          (if bump && s.to_release then Tool.newest_series tool s.to_found
           else None);
        spanned =
          (if bump then Tool.spanned tool ~from:s.from_found ~to_:s.to_found
           else None);
        totals = s.totals;
        authors = [];
      })

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
                (Numstat.keep ~under:[ path ] ~only:[]
                   ~exclude:s.exclude_snapshot)
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

type missing = { path : string; where : string; commit : string }

let missing_paths (p : Project.t) ~clones ~since ~until =
  let repo : Repo.t = clones p.clone in
  let files = Util.memo repo.files in
  (* [measured ~only ~exclude commit path] holds iff the tree of [commit] has a
     file under [path] that the rows would measure. *)
  let measured ~only ~exclude commit path =
    List.exists
      (fun file ->
        Numstat.keep ~under:[ path ] ~only ~exclude
          { Numstat.path = file; added = None; removed = None })
      (files commit)
  in
  match p.mode with
  | Project.History { under = []; _ } -> []
  | Project.History h -> (
      match repo.first_parent_log ~head:h.head ~since ~until ~paths:[] with
      | [] -> []
      | first :: _ ->
          let start =
            match first.parents with parent :: _ -> parent | [] -> first.hash
          in
          let measured = measured ~only:h.only ~exclude:(history_exclude h) in
          let report ~where commit paths =
            List.filter_map
              (fun path ->
                if measured commit path then None
                else Some { path; where; commit = short commit })
              paths
          in
          List.concat_map
            (fun (d : Project.dir) ->
              (* Before a move, each former path must hold files: one that
                 does not is a wrong entry, whatever the other ones hold. *)
              (if measured start d.path then []
               else
                 report ~where:"window start" start
                   (match d.formerly with [] -> [ d.path ] | f -> f))
              @ report ~where:"head" h.head [ d.path ])
            h.under)
  | Project.Snapshots s -> (
      match (s.refs, List.rev s.refs) with
      | (first_tag, first_ref) :: _, (last_tag, last_ref) :: _ ->
          let report (where, commit) path =
            if measured ~only:[] ~exclude:s.exclude_snapshot commit path then
              None
            else Some { path; where; commit }
          in
          List.concat_map
            (fun path ->
              List.filter_map
                (fun release -> report release path)
                [ (first_tag, first_ref); (last_tag, last_ref) ])
            s.paths
          |> Util.dedup
      | _ -> [])

let missing_to_string m =
  Printf.sprintf "%s missing at %s (%s)" m.path m.where m.commit
