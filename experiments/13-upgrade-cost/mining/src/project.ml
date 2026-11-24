type dir = { path : string; formerly : string list }

type history = {
  head : string;
  pins : Pin.t list;
  under : dir list;
  only : string list;
  exclude : string list;
  keywords : string list;
  keyword_periods : (string * string) list;
}

type snapshots = {
  refs : (string * string) list;
  paths : string list;
  exclude_snapshot : string list;
  authors_from : string option;
}

type mode = History of history | Snapshots of snapshots
type t = { name : string; tool : string; clone : string; mode : mode }

let dir ?(formerly = []) path = { path; formerly }
let measured_dirs = List.concat_map (fun d -> d.path :: d.formerly)
