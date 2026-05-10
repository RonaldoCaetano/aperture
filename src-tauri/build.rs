use std::process::Command;

fn main() {
    // Capture short git SHA at build time so the launcher footer can show
    // exactly which commit produced this binary. Critical for reinstall
    // verification — semver might not bump, but the SHA always changes.
    let git_sha = Command::new("git")
        .args(["rev-parse", "--short", "HEAD"])
        .output()
        .ok()
        .and_then(|o| {
            if o.status.success() {
                Some(String::from_utf8_lossy(&o.stdout).trim().to_string())
            } else {
                None
            }
        })
        .unwrap_or_else(|| "unknown".to_string());
    println!("cargo:rustc-env=APERTURE_GIT_SHA={}", git_sha);

    // Capture build date (UTC, YYYY-MM-DD) — confirms binary freshness at a
    // glance. No need for chrono; date(1) is universally available on the
    // platforms Tauri builds on.
    let build_date = Command::new("date")
        .args(["-u", "+%Y-%m-%d"])
        .output()
        .ok()
        .and_then(|o| {
            if o.status.success() {
                Some(String::from_utf8_lossy(&o.stdout).trim().to_string())
            } else {
                None
            }
        })
        .unwrap_or_else(|| "unknown".to_string());
    println!("cargo:rustc-env=APERTURE_BUILD_DATE={}", build_date);

    // Re-run this build script when HEAD or its target ref change so the
    // baked-in SHA stays in sync with the working tree.
    println!("cargo:rerun-if-changed=.git/HEAD");
    println!("cargo:rerun-if-changed=.git/refs/heads");

    tauri_build::build()
}
