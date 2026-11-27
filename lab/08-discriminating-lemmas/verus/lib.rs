// Experiment #8 follow-up (issue #34), Verus: crate root (checked with
// verus --crate-type=lib lib.rs).  fold.rs is experiment #8's file
// unchanged; absent.rs is experiment #8's with changes C1-C6 (its header);
// desugar.rs and cases.rs transcribe rocq/Desugar.v and rocq/Cases.v; the
// proof modules transcribe rocq/FoldProof.v, AbsentMono.v, AbsentProof.v.
pub mod fold;
pub mod fold_proof;
pub mod absent;
pub mod desugar;
pub mod absent_mono;
pub mod absent_proof;
pub mod cases;
