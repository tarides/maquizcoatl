(* Experiment #8, F*: subexpression calls with the nest limit.
   Semantics fixed in lab/08-hard-features/SEMANTICS.md, section "Calls".
   Pure F* (no Pulse: a semantics has no imperative state), checked with
   the Pulse-enabled fstar.exe of the stack C toolchain. *)
module Calls
open FStar.List.Tot

type re =
  | Eps | Chr of nat | Any | Seq of re & re | Alt of re & re | Star of re
  | Call of nat | Bos | Eos

type item = | R of re | Ret | Chk of nat & re

let rec nth (#a:Type) (l:list a) (n:nat) : option a =
  match l with
  | [] -> None
  | x :: t -> if n = 0 then Some x else nth t (n - 1)

(* m lim defs s f ks i d mx: results (end, max depth) of the pending items
   ks at position i, nest depth d (live call frames), running maximum mx. *)
let rec m (lim:nat) (defs:list re) (s:list nat) (f:nat) (ks:list item) (i d mx:nat)
  : Tot (list (nat & nat)) (decreases f) =
  if f = 0 then [] else
  let f = f - 1 in
  match ks with
  | [] -> [(i, mx)]
  | R Eps :: ks -> m lim defs s f ks i d mx
  | R (Chr c) :: ks ->
    (match nth s i with Some c' -> if c = c' then m lim defs s f ks (i + 1) d mx else [] | None -> [])
  | R Any :: ks ->
    (match nth s i with Some c' -> if c' = 10 then [] else m lim defs s f ks (i + 1) d mx | None -> [])
  | R (Seq (a, b)) :: ks -> m lim defs s f (R a :: R b :: ks) i d mx
  | R (Alt (a, b)) :: ks -> m lim defs s f (R a :: ks) i d mx @ m lim defs s f (R b :: ks) i d mx
  | R (Star a) :: ks -> m lim defs s f (R a :: Chk (i, a) :: ks) i d mx @ m lim defs s f ks i d mx
  | Chk (i0, a) :: ks ->
    if i = i0 then m lim defs s f ks i d mx else m lim defs s f (R (Star a) :: ks) i d mx
  | R (Call n) :: ks ->
    if lim <= d then []
    else (match nth defs n with
          | Some b -> m lim defs s f (R b :: Ret :: ks) i (d + 1) (if mx >= d + 1 then mx else d + 1)
          | None -> [])
  | Ret :: ks -> m lim defs s f ks i (if d = 0 then 0 else d - 1) mx
  | R Bos :: ks -> if i = 0 then m lim defs s f ks i d mx else []
  | R Eos :: ks -> if i = length s then m lim defs s f ks i d mx else []

let rec search_from (lim:nat) (defs:list re) (s:list nat) (f:nat) (main:re) (k st:nat)
  : Tot (option (nat & nat)) (decreases k) =
  if k = 0 then None else
  match m lim defs s f [R main] st 0 0 with
  | (e, _) :: _ -> Some (st, e)
  | [] -> search_from lim defs s f main (k - 1) (st + 1)

let default_limit : nat = 20
let fuel : nat = 1000
let search (lim:nat) (defs:list re) (main:re) (s:list nat) : option (nat & nat) =
  search_from lim defs s fuel main (length s + 1) 0

(* Main lemma (SEMANTICS.md, "Calls", lemma C). *)
let rec depth_bound (lim:nat) (defs:list re) (s:list nat) (f:nat) (ks:list item) (i d mx:nat) (p:nat & nat)
  : Lemma (requires d <= lim /\ mx <= lim /\ memP p (m lim defs s f ks i d mx))
          (ensures snd p <= lim) (decreases f) =
  if f = 0 then () else
  let f' = f - 1 in
  match ks with
  | [] -> ()
  | R Eps :: ks -> depth_bound lim defs s f' ks i d mx p
  | R (Chr c) :: ks -> depth_bound lim defs s f' ks (i + 1) d mx p
  | R Any :: ks -> depth_bound lim defs s f' ks (i + 1) d mx p
  | R (Seq (a, b)) :: ks -> depth_bound lim defs s f' (R a :: R b :: ks) i d mx p
  | R (Alt (a, b)) :: ks ->
    FStar.List.Tot.Properties.append_memP (m lim defs s f' (R a :: ks) i d mx) (m lim defs s f' (R b :: ks) i d mx) p;
    FStar.Classical.move_requires (depth_bound lim defs s f' (R a :: ks) i d mx) p;
    FStar.Classical.move_requires (depth_bound lim defs s f' (R b :: ks) i d mx) p
  | R (Star a) :: ks ->
    FStar.List.Tot.Properties.append_memP (m lim defs s f' (R a :: Chk (i, a) :: ks) i d mx) (m lim defs s f' ks i d mx) p;
    FStar.Classical.move_requires (depth_bound lim defs s f' (R a :: Chk (i, a) :: ks) i d mx) p;
    FStar.Classical.move_requires (depth_bound lim defs s f' ks i d mx) p
  | Chk (i0, a) :: ks ->
    if i = i0 then depth_bound lim defs s f' ks i d mx p
    else depth_bound lim defs s f' (R (Star a) :: ks) i d mx p
  | R (Call n) :: ks ->
    if lim <= d then ()
    else (match nth defs n with
          | Some b -> depth_bound lim defs s f' (R b :: Ret :: ks) i (d + 1) (if mx >= d + 1 then mx else d + 1) p
          | None -> ())
  | Ret :: ks -> depth_bound lim defs s f' ks i (if d = 0 then 0 else d - 1) mx p
  | R Bos :: ks -> depth_bound lim defs s f' ks i d mx p
  | R Eos :: ks -> depth_bound lim defs s f' ks i d mx p

(* Test cases (cases/calls.tsv, nest.tsv); a=97 b=98 (=40 )=41. *)
let a = Chr 97
let b = Chr 98
let lp = Chr 40
let rp = Chr 41
let d1 = [a]
let m1 = Seq (Call 0, Call 0)
let d2 = [Seq (a, b)]
let d3 = [Alt (Seq (a, Call 0), Eps)]
let m3 = Seq (Bos, Seq (Call 0, Eos))
let d4 = [Alt (a, Seq (lp, Seq (Call 0, rp)))]
let d5 = [Alt (Seq (a, Call 0), b)]
let s4 : list nat = [40;40;40;40;40;40;97;41;41;41;41;41;41]

let ca01 = assert_norm (search default_limit d1 m1 [97;97] == Some (0, 2))
let ca02 = assert_norm (search default_limit d2 m1 [97;98;97;98] == Some (0, 4))
let ca03 = assert_norm (search default_limit d3 m3 [97;97;97;97] == Some (0, 4))
let ca04 = assert_norm (search default_limit d4 (Call 0) s4 == Some (0, 13))
let ca05 = assert_norm (search default_limit d5 m3 [97;97;97;98] == Some (0, 4))
let nc01 = assert_norm (search 2 d5 m3 [97;97;97;98] == None)
let nc02 = assert_norm (search 20 d5 m3 [97;97;97;98] == Some (0, 4))
let nc03 = assert_norm (search 2 d4 (Call 0) s4 == Some (5, 8))
let nc04 = assert_norm (search 0 d1 m1 [97;97] == None)
let ns01_3 = assert_norm (search 3 d5 m3 [97;97;97;98] == None)
let ns01_4 = assert_norm (search 4 d5 m3 [97;97;97;98] == Some (0, 4))
let ns02_1 = assert_norm (search 1 d4 (Call 0) s4 == Some (6, 7))
let ns02_6 = assert_norm (search 6 d4 (Call 0) s4 == Some (1, 12))
let ns02_7 = assert_norm (search 7 d4 (Call 0) s4 == Some (0, 13))
