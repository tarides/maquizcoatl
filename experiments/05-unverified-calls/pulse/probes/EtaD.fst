module EtaD
#lang-pulse
open Pulse.Lib.Pervasives
module I32 = FStar.Int32

(* eta_d g a calls g a and returns its result. *)
fn eta_d (g: ((a: ref I32.t) -> stt I32.t (exists* v. a |-> v) (fun _ -> exists* v. a |-> v)))
  (a: ref I32.t)
  requires exists* v. a |-> v
  returns r: I32.t
  ensures exists* v'. a |-> v'
{ g a }
