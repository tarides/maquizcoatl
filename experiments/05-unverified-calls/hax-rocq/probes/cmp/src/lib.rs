// One comparison and one addition, with a precondition and a
// postcondition (setup.sh's smoke-hax crate).
#[hax_lib::requires(x < 100)]
#[hax_lib::ensures(|r| r == x + 1)]
pub fn add1(x: u32) -> u32 {
    x + 1
}
