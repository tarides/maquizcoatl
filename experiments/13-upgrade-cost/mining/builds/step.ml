type on_failure = Stop | Continue

type t =
  | Run of {
      label : string;
      command : Command.t;
      creates : string option;
      clears : string option;
      on_failure : on_failure;
    }
  | Edit of { label : string; dir : string; edits : Edit.t list }
  | Mkdir of string
  | Touch of string
  | Rename of { src : string; dst : string }
  | Sha256 of { file : string; expected : string }
  | Remove of string

let run ?creates ?clears ?(on_failure = Stop) label command =
  Run { label; command; creates; clears; on_failure }

let label = function
  | Run { label; _ } | Edit { label; _ } -> label
  | Mkdir dir -> "mkdir " ^ Filename.basename dir
  | Touch file -> "touch " ^ Filename.basename file
  | Rename { dst; _ } -> "rename to " ^ Filename.basename dst
  | Sha256 { file; _ } -> "sha256 " ^ Filename.basename file
  | Remove path -> "remove " ^ path

let describe ~prefix = function
  | Run { label; command; creates; clears; on_failure } ->
      Printf.sprintf "%s%s%s%s\n    %s" label
        (match creates with
        | Some path -> " [skipped if " ^ path ^ " exists]"
        | None -> "")
        (match clears with
        | Some path -> " [first empties " ^ path ^ "]"
        | None -> "")
        (match on_failure with
        | Stop -> ""
        | Continue -> " [continue on failure]")
        (Command.to_string (Command.prefixed prefix command))
  | Edit { label; dir; edits } ->
      Printf.sprintf "%s\n%s" label
        (String.concat "\n"
           (List.map
              (fun e -> "    " ^ Edit.describe e ^ " (in " ^ dir ^ ")")
              edits))
  | Mkdir dir -> "mkdir -p " ^ Command.quote dir
  | Touch file -> "touch " ^ Command.quote file
  | Remove path -> "rm -rf " ^ Command.quote path
  | Rename { src; dst } ->
      Printf.sprintf "rename %s to %s" (Command.quote src) (Command.quote dst)
  | Sha256 { file; expected } ->
      Printf.sprintf "sha256 of %s must be %s" (Command.quote file) expected
