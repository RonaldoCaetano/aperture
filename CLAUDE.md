# Project Instructions for AI Agents

This file provides instructions and context for AI coding agents working on this project.

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:ca08a54f -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files
- **Every `bd create` MUST include a `--label project:<name>` flag.** Canonical taxonomy: `project:aperture`, `project:incluir`, `project:beads-galaxy`, `project:mempalace`, `project:frame`. See the `aperture:beads` skill for the full discipline.
- **A task is closed when its PR is OPENED, not when merged.** Reviewer feedback creates a follow-up task. Don't hold tasks open through merge.

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd dolt push
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->


## Build & Test

```bash
just setup           # build the ~/.claude/aperture/ runtime tree from canonical sources
just build-mcp       # compile the MCP server (mcp-server/dist/index.js)
pnpm tauri build     # release build the Tauri app
just check-setup     # verify runtime tree is sane
just status          # full preflight (skills + MCP + BEADS + Docker + agents)
```

## Architecture Overview

Aperture is a Tauri desktop app + tmux + per-agent Claude/Codex CLI sessions, glued by an MCP server (`aperture-bus`).

- **Frontend** — `src/` Vite + vanilla TS launcher (agent cards, model picker, version footer).
- **Tauri backend** — `src-tauri/src/` Rust. Key files: `agent_loader.rs` (loads agents from `~/.claude/aperture/`), `agents.rs` (start/stop/inject_skills), `poller.rs` (BEADS message delivery), `tmux.rs`, `lib.rs` (entry + Tauri commands).
- **MCP server** — `mcp-server/src/` Node TS. Per-agent stdio MCP exposing send_message, BEADS task tools, identity. Filtering and projection on `query_tasks` / `search_tasks`.
- **Agent registry** — `agents/<name>/{manifest.json, skills.txt}` is the canonical source. `prompts/<name>.md` holds the system prompt. `.claude/skills/<skill>/SKILL.md` holds shared skill bodies.
- **Runtime tree** — `~/.claude/aperture/` is symlinked from the repo by `just setup`. Aperture only reads from this tree at boot; the repo is source of truth.

## Conventions & Patterns

- **Agent lanes** — see `AGENTS.md`. Cross-agent delegation flows through GLaDOS via BEADS.
- **BEADS first** — every task tracked, every message persisted via `send_message` (which writes a BEADS row). Operator alerts via `send_message(to: "operator")` light an attention badge but do NOT deliver text — agents reply in the terminal.
- **Project labels mandatory** — every BEADS task carries one `project:<name>` label. No exceptions.
- **Folder-driven agents** — adding/disabling/renaming an agent = editing `agents/<name>/` and re-running `just setup`. No Rust recompile.
