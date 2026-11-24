type t = string

let make dir =
  if Filename.is_relative dir then Filename.concat (Sys.getcwd ()) dir else dir

let workdir t = t
let opam_root t = Filename.concat t "opam"
let downloads t = Filename.concat t "downloads"
let switches t = Filename.concat t "switches"
let build t = Filename.concat t "build"
let cache t = Filename.concat t "cache"
let logs t = Filename.concat t "logs"

let environment t =
  Command.Set ("XDG_CACHE_HOME", cache t)
  :: Command.Set ("GIT_CONFIG_GLOBAL", "/dev/null")
  :: List.map
       (fun v -> Command.Unset v)
       [
         "OPAMSWITCH";
         "OPAM_SWITCH_PREFIX";
         "OCAMLPATH";
         "OCAMLFIND_CONF";
         "CAML_LD_LIBRARY_PATH";
       ]
