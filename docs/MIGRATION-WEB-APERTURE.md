# Aperture Web Migration Plan

> Migrate Aperture from a Tauri desktop app (MacBook) to a web-based platform running on the Mac Mini server. **Keep the Rust backend — swap Tauri's IPC layer for Axum HTTP/WebSocket.**

## Why

- The MacBook (M3, 16 GB) chokes running 4+ agents — swap storms, compression overhead, UI lag
- The Mac Mini (M1, 16 GB) is a dedicated server with no competing desktop workload
- A web UI means zero local resource usage — agents run on the Mini, you control them from any browser
- Bonus: accessible from any device on the Tailnet (iPad, phone, second machine)

## Why Keep Rust

- **~3,000 lines of working, debugged code** — rewriting is waste
- Edge cases already handled: trust-prompt polling, mutex-release-before-IO in `start_agent`, Codex output monitor threading
- The Rust code is straightforward shell scripting (`Command::new("tmux")`, `fs::read_to_string`) — no cognitive overhead
- `#[tauri::command]` → Axum handler is a **mechanical transformation**, not a rewrite
- Single compiled binary — no Node/Bun runtime dependency for the backend
- The `Arc<Mutex<AppState>>` pattern works identically in Axum

## Architecture: Before & After

```
BEFORE (Tauri Desktop)                    AFTER (Axum Web on Mac Mini)
┌──────────────────────────┐              ┌─────────────────────────────────────┐
│ MacBook (16 GB)          │              │ Mac Mini (16 GB, dedicated)         │
│                          │              │                                     │
│  Tauri App               │              │  Rust Binary (Axum)                 │
│  ├─ Vite Frontend        │              │  ├─ HTTP API (REST)                 │
│  ├─ Rust Backend (IPC)   │              │  ├─ WebSocket (terminals + events)  │
│  ├─ xterm.js terminals   │              │  ├─ Static file serving (Vite dist) │
│  └─ tmux control         │              │  └─ tmux control                    │
│                          │              │                                     │
│  tmux "aperture"         │              │  tmux "aperture"                    │
│  ├─ glados (claude)      │              │  ├─ glados (claude)                 │
│  ├─ wheatley (claude)    │              │  ├─ wheatley (claude)               │
│  └─ ...                  │              │  └─ ...                             │
│                          │              │                                     │
│  MCP Server (node)       │              │  MCP Server (node) ← unchanged     │
│  BEADS (dolt)            │              │  BEADS (dolt)       ← unchanged    │
└──────────────────────────┘              └─────────────────────────────────────┘
                                                       │
                                                       │ Tailscale / HTTPS
                                                       │
                                          ┌────────────▼──────────────┐
                                          │ Browser (any device)      │
                                          │  ├─ Vite SPA (same UI)   │
                                          │  ├─ xterm.js terminals   │
                                          │  └─ WebSocket client     │
                                          └───────────────────────────┘
```

## What Changes, What Doesn't

### Unchanged (zero migration effort)

- **All Rust service logic** — `agents.rs`, `tmux.rs`, `poller.rs`, `warroom.rs`, `spawner.rs`, `config.rs`, `state.rs`, `codex_harness.rs`, `beads.rs`, `beads_parser.rs`, `objectives.rs` — **all preserved as-is**
- **MCP Server** (`mcp-server/`) — Node stdio server, agents call it directly. No change.
- **BEADS** — Dolt database + `bd` CLI. Runs wherever `~/.aperture/.beads` lives.
- **Agent prompts** (`prompts/`) — Markdown files. Copy to Mini.
- **Mailbox system** (`~/.aperture/mailbox/`) — File-based. Works anywhere.
- **Skills** (`~/.claude/skills/`) — File-based injection. Copy to Mini.
- **tmux integration** — Same commands, same session management.
- **Frontend SPA** — Already Vite + TypeScript + xterm.js. Works in any browser as-is.

### Must Change

| Component | What Changes | Effort |
|-----------|-------------|--------|
| **Cargo.toml** | Add `axum`, `tokio`, `tower-http` deps; remove `tauri` | Trivial |
| **lib.rs / main.rs** | Replace `tauri::Builder` with `axum::Router` + `tokio::main` | Low |
| **Command annotations** | `#[tauri::command]` → Axum handler extractors | Mechanical |
| **State injection** | `tauri::State<'_, Arc<Mutex<AppState>>>` → `axum::extract::State<AppState>` | Mechanical |
| **WebSocket terminals** | New — stream tmux pane output via `axum::extract::ws` | Medium |
| **Static file serving** | New — serve Vite `dist/` via `tower-http::services::ServeDir` | Trivial |
| **Frontend IPC** | `invoke()` → `fetch()` / `WebSocket` (44-line file) | Low |
| **Frontend Terminal.ts** | Tauri PTY → WebSocket | Low |

## Rust Migration Details

### Step 1: Update Cargo.toml

```diff
[dependencies]
- tauri = { version = "2", features = [] }
+ axum = { version = "0.8", features = ["ws"] }
+ tokio = { version = "1", features = ["full"] }
+ tower-http = { version = "0.6", features = ["fs", "cors"] }
  serde = { version = "1", features = ["derive"] }
  serde_json = "1"
  portable-pty = "0.8"
  regex = "1"

- [build-dependencies]
- tauri-build = { version = "2", features = [] }

- [lib]
- name = "aperture_lib"
- crate-type = ["lib", "cdylib", "staticlib"]
+ [[bin]]
+ name = "aperture"
+ path = "src/main.rs"
```

### Step 2: Replace lib.rs with main.rs

The bootstrap logic stays almost identical — swap Tauri's builder for Axum's router:

```rust
// src/main.rs
mod agents;
mod beads;
mod beads_parser;
mod codex_harness;
mod config;
mod objectives;
mod poller;
mod spawner;
mod state;
mod tmux;
mod warroom;
mod routes;  // NEW: HTTP route handlers
mod ws;      // NEW: WebSocket handlers

use std::sync::{Arc, Mutex};
use axum::Router;
use tower_http::services::ServeDir;
use tower_http::cors::CorsLayer;

#[tokio::main]
async fn main() {
    let app_state = Arc::new(Mutex::new(config::default_state()));

    // Initialize BEADS — same code as current lib.rs
    init_beads(&app_state);

    // Start background message delivery poller — same as current
    let poller_state = Arc::clone(&app_state);
    tokio::spawn(async move {
        poller::run_message_poller(poller_state);
    });

    let app = Router::new()
        // API routes
        .nest("/api", routes::api_router())
        // WebSocket routes
        .nest("/ws", ws::ws_router())
        // Serve frontend static files
        .fallback_service(ServeDir::new("../dist"))
        .layer(CorsLayer::permissive())
        .with_state(app_state);

    let addr = "0.0.0.0:4000";
    println!("Aperture running at http://{}", addr);
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
```

### Step 3: Convert Command Handlers (Mechanical)

Every `#[tauri::command]` becomes an Axum handler. The transformation is formulaic:

**Before (Tauri):**
```rust
#[tauri::command]
pub fn list_agents(state: tauri::State<'_, Arc<Mutex<AppState>>>) -> Result<Vec<AgentDef>, String> {
    let mut app_state = state.lock().map_err(|e| e.to_string())?;
    // ... existing logic unchanged ...
    Ok(app_state.agents.values().cloned().collect())
}
```

**After (Axum):**
```rust
use axum::{extract::State, Json};

pub async fn list_agents(
    State(state): State<Arc<Mutex<AppState>>>
) -> Result<Json<Vec<AgentDef>>, String> {
    let mut app_state = state.lock().map_err(|e| e.to_string())?;
    // ... existing logic UNCHANGED ...
    Ok(Json(app_state.agents.values().cloned().collect()))
}
```

**The pattern for every handler:**
1. `tauri::State<'_, Arc<Mutex<AppState>>>` → `State<Arc<Mutex<AppState>>>`
2. Input params → `Json<T>` or `Path<String>` extractors
3. `Result<T, String>` → `Result<Json<T>, StatusCode>` (or keep String errors with a custom error type)
4. **Function body stays identical**

### Step 4: Create Route File

```rust
// src/routes.rs
use axum::{Router, routing::{get, post, patch, delete}};

pub fn api_router() -> Router<Arc<Mutex<AppState>>> {
    Router::new()
        // Agents
        .route("/agents", get(agents::list_agents))
        .route("/agents/:name/start", post(agents::start_agent))
        .route("/agents/:name/stop", post(agents::stop_agent))
        .route("/agents/:name/model", patch(agents::update_agent_model))
        // Chat
        .route("/chat", get(agents::get_chat_messages)
                       .post(agents::send_chat)
                       .delete(agents::clear_chat_history))
        // Messages
        .route("/messages", get(agents::get_recent_messages)
                           .delete(agents::clear_message_history))
        // BEADS
        .route("/beads/tasks", get(beads::list_beads_tasks))
        .route("/beads/tasks/:id/status", patch(beads::update_beads_task_status))
        // War Room
        .route("/warroom", get(warroom::get_warroom_state)
                          .post(warroom::create_warroom))
        .route("/warroom/transcript", get(warroom::get_warroom_transcript))
        .route("/warroom/interject", post(warroom::warroom_interject))
        .route("/warroom/skip", post(warroom::warroom_skip))
        .route("/warroom/conclude", post(warroom::warroom_conclude))
        .route("/warroom/cancel", post(warroom::warroom_cancel))
        .route("/warroom/invite", post(warroom::warroom_invite_participant))
        .route("/warroom/history", get(warroom::list_warroom_history))
        .route("/warroom/history/:id", get(warroom::get_warroom_history_transcript))
        // Spiderlings
        .route("/spiderlings", get(spawner::list_spiderlings))
        .route("/spiderlings/:name", delete(spawner::kill_spiderling_cmd))
        // Objectives
        .route("/objectives", get(objectives::list_objectives)
                             .post(objectives::create_objective))
        .route("/objectives/:id", patch(objectives::update_objective)
                                 .delete(objectives::delete_objective))
}
```

### Step 5: Terminal WebSocket

The only genuinely new code. Stream tmux pane output to the browser:

```rust
// src/ws.rs
use axum::{
    extract::{ws::{WebSocket, WebSocketUpgrade}, Path, State},
    response::Response,
    Router, routing::get,
};

pub fn ws_router() -> Router<Arc<Mutex<AppState>>> {
    Router::new()
        .route("/terminal/:agent", get(terminal_ws))
        .route("/events", get(events_ws))
}

async fn terminal_ws(
    ws: WebSocketUpgrade,
    Path(agent): Path<String>,
    State(state): State<Arc<Mutex<AppState>>>,
) -> Response {
    ws.on_upgrade(move |socket| handle_terminal(socket, agent, state))
}

async fn handle_terminal(mut socket: WebSocket, agent: String, state: Arc<Mutex<AppState>>) {
    let window_id = {
        let s = state.lock().unwrap();
        s.agents.get(&agent).and_then(|a| a.tmux_window_id.clone())
    };

    let Some(window_id) = window_id else { return };

    // Read loop: capture tmux pane output, send to browser
    let wid = window_id.clone();
    let (mut sender, mut receiver) = socket.split();

    // Spawn reader: poll tmux pane content every 100ms
    let read_handle = tokio::spawn(async move {
        let mut last_content = String::new();
        loop {
            tokio::time::sleep(std::time::Duration::from_millis(100)).await;
            if let Ok(content) = tmux::tmux_capture_pane(&wid) {
                if content != last_content {
                    let diff = &content; // Could diff for efficiency
                    if sender.send(axum::extract::ws::Message::Text(diff.into())).await.is_err() {
                        break;
                    }
                    last_content = content;
                }
            }
        }
    });

    // Write loop: receive from browser, send to tmux
    while let Some(Ok(msg)) = receiver.next().await {
        if let axum::extract::ws::Message::Text(text) = msg {
            let _ = tmux::tmux_send_keys(window_id.clone(), text.to_string());
        }
    }

    read_handle.abort();
}
```

> **Note:** The terminal streaming approach above uses `tmux capture-pane` polling. A more efficient approach is `tmux pipe-pane` which streams output to a file/pipe — but capture-pane polling is simpler to implement first and can be optimized later.

### Step 6: Frontend Changes

**Replace `tauri-commands.ts` (44 lines):**

```typescript
// src/services/commands.ts
const API = "";  // same origin

async function json<T>(url: string, opts?: RequestInit): Promise<T> {
  const res = await fetch(`${API}${url}`, opts);
  if (!res.ok) throw new Error(await res.text());
  return res.json();
}

export const commands = {
  // Agents
  listAgents: () => json<AgentDef[]>("/api/agents"),
  startAgent: (name: string) => json<void>(`/api/agents/${name}/start`, { method: "POST" }),
  stopAgent: (name: string) => json<void>(`/api/agents/${name}/stop`, { method: "POST" }),
  updateAgentModel: (name: string, model: string) =>
    json<void>(`/api/agents/${name}/model`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ model }),
    }),

  // Chat
  getChatMessages: () => json<ChatMessage[]>("/api/chat"),
  sendChat: (toAgent: string, message: string) =>
    json<void>("/api/chat", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ toAgent, message }),
    }),
  clearChatHistory: () => fetch("/api/chat", { method: "DELETE" }),

  // Messages
  getRecentMessages: () => json<AgentMessage[]>("/api/messages"),
  clearMessageHistory: () => fetch("/api/messages", { method: "DELETE" }),

  // BEADS
  listBeadsTasks: () => json<any>("/api/beads/tasks"),
  updateBeadsTaskStatus: (taskId: string, status: string) =>
    json<void>(`/api/beads/tasks/${taskId}/status`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ status }),
    }),

  // War Room
  getWarroomState: () => json<WarRoomState | null>("/api/warroom"),
  createWarroom: (topic: string, participants: string[]) =>
    json<void>("/api/warroom", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ topic, participants }),
    }),
  getWarroomTranscript: () => json<TranscriptEntry[]>("/api/warroom/transcript"),
  warroomInterject: (message: string) =>
    json<void>("/api/warroom/interject", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ message }),
    }),
  warroomSkip: () => fetch("/api/warroom/skip", { method: "POST" }),
  warroomConclude: () => fetch("/api/warroom/conclude", { method: "POST" }),
  warroomCancel: () => fetch("/api/warroom/cancel", { method: "POST" }),
  warroomInviteParticipant: (name: string) =>
    json<void>("/api/warroom/invite", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name }),
    }),
  listWarroomHistory: () => json<WarRoomState[]>("/api/warroom/history"),
  getWarroomHistoryTranscript: (id: string) => json<TranscriptEntry[]>(`/api/warroom/history/${id}`),

  // Spiderlings
  listSpiderlings: () => json<SpiderlingDef[]>("/api/spiderlings"),
  killSpiderling: (name: string) => fetch(`/api/spiderlings/${name}`, { method: "DELETE" }),

  // Objectives
  listObjectives: () => json<Objective[]>("/api/objectives"),
  createObjective: (title: string, description: string, priority: number) =>
    json<Objective>("/api/objectives", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title, description, priority }),
    }),
  updateObjective: (id: string, fields: Partial<Objective>) =>
    json<Objective>(`/api/objectives/${id}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(fields),
    }),
  deleteObjective: (id: string) => fetch(`/api/objectives/${id}`, { method: "DELETE" }),
};
```

**Terminal.ts** — replace Tauri PTY with WebSocket:
```typescript
// Connect to agent terminal
const ws = new WebSocket(`ws://${location.host}/ws/terminal/${agentName}`);
ws.onmessage = (e) => terminal.write(e.data);
terminal.onData((data) => ws.send(data));
terminal.onResize(({ cols, rows }) => {
  ws.send(JSON.stringify({ type: "resize", cols, rows }));
});
```

**Remove Tauri deps from package.json:**
```diff
  "devDependencies": {
-   "@tauri-apps/cli": "^2.10.1",
    "typescript": "^5.9.3",
    "vite": "^8.0.0"
  },
  "dependencies": {
-   "@tauri-apps/api": "^2.10.1",
    "@xterm/addon-fit": "^0.11.0",
    "@xterm/addon-webgl": "^0.19.0",
    "@xterm/xterm": "^6.0.0"
  }
```

## Migration Phases (Revised)

### Phase 1: Swap Tauri for Axum (Day 1)

- Update `Cargo.toml` — add axum/tokio/tower-http, remove tauri
- Create `main.rs` — bootstrap Axum server with same init logic
- Create `routes.rs` — map all existing handlers to HTTP routes
- Mechanically convert `#[tauri::command]` annotations to Axum extractors
- **All function bodies stay identical**

### Phase 2: Terminal WebSocket (Day 1-2)

- Implement `ws.rs` — WebSocket handler for terminal streaming
- Use `tmux capture-pane` polling initially (simple, works)
- Optimize to `tmux pipe-pane` later if polling is too chatty

### Phase 3: Frontend Adaptation (Day 2)

- Replace `tauri-commands.ts` with `commands.ts` (HTTP/WS client)
- Update `Terminal.ts` to use WebSocket
- Remove `@tauri-apps/*` dependencies
- Update `vite.config.ts` — remove Tauri plugin, add dev proxy to `localhost:4000`

### Phase 4: Deploy on Mac Mini (Day 2)

```bash
# On Mac Mini
cd ~/projects/aperture

# Build the Rust backend
cd src-tauri  # or rename to just `server/`
cargo build --release
# → target/release/aperture

# Build the frontend
cd ..
pnpm install && pnpm build
# → dist/

# Run it
./src-tauri/target/release/aperture
# Aperture running at http://0.0.0.0:4000

# Keep alive with launchd or pm2
# Expose via Tailscale
tailscale serve --bg 443 http://localhost:4000
# → https://mini.your-tailnet.ts.net/
```

## File Change Summary

| File | Action | Lines Changed |
|------|--------|---------------|
| `src-tauri/Cargo.toml` | Edit deps | ~10 |
| `src-tauri/src/main.rs` | New (replaces lib.rs) | ~60 |
| `src-tauri/src/routes.rs` | New | ~50 |
| `src-tauri/src/ws.rs` | New | ~80 |
| `src-tauri/src/agents.rs` | Remove `#[tauri::command]`, change extractors | ~20 lines changed |
| `src-tauri/src/tmux.rs` | Remove `#[tauri::command]`, change extractors | ~10 lines changed |
| `src-tauri/src/warroom.rs` | Remove `#[tauri::command]`, change extractors | ~15 lines changed |
| `src-tauri/src/spawner.rs` | Remove `#[tauri::command]`, change extractors | ~5 lines changed |
| `src-tauri/src/beads.rs` | Remove `#[tauri::command]`, change extractors | ~5 lines changed |
| `src-tauri/src/objectives.rs` | Remove `#[tauri::command]`, change extractors | ~10 lines changed |
| `src/services/tauri-commands.ts` | Rewrite → `commands.ts` | ~80 |
| `src/components/Terminal.ts` | WebSocket swap | ~20 |
| `src/main.ts` | Remove Tauri init | ~5 |
| `package.json` | Remove Tauri deps | ~3 |
| `vite.config.ts` | Remove Tauri, add proxy | ~5 |
| **Total new code** | | **~190 lines** |
| **Total lines modified** | | **~65 lines** |

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Terminal latency over network | Medium | Tailscale is <5ms local. WebSocket is fine for terminal I/O |
| Mac Mini also has 16 GB | Low | No competing desktop apps — 16 GB goes entirely to agents |
| Auth/security | Low | Tailscale identity = built-in auth. No public exposure |
| tmux session persistence | None | Identical tmux setup. SSH still works as escape hatch |
| BEADS/Dolt compat | None | Same CLI, same filesystem paths |
| Axum learning curve | Low | Pattern is simple — extractors + handlers. Well-documented |

## Estimated Effort

| Phase | Time |
|-------|------|
| 1. Swap Tauri → Axum | 4-6 hours |
| 2. Terminal WebSocket | 3-4 hours |
| 3. Frontend adaptation | 2-3 hours |
| 4. Deploy on Mini | 1-2 hours |
| **Total** | **~2 days** |

This is mostly mechanical refactoring — not a rewrite. The service logic, the edge case handling, the threading model — all preserved.

## Open Questions

1. **Keep Tauri build too?** — Maintain dual-mode (desktop + web) or fully abandon Tauri?
   - Recommendation: Abandon Tauri. The web version is strictly better for this use case.

2. **Mac Mini RAM** — Also 16 GB. Should we consider upgrading?
   - At ~300 MB per agent, 16 GB supports ~6-7 agents comfortably. Fine for now; upgrade if you want the full 13-agent roster.

3. **Directory rename?** — Keep `src-tauri/` or rename to `server/`?
   - Recommendation: Rename to `server/` since it's no longer Tauri-specific.

4. **Terminal polling vs pipe-pane** — Start with `capture-pane` polling (simpler) or `pipe-pane` (more efficient)?
   - Recommendation: Start with polling at 100ms. Optimize later only if it's a problem.
