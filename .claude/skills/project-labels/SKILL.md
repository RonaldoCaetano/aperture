---
name: aperture-project-labels
description: BEADS project label taxonomy. Use when creating any BEADS task, querying tasks, or backfilling labels on existing tasks. Triggers on bd create, bd update --label, query_tasks calls.
---

# Project Labels

Every BEADS task in this facility carries a `project:<name>` label. The label tells agents (and the operator) which body of work the task belongs to without parsing the title or guessing from the description.

---

## 1. The Canonical Taxonomy

| Label | Project | Description |
|---|---|---|
| `project:aperture` | Aperture | The orchestration platform itself — Tauri app, MCP server, agent prompts, skills |
| `project:incluir` | Programa Incluir | The customer-facing platform (`monorepo-incluir`, BH Escape, etc.) |
| `project:beads-galaxy` | BEADS Galaxy | BEADS upstream tooling, dolt sync, conventions |
| `project:mempalace` | MemPalace | The agent memory palace — drawers, tunnels, knowledge graph |

If you're working on something that doesn't fit one of these, **stop and ask the operator before inventing a new label.** The taxonomy is small on purpose.

---

## 2. When to Apply

**Always:** every `bd create` MUST include exactly one `project:<name>` label. No exceptions.

```bash
bd create --title "..." --description "..." -p 2 --label project:aperture
```

If you're creating tasks programmatically through the MCP `create_task` tool, append the label after creation:

```
create_task(title: "...", priority: 2, description: "...")
update_task(id: "<returned-id>", labels: ["project:aperture"])  // or pass via --label
```

(The MCP `create_task` does not yet take labels directly. Until it does, follow up with an update — see follow-up tasks.)

---

## 3. When to Filter

The MCP `query_tasks` and `search_tasks` tools accept a `project:` filter that maps to this label. Use it aggressively to cut response size:

```
query_tasks(mode: "list", project: "aperture")        // only aperture tasks assigned to me
query_tasks(mode: "list", project: "incluir", assignee: "*")  // all incluir tasks anywhere
```

Without `project:`, the default is "all projects" — usually too broad.

---

## 4. Multi-Project Tasks

A task that genuinely spans projects (e.g. "Aperture work that requires Incluir schema changes") gets the **primary** project label. Cross-project context goes in the description, not in a second label. Multiple `project:` labels on one task is a smell — it usually means the task should be split.

---

## 5. Renaming a Project

If a project name changes:
1. Operator decides on the new name
2. GLaDOS announces the rename in BEADS
3. A subagent runs the bulk relabel: `bd list --label project:old --json | jq -r .[].id | xargs -I{} bd update {} --label project:new`
4. Old label is removed via `--unlabel`
5. This skill is updated with the new taxonomy

---

## 6. Lint / Drift Detection

Periodically (or via `bd doctor` once it grows the check):

```bash
bd list --json | jq -r '.[] | select((.labels // []) | map(startswith("project:")) | any | not) | .id'
```

Any task in the output is missing a project label. Backfill it.

---

## 7. Anti-Patterns

| Don't | Why |
|---|---|
| Create a task without a project label | Future filtering breaks; the row becomes invisible to project-scoped queries |
| Invent new project names without operator sign-off | Drift turns the taxonomy into noise |
| Use `project:misc` or `project:other` | A project label that means "I didn't think about it" is worse than no label |
| Apply two `project:` labels | Either the task is misshaped or you're hiding cross-project coupling |
