#!/usr/bin/env bash
# ─── Rig: Autonomous AI Development Pipeline ────────────────────────
# Source this file from your shell rc: source ~/projects/rig2/scripts/rig.sh

RIG_DIR="${RIG_DIR:-$HOME/projects/rig2}"
RIG_INBOX_REPO="smwade/rig-inbox"

# Capture an idea → GitHub issue on rig-inbox
rig() {
  if [[ $# -gt 0 ]]; then
    gh issue create -R "$RIG_INBOX_REPO" \
      --title "$*" \
      --body "$(printf 'source: mac-cli\ncaptured: %s' "$(date -Iseconds)")" \
      --label inbox
  else
    local TMPFILE=$(mktemp /tmp/rig-XXXXXX.md)
    ${EDITOR:-vim} "$TMPFILE"
    if [[ -s "$TMPFILE" ]]; then
      local TITLE=$(head -1 "$TMPFILE")
      local BODY=$(tail -n +2 "$TMPFILE")
      gh issue create -R "$RIG_INBOX_REPO" \
        --title "$TITLE" \
        --body "$(printf 'source: mac-cli\ncaptured: %s\n\n%s' "$(date -Iseconds)" "$BODY")" \
        --label inbox
    fi
    rm -f "$TMPFILE"
  fi
}

# Quick status overview
rig-status() {
  echo "=== Rig Inbox ==="
  gh issue list -R "$RIG_INBOX_REPO" --label inbox -L 5
  echo ""
  echo "=== Pending Review ==="
  gh issue list -R "$RIG_INBOX_REPO" --label pending-review -L 10
  echo ""
  echo "=== In Progress ==="
  gh issue list -R "$RIG_INBOX_REPO" --label in-progress -L 5
  echo ""
  echo "=== Open Rig PRs ==="
  gh search prs --author @me --state open --json repository,number,title \
    --template '{{range .}}  {{.repository.nameWithOwner}}#{{.number}} {{.title}}{{"\n"}}{{end}}' 2>/dev/null \
    | head -10 || echo "  None"
}

# Show the review queue with full details
rig-review() {
  local issues
  issues=$(gh issue list -R "$RIG_INBOX_REPO" --label pending-review --json number,title,body -L 10)
  local count=$(echo "$issues" | jq length)
  echo "=== $count items pending review ==="
  echo "$issues" | jq -r '.[] | "\n--- #\(.number): \(.title) ---\n\(.body | split("\n")[0:10] | join("\n"))\n..."'
}

# Approve an issue by number (on rig-inbox or a project repo)
rig-approve() {
  local num="${1:?Usage: rig-approve <issue-number> [repo]}"
  local repo="${2:-$RIG_INBOX_REPO}"
  gh issue edit "$num" -R "$repo" --add-label approved --remove-label pending-review
  echo "Approved #$num on $repo"
}

# Show recent execution logs
rig-log() {
  local log_dir="$RIG_DIR/logs/executions"
  if [[ -d "$log_dir" ]] && ls "$log_dir"/*.json &>/dev/null; then
    for f in $(ls -t "$log_dir"/*.json | head -5); do
      jq -r '"\(.repo)#\(.issue_number) — \(.outcome) — PR: \(.pr_url // "n/a")"' "$f"
    done
  else
    echo "No execution logs yet."
  fi
}

# Run a specific rig job manually
rig-run() {
  local job="${1:?Usage: rig-run <job-name>}"
  bash ~/.claude/jobs/_runner.sh "$job"
}
