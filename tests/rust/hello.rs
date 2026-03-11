use std::process;

extern "C" {
    fn getuid() -> u32;
}

fn main() {
    // Verify non-root execution
    let uid = unsafe { getuid() };
    if uid == 0 {
        eprintln!("Container must not run as root (got uid={})", uid);
        process::exit(1);
    }

    println!("Rust smoke test");
    println!("Running as uid: {}", uid);
    println!("All smoke test assertions passed.");
}
