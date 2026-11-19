type history = {
  pins : Pin.t list;
  under : string list;
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

type t = {
  name : string;
  tool : string;
  clone : string;
  head : string;
  mode : mode;
}
