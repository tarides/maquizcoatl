module Sem
(* Experiment #9, F*: the reference semantics (FRAGMENT.md 4),
   transcribed from rocq/Sem.v: a backtracking tree in Linden's style.
   [compute_tree] unfolds the pattern, under a list of pending actions
   (the continuation), into the tree of choices in priority order; the
   result is the tree's leftmost leaf that is a match.  The
   empty-iteration rule is DEV-008 on the fragment, i.e. upstream's
   plain check.  Fuel: one unit per [compute_tree] call, as in Rocq
   (FRAGMENT.md 4, "Fuel, per tool"). *)

open Syntax

(* captures: group number -> span, last write first *)
type gmap = list (nat & (nat & nat))

let rec gget (k:nat) (g:gmap) : span =
  match g with
  | [] -> None
  | (k', v) :: t -> if k = k' then Some v else gget k t

let gset (k:nat) (v:nat & nat) (g:gmap) : gmap = (k, v) :: g

(* pending actions *)
type action =
  | ARe : r:regex -> action                 (* match r *)
  | ACheck : p0:nat -> r:regex -> action    (* end of an iteration of Star r begun at p0 *)
  | AClose : k:nat -> p0:nat -> action      (* close group k opened at p0 *)

type tree =
  | TMismatch
  | TMatch : e:nat -> g:gmap -> tree
  | TChoice : t1:tree -> t2:tree -> tree    (* t1 has priority *)

let rec compute_tree (fuel:nat) (s:list nat) (acts:list action) (pos:nat) (g:gmap)
  : Tot (option tree) (decreases fuel) =
  if fuel = 0 then None
  else
    let f : nat = fuel - 1 in
    match acts with
    | [] -> Some (TMatch pos g)
    | ARe Eps :: k -> compute_tree f s k pos g
    | ARe (Lit l) :: k ->
      if is_prefix l (skipn pos s) then compute_tree f s k (pos + length l) g
      else Some TMismatch
    | ARe (Cat a b) :: k -> compute_tree f s (ARe a :: ARe b :: k) pos g
    | ARe (Alt a b) :: k ->
      (match compute_tree f s (ARe a :: k) pos g, compute_tree f s (ARe b :: k) pos g with
       | Some t1, Some t2 -> Some (TChoice t1 t2)
       | _, _ -> None)
    | ARe (Star a) :: k ->
      (* greedy: one more iteration first, then leave the loop *)
      (match compute_tree f s (ARe a :: ACheck pos a :: k) pos g, compute_tree f s k pos g with
       | Some t1, Some t2 -> Some (TChoice t1 t2)
       | _, _ -> None)
    | ACheck p0 a :: k ->
      (* plain empty check: an empty iteration leaves the loop *)
      if pos = p0 then compute_tree f s k pos g
      else compute_tree f s (ARe (Star a) :: k) pos g
    | ARe (Group n a) :: k -> compute_tree f s (ARe a :: AClose n pos :: k) pos g
    | AClose n p0 :: k -> compute_tree f s k pos (gset n (p0, pos) g)

(* leftmost match leaf *)
let rec first_match (t:tree) : option (nat & gmap) =
  match t with
  | TMismatch -> None
  | TMatch e g -> Some (e, g)
  | TChoice t1 t2 ->
    (match first_match t1 with
     | Some x -> Some x
     | None -> first_match t2)

(* spans of groups k, k+1, ..., k+n-1 *)
let rec spans_from (k n:nat) (g:gmap) : Tot (list span) (decreases n) =
  if n = 0 then [] else gget k g :: spans_from (k + 1) (n - 1) g

let spans (n:nat) (g:gmap) : list span = spans_from 1 n g

(* the semantics of r on subject s at start position p *)
let sem (fuel:nat) (r:regex) (s:list nat) (p:nat) : result =
  match compute_tree fuel s [ARe r] p [] with
  | None -> OutOfFuel
  | Some t ->
    (match first_match t with
     | None -> NoMatch
     | Some (e, g) -> Match e (spans (ncap r) g))
