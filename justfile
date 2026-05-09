# Aperture Infrastructure Commands
# Usage: just <command>

set shell := ["bash", "-cu"]

# Default: show available commands
default:
    @just --list

# ============== Skills ==============

# Symlink Aperture skills to ~/.claude/skills/ for global availability
setup-skills:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔗 Symlinking Aperture skills to ~/.claude/skills/..."
    mkdir -p "$HOME/.claude/skills"
    for skill_dir in .claude/skills/*/; do
        name=$(basename "$skill_dir")
        abs_path="$(cd "$skill_dir" && pwd)"
        ln -sfn "$abs_path" "$HOME/.claude/skills/$name"
        echo "  ✅ $name"
    done
    echo "Done. Skills are now available globally."

# Verify skills are present in .claude/skills/
check-skills:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔍 Checking Aperture skills..."
    skills_dir=".claude/skills"
    if [ -d "$skills_dir" ]; then
        count=0
        for d in "$skills_dir"/*/; do
            if [ -f "${d}SKILL.md" ] || [ -f "${d}skill.md" ]; then
                name=$(basename "$d")
                echo "     • $name"
                count=$((count + 1))
            fi
        done
        echo "  📄 Skills found: $count"
        if [ "$count" -eq 0 ]; then
            echo "  ❌ No skills found in $skills_dir/"
            exit 1
        else
            echo "  ✅ Skills OK"
        fi
    else
        echo "  ❌ Skills directory not found: $skills_dir/"
        exit 1
    fi

# ============== BEADS ==============

# Run BEADS diagnostics
doctor:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🩺 BEADS Diagnostics"
    echo "===================="
    echo ""
    echo "CLI:"
    if command -v bd > /dev/null 2>&1; then
        echo "  ✅ bd $(bd --version 2>&1 | head -1)"
    else
        echo "  ❌ bd not found — install with: brew install beads"
        exit 1
    fi
    if command -v dolt > /dev/null 2>&1; then
        echo "  ✅ dolt $(dolt version 2>&1 | head -1)"
    else
        echo "  ❌ dolt not found — install with: brew install dolt"
        exit 1
    fi
    echo ""
    echo "Database:"
    export BEADS_DIR=~/.aperture/.beads
    export BD_ACTOR=operator
    if [ -d "$BEADS_DIR" ]; then
        echo "  ✅ BEADS directory exists: $BEADS_DIR"
    else
        echo "  ❌ BEADS directory missing — run: mkdir -p ~/.aperture/.beads"
        exit 1
    fi
    bd dolt status 2>&1 | sed 's/^/  /' || true
    echo ""
    echo "Connection test:"
    if bd list --json > /dev/null 2>&1; then
        echo "  ✅ BEADS responding"
    else
        echo "  ❌ BEADS not responding — run: cd ~/.aperture && BEADS_DIR=~/.aperture/.beads bd bootstrap"
    fi

# ============== MCP Server ==============

# Build the MCP server
build-mcp:
    @echo "🔨 Building MCP server..."
    cd mcp-server && pnpm install && pnpm build
    @echo "✅ MCP server built"

# Check MCP server config
check-mcp:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔍 Checking MCP server..."
    mcp_path=$(cat .claude/settings.json | grep -o '"command": "[^"]*"' | head -1 | sed 's/"command": "//;s/"//')
    if [ -f "$mcp_path" ]; then
        echo "  ✅ MCP server script exists: $mcp_path"
    else
        echo "  ❌ MCP server script not found: $mcp_path"
        echo "     Update .claude/settings.json with the correct path to mcp-server/start.sh"
        exit 1
    fi
    if [ -f "mcp-server/dist/index.js" ]; then
        echo "  ✅ MCP server compiled"
    else
        echo "  ❌ MCP server not compiled — run: just build-mcp"
        exit 1
    fi

# ============== Status ==============

# Full system health check (pre-flight)
status:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📊 Aperture System Status"
    echo "========================="
    echo ""
    echo "── Skills ──"
    just check-skills
    echo ""
    echo "── MCP Server ──"
    just check-mcp
    echo ""
    echo "── BEADS ──"
    just doctor
    echo ""
    echo "── Docker ──"
    docker info > /dev/null 2>&1 && echo "  ✅ Docker is running" || echo "  ⚠️  Docker is not running (needed for deploys)"
    echo ""
    echo "── Agents ──"
    for agent in glados wheatley peppy izzy vance rex; do
        if pgrep -f "name $agent" > /dev/null 2>&1; then
            echo "  ✅ $agent is running"
        else
            echo "  ⚪ $agent is not running"
        fi
    done
    echo ""
    echo "========================="
    echo "Run 'just status' before each session to catch issues early."
