// Experiment #6 milestone 2: driver for the Verus row on S2 (plain Rust
// outside verus!, like the OCaml drivers of the other rows).  Prints one
// verdict per case, then times REPS passes of `passes` (search only: the
// cases are arenas built by the generated case module).
mod tables2;
mod spec2;
mod cases2;
use std::time::Instant;

fn main() {
    let reps: u64 = std::env::args().nth(1).unwrap().parse().unwrap();
    let cs = cases2::cases();
    for c in cs.iter() {
        let v = spec2::run_case(spec2::FUEL0, c.ncap, &c.refs, &c.re, &c.s);
        let w: Vec<String> = v.iter().map(|x| x.to_string()).collect();
        println!("{}", w.join(" "));
    }
    if reps > 0 {
        let t0 = Instant::now();
        let n = spec2::passes(reps, &cs);
        let dt = t0.elapsed().as_secs_f64();
        println!("cases={} reps={} agree={} search_s={:.3} search_cps={:.0}", cs.len(), reps, n, dt,
                 (cs.len() as f64) * (reps as f64) / dt);
    }
}
