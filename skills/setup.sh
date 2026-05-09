#!/bin/bash
# aperture/skills/setup.sh
#
# DEPRECATED: Skills now live in .claude/skills/ within the project directory.
# Claude Code loads them automatically — no symlinks needed.
#
# This script is kept for backward compatibility but does nothing.
# See .claude/skills/ for the actual skill definitions.

echo "ℹ️  Skills are now loaded automatically from .claude/skills/"
echo "   No symlinks needed. This script is deprecated."
echo "   Run 'just check-skills' to verify skill availability."
