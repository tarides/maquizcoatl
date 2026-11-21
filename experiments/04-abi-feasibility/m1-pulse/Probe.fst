(* Probe.fst: the ABI constructs of libonig written in F* / Pulse, to
   see what each emitter (1a KaRaMeL via --codegen KrmlC, 1b Custard via
   --codegen C) produces for them. One definition per construct. *)
module Probe
#lang-pulse
open Pulse.Lib.Pervasives
module U8 = FStar.UInt8
module U32 = FStar.UInt32
module I32 = FStar.Int32

(* (0) an exported function, lower-case C name, scalar arguments *)
let onig_version_num (x: I32.t) : I32.t = x

(* (1) a Pulse function taking pointers (OnigRegex, OnigRegion* ...) *)
fn onig_free (reg: ref U8.t)
  requires emp
  ensures emp
{
  ()
}

(* (2) a struct whose fields include function pointers (OnigEncodingType) *)
noeq type enc = {
  mbc_enc_len : (p: ref U8.t) -> I32.t;
  name_len : I32.t;
  max_enc_len : I32.t;
  code_to_mbclen : U32.t -> I32.t;
  flag : U32.t;
}

let s_mbc_enc_len (p: ref U8.t) : I32.t = 1l
let s_code_to_mbclen (c: U32.t) : I32.t = 1l

(* (3) a global struct initialised with function pointers, exported under
   an exact mixed-case name (OnigEncodingUTF8). F* value names start
   with a lower-case letter; rename_let asks for an exact C identifier
   (Custard direct C only, per FStar.Attributes). *)
[@@ rename_let "OnigEncodingUTF8"]
let onigEncodingUTF8 : enc = {
  mbc_enc_len = s_mbc_enc_len;
  name_len = 4l;
  max_enc_len = 4l;
  code_to_mbclen = s_code_to_mbclen;
  flag = 0ul;
}

(* (4) a scalar data symbol with an exact name (OnigDefaultCaseFoldFlag) *)
[@@ rename_let "OnigDefaultCaseFoldFlag"]
let onigDefaultCaseFoldFlag : U32.t = 0x40000000ul

(* (5) a function reading the struct through its function pointer, so
   that the global is used *)
let enc_len_of (e: enc) (c: U32.t) : I32.t = e.code_to_mbclen c
let utf8_len (c: U32.t) : I32.t = enc_len_of onigEncodingUTF8 c

(* (6) the variadic onig_error_code_to_str: F* has no C-variadic
   function type; the closest is a fixed-arity declaration of an external
   symbol (custard_extern), whose body is written in C. *)
[@@ custard_extern "onig_error_code_to_str"]
assume val onig_error_code_to_str2 : (s: ref U8.t) -> (code: I32.t) -> I32.t
let call_err (s: ref U8.t) : I32.t = onig_error_code_to_str2 s 0l
