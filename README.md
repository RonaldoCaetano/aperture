# Aperture

> Multi-agent AI orchestration platform. A Tauri desktop app that runs, coordinates, and monitors a team of Claude CLI agents inside tmux windows.

---

## What It Is

Aperture is a control room for AI agents. It launches Claude Code sessions as named agents (GLaDOS, Wheatley, Peppy, Izzy, and others), routes messages between them through a file-based mailbox system, tracks work through BEADS task tracking, and lets the human operator observe and direct everything through a native desktop UI.

The agents are real Claude CLI processes. The operator sees their terminals live, can chat with any agent directly, invite them to structured War Room discussions, and assign work through BEADS.

---

## Architecture

```
┌──────────────────────────────────────────────────────┐
│                  Tauri Desktop App                    │
│  Terminals  │  Agent Cards  │  War Room  │  BEADS    │
│─────────────────────────────────────────────────────│
│                  Tauri Command Bridge                 │
│─────────────────────────────────────────────────────│
│  PTY/tmux  │  Agent Mgmt  │  War Room  │  BEADS     │
│─────────────────────────────────────────────────────│
│         Background Message Poller (3s loop)          │
│   Scans ~/.aperture/mailbox/* → feeds tmux windows   │
└──────────────────────────────────────────────────────┘

                    tmux Session
         GLaDOS │ Wheatley │ Peppy │ Izzy │ ...
                      │
              MCP Server (stdio)
              aperture-bus — one instance per agent
```

**Three layers:**

1. **Frontend** — Vite + TypeScript UI. Terminals rendered via xterm.js with WebGL. Components for agent cards, War Room, BEADS panel, spiderlings, objectives.

2. **Tauri backend (Rust)** — PTY management, tmux session control, agent lifecycle, War Room state machine, BEADS/Dolt integration, background message poller.

3. **MCP server (Node.js)** — `aperture-bus` runs as a stdio MCP server. One instance per agent. Exposes tools for messaging, task management, artifact storage, spiderling spawning.

---

## Communication

**All inter-agent communication is file-based.**

```
Agent A calls send_message(to: "B", message: "...")
  → MCP writes .md file to ~/.aperture/mailbox/B/
  → Poller (3s) detects file → cat into B's tmux window via send-keys
  → Agent B reads it in conversation → responds
```

No sockets. No queues. The mailbox is a directory you can `ls`. Fully debuggable, resilient to crashes.

---

## Agent Team

| Agent | Model | Role |
|-------|-------|------|
| **GLaDOS** | Opus | Orchestration — delegates tasks, spawns spiderlings, enforces quality gate |
| **The Planner** | Opus | Project direction — War Room analysis, BEADS task creation, operator sign-off |
| **Wheatley** | Sonnet | Implementation — code, bug fixes, feature work |
| **Peppy** | Opus | Infrastructure — Docker, deployments, CI/CD, services |
| **Izzy** | Opus | QA — tests, code review, quality gate sign-off |
| **Atlas** | Sonnet | Documentation |
| **Cipher** | Sonnet | Security review |
| **Sentinel** | Sonnet | Task health monitoring |
| + others | — | See `AGENTS.md` for full roster |

---

## Supported Agent Types

Aperture supports both **Claude Code agents** and **Codex agents**.

- **Claude Code agents** call MCP tools directly through `aperture-bus`.
- **Codex agents** do not call MCP tools directly. They emit `@@BEADS@@` command blocks instead.
- The **Tauri harness** intercepts those `@@BEADS@@` blocks and executes the corresponding BEADS operations on the agent's behalf.
- The `codex-comms` skill defines the Codex-side communication protocol.
- Model names starting with `codex/` are treated as Codex agents by the harness.

---

## Key Concepts

### War Rooms
Structured multi-agent discussions. The operator creates a War Room, invites participants, and each agent takes a turn contributing. The operator can interject. When concluded, the transcript is handed to The Planner for task creation.

### BEADS
Task tracking backed by [Dolt](https://github.com/dolthub/dolt) (a version-controlled MySQL-compatible database). The `bd` CLI manages issues with priority, dependencies, and status. Agents use BEADS MCP tools to create, claim, update, and close tasks.

### Spiderlings
Ephemeral sub-agents spawned by GLaDOS for isolated subtasks. They run in git worktrees, complete a scoped task, store an artifact, and terminate. Spiderling state is visible in the Spiderlings panel.

### Objectives
High-level project goals tracked in a Kanban view. Linked to BEADS task clusters.

---

## Project Structure

```
aperture/
├── src/                    # Frontend (TypeScript + Vite)
│   ├── components/         # UI components (Terminal, AgentCard, WarRoom, BeadsPanel, ...)
│   ├── services/           # Tauri command wrappers
│   ├── main.ts
│   └── types.ts
├── src-tauri/              # Tauri backend (Rust)
│   └── src/
│       ├── agents.rs       # Agent lifecycle (start, stop, list, chat)
│       ├── beads.rs        # BEADS/Dolt integration
│       ├── config.rs       # App config and default state
│       ├── objectives.rs   # Project objectives
│       ├── poller.rs       # Background message delivery poller
│       ├── pty.rs          # PTY management
│       ├── spawner.rs      # Spiderling management
│       ├── state.rs        # Shared app state
│       ├── tmux.rs         # tmux session control
│       ├── warroom.rs      # War Room state machine
│       └── lib.rs          # Entry point, service init
├── mcp-server/             # aperture-bus MCP server (Node.js)
├── docs/                   # Architecture docs and implementation guides
├── prompts/                # Agent system prompts
├── justfile                # Dev commands
├── AGENTS.md               # Agent lane definitions and workflow rules
├── WARROOM-SPEC.md         # War Room protocol specification
└── CLAUDE.md               # Instructions for AI agents working on this repo
```

---

## Getting Started

### Prerequisites

| Dependency | Install | Verify |
|------------|---------|--------|
| [Rust](https://rustup.rs/) + Cargo | `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \| sh` | `rustc --version` |
| [Node.js](https://nodejs.org/) + pnpm | `brew install node && npm i -g pnpm` (or use [Volta](https://volta.sh/)) | `node -v && pnpm -v` |
| [Tauri CLI v2](https://tauri.app/start/prerequisites/) | `cargo install tauri-cli@^2` | `cargo tauri --version` |
| [tmux](https://github.com/tmux/tmux) | `brew install tmux` | `tmux -V` |
| [Claude CLI](https://claude.ai/download) | Download from site, then `claude auth` | `claude --version` |
| [Dolt](https://docs.dolthub.com/introduction/installation) | `brew install dolt` | `dolt version` |
| [bd (Beads CLI)](https://github.com/steveyegge/beads) | `brew install beads` | `bd --version` |
| [Docker](https://www.docker.com/) | Docker Desktop or `brew install --cask docker` | `docker info` |

### Install & Run

```bash
# 1. Install frontend deps
pnpm install

# 2. Install and build MCP server
cd mcp-server && pnpm install && pnpm build && cd ..

# 3. Fix MCP server path in settings (IMPORTANT — see Troubleshooting)
#    Edit .claude/settings.json and set the aperture-bus command path
#    to match YOUR machine's absolute path to mcp-server/start.sh

# 4. Configure Dolt identity (first time only)
dolt config --global --add user.email "you@example.com"
dolt config --global --add user.name "Your Name"

# 5. Initialize BEADS (first time only)
mkdir -p ~/.aperture/.beads
cd ~/.aperture && BEADS_DIR=~/.aperture/.beads BD_ACTOR=operator bd init
cd -

# 6. Verify BEADS
BEADS_DIR=~/.aperture/.beads BD_ACTOR=operator bd list --json
# Should return: []

# 7. Run in dev mode
pnpm tauri dev

# 8. Build for production
pnpm tauri build
```

### First Launch

1. Aperture auto-starts the Dolt SQL server and initializes BEADS (`~/.aperture/.beads/`).
2. Create a tmux session from the UI or let Aperture create one automatically.
3. Start agents from the Agent Cards panel — each agent launches as a named Claude CLI session with its MCP server.
4. The operator Chat panel connects you directly to any agent.

### Skills

Agent skills live in `.claude/skills/` within the project directory. Claude Code loads them automatically — **no symlinks needed**. The skills are:

| Skill | Purpose |
|-------|---------|
| `communicate` | Inter-agent messaging patterns via BEADS |
| `task-workflow` | BEADS task lifecycle (claim, update, close) |
| `team` | Full agent roster and routing table |
| `war-room` | War Room discussion participation protocol |
| `spiderling` | Spiderling delegation patterns |
| `deploy-workflow` | End-to-end deployment pipeline |
| `dokploy-api` | Dokploy API reference for infra operations |
| `codex-comms` | Communication protocol for Codex agents |

---

## Development

```bash
just status          # System health check (skills, Docker, agents)
just check-skills    # Verify skills are loadable
just doctor          # Run BEADS diagnostics
```

### Adding a New Agent

1. Add the agent system prompt to `prompts/<agent-name>.md`
2. Update `AGENTS.md` with the agent's lane and responsibilities
3. Register the agent name in `src-tauri/src/config.rs` (permanent agents list)

### Adding a New Skill

Skills are directories inside `.claude/skills/` containing a `SKILL.md` file. Claude Code discovers them automatically from the project directory.

### Adding a New MCP Tool

Tools live in `mcp-server/src/`. Add the tool schema and handler, rebuild with `pnpm build` inside `mcp-server/`, and restart any running agents.

---

## Troubleshooting

### MCP Server Not Connecting (BEADS tools unavailable)

**Symptom:** Agent skills load but BEADS/messaging tools (create_task, send_message, etc.) are missing.

**Cause:** The MCP server path in `.claude/settings.json` is absolute and may point to the wrong machine or directory.

**Fix:**
```bash
# Check the current path
cat .claude/settings.json | grep command

# Update it to YOUR machine's path
# The command should point to: <your-repo-path>/mcp-server/start.sh
```

Also ensure the MCP server is built:
```bash
cd mcp-server && pnpm install && pnpm build && cd ..
ls mcp-server/dist/index.js  # Should exist
```

### BEADS Database Not Found

**Symptom:** `bd list` returns "database not found" error.

**Fix:**
```bash
# Check server status
BEADS_DIR=~/.aperture/.beads bd dolt status

# If no server running, or database missing:
cd ~/.aperture && BEADS_DIR=~/.aperture/.beads BD_ACTOR=operator bd bootstrap

# If that doesn't work, reinitialize:
rm -rf ~/.aperture/.beads/dolt ~/.aperture/.beads/embeddeddolt
rm -f ~/.aperture/.beads/dolt-server.*
cd ~/.aperture && BEADS_DIR=~/.aperture/.beads BD_ACTOR=operator bd init
```

### Dolt Identity Not Set

**Symptom:** `dolt init` fails with "empty ident name not allowed".

**Fix:**
```bash
dolt config --global --add user.email "you@example.com"
dolt config --global --add user.name "Your Name"
```

### Skills Not Loading

**Symptom:** Claude Code doesn't see Aperture skills (communicate, team, etc.).

**Check:** Skills are loaded from `.claude/skills/` in the project directory. Ensure you're running Claude Code from the Aperture repo root, and that `.claude/skills/*/SKILL.md` files exist.

```bash
ls .claude/skills/*/SKILL.md
# Should list 8 skill files
```

> **Note:** The `skills/aperture/` directory and `justfile setup-skills` are legacy. Skills now live directly in `.claude/skills/` and don't need symlinks.

### Pre-Flight Checklist

Run this before launching Aperture to verify everything is ready:

```bash
just status                    # Skills, Docker, agents
bd --version                   # bd CLI installed
dolt version                   # Dolt installed
ls mcp-server/dist/index.js    # MCP server built
cat .claude/settings.json      # MCP path correct for this machine
BEADS_DIR=~/.aperture/.beads BD_ACTOR=operator bd list --json  # BEADS responding
```

---

## Docs

- `docs/implementations/` — 10 detailed implementation guides (architecture, terminals, BEADS, poller, chat, War Room, agents, spiderlings, MCP server, skills)
- `WARROOM-SPEC.md` — War Room protocol and state machine
- `AGENTS.md` — Agent lanes, proactivity rules, handoff protocols
- `CLAUDE.md` — Instructions for AI agents working on this repo

---

## License

Private. All rights reserved.
