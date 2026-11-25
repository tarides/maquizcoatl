(* Experiment #9, Rocq: the reference semantics (FRAGMENT.md 4), a
   backtracking tree in Linden's style: [compute_tree] unfolds the
   pattern, under a list of pending actions (the continuation), into the
   tree of choices in priority order; the result is the tree's leftmost
   leaf that is a match.  The empty-iteration rule is DEV-008 on the
   fragment, i.e. upstream's plain check: an iteration of a star that
   ends where it started leaves the loop, keeping what it captured.
   Fuel: one unit per [compute_tree] call; FRAGMENT.md 4 gives the
   structural measure and lemma (d) the fuel bound. *)

From Stdlib Require Import List Arith.
Import ListNotations.
From S Require Import Syntax.

(* captures: group number -> span, last write first *)
Definition gmap := list (nat * (nat * nat)).

Fixpoint gget (k : nat) (g : gmap) : span :=
  match g with
  | [] => None
  | (k', v) :: t => if Nat.eqb k k' then Some v else gget k t
  end.

Definition gset (k : nat) (v : nat * nat) (g : gmap) : gmap := (k, v) :: g.

(* pending actions *)
Inductive action : Type :=
| ARe (r : regex)                 (* match r *)
| ACheck (p0 : nat) (r : regex)   (* end of an iteration of Star r begun at p0 *)
| AClose (k : nat) (p0 : nat).    (* close group k opened at p0 *)

Inductive tree : Type :=
| TMismatch
| TMatch (e : nat) (g : gmap)
| TChoice (t1 t2 : tree).         (* t1 has priority *)

Fixpoint compute_tree (fuel : nat) (s : list nat) (acts : list action) (pos : nat)
         (g : gmap) : option tree :=
  match fuel with
  | O => None
  | S f =>
    match acts with
    | [] => Some (TMatch pos g)
    | ARe Eps :: k => compute_tree f s k pos g
    | ARe (Lit l) :: k =>
      if is_prefix l (skipn pos s) then compute_tree f s k (pos + length l) g
      else Some TMismatch
    | ARe (Cat a b) :: k => compute_tree f s (ARe a :: ARe b :: k) pos g
    | ARe (Alt a b) :: k =>
      match compute_tree f s (ARe a :: k) pos g, compute_tree f s (ARe b :: k) pos g with
      | Some t1, Some t2 => Some (TChoice t1 t2)
      | _, _ => None
      end
    | ARe (Star a) :: k =>
      (* greedy: one more iteration first, then leave the loop *)
      match compute_tree f s (ARe a :: ACheck pos a :: k) pos g, compute_tree f s k pos g with
      | Some t1, Some t2 => Some (TChoice t1 t2)
      | _, _ => None
      end
    | ACheck p0 a :: k =>
      (* plain empty check: an empty iteration leaves the loop *)
      if Nat.eqb pos p0 then compute_tree f s k pos g
      else compute_tree f s (ARe (Star a) :: k) pos g
    | ARe (Group n a) :: k => compute_tree f s (ARe a :: AClose n pos :: k) pos g
    | AClose n p0 :: k => compute_tree f s k pos (gset n (p0, pos) g)
    end
  end.

(* leftmost match leaf *)
Fixpoint first_match (t : tree) : option (nat * gmap) :=
  match t with
  | TMismatch => None
  | TMatch e g => Some (e, g)
  | TChoice t1 t2 =>
    match first_match t1 with
    | Some x => Some x
    | None => first_match t2
    end
  end.

Definition spans (n : nat) (g : gmap) : list span := map (fun k => gget k g) (seq 1 n).

(* the semantics of r on subject s at start position p *)
Definition sem (fuel : nat) (r : regex) (s : list nat) (p : nat) : result :=
  match compute_tree fuel s [ARe r] p [] with
  | None => OutOfFuel
  | Some t =>
    match first_match t with
    | None => NoMatch
    | Some (e, g) => Match e (spans (ncap r) g)
    end
  end.
