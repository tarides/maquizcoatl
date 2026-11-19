(* Experiment #8, F*: the absent operator (non-nested).
   Semantics fixed in lab/08-hard-features/SEMANTICS.md, "Absent operator".
   The state carries the right range rr; every consuming step checks i < rr. *)
module Absent
open FStar.List.Tot

type re =
  | Eps | Chr of nat | Any | AnyO | Seq of re & re | Alt of re & re | Star of re
  | AbsRep of re | AbsExp of re & re | Stopper of re | RClear

type item = | R of re | Chk of nat & re | SetRR of nat | Ends of list nat

let rec nth (l:list nat) (n:nat) : option nat =
  match l with [] -> None | x :: t -> if n = 0 then Some x else nth t (n - 1)

let at_ (s:list nat) (i rr:nat) : option nat = if i < rr then nth s i else None

(* Base matcher, absent-free patterns: does ks have a result at i? *)
let rec mb (s:list nat) (f:nat) (ks:list item) (i rr:nat) : Tot bool (decreases f) =
  if f = 0 then false else
  let f = f - 1 in
  match ks with
  | [] -> true
  | R Eps :: ks -> mb s f ks i rr
  | R (Chr c) :: ks -> (match at_ s i rr with Some c' -> c = c' && mb s f ks (i + 1) rr | None -> false)
  | R Any :: ks -> (match at_ s i rr with Some c' -> c' <> 10 && mb s f ks (i + 1) rr | None -> false)
  | R AnyO :: ks -> (match at_ s i rr with Some _ -> mb s f ks (i + 1) rr | None -> false)
  | R (Seq (a, b)) :: ks -> mb s f (R a :: R b :: ks) i rr
  | R (Alt (a, b)) :: ks -> mb s f (R a :: ks) i rr || mb s f (R b :: ks) i rr
  | R (Star a) :: ks -> mb s f (R a :: Chk (i, a) :: ks) i rr || mb s f ks i rr
  | Chk (i0, a) :: ks -> if i = i0 then mb s f ks i rr else mb s f (R (Star a) :: ks) i rr
  | SetRR n :: ks -> mb s f ks i n
  | _ :: _ -> false (* absent constructors, Ends: out of scope here *)

let fuel : nat = 1000
let occ (a:re) (s:list nat) (p rr:nat) : bool = mb s fuel [R a] p rr

let rec scan (a:re) (s:list nat) (rr:nat) (k p:nat) : Tot nat (decreases k) =
  if k = 0 then p else if occ a s p rr then p else scan a s rr (k - 1) (p + 1)

let cut (a:re) (s:list nat) (i rr:nat) : nat = scan a s rr (if rr >= i then rr - i else 0) i

let rec downs (n i:nat) : Tot (list nat) (decreases n) =
  if n = 0 then [i] else (i + n) :: downs (n - 1) i

let rep_ends (a:re) (s:list nat) (i rr:nat) : list nat =
  let c = cut a s i rr in downs (if c >= i then c - i else 0) i

let rec m (s:list nat) (f:nat) (ks:list item) (i rr:nat) : Tot (list nat) (decreases f) =
  if f = 0 then [] else
  let f = f - 1 in
  match ks with
  | [] -> [i]
  | R Eps :: ks -> m s f ks i rr
  | R (Chr c) :: ks -> (match at_ s i rr with Some c' -> if c = c' then m s f ks (i + 1) rr else [] | None -> [])
  | R Any :: ks -> (match at_ s i rr with Some c' -> if c' = 10 then [] else m s f ks (i + 1) rr | None -> [])
  | R AnyO :: ks -> (match at_ s i rr with Some _ -> m s f ks (i + 1) rr | None -> [])
  | R (Seq (a, b)) :: ks -> m s f (R a :: R b :: ks) i rr
  | R (Alt (a, b)) :: ks -> m s f (R a :: ks) i rr @ m s f (R b :: ks) i rr
  | R (Star a) :: ks -> m s f (R a :: Chk (i, a) :: ks) i rr @ m s f ks i rr
  | Chk (i0, a) :: ks -> if i = i0 then m s f ks i rr else m s f (R (Star a) :: ks) i rr
  | SetRR n :: ks -> m s f ks i n
  | R (AbsRep a) :: ks -> m s f (Ends (rep_ends a s i rr) :: ks) i rr
  | Ends [] :: _ -> []
  | Ends (e :: es) :: ks -> m s f ks e rr @ m s f (Ends es :: ks) i rr
  | R (AbsExp (a, e)) :: ks -> m s f (R e :: SetRR rr :: ks) i (cut a s i rr)
  | R (Stopper a) :: ks -> m s f ks i (cut a s i rr)
  | R RClear :: ks -> m s f ks i (length s)

let rec search_from (s:list nat) (main:re) (k st:nat) : Tot (option (nat & nat)) (decreases k) =
  if k = 0 then None else
  match m s fuel [R main] st (length s) with
  | e :: _ -> Some (st, e)
  | [] -> search_from s main (k - 1) (st + 1)

let search (main:re) (s:list nat) : option (nat & nat) = search_from s main (length s + 1) 0

(* Main lemma (SEMANTICS.md, "Absent operator", lemma A). *)
let rec scan_ge (a:re) (s:list nat) (rr:nat) (k p:nat)
  : Lemma (ensures p <= scan a s rr k p) (decreases k) =
  if k = 0 then () else if occ a s p rr then () else scan_ge a s rr (k - 1) (p + 1)

let rec scan_none (a:re) (s:list nat) (rr:nat) (k p q:nat)
  : Lemma (requires p <= q /\ q < scan a s rr k p) (ensures occ a s q rr = false) (decreases k) =
  if k = 0 then () else if occ a s p rr then () else if q = p then () else scan_none a s rr (k - 1) (p + 1) q

let rec downs_mem (n i e:nat)
  : Lemma (requires memP e (downs n i)) (ensures i <= e /\ e <= i + n) (decreases n) =
  if n = 0 then () else if e = i + n then () else downs_mem (n - 1) i e

let absent_not_inside (a:re) (s:list nat) (i rr e:nat) (p:nat)
  : Lemma (requires memP e (rep_ends a s i rr) /\ i <= p /\ p < e) (ensures occ a s p rr = false) =
  let k = if rr >= i then rr - i else 0 in
  scan_ge a s rr k i;
  let c = cut a s i rr in
  downs_mem (if c >= i then c - i else 0) i e;
  scan_none a s rr k i p

(* Test cases (cases/absent.tsv); a=97 b=98 c=99 x=120 y=121 z=122. *)
let rec lit (l:list nat) : re =
  match l with [] -> Eps | [c] -> Chr c | c :: cs -> Seq (Chr c, lit cs)
let abc = lit [97;98;99]
let ostar = Star AnyO
let dotstar = Star Any
let s_abc : list nat = [97;98;99]
let s_xabcx : list nat = [120;97;98;99;120]
let s_xabz : list nat = [120;97;98;122]
let s_xxabcyy : list nat = [120;120;97;98;99;121;121]
let s_a10 : list nat = [97;97;97;97;97;97;97;97;97;97]

let ab01 = assert_norm (search (AbsRep (lit [97;98])) s_abc == Some (0, 0))
let ab02 = assert_norm (search (AbsRep abc) s_abc == Some (0, 0))
let ab03 = assert_norm (search (AbsRep (Alt (abc, lit [97;98]))) s_abc == Some (0, 0))
let ab04 = assert_norm (search (Seq (lit [97;97;97;97;97], AbsRep Eps)) s_a10 == Some (0, 5))
let ab05 = assert_norm (search (AbsExp (abc, ostar)) s_abc == Some (0, 0))
let ab06 = assert_norm (search (AbsRep abc) s_xabcx == Some (0, 1))
let ab07 = assert_norm (search (AbsExp (abc, ostar)) s_xabcx == Some (0, 1))
let ab08 = assert_norm (search (Seq (AbsRep abc, Chr 122)) s_xabz == Some (0, 4))
let ab09 = assert_norm (search (Seq (AbsExp (abc, ostar), Chr 122)) s_xabz == Some (0, 4))
let ab10 = assert_norm (search (Seq (Stopper abc, dotstar)) s_xxabcyy == Some (0, 2))
let ab11 = assert_norm (search (Seq (Stopper abc, Seq (RClear, dotstar))) s_xxabcyy == Some (0, 7))
