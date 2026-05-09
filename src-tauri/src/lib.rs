mod agents;
mod beads_parser;
mod codex_harness;
mod config;
mod poller;
mod spawner;
mod state;
mod tmux;
mod warroom;

use std::sync::{Arc, Mutex};

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let app_state = Arc::new(Mutex::new(config::default_state()));

    // Initialize BEADS database
    let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".into());
    let beads_dir = format!("{}/.aperture/.beads", home);
    let current_path = std::env::var("PATH").unwrap_or_default();
    let go_bin = format!("{}/go/bin", home);
    let path_env = format!("/opt/homebrew/bin:/usr/local/bin:{}:{}", go_bin, current_path);
    let bd_bin = format!("{}/go/bin/bd", home);

    // Ensure dolt is initialized in .beads dir
    if !std::path::Path::new(&format!("{}/config.json", beads_dir)).exists() {
        let _ = std::fs::create_dir_all(&beads_dir);
        let _ = std::process::Command::new("dolt")
            .arg("init")
            .current_dir(&beads_dir)
            .env("PATH", &path_env)
            .output();
    }

    // Initialize BEADS if not yet done
    // NOTE: dolt server lifecycle is owned by `bd dolt start` — Tauri no longer
    // spawns its own dolt sql-server on port 3307. This was removed to avoid
    // orphaned processes and conflicts with bd's managed server mode.
    {
        let mut cmd = std::process::Command::new(&bd_bin);
        cmd.args(["init", "--quiet"]);
        cmd.env("BEADS_DIR", &beads_dir);
        cmd.env("PATH", &path_env);
        cmd.current_dir(&app_state.lock().unwrap().project_dir);
        match cmd.output() {
            Ok(output) if output.status.success() => {
                println!("BEADS ready at {}", beads_dir);
            }
            Ok(output) => {
                let stderr = String::from_utf8_lossy(&output.stderr);
                if !stderr.contains("already initialized") {
                    eprintln!("BEADS init warning: {}", stderr);
                }
            }
            Err(e) => {
                eprintln!("BEADS init failed (bd not found?): {}", e);
            }
        }
    }

    // Start background message delivery poller
    let poller_state = Arc::clone(&app_state);
    std::thread::spawn(move || {
        poller::run_message_poller(poller_state);
    });

    tauri::Builder::default()
        .manage(app_state)
        .invoke_handler(tauri::generate_handler![
            // Launcher essentials — start/stop/list agents and configure model.
            agents::start_agent,
            agents::stop_agent,
            agents::list_agents,
            agents::update_agent_model,
            agents::clear_attention,
            // tmux session bootstrap (used at app startup) and window focus
            // (used by AgentCard click → switch to that agent's window).
            tmux::tmux_create_session,
            tmux::tmux_select_window,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
