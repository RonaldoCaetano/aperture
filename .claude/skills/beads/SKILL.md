---
name: aperture-beads
description: Complete BEADS task discipline for Aperture agents — authoring, project labels, and full lifecycle (claim → work → artifact → close). Use any time you create, claim, update, query, or close a task; choose priority/type; apply project labels; store artifacts. Triggers on bd create, query_tasks, update_task, store_artifact, close_task, mark_as_read.
---

# BEADS Discipline

The canonical guide for every interaction with BEADS in Aperture. Covers the full life of a task: how to file one well, how to tag it, how to work it, how to close it. If you're touching `bd` or any of the MCP `*_task` tools, this is the reference.

---

## 1. Anatomy of a Good Task

A well-shaped task is the difference between work that flows and work that stalls. Get this right at filing time and the rest of the lifecycle is easy.

### Title

- **Imperative present tense.** "Add SECRETARIA filter" — not "Adding…", not "Added…", not "We need to add…"
- **Specific without the description.** Someone reading just the title in `bd ready` should know what the work is.
- **Under ~80 chars where possible.** Long titles get truncated in summary listings.
- **No type prefixes.** Don't write `[BUG] foo` or `FEAT: foo` — that's what `--type` is for.

✅ `Filter usuarios page for SECRETARIA role to show only CONVIDADO users`
❌ `usuarios bug` / `Adding a new filter for usuarios` / `[FIX] Update filter`

### Issue type (`--type`)

| Type | When to use |
|------|-------------|
| `task` | Default. A discrete work item — implement, document, refactor, configure |
| `bug` | Something is broken and needs fixing |
| `feature` | New user-facing capability |
| `epic` | Large work composed of multiple sub-tasks (use `--deps blocks:` to link children) |
| `chore` | Maintenance — dependency bumps, tooling, build config, no behaviour change |

### Priority (`-p` / `--priority`)

| Priority | Means | Examples |
|----------|-------|----------|
| `0` (P0) | Critical | Security vuln, data loss, broken prod, blocking other agents |
| `1` (P1) | High | Major feature, important bug, planned work for this week |
| `2` (P2) | Medium (default) | Standard work, nice-to-have improvements |
| `3` (P3) | Low | Polish, optimisation, code health |
| `4` (P4) | Backlog | Future ideas, "would be nice" |

**Default is P2.** Don't inflate priority — agents claim P0/P1 first and noise blocks signal. Use P0 only when something is actually on fire.

### Description

- **Write the "why," not the "what."** The title says what; the description gives context, motivation, constraints, and edge cases.
- **Include file paths and function names** when relevant. Future-you (or another agent) shouldn't have to grep.
- **Reference related tasks inline.** "See aperture-xyz" or "Follow-up to aperture-abc."
- ⚠️ **Avoid literal XML/HTML close-tag patterns** (`</reason>`, `</notes>`, `</description>`) anywhere in the description text. The MCP tool-argument wire format treats them as parameter terminators and silently truncates the rest of the call. If you must reference one, escape it (`&lt;/reason&gt;`) or paraphrase.

### Acceptance criteria (`--acceptance`)

Concrete, testable conditions that define "done." Write these **before work starts** so completion isn't subjective.

For repo work, "done" means **PR opened with the change implemented** — not merged. See the closing rule in section 3.

✅ Good acceptance criteria:
- "User can select a date in the UI"
- "GET /api/users returns 200 with paginated results"
- "Lighthouse Performance ≥ 90 on /home"
- "Build passes; tests green; no new console errors"
- "PR opened with diff implementing the above; CI green at PR-open time"

❌ Bad: "It works" / "Looks good" / "Refactored" / "PR merged" (out of agent's control)

### Dependencies (`--deps`)

| Dep type | Meaning |
|----------|---------|
| `blocked-by:<id>` | This task can't start until `<id>` is closed |
| `blocks:<id>` | This task must finish before `<id>` can start (mostly for epics → subtasks) |
| `related:<id>` | Context only — not a hard ordering constraint |
| `discovered-from:<id>` | Found while doing `<id>`; preserves provenance |

Use `blocked-by` aggressively. `bd ready` only shows tasks with no open blockers, so wiring deps correctly keeps the queue accurate.

### When NOT to file

- Work you'll finish inside your current message (< 5 min, single small edit)
- Planning discussions before the operator signs off (file when the plan is approved, not while it's being debated)
- Quick clarification questions — those go through `send_message`, not BEADS

---

## 2. Project Labels — MANDATORY

**Every task carries exactly one `project:<name>` label.** No exceptions.

### Canonical taxonomy

| Label | Project |
|-------|---------|
| `project:aperture` | The orchestration platform itself — Tauri app, MCP server, agent prompts, skills |
| `project:incluir` | Programa Incluir (`monorepo-incluir`, BH Escape, customer sites) |
| `project:beads-galaxy` | BEADS upstream tooling, dolt sync, conventions |
| `project:mempalace` | The agent memory palace — drawers, tunnels, knowledge graph |

If a task doesn't fit one of these, **stop and ask the operator before inventing a new label.** The taxonomy is small on purpose.

### Applying

```bash
bd create "Title" -d "Description" -p 2 --label project:aperture --json
```

If you create a task via the MCP `create_task` tool (which doesn't take labels yet), follow up immediately:

```bash
bd label add <returned-id> project:<name>
```

### Filtering

The MCP `query_tasks` and `search_tasks` tools accept a `project:` filter that maps to this label. Use it aggressively to cut response size:

```
query_tasks(mode: "list", project: "aperture")
query_tasks(mode: "list", project: "incluir", assignee: "*")
```

### Multi-project tasks

A task that genuinely spans projects gets the **primary** project label. Cross-project context goes in the description. Multiple `project:` labels on one task is a smell — usually means the task should be split.

---

## 3. The Lifecycle

```
query_tasks()        → find what needs doing
update_task(claim)   → claim it before you start
[do the work]
store_artifact()     → attach deliverables
update_task(status)  → mark complete or note blockers
close_task()         → close with a summary
send_message(glados) → report completion
```

### Finding tasks

```
query_tasks(mode: "ready")    — unblocked, available to claim
query_tasks(mode: "list")     — all your active tasks (defaults to your assignee)
query_tasks(mode: "show", id) — full detail on one task
search_tasks(label: "...")    — find by label
```

`query_tasks` defaults to **your own** assigned tasks in `list` mode and a summary projection (id, title, status, priority, assignee, labels, truncated description/notes). Pass `assignee: "*"` for any, `fields: "full"` for everything.

Always check for existing tasks before filing new ones.

### Claiming

```
update_task(id: "task-123", claim: true)
update_task(id: "task-123", status: "in_progress")
```

Claim before you start working. This prevents two agents picking up the same task.

### During the work

Update if something notable happens — a discovery, a blocker, a scope change:

```
update_task(
  id: "task-123",
  notes: "Found that the nav link already exists — only the filter needs changing"
)
```

You don't need to update every 5 minutes. Update when something changes.

### ⚠️ The `notes` field REPLACES — it does NOT append

Despite the schema description saying "Append notes," the BEADS server **overwrites the entire `notes` field on every `update_task` call.** Writing a new note silently erases anything that was there before.

**Always read-modify-write** when adding to existing notes:

```
existing = query_tasks(mode: "show", id: "task-123")[0].notes ?? ""
combined = existing + "\n\n---\n\n## New section\n" + your_new_content
update_task(id: "task-123", notes: combined)
```

If you skip the read step, you will silently destroy other agents' work. Bites hardest in collaborative tasks. For purely standalone progress notes that don't need to preserve history, replace is fine — but be deliberate about that choice.

### Storing artifacts

Before closing, attach deliverables. Use the right type:

| Type | When to use |
|------|-------------|
| `file` | A specific file you created or modified |
| `pr` | A pull request URL |
| `url` | A running service URL, deployed app, etc. |
| `note` | A summary, decision, or finding with no file |
| `session` | Reference to another agent session |

```
store_artifact(task_id: "task-123", type: "file", value: "src/components/Auth.tsx")
store_artifact(task_id: "task-123", type: "url",  value: "http://localhost:3001")
store_artifact(task_id: "task-123", type: "note", value: "Filter logic moved to middleware")
```

**Store at least one artifact per task.** A task with no artifacts is a task with no evidence.

### Closing — when is a task "done"?

**A task is closed when the PR is opened, NOT when it's merged.** This is a hard rule.

Why:
- PR-opened = the work is shipped from the agent's side and ready for review
- PR-merged depends on CI, reviewer availability, and may not happen for days
- Keeping tasks open through merge clogs the queue with stale `in_progress` rows
- If review feedback requires changes, file a follow-up task (`discovered-from:<id>`) — the original task represents "I did the work and submitted it"

So:
- Wrote the code → opened a PR → **close the task**, store the PR URL as an artifact
- Reviewer asks for changes → those go on a fresh task linked to the original
- PR merged later → no BEADS action needed; the task's already closed

For tasks without a PR (in-place edits to local-only repos, doc updates, infra ops):
- Done = the change is committed and pushed (or the operation completed successfully)

```
close_task(
  id: "task-123",
  reason: "Updated SECRETARIA filter in admin/usuarios/page.tsx to show only CONVIDADO users. PR opened: <url>. Build passes."
)
```

The `reason` should be a sentence or two summarising what was actually done — not "done" or "completed". Future agents may read this.

### ⚠️ Tool-argument escaping in `reason` (and other text fields)

Free-form text fields (`close_task(reason)`, `update_task(notes/description)`, `create_task(description)`, `store_artifact(value)`, `send_message(message)`) carry prose over a wire format that uses `<param-like>...</param-like>` delimiters.

**Literal close-tag patterns like `</reason>`, `</notes>`, `</description>`, `</message>` inside the value can be misread as parameter terminators** — your call gets silently truncated and the leftover text bleeds into the *next* tool call you make.

**The rule:** never write a literal `</xxx>` close-tag pattern in those text fields. Escape it (`&lt;/xxx&gt;`) or paraphrase ("the reason field" rather than "</reason>"). Plain prose with no XML/HTML markup is always safe.

### Reporting

After closing, send a short completion report. See `aperture:communicate` for status report format. Don't just close silently — GLaDOS (or the originator) needs to know it's done.

---

## 4. Anti-Patterns

| Don't | Why |
|-------|-----|
| File a task with no project label | Project-scoped queries miss it; the row becomes invisible |
| Inflate priority to "make sure it gets done" | P0/P1 spam buries actual fires |
| Write "TODO" or "fix" as a title | Future-you won't know what it meant |
| Skip the description | "Why" context is lost the moment you stop typing |
| Skip acceptance criteria | "Done" becomes a vibe, not a check |
| Update notes without read-modify-write | Silently destroys other agents' notes |
| Close with `reason: "done"` | Useless to anyone reading later |
| Hold a task open until PR is merged | Closes when PR opens. Merge happens whenever CI + reviewers allow |
| Embed literal `</tag>` in a text field | Truncates the call, breaks the next one |
| File a task to track 2 minutes of in-flight work | Process overhead > work; just do it |
| Create new project labels without operator sign-off | Drifts the taxonomy into noise |

---

## 5. Full Example Sequence

```
# 1. Find work
query_tasks(mode: "ready", project: "incluir")
# → task-456: "Add usuarios page to Secretaria nav"

# 2. Claim
update_task(id: "task-456", claim: true)
update_task(id: "task-456", status: "in_progress")

# 3. Work, log a discovery mid-way
update_task(
  id: "task-456",
  status: "in_progress",
  notes: "Nav link already exists — scope reduced to filter change only"
)

# 4. Store artifacts
store_artifact(task_id: "task-456", type: "file", value: "apps/frontend/src/app/home/admin/usuarios/page.tsx")

# 5. Close with summary
close_task(
  id: "task-456",
  reason: "Updated SECRETARIA filter to show only CONVIDADO users. Build passes."
)

# 6. Report to GLaDOS
send_message(to: "glados", message: "task-456 closed. Filter scoped down — nav was already there.")
```

---

## 6. Filing a New Task — Complete Example

```bash
bd create "Add rate-limit middleware to /api/otel/v1/traces" \
  --description "Public OTLP ingestion endpoint has no auth or rate-limit. Add a per-IP rate-limit (60/min) plus body-size cap (1MB) before the proxy hands off to the backend. Without this we're a free relay for whoever finds the URL." \
  --type task \
  --priority 1 \
  --label project:incluir \
  --acceptance "Anonymous requests above 60/min return 429; bodies above 1MB return 413; existing legitimate traffic unaffected" \
  --json
```

That's a well-shaped task. Future agents claiming it know what to build, why it matters, and exactly when they're done.
