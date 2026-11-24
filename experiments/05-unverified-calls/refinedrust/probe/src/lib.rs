// probe/src/lib.rs: run E, the one-function RefinedRust check of
// char_len with the EncLen trait specification (probe.sh).
#![feature(register_tool)]
#![register_tool(rr)]
#![feature(custom_inner_attributes)]
#![allow(unused)]

pub struct VuEncState {
    pub min_enc_len: i32,
    pub max_enc_len: i32,
}

pub trait EncLen {
    #[rr::params("s", "p")]
    #[rr::args("s", "p")]
    #[rr::exists("r")]
    #[rr::returns("r")]
    fn enc_len(&self, p: usize) -> i32;
}

#[rr::verify]
#[rr::params("f", "p", "lo", "hi")]
#[rr::args("f", "p", "*[lo; hi]")]
#[rr::requires("1 ≤ lo ≤ hi")]
#[rr::exists("r")]
#[rr::returns("r")]
#[rr::ensures("lo ≤ r ≤ hi")]
pub fn char_len<F: EncLen>(f: &F, p: usize, st: &VuEncState) -> i32 {
    let raw = f.enc_len(p);
    if raw < st.min_enc_len {
        st.min_enc_len
    } else if raw > st.max_enc_len {
        st.max_enc_len
    } else {
        raw
    }
}
