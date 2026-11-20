(* Experiment #6, Isabelle/HOL: executable semantics of experiment #9's
   subset of Oniguruma f95747b (concatenation, alternation, greedy
   star, capture groups, character classes; UTF-8; forward search),
   transcribed from stack G (lab/06-spec-speed/g/g.ml) as the same
   small-step machine as rocq/Spec.v: stack G's pending items plus an
   explicit list of backtracking points, one machine step per call of
   stack G's step, fuel structural on nat.  Code_Target_Numeral maps
   nat and int to target integers for value [code] and export_code. *)

theory Spec
  imports Main "HOL-Library.Code_Target_Numeral"
begin

datatype node =
    Eps
  | Lit "nat list"                  (* bytes of one code point *)
  | Cls bool "(nat \<times> nat) list"     (* negated, sorted ranges *)
  | Cat node node
  | Alt node node
  | Star node                       (* greedy *)
  | Group nat node

datatype item =
    INode node
  | IClose nat nat                  (* group, start position *)
  | ILoop node nat                  (* star body, iteration start *)

type_synonym caps = "(nat \<times> (nat \<times> nat)) list"

(* backtracking point: items, position, rest of the subject, captures *)
type_synonym frame = "item list \<times> nat \<times> nat list \<times> caps"

datatype state =
    Run "item list" nat "nat list" caps "frame list"
  | Matched nat caps
  | Failed

(* UTF-8, as upstream/src/utf8.c (EncLen_UTF8, USE_RFC3629_RANGE) *)
definition enc_len :: "nat \<Rightarrow> nat" where
  "enc_len b = (if b < 194 then 1 else if b < 224 then 2 else if b < 240 then 3
               else if b < 245 then 4 else 1)"

(* recursion on nat by "if n = 0" rather than 0/Suc patterns: with
   Code_Target_Nat, 0 is not a constructor in code equations *)
fun take_n :: "nat \<Rightarrow> nat list \<Rightarrow> (nat list \<times> nat list) option" where
  "take_n n l = (if n = 0 then Some ([], l)
                 else (case l of [] \<Rightarrow> None
                       | x # t \<Rightarrow> (case take_n (n - 1) t of
                                    Some (a, r) \<Rightarrow> Some (x # a, r) | None \<Rightarrow> None)))"

definition lead_mod :: "nat \<Rightarrow> nat" where
  "lead_mod l = (if l = 2 then 32 else if l = 3 then 16 else 8)"

(* code point, encoded length, rest; None past the end (DATA_ENSURE) *)
definition decode :: "nat list \<Rightarrow> (nat \<times> nat \<times> nat list) option" where
  "decode rest = (case rest of
     [] \<Rightarrow> None
   | b # t \<Rightarrow> (let l = enc_len b in
       if l = 1 then Some (b, 1, t)
       else (case take_n (l - 1) t of
               Some (tb, r) \<Rightarrow> Some (foldl (\<lambda>v d. v * 64 + d mod 64) (b mod lead_mod l) tb, l, r)
             | None \<Rightarrow> None)))"

fun lit_prefix :: "nat list \<Rightarrow> nat list \<Rightarrow> nat list option" where
  "lit_prefix [] rest = Some rest"
| "lit_prefix (x # l) (y # r) = (if x = y then lit_prefix l r else None)"
| "lit_prefix (x # l) [] = None"

definition in_ranges :: "nat \<Rightarrow> (nat \<times> nat) list \<Rightarrow> bool" where
  "in_ranges c rs = list_ex (\<lambda>(lo, hi). lo \<le> c \<and> c \<le> hi) rs"

fun set_cap :: "nat \<Rightarrow> nat \<times> nat \<Rightarrow> caps \<Rightarrow> caps" where
  "set_cap k v [] = [(k, v)]"
| "set_cap k v ((k', w) # t) = (if k' = k then (k, v) # t else (k', w) # set_cap k v t)"

fun backtrack :: "frame list \<Rightarrow> state" where
  "backtrack [] = Failed"
| "backtrack ((its, pos, rest, cs) # bt) = Run its pos rest cs bt"

fun step_items :: "item list \<Rightarrow> nat \<Rightarrow> nat list \<Rightarrow> caps \<Rightarrow> frame list \<Rightarrow> state" where
  "step_items [] pos rest cs bt = Matched pos cs"
| "step_items (INode Eps # k) pos rest cs bt = Run k pos rest cs bt"
| "step_items (INode (Lit l) # k) pos rest cs bt =
     (case lit_prefix l rest of Some r \<Rightarrow> Run k (pos + length l) r cs bt | None \<Rightarrow> backtrack bt)"
| "step_items (INode (Cls ng rs) # k) pos rest cs bt =
     (case decode rest of
        Some (c, l, r) \<Rightarrow> (if in_ranges c rs = ng then backtrack bt else Run k (pos + l) r cs bt)
      | None \<Rightarrow> backtrack bt)"
| "step_items (INode (Cat a b) # k) pos rest cs bt = Run (INode a # INode b # k) pos rest cs bt"
| "step_items (INode (Alt a b) # k) pos rest cs bt =
     Run (INode a # k) pos rest cs ((INode b # k, pos, rest, cs) # bt)"
| "step_items (INode (Star a) # k) pos rest cs bt =
     Run (INode a # ILoop a pos # k) pos rest cs ((k, pos, rest, cs) # bt)"
| "step_items (ILoop a p0 # k) pos rest cs bt =
     (if pos = p0 then Run k pos rest cs bt else Run (INode (Star a) # k) pos rest cs bt)"
| "step_items (INode (Group i a) # k) pos rest cs bt = Run (INode a # IClose i pos # k) pos rest cs bt"
| "step_items (IClose i p0 # k) pos rest cs bt = Run k pos rest (set_cap i (p0, pos) cs) bt"

fun step :: "state \<Rightarrow> state" where
  "step (Run its pos rest cs bt) = step_items its pos rest cs bt"
| "step st = st"

(* at most fuel steps *)
fun run :: "nat \<Rightarrow> state \<Rightarrow> state" where
  "run f st = (if f = 0 then st
               else (case st of Run _ _ _ _ _ \<Rightarrow> run (f - 1) (step st) | _ \<Rightarrow> st))"

datatype result = RMatch nat nat caps | RMismatch | RLimit

(* forward search: start positions 0..length, advanced by enc_len *)
fun search_from :: "nat \<Rightarrow> nat \<Rightarrow> node \<Rightarrow> nat \<Rightarrow> nat list \<Rightarrow> result" where
  "search_from n fuel re pos rest = (if n = 0 then RMismatch else
     (case run fuel (Run [INode re] pos rest [] []) of
        Matched e cs \<Rightarrow> RMatch pos e cs
      | Run _ _ _ _ _ \<Rightarrow> RLimit
      | Failed \<Rightarrow> (case rest of
          [] \<Rightarrow> RMismatch
        | b # _ \<Rightarrow> (case take_n (enc_len b) rest of
                     Some (_, r) \<Rightarrow> search_from (n - 1) fuel re (pos + enc_len b) r
                   | None \<Rightarrow> RMismatch))))"

definition search :: "nat \<Rightarrow> node \<Rightarrow> nat list \<Rightarrow> result" where
  "search fuel re s = search_from (length s + 1) fuel re 0 s"

fun lookup :: "nat \<Rightarrow> caps \<Rightarrow> (nat \<times> nat) option" where
  "lookup k [] = None"
| "lookup k ((k', v) # t) = (if k = k' then Some v else lookup k t)"

(* verdict as numbers: [0] no match, [2] limit, 1 # s # e # groups,
   each group [1, s, e] or [0] when unset *)
fun encode :: "nat \<Rightarrow> result \<Rightarrow> nat list" where
  "encode ncap RMismatch = [0]"
| "encode ncap RLimit = [2]"
| "encode ncap (RMatch s e cs) =
     1 # s # e # concat (map (\<lambda>k. case lookup k cs of Some (x, y) \<Rightarrow> [1, x, y] | None \<Rightarrow> [0])
                             [1..<ncap + 1])"

definition fuel0 :: nat where "fuel0 = 10000000"

definition run_case :: "nat \<Rightarrow> nat \<Rightarrow> node \<Rightarrow> nat list \<Rightarrow> nat list" where
  "run_case fuel ncap re s = encode ncap (search fuel re s)"

(* a case: number of groups, pattern, subject bytes, expected verdict *)
type_synonym tcase = "nat \<times> node \<times> nat list \<times> nat list"

definition agree :: "nat \<Rightarrow> tcase \<Rightarrow> bool" where
  "agree fuel c = (case c of (ncap, re, s, exp) \<Rightarrow> run_case fuel ncap re s = exp)"

definition count :: "nat \<Rightarrow> tcase list \<Rightarrow> nat" where
  "count fuel cs = foldl (\<lambda>acc c. if agree fuel c then acc + 1 else acc) 0 cs"

(* r passes; pass i uses fuel0 + i so that no pass can be shared *)
fun passes :: "nat \<Rightarrow> tcase list \<Rightarrow> nat \<Rightarrow> nat" where
  "passes r cs acc = (if r = 0 then acc else passes (r - 1) cs (acc + count (fuel0 + r) cs))"

end
