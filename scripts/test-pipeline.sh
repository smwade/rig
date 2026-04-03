#!/usr/bin/env bash
# test-pipeline.sh — Smoke test to verify the Rig pipeline is wired up correctly.
# Checks each stage of the pipeline can be reached, then cleans up.
set -euo pipefail

PASS=0
FAIL=0

ok()   { echo "  [PASS] $*"; ((PASS++)); }
fail() { echo "  [FAIL] $*"; ((FAIL++)); }

echo "=== Rig pipeline smoke test ==="
echo

# ── 1. gh CLI available ──────────────────────────────────────────────────────
echo "Stage 1: gh CLI"
if command -v gh &>/dev/null; then
  ok "gh found: $(gh --version | head -1)"
else
  fail "gh CLI not found — install from https://cli.github.com"
fi

# ── 2. gh auth ───────────────────────────────────────────────────────────────
echo "Stage 2: GitHub auth"
if gh auth status &>/dev/null; then
  ok "authenticated as $(gh api user --jq .login 2>/dev/null || echo '<user>')"
else
  fail "not authenticated — run: gh auth login"
fi

# ── 3. rig-inbox repo accessible ─────────────────────────────────────────────
echo "Stage 3: rig-inbox repo"
if gh repo view smwade/rig-inbox --json name --jq .name &>/dev/null; then
  ok "smwade/rig-inbox is accessible"
else
  fail "cannot access smwade/rig-inbox — check permissions"
fi

# ── 4. rig repo accessible ───────────────────────────────────────────────────
echo "Stage 4: rig repo"
if gh repo view smwade/rig --json name --jq .name &>/dev/null; then
  ok "smwade/rig is accessible"
else
  fail "cannot access smwade/rig — check permissions"
fi

# ── 5. State directory structure ─────────────────────────────────────────────
echo "Stage 5: state directories"
RIG_DIR="$(cd "$(dirname "$0")/.." && pwd)"
for dir in state state/dispatch logs logs/executions; do
  if [[ -d "$RIG_DIR/$dir" ]]; then
    ok "$dir/ exists"
  else
    mkdir -p "$RIG_DIR/$dir"
    ok "$dir/ created"
  fi
done

# ── 6. Capture stage (hello-world issue) ─────────────────────────────────────
echo "Stage 6: capture — create test issue on rig-inbox"
ISSUE_URL=$(gh issue create \
  --repo smwade/rig-inbox \
  --title "[test] hello-world pipeline smoke test" \
  --body "Automated smoke test from scripts/test-pipeline.sh — safe to close." \
  --label inbox 2>/dev/null) || true
if [[ -n "$ISSUE_URL" ]]; then
  ok "test issue created: $ISSUE_URL"
  ISSUE_NUMBER=$(echo "$ISSUE_URL" | grep -oE '[0-9]+$')
else
  fail "could not create test issue on rig-inbox"
  ISSUE_NUMBER=""
fi

# ── 7. Label state machine ───────────────────────────────────────────────────
echo "Stage 7: label state machine"
if [[ -n "$ISSUE_NUMBER" ]]; then
  if gh issue edit "$ISSUE_NUMBER" \
       --repo smwade/rig-inbox \
       --remove-label inbox \
       --add-label pending-review &>/dev/null; then
    ok "transitioned inbox → pending-review"
  else
    fail "label transition failed"
  fi
else
  fail "skipped (no test issue)"
fi

# ── 8. Clean up test issue ───────────────────────────────────────────────────
echo "Stage 8: cleanup"
if [[ -n "$ISSUE_NUMBER" ]]; then
  if gh issue close "$ISSUE_NUMBER" \
       --repo smwade/rig-inbox \
       --comment "Smoke test complete — closing." &>/dev/null; then
    ok "test issue #$ISSUE_NUMBER closed"
  else
    fail "could not close test issue"
  fi
else
  ok "nothing to clean up"
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo
echo "=== Results: $PASS passed, $FAIL failed ==="
if [[ $FAIL -gt 0 ]]; then
  echo "Pipeline has issues — review failures above."
  exit 1
else
  echo "Pipeline looks healthy."
  exit 0
fi
