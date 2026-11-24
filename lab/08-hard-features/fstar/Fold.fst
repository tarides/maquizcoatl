(* Experiment #8, F*: ISO-8859-1 multi-character case folding.
   Semantics fixed in lab/08-hard-features/SEMANTICS.md, "ISO-8859-1 folding". *)
module Fold
open FStar.List.Tot

type re = | Eps | Chr of nat | Seq of re & re | Alt of re & re | ILit of list nat

(* One-byte fold items of get_case_fold_codes_by_str (iso8859_1.c:116-215),
   for a position that does not start a two-byte ss spelling. *)
let one (c:nat) : list (list nat) =
  if 65 <= c && c <= 90 then [[c + 32]]
  else if 97 <= c && c <= 122 then [[c - 32]]
  else if 192 <= c && c <= 207 then [[c + 32]]
  else if c = 223 then [[115;115]; [83;83]; [115;83]; [83;115]]
  else if 208 <= c && c <= 222 && c <> 215 then [[c + 32]]
  else if 224 <= c && c <= 239 then [[c - 32]]
  else if 240 <= c && c <= 254 && c <> 247 then [[c - 32]]
  else []

let is_s (c:nat) : bool = c = 115 || c = 83

(* Items of a two-byte ss spelling: 0xDF, then the other three spellings. *)
let ss_items (c d:nat) : list (list nat) =
  [223] :: filter (fun (w:list nat) -> match w with [x; y] -> not (x = c && y = d) | _ -> true)
                  [[83;83]; [83;115]; [115;83]; [115;115]]

(* unravel_case_fold_string: one segment per pattern position, each the
   list of alternatives, original bytes first. *)
let rec unr (prev:option nat) (w:list nat) : Tot (list (list (list nat))) (decreases w) =
  match prev, w with
  | None, [] -> []
  | Some c, [] -> [[c] :: one c]
  | None, c :: rest -> unr (Some c) rest
  | Some c, d :: rest ->
    if is_s c && is_s d then ([c; d] :: ss_items c d) :: unr None rest
    else ([c] :: one c) :: unr (Some d) rest
let unravel (w:list nat) = unr None w

type item = | R of re | Seg of list (list nat)

let rec nth (l:list nat) (n:nat) : option nat =
  match l with [] -> None | x :: t -> if n = 0 then Some x else nth t (n - 1)

(* help: explicit decreases; the default lexicographic order on (s, i, w) fails *)
let rec prefix_at (s:list nat) (i:nat) (w:list nat) : Tot bool (decreases w) =
  match w with
  | [] -> true
  | c :: w' -> (match nth s i with Some c' -> c = c' && prefix_at s (i + 1) w' | None -> false)

let rec m (s:list nat) (f:nat) (ks:list item) (i:nat) : Tot (list nat) (decreases f) =
  if f = 0 then [] else
  let f = f - 1 in
  match ks with
  | [] -> [i]
  | R Eps :: ks -> m s f ks i
  | R (Chr c) :: ks -> (match nth s i with Some c' -> if c = c' then m s f ks (i + 1) else [] | None -> [])
  | R (Seq (a, b)) :: ks -> m s f (R a :: R b :: ks) i
  | R (Alt (a, b)) :: ks -> m s f (R a :: ks) i @ m s f (R b :: ks) i
  | R (ILit w) :: ks -> m s f (map Seg (unravel w) @ ks) i
  | Seg [] :: _ -> []
  | Seg (w :: ws) :: ks ->
    (if prefix_at s i w then m s f ks (i + length w) else []) @ m s f (Seg ws :: ks) i

let fuel : nat = 1000

let rec search_from (s:list nat) (main:re) (k st:nat) : Tot (option (nat & nat)) (decreases k) =
  if k = 0 then None else
  match m s fuel [R main] st with
  | e :: _ -> Some (st, e)
  | [] -> search_from s main (k - 1) (st + 1)

let search (main:re) (s:list nat) = search_from s main (length s + 1) 0

(* Main lemma (SEMANTICS.md, lemma F): 0xDF matches each of ss, SS, sS, Ss, and back. *)
let spellings : list (list nat) = [[115;115]; [83;83]; [115;83]; [83;115]]
let sharp_s_ok (w:list nat) : bool =
  search (ILit [223]) w = Some (0, 2) && search (ILit w) [223] = Some (0, 1)
let sharp_s () : Lemma (forall w. memP w spellings ==> sharp_s_ok w) =
  assert_norm (sharp_s_ok [115;115] /\ sharp_s_ok [83;83] /\ sharp_s_ok [115;83] /\ sharp_s_ok [83;115])

(* Test cases (cases/iso-fold.tsv). *)
let cf21 = assert_norm (search (ILit [115;115]) [223] == Some (0, 1))
let cf22 = assert_norm (search (ILit [223]) [115;115] == Some (0, 2))
let if01 = assert_norm (search (ILit [223]) [83;83] == Some (0, 2))
let if02 = assert_norm (search (ILit [223]) [115;83] == Some (0, 2))
let if03 = assert_norm (search (ILit [223]) [83;115] == Some (0, 2))
let if04 = assert_norm (search (ILit [83;83]) [223] == Some (0, 1))
let if05 = assert_norm (search (ILit [115;83]) [223] == Some (0, 1))
let if06 = assert_norm (search (ILit [83;115]) [223] == Some (0, 1))
let if07 = assert_norm (search (ILit [83;83;98;223;115;115;99]) [97;223;98;83;83;223;99;100] == Some (1, 7))
let if08 = assert_norm (search (ILit [105;115]) [105;115;115] == Some (0, 2))
