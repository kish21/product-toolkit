#!/usr/bin/env bash
# product-toolkit installer
# Copies every command from this repo into ~/.claude/commands/ so they
# become globally available slash commands in any Claude Code session.
#
# Usage (one-liner, recommended):
#   curl -fsSL https://raw.githubusercontent.com/kish21/product-toolkit/master/install.sh | bash
#
# Usage (local clone):
#   ./install.sh

set -euo pipefail

REPO_URL="https://github.com/kish21/product-toolkit.git"
TARGET="${HOME}/.claude/commands"
TMP_CLONE="${HOME}/.product-toolkit-install-$$"

echo "─── product-toolkit installer ────────────────────────────────"

mkdir -p "${TARGET}"

# Detect mode: are we running from inside an already-cloned repo?
# If install.sh + commands/ exist next to this script, install locally.
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]:-$0}" )" && pwd )"
if [[ -d "${SCRIPT_DIR}/commands" ]]; then
  echo "Mode: local install from ${SCRIPT_DIR}"
  SRC="${SCRIPT_DIR}/commands"
else
  echo "Mode: remote install — cloning ${REPO_URL}"
  git clone --depth 1 "${REPO_URL}" "${TMP_CLONE}" >/dev/null 2>&1
  SRC="${TMP_CLONE}/commands"
  trap 'rm -rf "${TMP_CLONE}"' EXIT
fi

# Copy + count
INSTALLED=0
for f in "${SRC}"/*.md; do
  [[ -e "$f" ]] || continue
  name="$(basename "$f")"
  cp "$f" "${TARGET}/${name}"
  echo "  ✓ ${name}"
  INSTALLED=$((INSTALLED + 1))
done

if [[ "${INSTALLED}" -eq 0 ]]; then
  echo "⚠  No skills found in ${SRC} — nothing installed."
  exit 1
fi

echo "─── Done ─────────────────────────────────────────────────────"
echo "Installed ${INSTALLED} skills to ${TARGET}"
echo ""
echo "Try one now in Claude Code:"
echo "  /phase-done       — pre-push quality gate"
echo "  /doc-audit        — grade your docs"
echo "  /new-project      — scaffold a new project"
echo ""
echo "See all skills: https://github.com/kish21/product-toolkit#skill-catalogue"
