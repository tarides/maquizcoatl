module Proof
(* Experiment #9, F* M2, lemma (d) for the VM and lemma (e): the main
   theorem (Statement.fst), from the simulation (ProofSim.sim) at the
   empty continuation (code OP_END, stack [EFinish]) and the fuel of the
   semantics (ProofSem.fuel_of), after rocq/Proof.v.  The VM's
   completeness comes out of the simulation itself: [sim] returns the
   number of VM steps. *)

open Syntax
open Sem
open Compile
open Vm
open Statement
open ProofA
open ProofSem
open ProofSim

#push-options "--fuel 2 --ifuel 1 --z3rlimit 10"

let rec run_mono (code:list instr) (s:list nat) (n:nat) (st:state) (n':nat)
  : Lemma (requires Some? (run n code s st) /\ n <= n')
          (ensures run n' code s st == run n code s st)
          (decreases n)
  = match step code s st with
    | Next st' -> run_mono code s (n - 1) st' (n' - 1)
    | Halt _ -> ()

let run_det (code:list instr) (s:list nat) (n1 n2:nat) (st:state)
  : Lemma (requires Some? (run n1 code s st) /\ Some? (run n2 code s st))
          (ensures run n1 code s st == run n2 code s st)
  = run_mono code s n1 st (n1 + n2); run_mono code s n2 st (n1 + n2)

let rec exe_run (code:list instr) (s:list nat) (n:nat) (st:state) (r:option (nat & mcaps))
  : Lemma (requires exe code s n st == Halt r) (ensures run n code s st == Some r)
          (decreases n)
  = match step code s st with
    | Next st' -> exe_run code s (n - 1) st' r
    | Halt _ -> ()

let vm_det (n1 n2:nat) (code:list instr) (k:nat) (s:list nat) (p:nat)
  : Lemma (requires vm n1 code k s p <> OutOfFuel /\ vm n2 code k s p <> OutOfFuel)
          (ensures vm n1 code k s p == vm n2 code k s p)
  = run_det code s n1 n2 (St 0 p [] [EFinish])

let rec region_spans (k n:nat) (m:mcaps) (g:gmap)
  : Lemma (requires forall (j:nat). rv (mget j m) == gget j g)
          (ensures region_from k n m == spans_from k n g)
          (decreases n)
  = if n = 0 then () else region_spans (k + 1) (n - 1) m g

let sem_of (r:regex) (t:tree) : result =
  match first_match t with
  | None -> NoMatch
  | Some (e, g) -> Match e (spans (ncap r) g)

(* lemma (d), VM: the VM on [compile r] finishes with the semantics'
   result (the fuel is returned) *)
let vm_complete (r:regex) (s:list nat) (p:nat) (f:nat) (t:tree)
  : Pure nat (requires nodup (groups r) /\ compute_tree f s [ARe r] p [] == Some t)
             (ensures fun n -> vm n (compile r) (ncap r) s p == sem_of r t)
  = let code = compile r in
    code_compile r;
    let x = append (npg r false) [] in
    let hend : rep code (clen r) [] p [EFinish] [] [] = REnd (clen r) p [EFinish] () in
    let hrep : rep code 0 [ARe r] p [EFinish] [] x =
      RRe 0 r 0 false [] p [EFinish] [] [] (clen r) p () hend in
    capsrel_init x;
    let o = sim code s f [ARe r] p [] t 0 [EFinish] [] x [] hrep in
    match first_match t with
    | Some (e, g) ->
      exe_run code s (fst o) (St 0 p [] [EFinish]) (Some (e, snd o));
      region_spans 1 (ncap r) (snd o) g;
      assert (run (fst o) code s (St 0 p [] [EFinish]) == Some (Some (e, snd o)));
      assert (region (ncap r) (snd o) == spans (ncap r) g);
      assert (sem_of r t == Match e (spans (ncap r) g));
      fst o
    | None ->
      exe_run code s (fst o) (St 0 p [] [EFinish]) None;
      assert (sem_of r t == NoMatch);
      fst o

let main_aux (r:regex) (s:list nat) (p:nat)
  : Lemma (requires nodup (groups r) /\ p <= length s)
          (ensures
            (forall (fv fs:nat).
               (vm fv (compile r) (ncap r) s p <> OutOfFuel /\ sem fs r s p <> OutOfFuel) ==>
               sem fs r s p == vm fv (compile r) (ncap r) s p)
            /\ (exists (fs:nat). sem fs r s p <> OutOfFuel)
            /\ (exists (fv:nat). vm fv (compile r) (ncap r) s p <> OutOfFuel))
  = let f0 = fuel_of s [ARe r] p [] in
    let t0 = Some?.v (compute_tree f0 s [ARe r] p []) in
    let n0 = vm_complete r s p f0 t0 in
    let sound (fv fs:nat)
      : Lemma ((vm fv (compile r) (ncap r) s p <> OutOfFuel /\ sem fs r s p <> OutOfFuel) ==>
               sem fs r s p == vm fv (compile r) (ncap r) s p)
      = if vm fv (compile r) (ncap r) s p <> OutOfFuel && sem fs r s p <> OutOfFuel then begin
          ct_det s fs f0 [ARe r] p [];
          vm_det n0 fv (compile r) (ncap r) s p
        end in
    FStar.Classical.forall_intro_2 sound;
    FStar.Classical.exists_intro (fun (fs:nat) -> sem fs r s p <> OutOfFuel) f0;
    FStar.Classical.exists_intro (fun (fv:nat) -> vm fv (compile r) (ncap r) s p <> OutOfFuel) n0

(* lemma (e) *)
let main_theorem () : Lemma main_theorem_statement =
  let aux (r:regex) (s:list nat) (p:nat)
    : Lemma (nodup (groups r) ==> p <= length s ==>
             ((forall (fv fs:nat).
                 (vm fv (compile r) (ncap r) s p <> OutOfFuel /\ sem fs r s p <> OutOfFuel) ==>
                 sem fs r s p == vm fv (compile r) (ncap r) s p)
              /\ (exists (fs:nat). sem fs r s p <> OutOfFuel)
              /\ (exists (fv:nat). vm fv (compile r) (ncap r) s p <> OutOfFuel)))
    = if nodup (groups r) && p <= length s then main_aux r s p in
  FStar.Classical.forall_intro_3 aux

#pop-options

(* Why Statement.fst needs [nodup (groups r)]: a group nested in a group
   with the same number (no parser writes it; the AST type allows it).
   The VM keeps the inner group's start, the semantics the outer one's
   (as rocq/Proof.v, nested_same_group_vm and nested_same_group_sem). *)
let nested_same_group_vm =
  assert_norm (vm 100 (compile (Group 1 (Cat (Lit [97]) (Group 1 (Lit [98]))))) 1 [97; 98] 0
               == Match 2 [Some (1, 2)])

let nested_same_group_sem =
  assert_norm (sem 100 (Group 1 (Cat (Lit [97]) (Group 1 (Lit [98])))) [97; 98] 0
               == Match 2 [Some (0, 2)])
