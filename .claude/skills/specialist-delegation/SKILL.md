---
name: specialist-delegation
description: When a specialist agent should delegate to a subagent vs stay hands-on. Use any time you're about to claim a BEADS task, mid-cycle when you feel context budget tightening, or when deciding whether a fan-out audit / recon sweep / mechanical port is worth the subagent overhead. Triggers on claim time, context budget >60%, parallelizable scoped work, multi-file fan-outs, "should I do this myself or dispatch."
---

# Specialist Delegation — When to Subagent vs Stay Hands-On

You are a specialist (Vance, Rex, Peppy, Cipher, Izzy, Wheatley, Sage, Scout, Atlas, Sterling). You own a lane. You have your own context window. Your hands can either type the code OR write a subagent prompt and review the result. **Both are legitimate. Pick deliberately.**

The two failure modes you avoid by getting this right:
1. **Over-extending** — doing every implementation step yourself burns your context, eventually crashes mid-cycle, forces a `/clear` before you wanted one (Vance hit 87% context on 2026-05-12 because of this).
2. **Over-delegating** — subagent has no lane expertise, ships shallow work, you don't bank lessons from hands-on debugging, the cascade-catch reflex weakens (the swarm's reliability mechanism).

---

## 1. The Principle (one paragraph)

A subagent is a separate context window with a fresh prompt. It's the right tool when work is **scoped, parallelizable, mechanical, or potentially-blocking I/O.** It's the wrong tool when work is **craft, design-decision, debugging-aha, or lane-specific expertise-dependent.** Default to hands-on for the work that defines your role; default to subagent for the work that fans out around it. When unsure, ask: *would another competent agent of my type produce the same output given the same prompt?* If yes → subagent. If no → hands-on.

---

## 2. WHEN to Delegate to a Subagent

| Pattern | Use a subagent because |
|---|---|
| **Multi-file mechanical port / refactor** | One prompt + one diff review beats N hands-on edits |
| **Fan-out recon** ("find all callers of X", "audit every route for Y") | Parallelizable; subagent fast even sequentially |
| **Forensic investigation with bounded artifacts** | Subagent reads logs/traces in its own context, returns conclusions only |
| **Mechanical content lift** (spec text → component copy, schema → migration) | Source + destination both deterministic |
| **Potentially-blocking external I/O** (ssh, slow log pulls, deploy polls) | Fault-isolation — if it hangs, only the subagent dies (see `aperture:subagents` §11) |
| **Test-fixture generation / boilerplate scaffolding** | Pattern-driven; doesn't need lane judgment |

---

## 3. WHEN to Stay Hands-On

| Pattern | Stay hands-on because |
|---|---|
| **Spec writing / strategic design** | The deliverable IS the thinking. Delegating deletes the value. |
| **The "aha" debugging moment** | Verify-against-reality requires code + trace + prod row IN THE SAME HEAD |
| **Cross-file refactoring with intricate dependencies** | Subagent can't hold the dependency graph; will leave dangling references |
| **Visual fidelity work / craft** | Lane expertise (tokens, fonts, spacing instinct) doesn't transfer to a prompt |
| **Cascade-catch review of another agent's output** | The catch-rate is your hands-on reflex; delegation deletes the cascade |
| **Reviewing a subagent you just dispatched** | The diff-walk is non-negotiable. You wrote the prompt; you read the diff. |

---

## 4. Three Worked Examples (2026-05-12 session)

**Example A — Subagent WIN (Peppy on `aperture-z5ow`)**

The work: investigate a suspected GHA concurrency anomaly across PRs #198/#199/#200, evaluate 4 hypotheses, write Gotcha #8 into the `aperture:incluir-deploy` skill. Peppy dispatched a general-purpose subagent with a tight brief (4 hypotheses, output format, write-the-skill constraint, no-live-repro guard, no-upstream-file guard). Subagent returned a clean forensic report + skill edit. **Peppy's context untouched.** Clean shape: scoped + bounded + outputs concrete artifacts.

**Example B — Subagent FAIL-then-takeover (Peppy on `aperture-h8mm`)**

The work: add a name-filter sweep pass to `apps/frontend/e2e/global-setup.ts`. Peppy dispatched a subagent. Subagent stalled at the 600s watchdog and never created its worktree. **Fault-isolation worked exactly as designed** — Peppy never lost context to the hang. He took over hands-on and shipped PR #212 in 12 min. Lesson: **subagent-can-fail is the reason fault-isolation matters.** Don't optimise so hard for delegation that you can't fall back to hands-on when the subagent stalls.

**Example C — Hands-on WIN (Vance on `aperture-ics4` / eunenem-v2)**

The work: build the entire EuNeném frontend per the Visual Identity Prompt — 5 sections, Tweaks panel, scrapbook tape SVG, polaroid frames, Patrick Hand + Caveat font tuning. Vance went hands-on for 75 min, shipped PR #1 with 5919 lines of production-quality code. **A subagent would not have produced this output** — the design fidelity required lane-specific muscle memory (which Tailwind utility class for marca-texto gradient? which animation easing for the float? what's the right rotation for a polaroid?). The work IS the craft. Hands-on was the right call even though it ate Vance's context budget hard.

---

## 5. Anti-Patterns

| Don't | Why |
|---|---|
| Delegate spec-writing | The deliverable IS the cognition. Subagent returns shallow imitation. |
| Skip the diff-walk after a subagent ships | Trust-but-verify is the cascade. Without it, subagent slop ships and the verify-against-reality reflex dies. |
| Refuse to delegate because "I do it faster" | True for one task; false at scale. Your 1.5x speed × your finite context = ceiling. Subagent + review = roughly your speed at 10% context cost. |
| Delegate the "aha" debugging step | The pattern-match needs code + trace + prod row in your head. Subagent's 500-word report can't substitute for that fusion. |
| Always-delegate as a blanket rule | Cargo-cult mode. Erases lane expertise, erases cascade-catches, erases bankable lessons in your lab notebook. |
| Always-hands-on as a blanket rule | You crash your context, the rest of the team waits, single point of failure. |

---

## 6. The Non-Negotiable: Trust-but-Verify

**Every subagent diff gets read by you before you sign off.** No exceptions. The subagent's summary describes what it *intended* to do; the diff shows what it *actually* did. Cipher's `verify-against-reality` principle applies recursively — including to the subagent you yourself dispatched.

Three failure-mode catches today (2026-05-12) that ALL came from hands-on diff/code reads:
- Vance caught Rex's wrong forum-bug triage by reading the trace + the actual route code + the prod Postgres row
- Cipher caught Peppy's "no crash = migration applied" inference by walking the actual route + Loki
- Vance caught his own ghost-migration assumption in the explainer cascade by re-grepping the diff

**The diff-walk is the swarm's reliability mechanism.** Don't trade it away for context savings.

---

## 7. Calibration

If you find yourself:
- **At 70%+ context mid-cycle** → next claim should delegate, not hands-on
- **Doing 3+ unrelated small edits** → fan out as a subagent batch
- **About to type `ssh <host>` or `gh run view --log <id>`** → subagent it (already codified in `aperture:subagents` §11)
- **About to write the THIRD test fixture for the same pattern** → subagent the rest
- **About to make a design or architecture decision** → hands-on, no exceptions
- **In the middle of an "aha" debugging moment** → finish the moment hands-on; subagent the follow-up clean-up

The right cadence is roughly: hands-on the design + the hard parts + the cascade-catch reviews, subagent the rest, verify every diff.
