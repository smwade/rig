# Rig

Autonomous AI development pipeline. Capture ideas with minimal friction, AI processes and routes them, human approves, work executes autonomously.

## Architecture

```
CAPTURE → PROCESS + ROUTE → REVIEW → EXECUTE → DELIVER → REFLECT
```

- **Capture**: `rig` CLI, Apple Shortcuts (voice/text)
- **Inbox**: GitHub Issues on [smwade/rig-inbox](https://github.com/smwade/rig-inbox)
- **Processing**: Cron job classifies and routes ideas to the right project
- **Execution**: Autonomous Claude Code sessions in git worktrees
- **Delivery**: PRs created on project repos, monitored by babysit-prs
- **Reflection**: Weekly analysis of outcomes, self-improving prompts

## Quick Start

```bash
# Capture an idea
rig "add dark mode to davywade.com"

# Check status
rig-status

# Ideas appear as GitHub issues → AI processes → you approve → PR appears
```

## Cron Jobs

| Job | Schedule | Purpose |
|-----|----------|---------|
| inbox-processor | Every 30 min | Process raw captures, route to projects |
| queue-dispatcher | Every 15 min | Pick up approved issues, create dispatch files |
| task-executor | Every 15 min | Execute tasks in worktrees, create PRs |
| babysit-prs | Every 30 min | Monitor PRs, fix CI, address reviews |
| rig-dashboard | 8am + 6pm | Update status dashboard |
| rig-reflection | Sunday 8pm | Weekly analysis and improvement |
