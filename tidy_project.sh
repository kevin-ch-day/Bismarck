#!/usr/bin/env bash
# tidy_project.sh
# Purpose: Clean up generated files from Git, normalize .gitignore,
#          park legacy scripts, and surface obvious script issues.
#          Safe by default; add --purge to delete artifacts from disk.

set -euo pipefail

BRANCH_NAME=""
PURGE=false
FORCE=false

usage() {
  cat <<'EOF'
Usage: ./tidy_project.sh [--purge] [--force] [--branch NAME]

Options:
  --purge         Also delete output/*, logs/run_*.log, tmp/*, and downloads symlink from disk.
  --force         Proceed even if a rebase/merge is in progress.
  --branch NAME   Use a specific branch name (default: tidy/cleanup-structure-<timestamp>).

This script will:
  1) Create a safety branch.
  2) Ensure keep-alive placeholders (logs/.gitkeep, tmp/.gitkeep, output/.gitkeep).
  3) Update .gitignore with stable rules and back it up if modified.
  4) Remove generated artifacts from Git index (not from disk unless --purge).
  5) Park legacy scripts into attic/ only if not referenced by current code.
  6) Run basic bash -n syntax checks; fix execute bits for shebang scripts.
  7) Commit the tidy change set.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --purge) PURGE=true; shift;;
    --force) FORCE=true; shift;;
    --branch) BRANCH_NAME="${2:-}"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown option: $1"; usage; exit 2;;
  esac
done

#--- sanity: inside a git repo
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[!] Not inside a Git repository. Abort."
  exit 1
fi

#--- guard: ongoing rebase/merge unless --force
if [[ -d .git/rebase-apply || -d .git/rebase-merge || -f .git/MERGE_HEAD ]]; then
  if ! $FORCE; then
    echo "[!] Rebase or merge in progress. Resolve it or pass --force to proceed."
    exit 1
  else
    echo "[*] Forced run with ongoing rebase/merge."
  fi
fi

#--- safety branch
ts="$(date +%Y%m%d_%H%M%S)"
if [[ -z "$BRANCH_NAME" ]]; then
  BRANCH_NAME="tidy/cleanup-structure-${ts}"
fi
echo "[*] Creating safety branch: ${BRANCH_NAME}"
git checkout -b "${BRANCH_NAME}" >/dev/null 2>&1 || git checkout -B "${BRANCH_NAME}"

#--- ensure core dirs and keepers
mkdir -p logs tmp output attic
: > logs/.gitkeep
: > tmp/.gitkeep
: > output/.gitkeep
: > attic/.gitkeep

#--- normalize .gitignore (idempotent)
ensure_gitignore_rule() {
  local rule="$1"
  if ! grep -qxF "$rule" .gitignore 2>/dev/null; then
    echo "$rule" >> .gitignore
    return 0
  fi
  return 1
}

backup_made=false
touch .gitignore
{
  echo "# ---- BEGIN tidy_project.sh managed rules ----"
} >> /dev/null

maybe_backup_gitignore() {
  if ! $backup_made; then
    cp -p .gitignore ".gitignore.bak.${ts}" || true
    backup_made=true
    echo "[*] Backed up .gitignore -> .gitignore.bak.${ts}"
  fi
}

add_rule() {
  local rule="$1"
  if ensure_gitignore_rule "$rule"; then
    maybe_backup_gitignore
  fi
}

# desired rules
add_rule "logs/**"
add_rule "!logs/.gitkeep"
add_rule "tmp/**"
add_rule "!tmp/.gitkeep"
add_rule "output/**"
add_rule "!output/.gitkeep"
add_rule "downloads"
add_rule "*.apk"

#--- remove generated artifacts from Git index (keep on disk unless --purge)
echo "[*] Removing generated artifacts from Git index (not disk)..."
git rm -r --cached --ignore-unmatch logs/* tmp/* output/* >/dev/null 2>&1 || true
git rm --cached --ignore-unmatch downloads >/dev/null 2>&1 || true
# remove any tracked APKs in repo root
git ls-files "*.apk" --error-unmatch >/dev/null 2>&1 && git rm --cached *.apk || true

#--- decide if legacy scripts can be moved to attic
# move only if not referenced outside attic/
move_if_unreferenced() {
  local src="$1"
  local dst="attic/$(basename "$src").bak"
  if [[ ! -f "$src" ]]; then
    return 0
  fi
  # any references outside attic ?
  if grep -R --line-number --exclude-dir=.git --exclude-dir=attic --exclude=tidy_project.sh "$(basename "$src")" . >/dev/null 2>&1; then
    echo "[!] Reference to ${src} still found in code; leaving it in place."
    return 0
  fi
  git mv "$src" "$dst"
  echo "[*] Parked ${src} -> ${dst}"
}

# candidates
move_if_unreferenced "utils/display_utils.sh"
move_if_unreferenced "parse_apks.sh"
move_if_unreferenced "apk_actions.sh"

#--- add keepers and attic
git add .gitignore logs/.gitkeep tmp/.gitkeep output/.gitkeep attic/.gitkeep >/dev/null 2>&1 || true
git add attic/ >/dev/null 2>&1 || true

#--- basic script checks: bash -n and fix execute bit for shebang files
echo "[*] Running basic shell syntax checks and permission fixes..."
syntax_fail=0
while IFS= read -r -d '' f; do
  # skip attic, output, logs, tmp, .git
  case "$f" in
    ./attic/*|./output/*|./logs/*|./tmp/*|./.git/*) continue;;
  esac
  # syntax check
  if ! bash -n "$f" 2>/dev/null; then
    echo "[!] Syntax check failed: $f"
    syntax_fail=1
  fi
  # ensure exec bit if shebang
  if head -n1 "$f" | grep -qE '^#!'; then
    if [[ ! -x "$f" ]]; then
      chmod +x "$f"
      git add "$f" >/dev/null 2>&1 || true
      echo "[*] Fixed execute bit: $f"
    fi
  fi
done < <(find . -type f -name "*.sh" -print0)

#--- optional purge from disk
if $PURGE; then
  echo "[*] Purging artifacts from disk (output/*, logs/run_*.log, tmp/*, downloads)..."
  rm -rf output/* tmp/* 2>/dev/null || true
  find logs -maxdepth 1 -type f -name "run_*.log" -exec rm -f {} + 2>/dev/null || true
  rm -f downloads 2>/dev/null || true
fi

#--- stage placeholder changes after purge
git add .gitignore logs/.gitkeep tmp/.gitkeep output/.gitkeep >/dev/null 2>&1 || true

#--- commit if there is anything to commit
if ! git diff --cached --quiet; then
  git commit -m "chore: tidy repo; ignore outputs/logs/tmp; attic legacy scripts when unreferenced; shell checks; perms" >/dev/null
  echo "[+] Committed tidy changes on branch ${BRANCH_NAME}."
else
  echo "[*] No staged changes to commit."
fi

#--- summarize potential issues
echo
echo "===== SUMMARY ====="
git status -s || true
if [[ $syntax_fail -ne 0 ]]; then
  echo "[!] One or more .sh files failed 'bash -n'. Check messages above."
fi

# scan for obvious broken sources in run.sh
if [[ -f run.sh ]]; then
  missing=0
  # naive checks for sourced files existence
  while IFS= read -r path; do
    # extract quoted path from lines like: . utils/display/base.sh  or source utils/display/base.sh
    file=$(echo "$path" | sed -E 's/^\s*(source|\.)\s+//')
    file=$(echo "$file" | sed -E 's/[\"\x27]//g' | awk '{print $1}')
    if [[ -n "$file" && ! -f "$file" ]]; then
      echo "[!] run.sh references missing file: $file"
      missing=1
    fi
  done < <(grep -E '^\s*(source|\.)\s+' run.sh || true)
  if [[ $missing -eq 0 ]]; then
    echo "[*] run.sh include references look OK."
  fi
fi

echo "[✓] Done."
