module ProofSim
(* Experiment #9, F* M2, lemmas (b) and (c): the VM simulates the
   backtracking tree (FRAGMENT.md 8), after rocq/ProofSim.v (same
   invariants, F* proof).  [rep code pc acts pos stk p x] says that the
   code at [pc] implements the pending actions [acts]: [ARe r] by
   [comp r], [AClose n] by OP_MEM_END, [ACheck p0 a] by the end of a
   star's iteration (its OP_EMPTY_CHECK_END, whose OP_EMPTY_CHECK_START
   entry holds p0, or, for a body that cannot match the empty string,
   the loop's OP_JUMP); OP_JUMPs may come in between.  [p] lists the
   empty-check ids the pending checks need on the stack; [x] the
   non-push groups still to be entered, whose VM captures are stale.
   [sim] is proved by induction on the fuel of [compute_tree], with an
   inner induction on [rep]; its Star and ACheck cases are lemma (c).
   [sim] and its case functions return the witnesses (number of VM steps,
   final captures) instead of stating existentials. *)

open Syntax
open Sem
open Compile
open Vm
open Statement
open ProofA
open ProofSem

#push-options "--fuel 2 --ifuel 1 --z3rlimit 10"

(* ---- lists of group numbers ---- *)

let rec mem_append (x:nat) (l1 l2:list nat)
  : Lemma (mem x (append l1 l2) == (mem x l1 || mem x l2))
          [SMTPat (mem x (append l1 l2))]
  = match l1 with [] -> () | _ :: t -> mem_append x t l2

let disj (l1 l2:list nat) : prop = forall (x:nat). mem x l1 ==> not (mem x l2)

let rec nodup_append (l1 l2:list nat)
  : Lemma (requires nodup (append l1 l2))
          (ensures nodup l1 /\ nodup l2 /\ disj l1 l2)
  = match l1 with [] -> () | _ :: t -> nodup_append t l2

(* ---- captures ---- *)

(* the capture a VM slot reports (Vm.region) *)
let rv (v:option nat & option nat) : span =
  match v with
  | (Some a, Some b) -> Some (a, b)
  | _ -> None

(* the groups opened on the current path and not yet closed *)
let rec cls (acts:list action) : list (nat & nat) =
  match acts with
  | [] -> []
  | AClose n p :: k -> (n, p) :: cls k
  | ARe _ :: k -> cls k
  | ACheck _ _ :: k -> cls k

let rec cget (k:nat) (c:list (nat & nat)) : option nat =
  match c with
  | [] -> None
  | (k', p) :: t -> if k = k' then Some p else cget k t

(* the captures relation: groups in x are free; an open group has its
   start; every other group has the semantics' span *)
[@@"opaque_to_smt"]
let capsrel (m:mcaps) (g:gmap) (c:list (nat & nat)) (x:list nat) : prop =
  forall (k:nat). not (mem k x) ==>
    (match cget k c with
     | Some p -> fst (mget k m) == Some p
     | None -> rv (mget k m) == gget k g)

(* what a failed attempt may leave changed in the captures *)
[@@"opaque_to_smt"]
let meq (c:list (nat & nat)) (x:list nat) (m1 m:mcaps) : prop =
  forall (k:nat). mget k m1 == mget k m \/ mem k x \/
                  (Some? (cget k c) /\ fst (mget k m1) == fst (mget k m))

(* group numbers on the pending path; none repeats *)
let rec gs (acts:list action) : list nat =
  match acts with
  | [] -> []
  | ARe r :: k -> append (groups r) (gs k)
  | AClose n _ :: k -> n :: gs k
  | ACheck _ _ :: k -> gs k

let rec uniq (acts:list action) : prop =
  match acts with
  | [] -> True
  | ARe r :: k -> nodup (groups r) /\ disj (groups r) (gs k) /\ uniq k
  | ACheck _ a :: k -> nodup (groups a) /\ disj (groups a) (gs k) /\ uniq k
  | AClose n _ :: k -> not (mem n (gs k)) /\ uniq k

(* the non-push groups of a pattern entered on every path *)
let rec topg (r:regex) : list nat =
  match r with
  | Eps | Lit _ | Alt _ _ | Star _ -> []
  | Cat a b -> append (topg a) (topg b)
  | Group n a -> n :: topg a

let npg (r:regex) (push:bool) : list nat = if push then [] else topg r

let fresh (eid n:nat) (p:list nat) : prop = forall (i:nat). mem i p ==> (i < eid \/ eid + n <= i)

let rec cls_none (n:nat) (k:list action)
  : Lemma (requires not (mem n (gs k))) (ensures cget n (cls k) == None)
  = match k with
    | [] -> ()
    | ARe r :: k' -> cls_none n k'
    | AClose _ _ :: k' -> cls_none n k'
    | ACheck _ _ :: k' -> cls_none n k'

let meq_refl (c:list (nat & nat)) (x:list nat) (m:mcaps) : Lemma (meq c x m m) =
  reveal_opaque (`%meq) (meq c x m m)

let meq_trans (c:list (nat & nat)) (x:list nat) (m2 m1 m:mcaps)
  : Lemma (requires meq c x m2 m1 /\ meq c x m1 m) (ensures meq c x m2 m)
  = reveal_opaque (`%meq) (meq c x m2 m1);
    reveal_opaque (`%meq) (meq c x m1 m);
    reveal_opaque (`%meq) (meq c x m2 m)

let capsrel_meq (m:mcaps) (g:gmap) (c:list (nat & nat)) (x:list nat) (m1:mcaps)
  : Lemma (requires capsrel m g c x /\ meq c x m1 m) (ensures capsrel m1 g c x)
  = reveal_opaque (`%capsrel) (capsrel m g c x);
    reveal_opaque (`%capsrel) (capsrel m1 g c x);
    reveal_opaque (`%meq) (meq c x m1 m)

let capsrel_open (m:mcaps) (g:gmap) (c:list (nat & nat)) (x x':list nat) (n pos:nat)
                 (v:option nat & option nat)
  : Lemma (requires capsrel m g c x /\ cget n c == None /\ fst v == Some pos /\
                    (forall (k:nat). k <> n /\ not (mem k x') ==> not (mem k x)))
          (ensures capsrel (mset n v m) g ((n, pos) :: c) x')
  = reveal_opaque (`%capsrel) (capsrel m g c x);
    reveal_opaque (`%capsrel) (capsrel (mset n v m) g ((n, pos) :: c) x')

(* failure through OP_MEM_START_PUSH: the popped entry restores group n *)
let meq_push (c:list (nat & nat)) (x:list nat) (m1 m:mcaps) (n pos:nat)
  : Lemma (requires meq ((n, pos) :: c) x m1 (mset n (Some pos, None) m))
          (ensures meq c x (mset n (mget n m) m1) m)
  = reveal_opaque (`%meq) (meq ((n, pos) :: c) x m1 (mset n (Some pos, None) m));
    reveal_opaque (`%meq) (meq c x (mset n (mget n m) m1) m)

(* failure through OP_MEM_START: group n is free again *)
let meq_nopush (c:list (nat & nat)) (x:list nat) (m1 m:mcaps) (n pos:nat)
               (v:option nat & option nat)
  : Lemma (requires meq ((n, pos) :: c) x m1 (mset n v m))
          (ensures meq c (n :: x) m1 m)
  = reveal_opaque (`%meq) (meq ((n, pos) :: c) x m1 (mset n v m));
    reveal_opaque (`%meq) (meq c (n :: x) m1 m)

let capsrel_close (m:mcaps) (g:gmap) (c:list (nat & nat)) (x:list nat) (n p0 pos:nat)
  : Lemma (requires capsrel m g ((n, p0) :: c) x /\ cget n c == None)
          (ensures capsrel (mset n (fst (mget n m), Some pos) m) (gset n (p0, pos) g) c x)
  = reveal_opaque (`%capsrel) (capsrel m g ((n, p0) :: c) x);
    reveal_opaque (`%capsrel) (capsrel (mset n (fst (mget n m), Some pos) m) (gset n (p0, pos) g) c x)

let meq_close (c:list (nat & nat)) (x:list nat) (m1 m:mcaps) (n p0 pos:nat)
  : Lemma (requires meq c x m1 (mset n (fst (mget n m), Some pos) m))
          (ensures meq ((n, p0) :: c) x m1 m)
  = reveal_opaque (`%meq) (meq c x m1 (mset n (fst (mget n m), Some pos) m));
    reveal_opaque (`%meq) (meq ((n, p0) :: c) x m1 m)

let capsrel_end (m:mcaps) (g:gmap)
  : Lemma (requires capsrel m g [] []) (ensures forall (k:nat). rv (mget k m) == gget k g)
  = reveal_opaque (`%capsrel) (capsrel m g [] [])

let capsrel_init (x:list nat) : Lemma (capsrel [] [] [] x) =
  reveal_opaque (`%capsrel) (capsrel [] [] [] x)

(* ---- VM runs of exactly n steps ---- *)

let rec exe (code:list instr) (s:list nat) (n:nat) (st:state) : Tot outcome (decreases n) =
  if n = 0 then Next st
  else match step code s st with
       | Next st' -> exe code s (n - 1) st'
       | Halt r -> Halt r

let exe_next (code:list instr) (s:list nat) (n:nat) (st st':state)
  : Lemma (requires step code s st == Next st') (ensures exe code s (n + 1) st == exe code s n st')
  = ()

let exe_fail1 (code:list instr) (s:list nat) (st:state) (stk:list entry) (m:mcaps)
  : Lemma (requires step code s st == fail stk m) (ensures exe code s 1 st == fail stk m)
  = ()

let rec exe_add (code:list instr) (s:list nat) (a b:nat) (st:state)
  : Lemma (ensures exe code s (a + b) st ==
                   (match exe code s a st with Next st' -> exe code s b st' | h -> h))
          (decreases a)
  = if a = 0 then ()
    else match step code s st with
         | Next st' -> exe_add code s (a - 1) b st'
         | Halt _ -> ()

(* ---- the representation of pending actions by code ---- *)

noeq type rep (code:list instr) : nat -> list action -> nat -> list entry -> list nat -> list nat -> Type =
  | RJump : pc:nat -> tg:nat -> acts:list action -> pos:nat -> stk:list entry -> p:list nat -> x:list nat ->
            squash (nth code pc == Some (IJump tg)) ->
            rep code tg acts pos stk p x -> rep code pc acts pos stk p x
  | REnd : pc:nat -> pos:nat -> stk:list entry ->
           squash (nth code pc == Some IEnd) -> rep code pc [] pos stk [] []
  | RRe : pc:nat -> r:regex -> eid:nat -> push:bool -> k:list action -> pos:nat -> stk:list entry ->
          p:list nat -> x:list nat -> pc':nat -> pos':nat ->
          squash (code_at code pc (comp r pc eid push) /\ fresh eid (nchecks r) p /\
                  pc' == pc + clen r /\ pos' <= pos + minlen r) ->
          rep code pc' k pos' stk p x -> rep code pc (ARe r :: k) pos stk p (append (npg r push) x)
  | RClose : pc:nat -> n:nat -> p0:nat -> k:list action -> pos:nat -> stk:list entry ->
             p:list nat -> x:list nat ->
             squash (nth code pc == Some (IMemEnd n)) ->
             rep code (pc + 1) k pos stk p x -> rep code pc (AClose n p0 :: k) pos stk p x
  | RChkNull : pc:nat -> l:nat -> a:regex -> eid:nat -> push:bool -> p0:nat -> k:list action ->
               pos:nat -> stk:list entry -> p:list nat -> x:list nat -> pc':nat -> pos':nat ->
               squash (code_at code l (comp (Star a) l eid push) /\ clen a <> 0 /\ nullable a /\
                       fresh eid (nchecks (Star a)) p /\ empty_start eid stk == Some p0 /\
                       p0 <= pos /\ pc == l + 2 + clen a /\ pc' == l + clen (Star a) /\ pos' <= p0) ->
               rep code pc' k pos' stk p x -> rep code pc (ACheck p0 a :: k) pos stk (eid :: p) x
  | RChkNN : pc:nat -> l:nat -> a:regex -> eid:nat -> push:bool -> p0:nat -> k:list action ->
             pos:nat -> stk:list entry -> p:list nat -> x:list nat -> pc':nat -> pos':nat ->
             squash (code_at code l (comp (Star a) l eid push) /\ clen a <> 0 /\ not (nullable a) /\
                     fresh eid (nchecks (Star a)) p /\ p0 + minlen a <= pos /\
                     pc == l + 1 + clen a /\ pc' == l + clen (Star a) /\ pos' <= p0) ->
             rep code pc' k pos' stk p x -> rep code pc (ACheck p0 a :: k) pos stk p x

let rec rep_mono (#code:list instr) (#pc:nat) (#acts:list action) (#pos:nat) (#stk:list entry)
                 (#p #x:list nat) (h:rep code pc acts pos stk p x) (pos2:nat) (stk2:list entry)
  : Pure (rep code pc acts pos2 stk2 p x)
         (requires pos <= pos2 /\ (forall (i:nat). mem i p ==> empty_start i stk2 == empty_start i stk))
         (ensures fun _ -> True) (decreases h)
  = match h with
    | RJump pc tg acts _ _ p x _ h' -> RJump pc tg acts pos2 stk2 p x () (rep_mono h' pos2 stk2)
    | REnd pc _ _ _ -> REnd pc pos2 stk2 ()
    | RRe pc r eid push k _ _ p x pc' pos' _ h' ->
      RRe pc r eid push k pos2 stk2 p x pc' pos' () (rep_mono h' pos' stk2)
    | RClose pc n p0 k _ _ p x _ h' -> RClose pc n p0 k pos2 stk2 p x () (rep_mono h' pos2 stk2)
    | RChkNull pc l a eid push p0 k _ _ p x pc' pos' _ h' ->
      RChkNull pc l a eid push p0 k pos2 stk2 p x pc' pos' () (rep_mono h' pos' stk2)
    | RChkNN pc l a eid push p0 k _ _ p x pc' pos' _ h' ->
      RChkNN pc l a eid push p0 k pos2 stk2 p x pc' pos' () (rep_mono h' pos' stk2)

(* ---- the simulation result ---- *)

(* o = (number of VM steps, final captures) *)
let simres (code:list instr) (s:list nat) (c:list (nat & nat)) (x:list nat) (pc pos:nat)
           (m:mcaps) (stk:list entry) (t:tree) (o:nat & mcaps) : prop =
  match first_match t with
  | Some (e, g') -> exe code s (fst o) (St pc pos m stk) == Halt (Some (e, snd o)) /\
                    (forall (k:nat). rv (mget k (snd o)) == gget k g')
  | None -> meq c x (snd o) m /\ exe code s (fst o) (St pc pos m stk) == fail stk (snd o)

(* the induction hypothesis at fuel f *)
let ih_t (code:list instr) (s:list nat) (f:nat) =
  acts:list action -> pos:nat -> g:gmap -> t:tree -> pc:nat -> stk:list entry ->
  p:list nat -> x:list nat -> m:mcaps -> h:rep code pc acts pos stk p x ->
  Pure (nat & mcaps)
    (requires compute_tree f s acts pos g == Some t /\ capsrel m g (cls acts) x /\ uniq acts)
    (ensures fun o -> simres code s (cls acts) x pc pos m stk t o)

(* a choice point: OP_PUSH (and j - 1 more steps), the first branch,
   then on its failure the second *)
let choice (code:list instr) (s:list nat) (c:list (nat & nat)) (x:list nat) (pc pos:nat)
           (m:mcaps) (stk stk1:list entry) (pcA pcB:nat) (t1 t2:tree) (j:nat)
           (oA:(nat & mcaps){simres code s c x pcA pos m stk1 t1 oA})
           (fB:((m1:mcaps{meq c x m1 m}) -> o:(nat & mcaps){simres code s c x pcB pos m1 stk t2 o}))
  : Pure (nat & mcaps)
         (requires exe code s j (St pc pos m stk) == Next (St pcA pos m stk1) /\
                   (forall (m1:mcaps). fail stk1 m1 == Next (St pcB pos m1 stk)))
         (ensures fun o -> simres code s c x pc pos m stk (TChoice t1 t2) o)
  = exe_add code s j (fst oA) (St pc pos m stk);
    match first_match t1 with
    | Some _ -> (j + fst oA, snd oA)
    | None ->
      let oB = fB (snd oA) in
      exe_add code s (j + fst oA) (fst oB) (St pc pos m stk);
      (match first_match t2 with
       | Some _ -> ()
       | None -> meq_trans c x (snd oB) (snd oA) m);
      (j + fst oA + fst oB, snd oB)

(* ---- the cases of sim ---- *)

let case_end (code:list instr) (s:list nat) (pc pos:nat) (stk:list entry) (g:gmap) (m:mcaps)
  : Pure (nat & mcaps)
         (requires nth code pc == Some IEnd /\ capsrel m g [] [])
         (ensures fun o -> simres code s [] [] pc pos m stk (TMatch pos g) o)
  = capsrel_end m g; (1, m)

let case_close (code:list instr) (s:list nat) (f:pos) (ih:ih_t code s (f - 1))
               (pc n p0:nat) (k:list action) (pos:nat) (stk:list entry) (p x:list nat)
               (g:gmap) (t:tree) (m:mcaps) (h':rep code (pc + 1) k pos stk p x)
  : Pure (nat & mcaps)
         (requires compute_tree f s (AClose n p0 :: k) pos g == Some t /\
                   capsrel m g ((n, p0) :: cls k) x /\ uniq (AClose n p0 :: k) /\
                   nth code pc == Some (IMemEnd n))
         (ensures fun o -> simres code s ((n, p0) :: cls k) x pc pos m stk t o)
  = let m' = mset n (fst (mget n m), Some pos) m in
    cls_none n k;
    capsrel_close m g (cls k) x n p0 pos;
    let o = ih k pos (gset n (p0, pos) g) t (pc + 1) stk p x m' h' in
    exe_next code s (fst o) (St pc pos m stk) (St (pc + 1) pos m' stk);
    (match first_match t with
     | Some _ -> ()
     | None -> meq_close (cls k) x (snd o) m n p0 pos);
    (fst o + 1, snd o)

let case_chk_null (code:list instr) (s:list nat) (f:pos) (ih:ih_t code s (f - 1))
                  (pc l:nat) (a:regex) (eid:nat) (push:bool) (p0:nat) (k:list action)
                  (pos:nat) (stk:list entry) (p x:list nat) (pc' pos':nat)
                  (g:gmap) (t:tree) (m:mcaps) (h':rep code pc' k pos' stk p x)
  : Pure (nat & mcaps)
         (requires compute_tree f s (ACheck p0 a :: k) pos g == Some t /\
                   capsrel m g (cls k) x /\ uniq (ACheck p0 a :: k) /\
                   code_at code l (comp (Star a) l eid push) /\ clen a <> 0 /\ nullable a /\
                   fresh eid (nchecks (Star a)) p /\ empty_start eid stk == Some p0 /\
                   p0 <= pos /\ pc == l + 2 + clen a /\ pc' == l + clen (Star a) /\ pos' <= p0)
         (ensures fun o -> simres code s (cls k) x pc pos m stk t o)
  = code_star_null code a l eid push;
    if pos = p0 then begin
      let o = ih k pos g t pc' stk p x m (rep_mono h' pos stk) in
      exe_next code s (fst o) (St pc pos m stk) (St pc' pos m stk);
      (fst o + 1, snd o)
    end else begin
      let hr : rep code l (ARe (Star a) :: k) pos stk p (append (npg (Star a) push) x) =
        RRe l (Star a) eid push k pos stk p x pc' pos' () h' in
      let o = ih (ARe (Star a) :: k) pos g t l stk p x m hr in
      exe_next code s (fst o) (St (pc + 1) pos m stk) (St l pos m stk);
      exe_next code s (fst o + 1) (St pc pos m stk) (St (pc + 1) pos m stk);
      (fst o + 1 + 1, snd o)
    end

let case_chk_nn (code:list instr) (s:list nat) (f:pos) (ih:ih_t code s (f - 1))
                (pc l:nat) (a:regex) (eid:nat) (push:bool) (p0:nat) (k:list action)
                (pos:nat) (stk:list entry) (p x:list nat) (pc' pos':nat)
                (g:gmap) (t:tree) (m:mcaps) (h':rep code pc' k pos' stk p x)
  : Pure (nat & mcaps)
         (requires compute_tree f s (ACheck p0 a :: k) pos g == Some t /\
                   capsrel m g (cls k) x /\ uniq (ACheck p0 a :: k) /\
                   code_at code l (comp (Star a) l eid push) /\ clen a <> 0 /\ not (nullable a) /\
                   fresh eid (nchecks (Star a)) p /\ p0 + minlen a <= pos /\
                   pc == l + 1 + clen a /\ pc' == l + clen (Star a) /\ pos' <= p0)
         (ensures fun o -> simres code s (cls k) x pc pos m stk t o)
  = code_star_nn code a l eid push;
    let hr : rep code l (ARe (Star a) :: k) pos stk p (append (npg (Star a) push) x) =
      RRe l (Star a) eid push k pos stk p x pc' pos' () h' in
    let o = ih (ARe (Star a) :: k) pos g t l stk p x m hr in
    exe_next code s (fst o) (St pc pos m stk) (St l pos m stk);
    (fst o + 1, snd o)

(* the facts every ARe case starts from *)
let re_pre (code:list instr) (s:list nat) (f:nat) (r:regex) (eid:nat) (push:bool)
           (k:list action) (pos:nat) (p x0:list nat) (pc' pos':nat) (g:gmap) (t:tree)
           (pc:nat) (m:mcaps) : prop =
  compute_tree f s (ARe r :: k) pos g == Some t /\
  capsrel m g (cls k) (append (npg r push) x0) /\ uniq (ARe r :: k) /\
  code_at code pc (comp r pc eid push) /\ fresh eid (nchecks r) p /\
  pc' == pc + clen r /\ pos' <= pos + minlen r

let case_empty (code:list instr) (s:list nat) (f:pos) (ih:ih_t code s (f - 1))
               (r:regex) (eid:nat) (push:bool) (k:list action) (pos:nat) (stk:list entry)
               (p x0:list nat) (pc' pos':nat) (g:gmap) (t:tree) (pc:nat) (m:mcaps)
               (h':rep code pc' k pos' stk p x0)
  : Pure (nat & mcaps)
         (requires re_pre code s f r eid push k pos p x0 pc' pos' g t pc m /\
                   (r == Eps \/ r == Lit []))
         (ensures fun o -> simres code s (cls k) (append (npg r push) x0) pc pos m stk t o)
  = ih k pos g t pc stk p x0 m (rep_mono h' pos stk)

let case_lit (code:list instr) (s:list nat) (f:pos) (ih:ih_t code s (f - 1))
             (l:list nat{Cons? l}) (eid:nat) (push:bool) (k:list action) (pos:nat) (stk:list entry)
             (p x0:list nat) (pc' pos':nat) (g:gmap) (t:tree) (pc:nat) (m:mcaps)
             (h':rep code pc' k pos' stk p x0)
  : Pure (nat & mcaps)
         (requires re_pre code s f (Lit l) eid push k pos p x0 pc' pos' g t pc m)
         (ensures fun o -> simres code s (cls k) (append (npg (Lit l) push) x0) pc pos m stk t o)
  = code_lit code l pc eid push;
    if is_prefix l (skipn pos s) then begin
      let o = ih k (pos + length l) g t pc' stk p x0 m (rep_mono h' (pos + length l) stk) in
      exe_next code s (fst o) (St pc pos m stk) (St (pc + 1) (pos + length l) m stk);
      (fst o + 1, snd o)
    end else begin
      exe_fail1 code s (St pc pos m stk) stk m;
      meq_refl (cls k) x0 m;
      (1, m)
    end

#push-options "--z3rlimit 20"
let case_cat (code:list instr) (s:list nat) (f:pos) (ih:ih_t code s (f - 1))
             (a b:regex) (eid:nat) (push:bool) (k:list action) (pos:nat) (stk:list entry)
             (p x0:list nat) (pc' pos':nat) (g:gmap) (t:tree) (pc:nat) (m:mcaps)
             (h':rep code pc' k pos' stk p x0)
  : Pure (nat & mcaps)
         (requires re_pre code s f (Cat a b) eid push k pos p x0 pc' pos' g t pc m)
         (ensures fun o -> simres code s (cls k) (append (npg (Cat a b) push) x0) pc pos m stk t o)
  = code_cat code a b pc eid push;
    nodup_append (groups a) (groups b);
    append_assoc (npg a push) (npg b push) x0;
    let xb = append (npg b push) x0 in
    let hb : rep code (pc + clen a) (ARe b :: k) (pos + minlen a) stk p xb =
      RRe (pc + clen a) b (eid + nchecks a) push k (pos + minlen a) stk p x0 pc' pos' () h' in
    let ha : rep code pc (ARe a :: ARe b :: k) pos stk p (append (npg a push) xb) =
      RRe pc a eid push (ARe b :: k) pos stk p xb (pc + clen a) (pos + minlen a) () hb in
    ih (ARe a :: ARe b :: k) pos g t pc stk p (append (npg a push) xb) m ha
#pop-options

let case_alt (code:list instr) (s:list nat) (f:pos) (ih:ih_t code s (f - 1))
             (a b:regex) (eid:nat) (push:bool) (k:list action) (pos:nat) (stk:list entry)
             (p x0:list nat) (pc' pos':nat) (g:gmap) (t:tree) (pc:nat) (m:mcaps)
             (h':rep code pc' k pos' stk p x0)
  : Pure (nat & mcaps)
         (requires re_pre code s f (Alt a b) eid push k pos p x0 pc' pos' g t pc m)
         (ensures fun o -> simres code s (cls k) (append (npg (Alt a b) push) x0) pc pos m stk t o)
  = code_alt code a b pc eid push;
    nodup_append (groups a) (groups b);
    let f1 : nat = f - 1 in
    let t1 = Some?.v (compute_tree f1 s (ARe a :: k) pos g) in
    let t2 = Some?.v (compute_tree f1 s (ARe b :: k) pos g) in
    let pcB = pc + clen a + 2 in
    let stk1 = EAlt pcB pos :: stk in
    let hj : rep code (pc + 1 + clen a) k pos' stk1 p x0 =
      RJump (pc + 1 + clen a) pc' k pos' stk1 p x0 () (rep_mono h' pos' stk1) in
    let ha : rep code (pc + 1) (ARe a :: k) pos stk1 p (append (npg a true) x0) =
      RRe (pc + 1) a eid true k pos stk1 p x0 (pc + 1 + clen a) pos' () hj in
    let hb : rep code pcB (ARe b :: k) pos stk p (append (npg b true) x0) =
      RRe pcB b (eid + nchecks a) true k pos stk p x0 pc' pos' () h' in
    let oA = ih (ARe a :: k) pos g t1 (pc + 1) stk1 p x0 m ha in
    exe_next code s 0 (St pc pos m stk) (St (pc + 1) pos m stk1);
    choice code s (cls k) x0 pc pos m stk stk1 (pc + 1) pcB t1 t2 1 oA
      (fun m1 -> capsrel_meq m g (cls k) x0 m1; ih (ARe b :: k) pos g t2 pcB stk p x0 m1 hb)

let case_star0 (code:list instr) (s:list nat) (f:pos) (ih:ih_t code s (f - 1))
               (a:regex) (eid:nat) (push:bool) (k:list action) (pos:nat) (stk:list entry)
               (p x0:list nat) (pc' pos':nat) (g:gmap) (t:tree) (pc:nat) (m:mcaps)
               (h':rep code pc' k pos' stk p x0)
  : Pure (nat & mcaps)
         (requires re_pre code s f (Star a) eid push k pos p x0 pc' pos' g t pc m /\ clen a = 0)
         (ensures fun o -> simres code s (cls k) (append (npg (Star a) push) x0) pc pos m stk t o)
  = let f1 : nat = f - 1 in
    let t2 = Some?.v (compute_tree f1 s k pos g) in
    clen0_fm s a f1 (ACheck pos a :: k) pos g;
    let f2 : nat = f1 - 1 in
    ct_det s f2 f1 k pos g;
    ih k pos g t2 pc stk p x0 m (rep_mono h' pos stk)

let case_star_null (code:list instr) (s:list nat) (f:pos) (ih:ih_t code s (f - 1))
                   (a:regex) (eid:nat) (push:bool) (k:list action) (pos:nat) (stk:list entry)
                   (p x0:list nat) (pc' pos':nat) (g:gmap) (t:tree) (pc:nat) (m:mcaps)
                   (h':rep code pc' k pos' stk p x0)
  : Pure (nat & mcaps)
         (requires re_pre code s f (Star a) eid push k pos p x0 pc' pos' g t pc m /\
                   clen a <> 0 /\ nullable a)
         (ensures fun o -> simres code s (cls k) (append (npg (Star a) push) x0) pc pos m stk t o)
  = code_star_null code a pc eid push;
    let f1 : nat = f - 1 in
    let t1 = Some?.v (compute_tree f1 s (ARe a :: ACheck pos a :: k) pos g) in
    let t2 = Some?.v (compute_tree f1 s k pos g) in
    let pcB = pc + clen a + 4 in
    let stk2 = EEmptyStart eid pos :: EAlt pcB pos :: stk in
    let hchk : rep code (pc + 2 + clen a) (ACheck pos a :: k) pos stk2 (eid :: p) x0 =
      RChkNull (pc + 2 + clen a) pc a eid push pos k pos stk2 p x0 pc' pos' ()
        (rep_mono h' pos' stk2) in
    let ha : rep code (pc + 2) (ARe a :: ACheck pos a :: k) pos stk2 (eid :: p) (append (npg a true) x0) =
      RRe (pc + 2) a (eid + 1) true (ACheck pos a :: k) pos stk2 (eid :: p) x0 (pc + 2 + clen a) pos ()
        hchk in
    let oA = ih (ARe a :: ACheck pos a :: k) pos g t1 (pc + 2) stk2 (eid :: p) x0 m ha in
    exe_next code s 0 (St (pc + 1) pos m (EAlt pcB pos :: stk)) (St (pc + 2) pos m stk2);
    exe_next code s 1 (St pc pos m stk) (St (pc + 1) pos m (EAlt pcB pos :: stk));
    choice code s (cls k) x0 pc pos m stk stk2 (pc + 2) pcB t1 t2 2 oA
      (fun m1 -> capsrel_meq m g (cls k) x0 m1; ih k pos g t2 pcB stk p x0 m1 (rep_mono h' pos stk))

let case_star_nn (code:list instr) (s:list nat) (f:pos) (ih:ih_t code s (f - 1))
                 (a:regex) (eid:nat) (push:bool) (k:list action) (pos:nat) (stk:list entry)
                 (p x0:list nat) (pc' pos':nat) (g:gmap) (t:tree) (pc:nat) (m:mcaps)
                 (h':rep code pc' k pos' stk p x0)
  : Pure (nat & mcaps)
         (requires re_pre code s f (Star a) eid push k pos p x0 pc' pos' g t pc m /\
                   clen a <> 0 /\ not (nullable a))
         (ensures fun o -> simres code s (cls k) (append (npg (Star a) push) x0) pc pos m stk t o)
  = code_star_nn code a pc eid push;
    let f1 : nat = f - 1 in
    let t1 = Some?.v (compute_tree f1 s (ARe a :: ACheck pos a :: k) pos g) in
    let t2 = Some?.v (compute_tree f1 s k pos g) in
    let pcB = pc + clen a + 2 in
    let stk1 = EAlt pcB pos :: stk in
    let hchk : rep code (pc + 1 + clen a) (ACheck pos a :: k) (pos + minlen a) stk1 p x0 =
      RChkNN (pc + 1 + clen a) pc a eid push pos k (pos + minlen a) stk1 p x0 pc' pos' ()
        (rep_mono h' pos' stk1) in
    let ha : rep code (pc + 1) (ARe a :: ACheck pos a :: k) pos stk1 p (append (npg a true) x0) =
      RRe (pc + 1) a eid true (ACheck pos a :: k) pos stk1 p x0 (pc + 1 + clen a) (pos + minlen a) ()
        hchk in
    let oA = ih (ARe a :: ACheck pos a :: k) pos g t1 (pc + 1) stk1 p x0 m ha in
    exe_next code s 0 (St pc pos m stk) (St (pc + 1) pos m stk1);
    choice code s (cls k) x0 pc pos m stk stk1 (pc + 1) pcB t1 t2 1 oA
      (fun m1 -> capsrel_meq m g (cls k) x0 m1; ih k pos g t2 pcB stk p x0 m1 (rep_mono h' pos stk))

let case_group (code:list instr) (s:list nat) (f:pos) (ih:ih_t code s (f - 1))
               (n:nat) (a:regex) (eid:nat) (push:bool) (k:list action) (pos:nat) (stk:list entry)
               (p x0:list nat) (pc' pos':nat) (g:gmap) (t:tree) (pc:nat) (m:mcaps)
               (h':rep code pc' k pos' stk p x0)
  : Pure (nat & mcaps)
         (requires re_pre code s f (Group n a) eid push k pos p x0 pc' pos' g t pc m)
         (ensures fun o -> simres code s (cls k) (append (npg (Group n a) push) x0) pc pos m stk t o)
  = code_group code n a pc eid push;
    cls_none n k;
    let acts' = ARe a :: AClose n pos :: k in
    let mk (stk':list entry{forall (i:nat). mem i p ==> empty_start i stk' == empty_start i stk})
      : rep code (pc + 1) acts' pos stk' p (append (npg a push) x0) =
      RRe (pc + 1) a eid push (AClose n pos :: k) pos stk' p x0 (pc + 1 + clen a) (pos + minlen a) ()
        (RClose (pc + 1 + clen a) n pos k (pos + minlen a) stk' p x0 ()
          (rep_mono h' (pos + minlen a) stk')) in
    if push then begin
      let stk' = EMemStart n (mget n m) :: stk in
      let m2 = mset n (Some pos, None) m in
      capsrel_open m g (cls k) x0 x0 n pos (Some pos, None);
      let o = ih acts' pos g t (pc + 1) stk' p x0 m2 (mk stk') in
      exe_next code s (fst o) (St pc pos m stk) (St (pc + 1) pos m2 stk');
      match first_match t with
      | Some _ -> (fst o + 1, snd o)
      | None -> meq_push (cls k) x0 (snd o) m n pos; (fst o + 1, mset n (mget n m) (snd o))
    end else begin
      let x1 = append (topg a) x0 in
      let m2 = mset n (Some pos, snd (mget n m)) m in
      capsrel_open m g (cls k) (n :: x1) x1 n pos (Some pos, snd (mget n m));
      let o = ih acts' pos g t (pc + 1) stk p x1 m2 (mk stk) in
      exe_next code s (fst o) (St pc pos m stk) (St (pc + 1) pos m2 stk);
      (match first_match t with
       | Some _ -> ()
       | None -> meq_nopush (cls k) x1 (snd o) m n pos (Some pos, snd (mget n m)));
      (fst o + 1, snd o)
    end

(* ---- lemmas (b) and (c) ---- *)

let rec sim (code:list instr) (s:list nat) (f:nat) (acts:list action) (pos:nat) (g:gmap) (t:tree)
            (pc:nat) (stk:list entry) (p x:list nat) (m:mcaps) (h:rep code pc acts pos stk p x)
  : Pure (nat & mcaps)
         (requires compute_tree f s acts pos g == Some t /\ capsrel m g (cls acts) x /\ uniq acts)
         (ensures fun o -> simres code s (cls acts) x pc pos m stk t o)
         (decreases %[f; h])
  = assert (f > 0);
    let ih : ih_t code s (f - 1) =
      fun acts pos g t pc stk p x m h -> sim code s (f - 1) acts pos g t pc stk p x m h in
    match h with
    | RJump _ tg _ _ _ _ _ _ h' ->
      let o = sim code s f acts pos g t tg stk p x m h' in
      exe_next code s (fst o) (St pc pos m stk) (St tg pos m stk);
      (fst o + 1, snd o)
    | REnd _ _ _ _ -> case_end code s pc pos stk g m
    | RRe _ r eid push k _ _ _ x0 pc' pos' _ h' ->
      (match r with
       | Eps -> case_empty code s f ih r eid push k pos stk p x0 pc' pos' g t pc m h'
       | Lit [] -> case_empty code s f ih r eid push k pos stk p x0 pc' pos' g t pc m h'
       | Lit l -> case_lit code s f ih l eid push k pos stk p x0 pc' pos' g t pc m h'
       | Cat a b -> case_cat code s f ih a b eid push k pos stk p x0 pc' pos' g t pc m h'
       | Alt a b -> case_alt code s f ih a b eid push k pos stk p x0 pc' pos' g t pc m h'
       | Star a ->
         if clen a = 0 then case_star0 code s f ih a eid push k pos stk p x0 pc' pos' g t pc m h'
         else if nullable a then case_star_null code s f ih a eid push k pos stk p x0 pc' pos' g t pc m h'
         else case_star_nn code s f ih a eid push k pos stk p x0 pc' pos' g t pc m h'
       | Group n a -> case_group code s f ih n a eid push k pos stk p x0 pc' pos' g t pc m h')
    | RClose _ n p0 k _ _ _ _ _ h' -> case_close code s f ih pc n p0 k pos stk p x g t m h'
    | RChkNull _ l a eid push p0 k _ _ p' _ pc' pos' _ h' ->
      case_chk_null code s f ih pc l a eid push p0 k pos stk p' x pc' pos' g t m h'
    | RChkNN _ l a eid push p0 k _ _ _ _ pc' pos' _ h' ->
      case_chk_nn code s f ih pc l a eid push p0 k pos stk p x pc' pos' g t m h'

#pop-options
