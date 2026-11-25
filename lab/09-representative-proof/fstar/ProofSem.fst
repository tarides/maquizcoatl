module ProofSem
(* Experiment #9, F* M2: facts about the reference semantics, after
   rocq/ProofSem.v.  Fuel monotonicity and determinism of
   [compute_tree], lemma (d) for the semantics (some fuel suffices, on
   the measure of FRAGMENT.md 4: remaining input, then the weight of the
   pending actions; [fuel_of] computes the fuel), and the elided star (a
   body of code length 0 matches only the empty string and changes no
   capture). *)

open Syntax
open Sem
open Compile

#push-options "--fuel 2 --ifuel 1 --z3rlimit 10"

let rec ct_mono (f:nat) (s:list nat) (acts:list action) (pos:nat) (g:gmap) (f':nat)
  : Lemma (requires Some? (compute_tree f s acts pos g) /\ f <= f')
          (ensures compute_tree f' s acts pos g == compute_tree f s acts pos g)
          (decreases f)
  = let f1 : nat = f - 1 in
    let f1' : nat = f' - 1 in
    match acts with
    | [] -> ()
    | ARe Eps :: k -> ct_mono f1 s k pos g f1'
    | ARe (Lit l) :: k ->
      if is_prefix l (skipn pos s) then ct_mono f1 s k (pos + length l) g f1' else ()
    | ARe (Cat a b) :: k -> ct_mono f1 s (ARe a :: ARe b :: k) pos g f1'
    | ARe (Alt a b) :: k -> ct_mono f1 s (ARe a :: k) pos g f1'; ct_mono f1 s (ARe b :: k) pos g f1'
    | ARe (Star a) :: k -> ct_mono f1 s (ARe a :: ACheck pos a :: k) pos g f1'; ct_mono f1 s k pos g f1'
    | ACheck p0 a :: k ->
      if pos = p0 then ct_mono f1 s k pos g f1' else ct_mono f1 s (ARe (Star a) :: k) pos g f1'
    | ARe (Group n a) :: k -> ct_mono f1 s (ARe a :: AClose n pos :: k) pos g f1'
    | AClose n p0 :: k -> ct_mono f1 s k pos (gset n (p0, pos) g) f1'

let ct_det (s:list nat) (f1 f2:nat) (acts:list action) (pos:nat) (g:gmap)
  : Lemma (requires Some? (compute_tree f1 s acts pos g) /\ Some? (compute_tree f2 s acts pos g))
          (ensures compute_tree f1 s acts pos g == compute_tree f2 s acts pos g)
  = ct_mono f1 s acts pos g (f1 + f2); ct_mono f2 s acts pos g (f1 + f2)

(* FRAGMENT.md 4: the termination measure *)
let rec size (r:regex) : nat =
  match r with
  | Eps | Lit _ -> 1
  | Cat a b | Alt a b -> size a + size b + 1
  | Star a | Group _ a -> size a + 2

let wa (pos:nat) (x:action) : nat =
  match x with
  | ARe r -> size r
  | AClose _ _ -> 1
  | ACheck p0 a -> if pos = p0 then 1 else size a + 3

let rec ww (pos:nat) (acts:list action) : nat =
  match acts with [] -> 0 | x :: k -> wa pos x + ww pos k

let rem (s:list nat) (pos:nat) : nat = if pos <= length s then length s - pos else 0

let rec is_prefix_length (l x:list nat)
  : Lemma (requires is_prefix l x) (ensures length l <= length x)
  = match l, x with
    | [], _ -> ()
    | _ :: l', _ :: x' -> is_prefix_length l' x'

let rec length_skipn (n:nat) (l:list nat)
  : Lemma (length (skipn n l) == (if n <= length l then length l - n else 0))
  = if n = 0 then () else match l with [] -> () | _ :: t -> length_skipn (n - 1) t

(* lemma (d), semantics: a fuel that makes compute_tree finish *)
let rec fuel_of (s:list nat) (acts:list action) (pos:nat) (g:gmap)
  : Pure nat (requires True) (ensures fun f -> Some? (compute_tree f s acts pos g))
             (decreases %[rem s pos; ww pos acts])
  = match acts with
    | [] -> 1
    | ARe Eps :: k -> 1 + fuel_of s k pos g
    | ARe (Lit l) :: k ->
      if is_prefix l (skipn pos s) then begin
        is_prefix_length l (skipn pos s); length_skipn pos s;
        1 + fuel_of s k (pos + length l) g
      end else 1
    | ARe (Cat a b) :: k -> 1 + fuel_of s (ARe a :: ARe b :: k) pos g
    | ARe (Alt a b) :: k ->
      let f1 = fuel_of s (ARe a :: k) pos g in
      let f2 = fuel_of s (ARe b :: k) pos g in
      ct_mono f1 s (ARe a :: k) pos g (f1 + f2);
      ct_mono f2 s (ARe b :: k) pos g (f1 + f2);
      1 + (f1 + f2)
    | ARe (Star a) :: k ->
      let f1 = fuel_of s (ARe a :: ACheck pos a :: k) pos g in
      let f2 = fuel_of s k pos g in
      ct_mono f1 s (ARe a :: ACheck pos a :: k) pos g (f1 + f2);
      ct_mono f2 s k pos g (f1 + f2);
      1 + (f1 + f2)
    | ACheck p0 a :: k ->
      if pos = p0 then 1 + fuel_of s k pos g else 1 + fuel_of s (ARe (Star a) :: k) pos g
    | ARe (Group n a) :: k -> 1 + fuel_of s (ARe a :: AClose n pos :: k) pos g
    | AClose n p0 :: k -> 1 + fuel_of s k pos (gset n (p0, pos) g)

let ct_total (s:list nat) (acts:list action) (pos:nat) (g:gmap)
  : Lemma (exists (f:nat). Some? (compute_tree f s acts pos g))
  = let f = fuel_of s acts pos g in
    FStar.Classical.exists_intro (fun (f:nat) -> Some? (compute_tree f s acts pos g)) f

(* a star whose body compiles to no code (FRAGMENT.md 3, tlen == 0):
   the body leaves the subject and the captures alone *)
let rec clen0_fm (s:list nat) (a:regex) (f:nat) (k:list action) (pos:nat) (g:gmap)
  : Lemma (requires clen a = 0 /\ Some? (compute_tree f s (ARe a :: k) pos g))
          (ensures Some? (compute_tree f s k pos g) /\
                   first_match (Some?.v (compute_tree f s k pos g))
                   == first_match (Some?.v (compute_tree f s (ARe a :: k) pos g)))
          (decreases a)
  = let f1 : nat = f - 1 in
    match a with
    | Eps -> ct_mono f1 s k pos g f
    | Lit _ -> ct_mono f1 s k pos g f
    | Cat a1 a2 ->
      clen0_fm s a1 f1 (ARe a2 :: k) pos g;
      clen0_fm s a2 f1 k pos g;
      ct_mono f1 s k pos g f
    | Star a1 ->
      clen0_fm s a1 f1 (ACheck pos a1 :: k) pos g;
      let f2 : nat = f1 - 1 in
      ct_det s f2 f1 k pos g;
      ct_mono f1 s k pos g f

#pop-options
