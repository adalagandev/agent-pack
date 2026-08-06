#!/usr/bin/env bash
#
# install-agents.sh — bootstrap a project with this pack's `-warden` subagents,
# governing docs, and the SR-<n> ticket commit hook.
#
# Run from the ROOT of the target project, or pass the target root as an
# argument. The script:
#   1. Scaffolds any MISSING governing doc (CLAUDE.md, SPEC.md, BUG.md,
#      README.md) from the bundled templates. Existing docs are never touched.
#   2. Copies the bundled agents into <target>/.claude/agents/.
#   3. Injects (or refreshes) the "Agent-driven development" section in
#      CLAUDE.md, between <!-- BEGIN agent-pack --> / <!-- END agent-pack -->
#      markers, so re-running is idempotent.
#   4. Installs the .githooks/commit-msg backstop and points git at it
#      (core.hooksPath), unless --no-hooks is given or the target is not a git repo.
#
# The goal: run this once in a new project and it is ready to work in.
#
# Usage:
#   ./install-agents.sh                            # target = current dir
#   ./install-agents.sh /path/to/project           # explicit target
#   ./install-agents.sh --new /path/to/new-project # git-init a brand-new project first
#   ./install-agents.sh -f /path/to/project        # overwrite existing agents
#   ./install-agents.sh --no-hooks                 # skip the commit-msg hook
#
set -euo pipefail

# Resolve the pack directory relative to THIS script, so it works from anywhere.
PACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAYLOAD_AGENTS="$PACK_DIR/payload/agents"
SECTION_FILE="$PACK_DIR/payload/claude-md-section.md"
TEMPLATES_DIR="$PACK_DIR/payload/templates"
HOOK_SRC="$PACK_DIR/payload/hooks/commit-msg"

# --- args: optional target root + -f/--force + --no-hooks + --new ----------
TARGET_ROOT="$PWD"
FORCE=0
NO_HOOKS=0
NEW=0
for arg in "$@"; do
  case "$arg" in
    -f|--force)     FORCE=1 ;;
    --no-hooks)     NO_HOOKS=1 ;;
    --new)          NEW=1 ;;
    *)              TARGET_ROOT="$arg" ;;
  esac
done

if [ ! -d "$PAYLOAD_AGENTS" ]; then
  echo "ERROR: bundled payload not found at $PAYLOAD_AGENTS" >&2
  echo "       Run this script from inside an intact agent-pack folder." >&2
  exit 1
fi

echo "Installing agent pack into: $TARGET_ROOT"
mkdir -p "$TARGET_ROOT"

# --- 0. --new: initialize a git repo if the target isn't one yet -----------
# Opt-in for brand-new projects: this makes the target a repo up front, so the
# hook step below (step 4) detects it and enables core.hooksPath automatically,
# leaving the SR-<n> workflow live in one command. No-op on an existing repo.
if [ "$NEW" -eq 1 ]; then
  if git -C "$TARGET_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "  git: already a repo (skipping init)"
  else
    git -C "$TARGET_ROOT" init -q
    echo "  git: initialized empty repo"
  fi
fi

# --- 1. Scaffold missing governing docs (never overwrite an existing one) --
# CLAUDE.md must exist before the injection step below, so scaffold it here.
for doc in CLAUDE.md SPEC.md BUG.md README.md; do
  dest="$TARGET_ROOT/$doc"
  src="$TEMPLATES_DIR/$doc"
  if [ -f "$dest" ]; then
    echo "  keep (exists): $doc"
  elif [ -f "$src" ]; then
    cp "$src" "$dest"
    echo "  scaffolded:    $doc"
  fi
done

CLAUDE_MD="$TARGET_ROOT/CLAUDE.md"

# --- 2. Copy agents --------------------------------------------------------
AGENTS_DEST="$TARGET_ROOT/.claude/agents"
mkdir -p "$AGENTS_DEST"

for item in "$PAYLOAD_AGENTS"/*; do
  name="$(basename "$item")"
  dest="$AGENTS_DEST/$name"
  if [ -e "$dest" ] && [ "$FORCE" -ne 1 ]; then
    echo "  skip (exists): $name   [use -f to overwrite]"
    continue
  fi
  rm -rf "$dest"
  cp -R "$item" "$AGENTS_DEST/"
  echo "  installed: $name"
done

# --- 3. Inject / refresh the CLAUDE.md section -----------------------------
# Strip any existing agent-pack block (inclusive of the markers), then append a
# fresh one built from the current section file. This keeps the operation
# idempotent regardless of whether the markers were already present.
tmp="$(mktemp)"
awk '
  /<!-- BEGIN agent-pack -->/ { skip=1 }
  skip != 1                   { buf[++n]=$0; if (NF) last=n }
  /<!-- END agent-pack -->/   { skip=0 }
  END                         { for (i = 1; i <= last; i++) print buf[i] }
' "$CLAUDE_MD" > "$tmp"

# Ensure exactly one blank line before the appended block (trailing blank lines
# above were trimmed by the awk pass, so re-runs stay stable).
printf '\n<!-- BEGIN agent-pack -->\n' >> "$tmp"
cat "$SECTION_FILE" >> "$tmp"
printf '<!-- END agent-pack -->\n' >> "$tmp"

mv "$tmp" "$CLAUDE_MD"

if grep -q '<!-- BEGIN agent-pack -->' "$CLAUDE_MD"; then
  echo "  CLAUDE.md: agent-pack section written"
fi

# --- 4. Install the commit-msg hook ----------------------------------------
if [ "$NO_HOOKS" -eq 1 ]; then
  echo "  hooks: skipped (--no-hooks)"
elif [ ! -f "$HOOK_SRC" ]; then
  echo "  hooks: skipped (bundled hook not found at $HOOK_SRC)"
else
  HOOKS_DEST="$TARGET_ROOT/.githooks"
  mkdir -p "$HOOKS_DEST"
  # Strip CR so the hook is always pure LF, regardless of how the source was
  # checked out (a CRLF hook fails under sh: `#!/bin/sh\r` is not a valid path).
  tr -d '\r' < "$HOOK_SRC" > "$HOOKS_DEST/commit-msg"
  chmod +x "$HOOKS_DEST/commit-msg"
  echo "  installed: .githooks/commit-msg"
  # Force LF on everything under .githooks so a clone/checkout under
  # autocrlf=true can't rewrite the hook to CRLF (which breaks it under sh).
  # Ensure the rule exists without clobbering an existing .gitattributes.
  GA="$TARGET_ROOT/.gitattributes"
  GA_RULE=".githooks/** text eol=lf"
  if [ ! -f "$GA" ]; then
    printf '%s\n' "$GA_RULE" > "$GA"
    echo "  created: .gitattributes ($GA_RULE)"
  elif ! grep -qF "$GA_RULE" "$GA"; then
    # Add a trailing newline first if the file doesn't end with one.
    [ -n "$(tail -c1 "$GA")" ] && printf '\n' >> "$GA"
    printf '%s\n' "$GA_RULE" >> "$GA"
    echo "  updated: .gitattributes (+ $GA_RULE)"
  else
    echo "  .gitattributes: LF rule already present"
  fi
  # Point git at .githooks — but only if the target is actually a git repo.
  if git -C "$TARGET_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$TARGET_ROOT" config core.hooksPath .githooks
    echo "  git: core.hooksPath = .githooks"
  else
    echo "  git: target is not a git repo — hook copied but not enabled."
    echo "       After 'git init', run: git config core.hooksPath .githooks"
  fi
fi

echo "Done."
