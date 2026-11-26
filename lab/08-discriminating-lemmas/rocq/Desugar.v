(* Experiment #8 follow-up (issue #34): a model of the C desugaring of the
   absent operator and a state-threaded matcher for it.
   Design and citations: lab/08-discriminating-lemmas/LEMMAS.md, sections
   "The desugaring" and "The state-threaded matcher".  References are
   upstream/<path>:<line> at f95747b.

   The model's faithfulness to the C library is checked only on the case
   corpus (Cases.v: lab/08-hard-features/cases/absent.tsv and
   lab/08-discriminating-lemmas/cases/absent-restore.tsv). *)
From Stdlib Require Import List Arith Bool.
Import ListNotations.
From S Require Import Absent.

(* The desugared AST: experiment #8's absent-free core plus the nodes the
   C parser emits for the absent constructs (regparse.c:2995-3391). *)
Inductive dre :=
  | DEps | DChr (c : nat) | DAny | DAnyO
  | DSeq (a b : dre) | DAlt (a b : dre) | DStar (a : dre)
  | DAtomic (a : dre)            (* BAG_STOP_BACKTRACK *)
  | DFail                        (* node_new_fail *)
  | DSaveRR (id : nat)           (* SAVE_RIGHT_RANGE gimmick *)
  | DSaveS (id : nat)            (* SAVE_S gimmick *)
  | DUpdRRFromStack (id : nat)   (* UPDATE_VAR_RIGHT_RANGE_FROM_STACK *)
  | DUpdRRFromS (id : nat)       (* UPDATE_VAR_RIGHT_RANGE_FROM_S_STACK *)
  | DUpdSFromStack (id : nat)    (* UPDATE_VAR_S_FROM_STACK *)
  | DRRInit.                     (* UPDATE_VAR_RIGHT_RANGE_INIT *)

(* Absent-free core, embedded unchanged. *)
Fixpoint emb (r : re) : dre :=
  match r with
  | Eps => DEps | Chr c => DChr c | Any => DAny | AnyO => DAnyO
  | Seq a b => DSeq (emb a) (emb b) | Alt a b => DAlt (emb a) (emb b)
  | Star a => DStar (emb a)
  | _ => DFail (* absent constructs inside an absent pattern: out of scope *)
  end.

Definition dseq (l : list dre) : dre := fold_right DSeq DEps l.

(* make_absent_engine (regparse.c:2995-3075), id = pre_save_right_id,
   j = the engine's own SAVE_S id.  The SUPER flag on the outer
   alternation (range cutter) is not modelled: it changes only which stack
   entries a cut voids, and no pattern in scope has an atomic group or a
   lookaround around an absent construct (LEMMAS.md, scope conditions). *)
Definition engine (id j : nat) (a step : dre) (poss : bool) : dre :=
  let body := DStar (DAlt (dseq [DSaveS j; a; DUpdRRFromS j; DFail]) step) in
  DAlt (if poss then DAtomic body else body) (dseq [DUpdRRFromStack id; DFail]).

(* make_absent_tail (regparse.c:3078-3124). *)
Definition tail (id1 id3 : nat) : dre :=
  DSeq (DSaveRR id3) (DAlt (DUpdRRFromStack id1) (dseq [DUpdRRFromStack id3; DFail])).

(* is_simple_one_char_repeat (regparse.c:3184-3249) on the AST: a greedy
   repeat whose body is a one-character string; the AST has no classes,
   other quantifiers or possessive groups, so Star (Chr c) is its only
   simple case. *)
Definition simple_step (e : re) : option nat :=
  match e with Star (Chr c) => Some c | _ => None end.

(* desugar r n = (tree, next free id).  Ids are allocated in the order the
   C allocates them (ID_ENTRY in node_new_save_gimmick, regparse.c:2785-2799);
   the model only needs them distinct per construct. *)
Fixpoint desugar (r : re) (n : nat) : dre * nat :=
  match r with
  | Eps => (DEps, n) | Chr c => (DChr c, n) | Any => (DAny, n) | AnyO => (DAnyO, n)
  | Seq a b => let (da, n1) := desugar a n in let (db, n2) := desugar b n1 in (DSeq da db, n2)
  | Alt a b => let (da, n1) := desugar a n in let (db, n2) := desugar b n1 in (DAlt da db, n2)
  | Star a => let (da, n1) := desugar a n in (DStar da, n1)
  | AbsRep a =>
      (* (?~absent): simple path with \O* (regparse.c:3317-3328, 3252-3296) *)
      (dseq [DSaveRR n; engine n (S n) (emb a) DAnyO false; DUpdRRFromStack n], n + 2)
  | AbsExp a e =>
      match simple_step e with
      | Some c =>
          (* simple path, step = the repeated character (regparse.c:3331, 3252-3296) *)
          (dseq [DSaveRR n; engine n (S n) (emb a) (DChr c) false; DUpdRRFromStack n], n + 2)
      | None =>
          (* general path (regparse.c:3347-3384): ids id1 = n, id2 = n+1,
             engine's SAVE_S n+2, tail's SAVE_RIGHT_RANGE n+3 *)
          (dseq [DSaveRR n; DSaveS (S n); engine n (n + 2) (emb a) DAnyO true;
                 DUpdSFromStack (S n); emb e; tail n (n + 3)], n + 4)
      end
  | Stopper a =>
      (* range cutter: the general path without the tail (regparse.c:3371-3373) *)
      (dseq [DSaveRR n; DSaveS (S n); engine n (n + 2) (emb a) DAnyO true;
             DUpdSFromStack (S n)], n + 3)
  | RClear =>
      (* make_range_clear (regparse.c:3127-3183); SUPER not modelled *)
      (dseq [DSaveRR n; DAlt DRRInit (dseq [DUpdRRFromStack n; DFail])], n + 1)
  end.

Inductive ditem := DR (x : dre) | DChk (i : nat) (a : dre).

(* The save store: STK_SAVE_VAL entries of the backtrack stack, newest
   first; STACK_GET_SAVE_VAL_TYPE_LAST_ID (regexec.c:2211-2230) takes the
   last entry of the id. *)
Fixpoint lookup (id : nat) (sv : list (nat * nat)) : option nat :=
  match sv with [] => None | (k, v) :: t => if Nat.eqb k id then Some v else lookup id t end.

Section MD.
Variable s : list nat.

(* A result: end position, register and save store at success. *)
Definition dres := (nat * nat * list (nat * nat))%type.

(* md f ks i rr sv = Some (results in priority order, register at final
   failure), or None (out of fuel, or a lookup of an id with no save).
   The register rr is right_range (regexec.c:3189): backtracking does not
   restore it, so the alternative tried next starts from the register the
   previous one failed with.  The save store sv lives on the backtrack
   stack: each alternative starts from the store of its choice point. *)
Fixpoint md (f : nat) (ks : list ditem) (i rr : nat) (sv : list (nat * nat)) {struct f}
  : option (list dres * nat) :=
  match f with
  | 0 => None
  | S f =>
    match ks with
    | [] => Some ([(i, rr, sv)], rr)
    | DR DEps :: ks => md f ks i rr sv
    | DR (DChr c) :: ks =>
        match at_ s i rr with
        | Some c' => if Nat.eqb c c' then md f ks (S i) rr sv else Some ([], rr)
        | None => Some ([], rr) end
    | DR DAny :: ks =>
        match at_ s i rr with
        | Some c' => if Nat.eqb c' 10 then Some ([], rr) else md f ks (S i) rr sv
        | None => Some ([], rr) end
    | DR DAnyO :: ks => match at_ s i rr with Some _ => md f ks (S i) rr sv | None => Some ([], rr) end
    | DR (DSeq a b) :: ks => md f (DR a :: DR b :: ks) i rr sv
    | DR (DAlt a b) :: ks =>
        match md f (DR a :: ks) i rr sv with
        | Some (r1, rr1) =>
            match md f (DR b :: ks) i rr1 sv with Some (r2, rr2) => Some (r1 ++ r2, rr2) | None => None end
        | None => None end
    | DR (DStar a) :: ks =>
        match md f (DR a :: DChk i a :: ks) i rr sv with
        | Some (r1, rr1) =>
            match md f ks i rr1 sv with Some (r2, rr2) => Some (r1 ++ r2, rr2) | None => None end
        | None => None end
    | DChk i0 a :: ks => if Nat.eqb i i0 then md f ks i rr sv else md f (DR (DStar a) :: ks) i rr sv
    | DR (DAtomic a) :: ks =>
        (* the body's first result, with its register and saves (STK_SAVE_VAL
           is not voided by the cut: regexec.c:1269, 1276, 2391); the body's
           other branches are dropped *)
        match md f [DR a] i rr sv with
        | Some ((e, rr', sv') :: _, _) => md f ks e rr' sv'
        | Some ([], rr') => Some ([], rr')
        | None => None end
    | DR DFail :: _ => Some ([], rr)
    | DR (DSaveRR id) :: ks => md f ks i rr ((id, rr) :: sv)
    | DR (DSaveS id) :: ks => md f ks i rr ((id, i) :: sv)
    | DR (DUpdRRFromStack id) :: ks | DR (DUpdRRFromS id) :: ks =>
        match lookup id sv with Some v => md f ks i v sv | None => None end
    | DR (DUpdSFromStack id) :: ks =>
        match lookup id sv with Some v => md f ks v rr sv | None => None end
    | DR DRRInit :: ks => md f ks i (length s) sv
    end
  end.

(* Forward search on the desugared tree; the register starts at the
   subject end at each start (INIT_RIGHT_RANGE, regexec.c:2729, 3278). *)
Fixpoint dsearch_from (f : nat) (d : dre) (k st : nat) : sres :=
  match k with
  | 0 => NoMatch
  | S k => match md f [DR d] st (length s) [] with
           | Some (((e, _), _) :: _, _) => Match st e
           | Some ([], _) => dsearch_from f d k (S st)
           | None => OutOfFuel
           end
  end.
End MD.

Definition dsearch f main s := dsearch_from s f (fst (desugar main 0)) (S (length s)) 0.
