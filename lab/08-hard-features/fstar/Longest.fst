(* Experiment #8, F*: ONIG_OPTION_FIND_LONGEST (forward search).
   Semantics fixed in lab/08-hard-features/SEMANTICS.md, "FIND_LONGEST". *)
module Longest
open FStar.List.Tot

type re = | Eps | Chr of nat | Word | Seq of re & re | Alt of re & re | Star of re
type item = | R of re | Chk of nat & re

(* \w on ASCII: [0-9A-Za-z_] *)
let is_word (c:nat) : bool =
  (48 <= c && c <= 57) || (65 <= c && c <= 90) || (97 <= c && c <= 122) || c = 95

let rec nth (l:list nat) (n:nat) : option nat =
  match l with [] -> None | x :: t -> if n = 0 then Some x else nth t (n - 1)

let rec m (s:list nat) (f:nat) (ks:list item) (i:nat) : Tot (list nat) (decreases f) =
  if f = 0 then [] else
  let f = f - 1 in
  match ks with
  | [] -> [i]
  | R Eps :: ks -> m s f ks i
  | R (Chr c) :: ks -> (match nth s i with Some c' -> if c = c' then m s f ks (i + 1) else [] | None -> [])
  | R Word :: ks -> (match nth s i with Some c' -> if is_word c' then m s f ks (i + 1) else [] | None -> [])
  | R (Seq (a, b)) :: ks -> m s f (R a :: R b :: ks) i
  | R (Alt (a, b)) :: ks -> m s f (R a :: ks) i @ m s f (R b :: ks) i
  | R (Star a) :: ks -> m s f (R a :: Chk (i, a) :: ks) i @ m s f ks i
  | Chk (i0, a) :: ks -> if i = i0 then m s f ks i else m s f (R (Star a) :: ks) i

let fuel : nat = 1000

(* First-match search. *)
let rec search_from (s:list nat) (main:re) (k st:nat) : Tot (option (nat & nat)) (decreases k) =
  if k = 0 then None else
  match m s fuel [R main] st with
  | e :: _ -> Some (st, e)
  | [] -> search_from s main (k - 1) (st + 1)

let search (main:re) (s:list nat) = search_from s main (length s + 1) 0

let better (st e:nat) (b:option (nat & nat)) : bool =
  match b with None -> true | Some (s0, e0) -> e0 - s0 < e - st

let rec pick (st:nat) (b:option (nat & nat)) (l:list nat) : Tot (option (nat & nat)) (decreases l) =
  match l with [] -> b | e :: es -> pick st (if better st e b then Some (st, e) else b) es

(* FIND_LONGEST: every start, every result, the first of maximal length. *)
let rec longest_from (s:list nat) (main:re) (b:option (nat & nat)) (k st:nat)
  : Tot (option (nat & nat)) (decreases k) =
  if k = 0 then b else longest_from s main (pick st b (m s fuel [R main] st)) (k - 1) (st + 1)

let longest (main:re) (s:list nat) = longest_from s main None (length s + 1) 0

let ge (b:option (nat & nat)) (n:int) : prop =
  match b with None -> False | Some (a, e) -> n <= e - a

(* Main lemma (SEMANTICS.md, "FIND_LONGEST", lemma L). *)
let rec pick_mono (st:nat) (l:list nat) (b:option (nat & nat)) (n:int)
  : Lemma (requires ge b n) (ensures ge (pick st b l) n) (decreases l) =
  match l with [] -> () | e :: es -> pick_mono st es (if better st e b then Some (st, e) else b) n

let rec pick_mem (st:nat) (l:list nat) (b:option (nat & nat)) (e:nat)
  : Lemma (requires memP e l) (ensures ge (pick st b l) (e - st)) (decreases l) =
  match l with
  | e' :: es ->
    let b' = if better st e' b then Some (st, e') else b in
    if e = e' then pick_mono st es b' (e - st)
    else pick_mem st es b' e

let rec longest_mono (s:list nat) (main:re) (k st:nat) (b:option (nat & nat)) (n:int)
  : Lemma (requires ge b n) (ensures ge (longest_from s main b k st) n) (decreases k) =
  if k = 0 then () else begin
    pick_mono st (m s fuel [R main] st) b n;
    longest_mono s main (k - 1) (st + 1) (pick st b (m s fuel [R main] st)) n
  end

let rec longest_ge_first (s:list nat) (main:re) (k st:nat) (b:option (nat & nat)) (s1 e1:nat)
  : Lemma (requires search_from s main k st == Some (s1, e1))
          (ensures ge (longest_from s main b k st) (e1 - s1)) (decreases k) =
  if k = 0 then () else
  match m s fuel [R main] st with
  | e :: _ ->
    pick_mem st (m s fuel [R main] st) b e;
    longest_mono s main (k - 1) (st + 1) (pick st b (m s fuel [R main] st)) (e - st)
  | [] -> longest_ge_first s main (k - 1) (st + 1) (pick st b (m s fuel [R main] st)) s1 e1

let longest_no_shorter (main:re) (s:list nat) (s1 e1:nat)
  : Lemma (requires search main s == Some (s1, e1))
          (ensures (match longest main s with
                    | Some (s2, e2) -> e1 - s1 <= e2 - s2
                    | None -> False)) =
  longest_ge_first s main (length s + 1) 0 None s1 e1

(* Test cases (cases/find-longest.tsv). *)
let w1 = Seq (Word, Star Word)
let a = Chr 97
let bcd = Seq (Chr 98, Seq (Chr 99, Chr 100))
let ab = Seq (Chr 97, Chr 98)
let s1 : list nat = [97;98;99;32;100;101;102;103;32;104;105;106]
let s2 : list nat = [97;98;32;99;100;32;101;102]
let s3 : list nat = [97;98;99;100]
let s4 : list nat = [97;98]

let fl01 = assert_norm (longest w1 s1 == Some (4, 8))
let fl02 = assert_norm (longest w1 s2 == Some (0, 2))
let fl03 = assert_norm (longest (Alt (a, bcd)) s3 == Some (1, 4))
let fl04 = assert_norm (longest (Alt (a, ab)) s4 == Some (0, 2))
let fl05 = assert_norm (search (Alt (a, bcd)) s3 == Some (0, 1))
let fl06 = assert_norm (search (Alt (a, ab)) s4 == Some (0, 1))
