// A one-field struct read and written: no specification, no trait.
pub struct S {
    pub a: i32,
}

pub fn get(s: &S) -> i32 {
    s.a
}

pub fn set(s: &mut S, v: i32) {
    s.a = v;
}
