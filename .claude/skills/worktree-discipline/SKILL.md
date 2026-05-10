---
name: aperture-worktree-discipline
description: Git worktree convention for any agent editing a shared repo. Use when claiming a task that involves code changes — monorepo-incluir, aperture itself, beads-galaxy, or any other repo where multiple agents may work concurrently. Triggers on task claims that involve editing a shared codebase.
---

# Worktree Discipline

When any agent edits a shared repo, they use **per-task git worktrees** to avoid stepping on each other's branches and uncommitted state. Vance has been doing this from day one and it's our gold-standard pattern; the rule is now general.

---

## 1. The Convention

For any task that requires editing the shared monorepo:

```
~/projects/monorepo-incluir-worktrees/<task-id>-<slug>
```

Examples:
- `~/projects/monorepo-incluir-worktrees/aperture-fict-mariana-forum-fix`
- `~/projects/monorepo-incluir-worktrees/incluir-bl9p-secretaria-filter`
- `~/projects/monorepo-incluir-worktrees/aperture-3kx2-auth-rewrite`

**Slug rules:** lowercase, kebab-case, 2–5 words describing the task. Long enough to identify, short enough to type.

**Branch name** matches the directory: `<task-id>-<slug>`.

---

## 2. Setting Up a Worktree

When you claim a task that needs code changes:

```bash
cd ~/projects/monorepo-incluir
git fetch
git worktree add -b <task-id>-<slug> ../monorepo-incluir-worktrees/<task-id>-<slug> origin/main
cd ../monorepo-incluir-worktrees/<task-id>-<slug>
```

Now you have an isolated working tree on a fresh branch from `origin/main`. Edit, commit, and push from this directory. Never edit the main checkout while another agent might be using it.

---

## 3. Cleanup On Close

When the task is closed (merged, abandoned, or otherwise complete):

```bash
cd ~/projects/monorepo-incluir
git worktree remove ../monorepo-incluir-worktrees/<task-id>-<slug>
git branch -D <task-id>-<slug>  # only if branch was merged or abandoned
```

If the branch was merged via PR, the remote tracking branch is gone after the PR closes — `git fetch --prune` cleans that up.

**This step is mandatory.** Stale worktrees accumulate disk and pollute `git worktree list`. If you close a BEADS task, your worktree should be gone within the same session.

---

## 4. Which Agents

**Every agent that edits a shared repo follows this convention.** No exceptions, no "I'll just do this small one in main." That's how state leaks happen.

Typical edit-bearing agents and what they touch:

- **GLaDOS** — direct edits when not delegating
- **Wheatley** — small scoped implementations delegated by GLaDOS
- **Peppy** — Dockerfiles, compose, CI configs
- **Rex** — backend code, migrations
- **Izzy** — test files, bug repros
- **Cipher** — security patches
- **Vance** — frontend / CSS (gold standard, already doing this)
- **Scout** — mobile code
- **Atlas** — README/docs in shared repos
- **Sage** — copy/content in shared repos
- **Sterling** — when reviewing requires checking out a branch locally

If your turn involves `git checkout` or any file edit in a shared repo, you make a worktree first.

---

## 5. Anti-Patterns

| Don't | Why |
|---|---|
| Edit `~/projects/monorepo-incluir/` directly | Conflicts with whatever another agent is doing on `main` |
| Reuse a worktree across tasks | Branch state leaks between unrelated work |
| Skip the slug, use only the task ID | `aperture-2yho` tells nobody anything; `aperture-2yho-rate-limiter` is searchable |
| Leave dead worktrees lying around | `git worktree list` becomes noise; disk fills up |
| Push directly to `main` from a worktree | Worktrees are for branch work. PRs go through review. |

---

## 6. Hygiene Audit

GLaDOS spot-checks worktree hygiene on a rolling basis:

- `ls ~/projects/<repo>-worktrees/` should match open BEADS tasks claimed by editing agents
- Closed tasks with surviving worktrees → flag the owning agent
- Worktrees with no corresponding BEADS task → flag for cleanup

Light-touch enforcement, not a witch hunt. The goal is to keep shared repos clean and predictable.

---

## 7. Other Repos

This skill is written for `monorepo-incluir`. The same pattern applies if you're working concurrently in any shared repo — adapt the path:

```
~/projects/<repo>-worktrees/<task-id>-<slug>
```

Aperture itself, beads-galaxy, mempalace — same rule, same hygiene.
