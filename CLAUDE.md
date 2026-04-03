# Rig - Autonomous AI Pipeline

This is the Rig system -- an autonomous AI development pipeline.

## Key Repos
- `smwade/rig-inbox` -- idea capture (GitHub Issues as inbox)
- `smwade/rig` -- this repo (system code, prompts, scripts)

## How It Works
1. Ideas captured via `rig` CLI or Apple Shortcuts → GitHub issue on rig-inbox with `inbox` label
2. inbox-processor job routes to existing project repos or keeps as new idea
3. Human approves by adding `approved` label on GitHub
4. task-executor picks up, creates worktree, writes code, opens PR
5. babysit-prs monitors PR lifecycle

## Important Paths
- Prompts: `./prompts/` (version controlled)
- State: `./state/` (gitignored, runtime data)
- Dispatch queue: `./state/dispatch/` (JSON files for approved tasks)
- Projects registry: `./state/projects.json`
- Execution logs: `./logs/executions/`

## Conventions
- All cron jobs exit immediately when there's no work (save rate limits)
- Use `gh` CLI for all GitHub operations
- Worktrees named `rig-{issue-number}` with branch `rig/issue-{number}`
- Labels drive the state machine: inbox → pending-review → approved → in-progress → done
