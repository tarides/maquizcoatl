// Experiment #9, Verus driver: crate root of the executable (plain Rust
// outside verus!, like experiment #6's main2.rs).  Reads a case file
// (index id kind pat_hex sub_hex a b c ncap ast; the AST as an
// s-expression written by experiment #6's parser) and prints, for each
// case:
//   id TAB p TAB vm|sem|e06 TAB verdict    for every start position p
//   id TAB search TAB vm|sem|e06 TAB verdict
// in the C oracle's format (MATCH s0 e0 s1 e1 ..., unset -1 -1;
// MISMATCH; LIMIT for out of fuel); the same format as rocq/main.ml and
// fstar/main.ml.  vm: compile::ecompile then vm::evm (search:
// vm::esearch_vm); sem: sem::esem (sem::esearch_sem); these exec fns are
// proved equal to the spec fns compile, vm, sem and search.  e06:
// experiment #6 milestone 2's Verus semantics (spec2.rs, unchanged),
// with Star as Rep(0, None, true) and no backreferenced group; one
// `run` per start position, `search` for the search.
//   usage: verus_e09 CASES.tsv
mod syntax;
mod sem;
mod compile;
mod vm;
mod statement;
mod tables2;
mod spec2;

use syntax::{ERegex, ERes};

const FUEL: u64 = 10_000_000;

enum Sx { A(String), L(Vec<Sx>) }

fn tokens(s: &str) -> Vec<String> {
    let mut out = Vec::new();
    let mut b = String::new();
    for c in s.chars() {
        match c {
            '(' | ')' => {
                if !b.is_empty() { out.push(std::mem::take(&mut b)); }
                out.push(c.to_string());
            }
            ' ' => { if !b.is_empty() { out.push(std::mem::take(&mut b)); } }
            c => b.push(c),
        }
    }
    if !b.is_empty() { out.push(b); }
    out
}

fn parse(t: &[String], i: &mut usize) -> Sx {
    let x = &t[*i];
    *i += 1;
    if x == "(" {
        let mut v = Vec::new();
        while t[*i] != ")" { v.push(parse(t, i)); }
        *i += 1;
        Sx::L(v)
    } else {
        Sx::A(x.clone())
    }
}

fn bytes_of_hex(h: &str) -> Vec<u8> {
    (0..h.len() / 2).map(|i| u8::from_str_radix(&h[2 * i..2 * i + 2], 16).unwrap()).collect()
}

fn frag(x: &Sx) -> ERegex {
    match x {
        Sx::A(a) if a == "E" => ERegex::Eps,
        Sx::A(a) if a.starts_with('L') => ERegex::Lit(bytes_of_hex(&a[1..])),
        Sx::L(v) => match (v.first(), v.len()) {
            (Some(Sx::A(o)), 3) if o == "." => ERegex::Cat(Box::new(frag(&v[1])), Box::new(frag(&v[2]))),
            (Some(Sx::A(o)), 3) if o == "|" => ERegex::Alt(Box::new(frag(&v[1])), Box::new(frag(&v[2]))),
            (Some(Sx::A(o)), 2) if o == "*" => ERegex::Star(Box::new(frag(&v[1]))),
            (Some(Sx::A(o)), 3) if o == "g" => match &v[1] {
                Sx::A(k) => ERegex::Group(k.parse().unwrap(), Box::new(frag(&v[2]))),
                _ => panic!("not a fragment AST"),
            },
            _ => panic!("not a fragment AST"),
        },
        _ => panic!("not a fragment AST"),
    }
}

// experiment #6's arena (spec2::Re) for the same AST
fn e06(x: &Sx, re: &mut spec2::Re) -> usize {
    let n = match x {
        Sx::A(a) if a == "E" => spec2::Node::Eps,
        Sx::A(a) if a.starts_with('L') => {
            let b = bytes_of_hex(&a[1..]);
            let st = re.bytes.len();
            re.bytes.extend_from_slice(&b);
            spec2::Node::Lit(st, b.len())
        }
        Sx::L(v) => match (&v[0], v.len()) {
            (Sx::A(o), 3) if o == "." => { let a = e06(&v[1], re); let b = e06(&v[2], re); spec2::Node::Cat(a, b) }
            (Sx::A(o), 3) if o == "|" => { let a = e06(&v[1], re); let b = e06(&v[2], re); spec2::Node::Alt(a, b) }
            (Sx::A(o), 2) if o == "*" => { let a = e06(&v[1], re); spec2::Node::Rep(0, None, true, a) }
            (Sx::A(o), 3) if o == "g" => match &v[1] {
                Sx::A(k) => { let a = e06(&v[2], re); spec2::Node::Group(k.parse().unwrap(), a) }
                _ => panic!("not a fragment AST"),
            },
            _ => panic!("not a fragment AST"),
        },
        _ => panic!("not a fragment AST"),
    };
    re.nodes.push(n);
    re.nodes.len() - 1
}

fn show(p: usize, r: &ERes) -> String {
    match r {
        ERes::Match(e, caps) => {
            let mut v = vec![p as i64, *e as i64];
            for c in caps.iter() {
                match c { Some((a, b)) => { v.push(*a as i64); v.push(*b as i64); } None => { v.push(-1); v.push(-1); } }
            }
            format!("MATCH {}", v.iter().map(|x| x.to_string()).collect::<Vec<_>>().join(" "))
        }
        ERes::NoMatch => "MISMATCH".to_string(),
        ERes::OutOfFuel => "LIMIT".to_string(),
    }
}

fn show_search(o: &Option<(usize, ERes)>) -> String {
    match o { None => "MISMATCH".to_string(), Some((p, r)) => show(*p, r) }
}

// spec2::encode's numbers: [0] no match, [2] limit, 1 s e then per group [1 s e] or [0]
fn show_e06(v: &[u64]) -> String {
    match v[0] {
        0 => "MISMATCH".to_string(),
        2 => "LIMIT".to_string(),
        _ => {
            let mut out = vec![v[1] as i64, v[2] as i64];
            let mut i = 3;
            while i < v.len() {
                if v[i] == 1 { out.push(v[i + 1] as i64); out.push(v[i + 2] as i64); i += 3; }
                else { out.push(-1); out.push(-1); i += 1; }
            }
            format!("MATCH {}", out.iter().map(|x| x.to_string()).collect::<Vec<_>>().join(" "))
        }
    }
}

fn run_file(path: &str) {
    let text = std::fs::read_to_string(path).unwrap();
    let refs: Vec<usize> = Vec::new();
    for line in text.lines() {
        let f: Vec<&str> = line.split('\t').collect();
        let id = f[1];
        let toks = tokens(f[9]);
        let ast = parse(&toks, &mut 0);
        let s = bytes_of_hex(f[4]);
        let r = frag(&ast);
        let mut re6 = spec2::Re { nodes: Vec::new(), bytes: Vec::new(), cps: Vec::new(), seqs: Vec::new(),
            kids: Vec::new(), gidx: Vec::new(), csets: Vec::new(), cidx: Vec::new(), root: 0 };
        re6.root = e06(&ast, &mut re6);
        let n = syntax::encap(&r);
        let code = compile::ecompile(&r).expect("address overflow in compile");
        for p in 0..=s.len() {
            println!("{}\t{}\tvm\t{}", id, p, show(p, &vm::evm(FUEL, &code, n, &s, p)));
            println!("{}\t{}\tsem\t{}", id, p, show(p, &sem::esem(FUEL, &r, &s, p)));
            let o = match spec2::run(&re6, &refs, &s, p, spec2::FUEL0) {
                spec2::Outcome::Matched(e, m, cs) => spec2::SResult::Match(p, e, m, cs),
                spec2::Outcome::Failed => spec2::SResult::Mismatch,
                spec2::Outcome::Limit => spec2::SResult::Limit,
            };
            println!("{}\t{}\te06\t{}", id, p, show_e06(&spec2::encode(n, &o)));
        }
        println!("{}\tsearch\tvm\t{}", id, show_search(&vm::esearch_vm(FUEL, &code, n, &s)));
        println!("{}\tsearch\tsem\t{}", id, show_search(&sem::esearch_sem(FUEL, &r, &s)));
        println!("{}\tsearch\te06\t{}", id, show_e06(&spec2::encode(n, &spec2::search(&re6, &refs, &s, spec2::FUEL0))));
    }
}

fn main() {
    let path = std::env::args().nth(1).expect("usage: verus_e09 CASES.tsv");
    // the exec semantics recurses once per tree node on a path
    let h = std::thread::Builder::new().stack_size(1 << 30).spawn(move || run_file(&path)).unwrap();
    h.join().unwrap();
}
