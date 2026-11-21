// build.rs: soname, and the C shim for the variadic
// onig_error_code_to_str (stable Rust cannot define a C-variadic
// function, rust-lang/rust#44930). The shim is outside any proof.
use std::{env, path::PathBuf, process::Command};

fn main() {
    let out = PathBuf::from(env::var("OUT_DIR").unwrap());
    let inc = env::var("ONIG_INCLUDE").expect("ONIG_INCLUDE: upstream public headers");
    let shim = env::var("ONIG_SHIM_C").expect("ONIG_SHIM_C: the C shim source");
    println!("cargo:rerun-if-env-changed=ONIG_STUB_GEN");
    println!("cargo:rerun-if-changed={shim}");
    let obj = out.join("shim.o");
    let tramp = env::var("ONIG_TRAMPOLINE").is_ok();
    println!("cargo:rerun-if-env-changed=ONIG_TRAMPOLINE");
    println!("cargo:rerun-if-env-changed=ONIG_EXPORT_SHIM");
    println!("cargo::rustc-check-cfg=cfg(trampoline)");
    let mut cc = Command::new(env::var("CC").unwrap_or("cc".into()));
    if tramp {
        // the C body gets a private name; the exported name is a Rust
        // naked function that tail-jumps to it (src/lib.rs)
        cc.arg("-Donig_error_code_to_str=onig_stub_error_code_to_str_c");
        println!("cargo:rustc-cfg=trampoline");
    }
    let ok = cc
        .args(["-c", "-fPIC", "-O2", "-I", &inc, &shim, "-o"])
        .arg(&obj)
        .status()
        .unwrap()
        .success();
    assert!(ok, "shim compile failed");
    let ok = Command::new("ar").arg("crs").arg(out.join("libshim.a")).arg(&obj).status().unwrap().success();
    assert!(ok, "ar failed");
    println!("cargo:rustc-link-search=native={}", out.display());
    // whole-archive so the object is kept although no Rust code calls it
    println!("cargo:rustc-link-lib=static:+whole-archive=shim");
    println!("cargo:rustc-cdylib-link-arg=-Wl,-soname,libonig.so.5");
    if env::var("ONIG_EXPORT_SHIM").is_ok() {
        // rustc's version script hides non-Rust symbols of a cdylib;
        // re-export the shim's symbol explicitly
        println!("cargo:rustc-cdylib-link-arg=-Wl,--export-dynamic-symbol=onig_error_code_to_str");
    }
}
