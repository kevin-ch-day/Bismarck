#!/usr/bin/env bash
# Script: setup_git_ignores.sh
# Purpose: Keep logs/ and tmp/ out of Git while preserving the directories.
# Usage: bash setup_git_ignores.sh [--no-add-all]

set -euo pipefail

# --- options ---
ADD_ALL=1
if [[ "${1-}" == "--no-add-all" ]]; then
  ADD_ALL=0
fi

# --- move to repo root (or fail clearly) ---
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[!] Not inside a Git repository. Aborting."
  exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

# --- 1) ensure placeholders exist ---
mkdir -p logs tmp
: > logs/.gitkeep
: > tmp/.gitkeep
echo "[*] Ensured logs/.gitkeep and tmp/.gitkeep exist."

# --- 2) write/overwrite .gitignore (backup if it already exists) ---
IGNORE_CONTENT='# Ignore logs and temp artifacts (recursively), keep .gitkeep
logs/**
!logs/.gitkeep

tmp/**
!tmp/.gitkeep
'

if [[ -f .gitignore ]]; then
  TS="$(date +%Y%m%d_%H%M%S)"
  cp .gitignore ".gitignore.bak.$TS"
  echo "[*] Backed up existing .gitignore -> .gitignore.bak.$TS"
fi

printf "%s\n" "$IGNORE_CONTENT" > .gitignore
echo "[*] Wrote .gitignore rules."

# --- 3) stop tracking any already-added files under logs/ and tmp/ (keeps them on disk) ---
# Untrack everything under logs/ and tmp/ except .gitkeep
# (If nothing is tracked, this is a no-op.)
while IFS= read -r -d '' f; do
  base="$(basename "$f")"
  if [[ "$base" != ".gitkeep" ]]; then
    git rm --cached "$f" >/dev/null 2>&1 || true
  fi
done < <(git ls-files -z -- logs tmp || printf '\0')

# Also handle the original explicit patterns (harmless if none match)
git rm --cached logs/run_*.log tmp/adb*.log 2>/dev/null || true
echo "[*] Untracked any existing log/temp files from Git index."

# --- 4) stage changes ---
git add .gitignore logs/.gitkeep tmp/.gitkeep
echo "[*] Staged .gitignore and .gitkeep files."

# Optional: stage other removals/updates from step 3
if [[ "$ADD_ALL" -eq 1 ]]; then
  git add -A
  echo "[*] Staged all related changes (git add -A)."
else
  echo "[i] Skipped git add -A (use without --no-add-all to enable)."
fi

echo "[✓] Done. Commit when ready (e.g., git commit -m 'chore: ignore logs/tmp and keep dirs')."
