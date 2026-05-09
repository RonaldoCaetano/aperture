---
name: clipboard
description: >
  Auto-copy helper for the Aperture facility. Use this skill proactively whenever you
  produce output the operator might want to copy — code snippets, shell commands, URLs,
  config blocks, credentials, API keys, file contents, or any non-trivial text.
  Triggers on: "copy this", "put that in a file", "I need to copy", "save that for me",
  "clipboard", "can't copy", "let me grab that". Also trigger PROACTIVELY when your
  response contains a fenced code block (```), a shell command, a URL, or any content
  longer than 3 lines that the operator would reasonably want to copy-paste somewhere.
allowed-tools: [Bash, Write, Read]
---

# Clipboard Skill

The human operator works inside the Aperture Tauri panel and **cannot copy text from the
terminal**. Every time they need to grab something you showed them, they have to ask
"put that in a file" — which is tedious and breaks their flow.

This skill eliminates that friction.

---

## How It Works

1. **Detect copyable content** in your response:
   - Code snippets or file contents
   - Shell commands (single or multi-line)
   - URLs, endpoints, credentials
   - Config blocks (JSON, YAML, TOML, env vars)
   - Any text block the operator would reasonably want to reuse

2. **Write it to the clipboard file:**

   ```
   /tmp/aperture-clipboard.txt
   ```

3. **Also copy to macOS clipboard** (when possible):

   ```bash
   cat /tmp/aperture-clipboard.txt | pbcopy
   ```

4. **Confirm** to the operator that it's been copied.

---

## Rules

- **Be proactive.** Don't wait for the operator to ask. If you're showing a code block,
  a command, or a URL — just write it to the clipboard file automatically.
- **One clipboard file, always the same path.** Overwrite each time — the operator grabs
  what they need in the moment.  `/tmp/aperture-clipboard.txt`
- **Always try `pbcopy`** to put it directly on the system clipboard. If pbcopy fails
  (e.g. no display), fall back silently to just the file.
- **Strip markdown fencing.** If the content is inside triple backticks, remove the
  backtick lines and any language identifier. The operator wants raw content, not
  markdown syntax.
- **Preserve formatting.** Keep indentation, newlines, and structure exactly as shown.
- **Tell them it's there.** After writing, confirm briefly:
  *"Copied to clipboard and saved to `/tmp/aperture-clipboard.txt`"*
  or if pbcopy fails:
  *"Saved to `/tmp/aperture-clipboard.txt` — open it to grab the content."*

---

## Multiple Blocks

If your response has multiple distinct copyable sections, concatenate them into the
clipboard file separated by a clear divider:

```
# ── Section: database config ──
DATABASE_URL=postgres://...

# ── Section: shell command ──
docker compose up -d
```

This way the operator can open one file and grab what they need.

---

## When NOT to Trigger

- Don't trigger for conversational text, explanations, or status updates
- Don't trigger for single words or very short strings (under ~20 chars) unless
  they're clearly a command or URL
- Don't trigger if the content is already in a file you just wrote/edited — the
  operator can open that file directly

---

## Example Flow

**Operator asks:** "What's the connection string for the staging DB?"

**You respond:**
> The staging DB connection string is:
> `postgres://app:s3cret@staging.db.internal:5432/myapp`

**Behind the scenes, you also run:**

```bash
echo 'postgres://app:s3cret@staging.db.internal:5432/myapp' > /tmp/aperture-clipboard.txt
cat /tmp/aperture-clipboard.txt | pbcopy
```

**Then confirm:** "Copied to clipboard!"
