(* Experiment #6, Rocq: executable semantics of experiment #9's subset of
   Oniguruma f95747b (concatenation, alternation, greedy star, capture
   groups, character classes; UTF-8; forward search), transcribed from
   stack G (lab/06-spec-speed/g/g.ml) as a small-step machine: the
   pending items of stack G's [step] plus an explicit list of
   backtracking points.  One machine step per call of stack G's [step];
   fuel is a positive, iterated by halving, so that 10,000,000 costs no
   unary number.  No type indices or proofs in executable definitions. *)

From Stdlib Require Import List NArith PArith Bool Arith.
Import ListNotations.

Inductive node : Type :=
| Eps
| Lit (bs : list N)                    (* bytes of one code point *)
| Cls (neg : bool) (rs : list (N * N)) (* negated, sorted ranges *)
| Cat (a b : node)
| Alt (a b : node)
| Star (a : node)                      (* greedy *)
| Group (k : nat) (a : node).

Inductive item : Type :=
| INode (n : node)
| IClose (k : nat) (p : nat)           (* group, start position *)
| ILoop (a : node) (p : nat).          (* star body, iteration start *)

Definition caps := list (nat * (nat * nat)).

(* backtracking point: items, position, rest of the subject, captures *)
Definition frame := (list item * nat * list N * caps)%type.

Inductive state : Type :=
| Run (its : list item) (pos : nat) (rest : list N) (cs : caps) (bt : list frame)
| Matched (pos : nat) (cs : caps)
| Failed.

(* UTF-8, as upstream/src/utf8.c (EncLen_UTF8, USE_RFC3629_RANGE) *)
Definition enc_len (b : N) : nat :=
  if (b <? 194)%N then 1 else if (b <? 224)%N then 2
  else if (b <? 240)%N then 3 else if (b <? 245)%N then 4 else 1.

Fixpoint take (n : nat) (l : list N) : option (list N * list N) :=
  match n with
  | O => Some ([], l)
  | S m => match l with
           | [] => None
           | x :: t => match take m t with
                       | Some (a, r) => Some (x :: a, r)
                       | None => None
                       end
           end
  end.

Definition lead_mod (l : nat) : N :=
  match l with 2 => 32%N | 3 => 16%N | _ => 8%N end.

(* code point, encoded length, rest; None past the end (DATA_ENSURE) *)
Definition decode (rest : list N) : option (N * nat * list N) :=
  match rest with
  | [] => None
  | b :: t =>
    let l := enc_len b in
    match l with
    | 1 => Some (b, 1, t)
    | _ => match take (l - 1) t with
           | Some (tl, r) =>
             Some (fold_left (fun v d => (v * 64 + N.modulo d 64)%N) tl
                             (N.modulo b (lead_mod l)), l, r)
           | None => None
           end
    end
  end.

Fixpoint prefix (l rest : list N) : option (list N) :=
  match l, rest with
  | [], _ => Some rest
  | x :: l', y :: r => if N.eqb x y then prefix l' r else None
  | _, [] => None
  end.

Definition in_ranges (c : N) (rs : list (N * N)) : bool :=
  existsb (fun r => andb (N.leb (fst r) c) (N.leb c (snd r))) rs.

Fixpoint set_cap (k : nat) (v : nat * nat) (cs : caps) : caps :=
  match cs with
  | [] => [(k, v)]
  | (k', w) :: t => if Nat.eqb k' k then (k, v) :: t else (k', w) :: set_cap k v t
  end.

Definition backtrack (bt : list frame) : state :=
  match bt with
  | [] => Failed
  | (its, pos, rest, cs) :: bt' => Run its pos rest cs bt'
  end.

Definition step (st : state) : state :=
  match st with
  | Run its pos rest cs bt =>
    match its with
    | [] => Matched pos cs
    | INode Eps :: k => Run k pos rest cs bt
    | INode (Lit l) :: k =>
      match prefix l rest with
      | Some r => Run k (pos + length l) r cs bt
      | None => backtrack bt
      end
    | INode (Cls ng rs) :: k =>
      match decode rest with
      | Some (c, l, r) =>
        if Bool.eqb (in_ranges c rs) ng then backtrack bt
        else Run k (pos + l) r cs bt
      | None => backtrack bt
      end
    | INode (Cat a b) :: k => Run (INode a :: INode b :: k) pos rest cs bt
    | INode (Alt a b) :: k =>
      Run (INode a :: k) pos rest cs ((INode b :: k, pos, rest, cs) :: bt)
    | INode (Star a) :: k =>
      Run (INode a :: ILoop a pos :: k) pos rest cs ((k, pos, rest, cs) :: bt)
    | ILoop a p0 :: k =>
      if Nat.eqb pos p0 then Run k pos rest cs bt
      else Run (INode (Star a) :: k) pos rest cs bt
    | INode (Group i a) :: k => Run (INode a :: IClose i pos :: k) pos rest cs bt
    | IClose i p0 :: k => Run k pos rest (set_cap i (p0, pos) cs) bt
    end
  | _ => st
  end.

(* exactly p steps, or fewer if the machine stops *)
Fixpoint run (p : positive) (st : state) : state :=
  match st with
  | Run _ _ _ _ _ =>
    match p with
    | xH => step st
    | xO q => run q (run q st)
    | xI q => run q (run q (step st))
    end
  | _ => st
  end.

Inductive result : Type :=
| RMatch (s e : nat) (cs : caps)
| RMismatch
| RLimit.

(* forward search: start positions 0..length, advanced by enc_len *)
Fixpoint search_from (n : nat) (fuel : positive) (re : node) (pos : nat)
         (rest : list N) : result :=
  match n with
  | O => RMismatch
  | S n' =>
    match run fuel (Run [INode re] pos rest [] []) with
    | Matched e cs => RMatch pos e cs
    | Run _ _ _ _ _ => RLimit
    | Failed =>
      match rest with
      | [] => RMismatch
      | b :: _ =>
        let l := enc_len b in
        match take l rest with
        | Some (_, r) => search_from n' fuel re (pos + l) r
        | None => RMismatch
        end
      end
    end
  end.

Definition search (fuel : positive) (re : node) (s : list N) : result :=
  search_from (S (length s)) fuel re 0 s.

Fixpoint lookup (k : nat) (cs : caps) : option (nat * nat) :=
  match cs with
  | [] => None
  | (k', v) :: t => if Nat.eqb k k' then Some v else lookup k t
  end.

(* verdict as numbers: [0] no match, [2] limit, 1 :: s :: e :: groups,
   each group [1; s; e] or [0] when unset *)
Definition encode (ncap : nat) (r : result) : list nat :=
  match r with
  | RMismatch => [0]
  | RLimit => [2]
  | RMatch s e cs =>
    1 :: s :: e :: flat_map (fun k => match lookup k cs with
                                      | Some (x, y) => [1; x; y]
                                      | None => [0]
                                      end) (seq 1 ncap)
  end.

Definition fuel0 : positive := 10000000%positive.

Definition run_case (fuel : positive) (ncap : nat) (re : node) (s : list N) : list nat :=
  encode ncap (search fuel re s).

(* a case: number of groups, pattern, subject bytes, expected verdict *)
Definition case := (nat * node * list N * list nat)%type.

Fixpoint nat_list_eqb (a b : list nat) : bool :=
  match a, b with
  | [], [] => true
  | x :: a', y :: b' => Nat.eqb x y && nat_list_eqb a' b'
  | _, _ => false
  end.

Definition agree (fuel : positive) (c : case) : bool :=
  match c with
  | (ncap, re, s, exp) => nat_list_eqb (run_case fuel ncap re s) exp
  end.

Definition count (fuel : positive) (cs : list case) : nat :=
  fold_left (fun acc c => if agree fuel c then S acc else acc) cs 0.

(* r passes; pass i uses fuel0 + i so that no pass can be shared *)
Fixpoint passes (r : nat) (cs : list case) (acc : nat) : nat :=
  match r with
  | O => acc
  | S r' => passes r' cs (acc + count (Pos.add fuel0 (Pos.of_succ_nat r')) cs)
  end.
