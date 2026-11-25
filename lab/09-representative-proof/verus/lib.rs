// Experiment #9, Verus: crate root of the definitions (checked with
// verus --crate-type=lib lib.rs).
pub mod syntax;
pub mod sem;
pub mod compile;
pub mod vm;
pub mod statement;
