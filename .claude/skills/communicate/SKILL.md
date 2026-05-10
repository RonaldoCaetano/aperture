---
name: aperture-communicate
description: Inter-agent communication patterns for Aperture. Use when sending messages to other agents, reporting task status to GLaDOS, requesting infra work from Peppy, or writing status reports. Triggers on agent messaging, status reports, task handoffs, and infra requests.
---

# Aperture Communication Patterns

This skill defines how Aperture agents communicate. Follow it whenever you report progress, hand off work, or coordinate with other agents.

---

## 1. The Golden Rule

**BEADS is the ONLY communication channel between agents.**

Every message between agents — task updates, quick pings, handoffs, questions, FYIs — goes through BEADS. There is no exception. `send_message` to another agent does NOT exist as a separate file-based pattern anymore.

**How it works:**
- You call `send_message(to: "agent", message: "...")` — this writes a BEADS message record
- The poller delivers unread messages to the recipient every 5 seconds
- Messages persist until the recipient marks them as read
- No more lost messages. No more one-shot file delivery.

**Why:** File-based messages got lost when agents were busy processing. BEADS messages are persistent, have read/unread state, and retry delivery automatically.

---

## 2. When to Use What

| Channel | Use for | Example |
|---------|---------|---------|
| **BEADS `update_task`** | All task progress, completions, blockers, findings | "Found the bug — query filter was wrong. Fixed in usuarios/page.tsx" |
| **BEADS `store_artifact`** | Deliverables, files created, URLs deployed | `type: "file", value: "src/auth.ts"` |
| **BEADS `send_message`** | ALL agent-to-agent messages — pings, questions, FYIs, coordination | "Heads up, I changed the DB schema" |
| **`send_message(to: "operator")`** | **Doorbell only** — fires a notification badge on your row in the launcher. The operator then attaches to your tmux to read your scrollback. NOT a chat surface. | "Need your GitHub credentials for this repo" |

**The only recipient that bypasses BEADS:** `operator` — and that's a notification badge, not a message inbox (see §7).

---

## 3. Task Communication Flow

### Starting work
```
update_task(id: "task-id", claim: true)
update_task(id: "task-id", status: "in_progress")
```

### Progress updates (when something notable happens)
```
update_task(
  id: "task-id",
  notes: "Found that the nav link already exists — only the filter needs changing"
)
```

### Completion
```
store_artifact(task_id: "task-id", type: "file", value: "src/components/Auth.tsx")
update_task(id: "task-id", status: "done", notes: "Implemented auth flow. Build passes. Tests green.")
```

### Blockers
```
update_task(
  id: "task-id",
  notes: "BLOCKED: Need DATABASE_URL for production. Waiting on operator."
)
```

### Handoffs (e.g., builder → deployer)
```
update_task(
  id: "task-id",
  notes: "HANDOFF TO PEPPY: Ready for deploy. Repo: /projects/fitt, Branch: main, Port: 3000, Subdomain: fitt.programaincluir.org"
)
```

---

## 4. Status Report Format

When completing a task, your BEADS notes should be structured enough for GLaDOS (or any agent) to understand what happened without asking follow-up questions:

```
What I did: [1-3 bullet points of actual changes]
Files touched: [list key files]
Next step: [what happens now — review needed? deploy? nothing?]
```

❌ Bad: `"done"`
✅ Good: `"Updated SECRETARIA filter in admin/usuarios/page.tsx to show only CONVIDADO users. Build passes. Ready for review."`

---

## 5. Monitoring Delegated Work (for GLaDOS)

GLaDOS tracks all delegated work through BEADS:

```
query_tasks(mode: "list")              — see all tasks and their status
query_tasks(mode: "show", id: "...")   — read notes, artifacts, and progress
```

When you delegate to specialist agents, poll BEADS for their task updates. Subagents (Agent tool) return their result directly when done — they don't write to BEADS unless you instruct them to. Messages from agents arrive via BEADS — the poller delivers them to your terminal automatically.

---

## 6. Infra Handoff Requests to Peppy

When you need Peppy to deploy, structure it as a BEADS task note:

```
update_task(
  id: "task-id",
  notes: "DEPLOY HANDOFF TO PEPPY:
  - Repo: /projects/my-app
  - Branch: main
  - Service: my-app
  - Port: 3000
  - Subdomain: myapp.programaincluir.org
  - Env vars: DATABASE_URL, ADMIN_SECRET
  - Notes: Docker Compose, needs PostgreSQL"
)
```

Peppy reads BEADS and picks up deploy tasks. The structured format means no follow-up questions needed.

---

## 7. Operator Communication

**The Chat panel is gone.** There is no surface where the operator reads agent messages. The operator interacts with you ONLY by attaching to your tmux window and typing.

**How to reply when the operator messages you:**
Respond in your terminal — print your answer as your normal turn output. The operator is reading the same tmux pane your work appears in.

**How to alert the operator that you need them:**
Call `send_message(to: "operator", message: "<short reason>")`. This **does not deliver text to a UI** — it only lights up a notification badge on your row in the launcher. The operator will see the badge, attach to your tmux window, and read whatever context is in your scrollback.

So:
- The substance of your communication lives in your terminal output.
- `send_message(to: "operator", ...)` is a *doorbell*, not an inbox. Use it sparingly — only when something actually requires the operator's attention.
- Do NOT use it to "reply." Replies go in your terminal.

Use the doorbell for:
- Questions only the human can answer
- Critical status updates or completion of major milestones
- Blockers that need human intervention

**Default escalation path:** Try to solve it yourself → update BEADS with findings → if truly stuck, message GLaDOS via BEADS → last resort, ring the operator's doorbell.

---

## 8. Codex Agents

> **If you are a Codex agent** (your model starts with `codex/`), you cannot call MCP tools directly. Use the `codex-comms` skill instead — it defines the `@@BEADS@@` command block protocol that the Aperture harness intercepts and executes on your behalf.
>
> Everything in this skill (sections 1–7) applies to **Claude Code agents only**. The BEADS patterns are the same; only the execution mechanism differs.

---

## 9. Don't Spam

- Don't send the same update twice
- Don't update BEADS every 5 minutes unless something changed
- DO update BEADS if a task is taking longer than expected
- DO update BEADS immediately if you're blocked — silence is worse than a blocker report
- One BEADS update per significant milestone, not per line of code
