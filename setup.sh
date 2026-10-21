#!/bin/bash
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Args ────────────────────────────────────────────────────────────────────

if [ -z "$1" ]; then
  echo "Usage: ./setup.sh <path-to-workspace>"
  echo "Example: ./setup.sh ~/Projects/my-app"
  exit 1
fi

WORKSPACE="${1/#\~/$HOME}"

if [ ! -d "$WORKSPACE" ]; then
  echo "❌ Error: workspace directory '$WORKSPACE' does not exist."
  exit 1
fi

# ─── Claude context ──────────────────────────────────────────────────────────

WORKSPACE="$(cd "$WORKSPACE" && pwd)"

if [ "$(cd "$WORKSPACE" && pwd -P)" = "$(cd "$REPO_DIR" && pwd -P)" ]; then
  echo "❌ Error: the workspace must not be this context repository itself."
  exit 1
fi

# Link context entries into the workspace without ever overwriting or nesting into existing files.
# All targets are checked before anything is linked, so a failure never leaves a half-linked workspace.
CONTEXT_ENTRIES=("CLAUDE.md" ".claude")

for entry in "${CONTEXT_ENTRIES[@]}"; do
  target="$WORKSPACE/$entry"
  if [ -L "$target" ] && [ "$(readlink "$target")" = "$REPO_DIR/$entry" ]; then
    continue
  elif [ -e "$target" ] || [ -L "$target" ]; then
    echo "❌ Error: '$target' already exists. Nothing was linked."
    echo "   Move or back it up, then re-run: mv \"$target\" \"$target.bak\""
    exit 1
  fi
done

for entry in "${CONTEXT_ENTRIES[@]}"; do
  target="$WORKSPACE/$entry"
  if [ -L "$target" ]; then
    echo "⏭️  $entry already linked — skipped"
  else
    ln -s "$REPO_DIR/$entry" "$target"
    echo "🔗 $entry linked"
  fi
done

echo "🔗 Claude context linked to $WORKSPACE"

# Warn (never edit) while organisation-wide Project Settings in CLAUDE.md still use placeholders
UNSET_SETTINGS=$(sed -n '/<!-- project-settings:start -->/,/<!-- project-settings:end -->/p' "$REPO_DIR/CLAUDE.md" \
  | grep '_not set_' | sed -E 's/^\| `([^`]+)`.*/\1/' || true)
if [ -n "$UNSET_SETTINGS" ]; then
  echo ""
  echo "⚠️  $(echo "$UNSET_SETTINGS" | wc -l | tr -d ' ') Project Settings are not set yet: $(echo "$UNSET_SETTINGS" | tr '\n' ' ')"
  echo "   Edit the Project Settings table in $REPO_DIR/CLAUDE.md (once per organisation)."
  echo "   Until then, Claude will ask you for these values when it needs them."
fi

# ─── code-review-graph ───────────────────────────────────────────────────────

echo ""
echo "🔧 Setting up code-review-graph..."

# Require Python 3.10+
if ! command -v python3 &>/dev/null; then
  echo "❌ Error: python3 is required but not found. Install Python 3.10+ and retry."
  exit 1
fi

PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
PYTHON_MAJOR=$(echo "$PYTHON_VERSION" | cut -d. -f1)
PYTHON_MINOR=$(echo "$PYTHON_VERSION" | cut -d. -f2)

if [ "$PYTHON_MAJOR" -lt 3 ] || { [ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 10 ]; }; then
  echo "❌ Error: Python 3.10+ is required (found $PYTHON_VERSION)."
  exit 1
fi

# Install via uv tool, pipx, or brew-installed pipx — never raw pip3 (breaks on macOS managed Python)
if command -v uv &>/dev/null; then
  echo "📦 Installing code-review-graph via uv tool..."
  uv tool install code-review-graph --quiet
elif command -v pipx &>/dev/null; then
  echo "📦 Installing code-review-graph via pipx..."
  pipx install code-review-graph --quiet
elif command -v brew &>/dev/null; then
  echo "📦 pipx not found — installing via Homebrew..."
  brew install pipx --quiet
  pipx ensurepath --quiet
  echo "📦 Installing code-review-graph via pipx..."
  pipx install code-review-graph --quiet
else
  echo "❌ Error: no supported installer found (uv, pipx, or Homebrew required)."
  echo "   Install one of the following and retry:"
  echo "     brew install pipx   (recommended)"
  echo "     brew install uv"
  exit 1
fi

echo "✅ code-review-graph installed"

# Register the MCP server with Claude Code (auto-detected)
echo "🤖 Configuring MCP integration with Claude Code..."
code-review-graph install --platform claude-code
echo "✅ MCP server registered with Claude Code"

# Write .code-review-graphignore in the workspace (idempotent)
IGNORE_FILE="$WORKSPACE/.code-review-graphignore"
if [ ! -f "$IGNORE_FILE" ]; then
  cat > "$IGNORE_FILE" <<'EOF'
# Build outputs
build/**
dist/**
target/**
out/**

# Dependencies
node_modules/**
.gradle/**
.venv/**
__pycache__/**

# Logs and fixtures
*.log
**/__fixtures__/**
**/testdata/**

# Generated code
**/*.generated.*
generated/**
EOF
  echo "✅ .code-review-graphignore created"
else
  echo "⏭️  .code-review-graphignore already exists — skipped"
fi

# Add .code-review-graph/ to .gitignore in the workspace (idempotent)
GITIGNORE_FILE="$WORKSPACE/.gitignore"
if ! grep -q ".code-review-graph" "$GITIGNORE_FILE" 2>/dev/null; then
  echo "" >> "$GITIGNORE_FILE"
  echo "# code-review-graph (local SQLite index — do not commit)" >> "$GITIGNORE_FILE"
  echo ".code-review-graph/" >> "$GITIGNORE_FILE"
  echo "✅ .code-review-graph/ added to .gitignore"
else
  echo "⏭️  .code-review-graph/ already in .gitignore — skipped"
fi

# Build the graph for the workspace
echo "🔍 Building code graph for $WORKSPACE (this may take ~10s for large projects)..."
(cd "$WORKSPACE" && code-review-graph build)
echo "✅ Code graph built"

# ─── Done ────────────────────────────────────────────────────────────────────

echo ""
echo "🎉 Setup complete."
echo ""
echo "  📁 Workspace : $WORKSPACE"
echo "  🔌 MCP server: code-review-graph (registered with Claude Code)"
echo ""
echo "💡 To keep the graph current after large changes:"
echo "   cd $WORKSPACE && code-review-graph update"
