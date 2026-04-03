#!/usr/bin/env bash
set -euo pipefail

# ─── Rig Setup Script ────────────────────────────────────────────────
# Run this on a new machine to set up the full Rig pipeline.
# Prerequisites: gh CLI (authenticated), claude CLI, git
# ──────────────────────────────────────────────────────────────────────

RIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JOBS_DIR="$HOME/.claude/jobs"
RUNNER="$JOBS_DIR/_runner.sh"

echo "=== Rig Setup ==="
echo "RIG_DIR: $RIG_DIR"

# ─── Check prerequisites ─────────────────────────────────────────────
for cmd in gh claude git jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: $cmd is required but not installed." >&2
    exit 1
  fi
done

if ! gh auth status &>/dev/null; then
  echo "ERROR: gh CLI not authenticated. Run 'gh auth login' first." >&2
  exit 1
fi

echo "[1/6] Prerequisites OK"

# ─── Create GitHub repos if they don't exist ──────────────────────────
if ! gh repo view smwade/rig-inbox &>/dev/null; then
  gh repo create smwade/rig-inbox --public --description "Universal idea capture inbox for Rig autonomous AI pipeline"
  echo "  Created smwade/rig-inbox"
else
  echo "  smwade/rig-inbox already exists"
fi

# ─── Create labels on rig-inbox ───────────────────────────────────────
REPO="smwade/rig-inbox"
declare -A LABELS=(
  ["inbox"]="0E8A16:Raw capture, awaiting AI processing"
  ["processing"]="FBCA04:Currently being processed by AI"
  ["pending-review"]="1D76DB:AI processed, awaiting human review"
  ["approved"]="0E8A16:Human approved, ready for execution"
  ["in-progress"]="FBCA04:Currently being executed"
  ["done"]="5319E7:Completed"
  ["failed"]="D93F0B:Execution failed"
  ["needs-info"]="D93F0B:AI needs clarification from human"
  ["quick-task"]="C5DEF5:Single session, one PR"
  ["project"]="C5DEF5:Multi-step, needs decomposition"
  ["enhancement"]="C5DEF5:Improvement to existing project"
  ["bug"]="C5DEF5:Bug fix"
  ["question"]="C5DEF5:Research question"
  ["note"]="C5DEF5:Non-actionable thought"
  ["new-idea"]="BFD4F2:Standalone new idea"
  ["routed"]="BFD4F2:Routed to a specific project repo"
  ["p0-urgent"]="B60205:Do immediately"
  ["p1-normal"]="FBCA04:Normal priority"
  ["p2-someday"]="D4C5F9:Nice to have, no rush"
)

for label in "${!LABELS[@]}"; do
  IFS=':' read -r color desc <<< "${LABELS[$label]}"
  gh label create "$label" -R "$REPO" --color "$color" --description "$desc" --force 2>/dev/null || true
done
echo "[2/6] Labels configured"

# ─── Create local state directories ──────────────────────────────────
mkdir -p "$RIG_DIR/state/dispatch"
mkdir -p "$RIG_DIR/logs/executions"
mkdir -p "$RIG_DIR/logs/reflections"
mkdir -p "$RIG_DIR/prompts"
echo "[3/6] Local directories created"

# ─── Install cron jobs ────────────────────────────────────────────────
JOBS=(inbox-processor queue-dispatcher task-executor rig-babysit-prs rig-dashboard rig-reflection)

for job in "${JOBS[@]}"; do
  JOB_DIR="$JOBS_DIR/$job"
  if [[ ! -d "$JOB_DIR" ]]; then
    echo "  WARNING: Job directory missing: $JOB_DIR — skipping"
    continue
  fi
done

# Build new cron entries
RIG_CRON=$(cat << 'CRON'
# claude-job:inbox-processor
0,30 * * * * /Users/seanwade/.claude/jobs/_runner.sh inbox-processor
# claude-job:queue-dispatcher
5,20,35,50 * * * * /Users/seanwade/.claude/jobs/_runner.sh queue-dispatcher
# claude-job:task-executor
10,25,40,55 * * * * /Users/seanwade/.claude/jobs/_runner.sh task-executor
# claude-job:rig-babysit-prs
0,30 * * * * /Users/seanwade/.claude/jobs/_runner.sh rig-babysit-prs
# claude-job:rig-dashboard
0 8,18 * * * /Users/seanwade/.claude/jobs/_runner.sh rig-dashboard
# claude-job:rig-reflection
0 20 * * 0 /Users/seanwade/.claude/jobs/_runner.sh rig-reflection
CRON
)

# Merge with existing crontab (remove old rig entries first)
EXISTING=$(crontab -l 2>/dev/null | grep -v "inbox-processor\|queue-dispatcher\|task-executor\|rig-babysit-prs\|rig-dashboard\|rig-reflection" || true)
echo "$EXISTING
$RIG_CRON" | crontab -

echo "[4/6] Cron jobs installed"

# ─── Source rig.sh from shell rc ──────────────────────────────────────
SHELL_RC="$HOME/.zshrc"
SOURCE_LINE="source $RIG_DIR/scripts/rig.sh"

if ! grep -qF "rig.sh" "$SHELL_RC" 2>/dev/null; then
  echo "" >> "$SHELL_RC"
  echo "$SOURCE_LINE" >> "$SHELL_RC"
  echo "[5/6] Added rig.sh source to $SHELL_RC"
else
  echo "[5/6] rig.sh already sourced in $SHELL_RC"
fi

# ─── Build projects registry ─────────────────────────────────────────
PROJECTS_FILE="$RIG_DIR/state/projects.json"
if [[ ! -f "$PROJECTS_FILE" ]]; then
  echo "{}" > "$PROJECTS_FILE"
  echo "[6/6] Created empty projects.json — run 'rig-scan-projects' to populate"
else
  echo "[6/6] projects.json already exists"
fi

echo ""
echo "=== Rig Setup Complete ==="
echo ""
echo "Quick start:"
echo "  source $SHELL_RC"
echo "  rig \"your first idea\""
echo "  rig-status"
echo ""
echo "The pipeline will start processing on the next cron cycle (every 30 min)."
echo "Or run manually: rig-run inbox-processor"
