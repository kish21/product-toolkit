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
#
# What it installs:
#   * Flat .md files in commands/ (one file = one skill)
#   * Skill directories (commands/<name>/SKILL.md + commands/<name>/references/*)
#     Used by larger skills like /new-project where progressive disclosure
#     keeps the main SKILL.md small.

set -euo pipefail

REPO_URL="https://github.com/kish21/product-toolkit.git"
TARGET="${HOME}/.claude/commands"
TMP_CLONE="${HOME}/.product-toolkit-install-$$"

echo "─── product-toolkit installer ────────────────────────────────"

mkdir -p "${TARGET}"

# Detect mode: are we running from inside an already-cloned repo?
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

# Install flat skills (commands/*.md, single-file skills)
INSTALLED=0
for f in "${SRC}"/*.md; do
  [[ -e "$f" ]] || continue
  name="$(basename "$f")"
  cp "$f" "${TARGET}/${name}"
  echo "  ✓ ${name}"
  INSTALLED=$((INSTALLED + 1))
done

# Install directory-form skills (commands/<name>/SKILL.md + references/)
for d in "${SRC}"/*/; do
  [[ -d "$d" ]] || continue
  name="$(basename "$d")"
  rm -rf "${TARGET:?}/${name}"   # prevent nested copy (new-project/new-project) on re-install
  cp -R "$d" "${TARGET}/${name}"
  files_in=$(find "${TARGET}/${name}" -name "*.md" | wc -l)
  echo "  ✓ ${name}/ (${files_in} files — SKILL.md + references)"
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
echo "  /new-project      — scaffold a new project (split: slim SKILL.md + references)"
echo "  /phase-done       — pre-push quality gate"
echo "  /doc-audit        — grade your docs"
echo ""
echo "See all skills: https://github.com/kish21/product-toolkit#skill-catalogue"
