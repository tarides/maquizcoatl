// Experiment #11: Rust `regex` harness. Same modes, output format and
// enumeration loop as driver.h (see there). Searches extract every
// capture group (captures_read_at with one CaptureLocations per pattern,
// reused across searches), as Oniguruma and PCRE2 fill every group.
use regex::bytes::{CaptureLocations, Regex, RegexBuilder};
use std::cell::RefCell;
use std::io::{BufRead, BufReader, Write};
use std::time::Instant;

struct Pat { syntax: String, options: u64, encoding: String, pat: Vec<u8> }

const O_IGNORECASE: u64 = 1;
const O_EXTEND: u64 = 2;
const O_MULTILINE: u64 = 4;
const O_SINGLELINE: u64 = 8;
const O_NEGATE_SINGLELINE: u64 = 64;
const O_CAPTURE_GROUP_BITS: u64 = 128 | 256;

fn unhex(h: &str) -> Vec<u8> {
    let b = h.as_bytes();
    let v = |c: u8| -> u8 { match c { b'0'..=b'9' => c - b'0', b'a'..=b'f' => c - b'a' + 10, _ => c - b'A' + 10 } };
    (0..b.len() / 2).map(|i| v(b[2 * i]) << 4 | v(b[2 * i + 1])).collect()
}

fn lines(dir: &str, name: &str) -> Vec<String> {
    let f = std::fs::File::open(format!("{}/{}", dir, name)).expect(name);
    BufReader::new(f).lines().map(|l| l.unwrap()).collect()
}

fn perl_like(s: &str) -> bool { matches!(s, "ONIGURUMA" | "RUBY" | "PERL_NG" | "PERL" | "JAVA" | "PYTHON") }
fn singleline(p: &Pat) -> bool {
    if p.options & O_NEGATE_SINGLELINE != 0 { return false; }
    p.options & O_SINGLELINE != 0 || matches!(p.syntax.as_str(), "PERL_NG" | "PERL" | "JAVA" | "PYTHON")
}

// 0 ok, 1 err, 2 unsup, 3 limit
fn compile(p: &Pat) -> Result<Regex, (u8, String)> {
    if p.encoding != "UTF-8" || !perl_like(&p.syntax) { return Err((2, "syntax or encoding".into())); }
    if p.options & !(O_IGNORECASE | O_EXTEND | O_MULTILINE | O_SINGLELINE | O_CAPTURE_GROUP_BITS) != 0 {
        return Err((2, format!("option {}", p.options)));
    }
    let s = match std::str::from_utf8(&p.pat) { Ok(s) => s, Err(_) => return Err((2, "pattern not UTF-8".into())) };
    // Defaults otherwise: Unicode on, size_limit and dfa_size_limit default.
    RegexBuilder::new(s)
        .case_insensitive(p.options & O_IGNORECASE != 0)
        .ignore_whitespace(p.options & O_EXTEND != 0)
        .dot_matches_new_line(p.options & O_MULTILINE != 0)
        .multi_line(!singleline(p))
        .build()
        .map_err(|e| match e {
            regex::Error::CompiledTooBig(_) => (3, "CompiledTooBig".into()),
            _ => (1, "syntax".into()),
        })
}

fn utf8_advance(s: &[u8], at: usize) -> usize {
    if at >= s.len() { return 1; }
    let c = s[at];
    let n = if c < 0x80 { 1 } else if c < 0xC2 { 1 } else if c < 0xE0 { 2 } else if c < 0xF0 { 3 } else if c < 0xF5 { 4 } else { 1 };
    if at + n > s.len() { s.len() - at } else { n }
}

fn enum_pair(re: &Regex, locs: &mut CaptureLocations, s: &[u8], out: Option<&mut String>) -> u64 {
    let mut pos = 0usize;
    let mut n = 0u64;
    let mut out = out;
    while pos <= s.len() {
        match re.captures_read_at(locs, s, pos) {
            None => break,
            Some(m) => {
                n += 1;
                if let Some(o) = out.as_deref_mut() { o.push_str(&format!(" {}-{}", m.start(), m.end())); }
                if m.end() > m.start() { pos = m.end(); }
                else { if m.end() >= s.len() { break; } pos = m.end() + utf8_advance(s, m.end()); }
            }
        }
    }
    n
}

fn env_f(k: &str, d: f64) -> f64 { std::env::var(k).ok().and_then(|v| v.parse().ok()).unwrap_or(d) }

fn main() {
    let a: Vec<String> = std::env::args().collect();
    let mode = a.get(1).map(|s| s.as_str()).unwrap_or("");
    let stdout = std::io::stdout();
    let mut w = std::io::BufWriter::new(stdout.lock());
    if mode == "worst" {
        let p = Pat { syntax: a[3].clone(), options: a[4].parse().unwrap(), encoding: "UTF-8".into(), pat: a[2].as_bytes().to_vec() };
        let n: usize = a[5].parse().unwrap();
        match compile(&p) {
            Err((c, why)) => { writeln!(w, "compile\t{}\t{}", c, why).unwrap(); }
            Ok(re) => {
                let mut s = vec![b'a'; n]; s.push(b'!');
                let mut locs = re.capture_locations();
                let t0 = Instant::now();
                let r = re.captures_read_at(&mut locs, &s, 0).is_some();
                writeln!(w, "result\t{}\t{:.6}", r as i32, t0.elapsed().as_secs_f64()).unwrap();
            }
        }
        return;
    }
    if mode != "check" && mode != "time" { eprintln!("usage: rust_bench check|time|worst ..."); std::process::exit(2); }
    let dir = &a[2];
    let pats: Vec<Pat> = lines(dir, "patterns.tsv").iter().map(|l| {
        let f: Vec<&str> = l.split('\t').collect();
        Pat { syntax: f[2].into(), options: f[3].parse().unwrap(), encoding: f[4].into(), pat: unhex(f[5]) }
    }).collect();
    let subs: Vec<Vec<u8>> = lines(dir, "subjects.tsv").iter().map(|l| unhex(l.split('\t').nth(1).unwrap())).collect();
    let pairs: Vec<(usize, usize)> = lines(dir, "pairs.tsv").iter().map(|l| {
        let f: Vec<&str> = l.split('\t').collect(); (f[0].parse().unwrap(), f[1].parse().unwrap())
    }).collect();
    let res: Vec<Result<Regex, (u8, String)>> = pats.iter().map(compile).collect();
    let mut include: Vec<bool> = res.iter().map(|r| r.is_ok()).collect();
    if mode == "time" {
        if let Some(only) = a.get(3) {
            include = vec![false; pats.len()];
            for l in std::fs::read_to_string(only).unwrap().lines() {
                if let Ok(p) = l.trim().parse::<usize>() { if p < pats.len() && res[p].is_ok() { include[p] = true; } }
            }
        }
    }
    let locs: Vec<Option<RefCell<CaptureLocations>>> =
        res.iter().map(|r| r.as_ref().ok().map(|re| RefCell::new(re.capture_locations()))).collect();
    let pass = |include: &Vec<bool>| -> (f64, u64, f64) {
        let t0 = Instant::now();
        let (mut m, mut b) = (0u64, 0f64);
        for &(p, s) in &pairs {
            if !include[p] { continue; }
            if let (Ok(re), Some(l)) = (&res[p], &locs[p]) {
                m += enum_pair(re, &mut l.borrow_mut(), &subs[s], None);
                b += subs[s].len() as f64;
            }
        }
        (t0.elapsed().as_secs_f64(), m, b)
    };
    if mode == "check" {
        for (i, r) in res.iter().enumerate() {
            match r {
                Ok(_) => writeln!(w, "P\t{}\tok\t", i).unwrap(),
                Err((c, why)) => writeln!(w, "P\t{}\t{}\t{}", i, ["ok", "err", "unsup", "limit"][*c as usize], why).unwrap(),
            }
        }
        for &(p, s) in &pairs {
            if let (Ok(re), Some(l)) = (&res[p], &locs[p]) {
                let mut o = String::new();
                enum_pair(re, &mut l.borrow_mut(), &subs[s], Some(&mut o));
                writeln!(w, "M\t{}\t{}\t{}", p, s, o).unwrap();
            }
        }
        let (t, _, _) = pass(&include);
        writeln!(w, "PASS\t{:.6}", t).unwrap();
        return;
    }
    // time
    let cmin_n = env_f("E11_COMPILE_N", 1000.0) as usize;
    let cmin_t = env_f("E11_COMPILE_MIN", 0.010);
    let ccap = env_f("E11_COMPILE_CAP", 1.0);
    let rep_min = env_f("E11_REP_MIN", 0.5);
    let nrep = env_f("E11_REPS", 5.0) as usize;
    if std::env::var("E11_NO_COMPILE").is_err() {
        for (i, p) in pats.iter().enumerate() {
            if !include[i] { continue; }
            let start = Instant::now();
            let mut ct: Vec<f64> = Vec::new();
            loop {
                let a0 = Instant::now();
                let r = compile(p);
                ct.push(a0.elapsed().as_secs_f64());
                drop(r);
                let el = start.elapsed().as_secs_f64();
                if (ct.len() >= cmin_n && el >= cmin_t) || el >= ccap { break; }
            }
            ct.sort_by(|x, y| x.partial_cmp(y).unwrap());
            writeln!(w, "C\t{}\t{:.1}\t{}", i, ct[ct.len() / 2] * 1e9, ct.len()).unwrap();
        }
    }
    // Warm-up pass, then repetitions of whole passes lasting at least
    // rep_min seconds each (see driver.h); one pass when it has no byte.
    let (t, matches, bytes) = pass(&include);
    let rep_min = if bytes == 0.0 { 0.0 } else { rep_min };
    writeln!(w, "W\t{:.6}\t{}", t, rep_min).unwrap();
    for rep in 0..nrep {
        let t0 = Instant::now();
        let mut npass = 0usize;
        let el = loop {
            pass(&include);
            npass += 1;
            let el = t0.elapsed().as_secs_f64();
            if el >= rep_min { break el; }
        };
        writeln!(w, "T\t{}\t{:.9}\t{}", rep, el / npass as f64, npass).unwrap();
    }
    writeln!(w, "S\tbytes_per_pass={:.0}\tmatches_per_pass={}\tincluded_patterns={}", bytes, matches, include.iter().filter(|x| **x).count()).unwrap();
}
