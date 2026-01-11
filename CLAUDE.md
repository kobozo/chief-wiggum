# Chief Wiggum - Claude Code Instructions

## Overview

Chief Wiggum is an autonomous AI agent orchestrator that uses Claude Code with the `/ralph-loop:ralph-loop` skill to execute user stories from a PRD. It implements a two-tier architecture:

1. **Chief Wiggum (Outer Loop)**: Orchestrates story execution, tracks progress, manages state
2. **Ralph Loop (Inner Loop)**: Executes each individual story with iteration support

## Architecture

```
chief-wiggum.sh (Outer Orchestrator)
    |
    +-- Reads prd.json for stories
    +-- Picks highest priority story where passes: false
    +-- Generates prompt from story-prompt.template.md
    +-- Spawns: claude --dangerously-skip-permissions --print "/ralph-loop:ralph-loop \"<prompt>\" --max-iterations 25 --completion-promise STORY_COMPLETE"
    |
    +-- Detects STORY_COMPLETE or BLOCKED promises
    +-- Updates prd.json (marks passes: true)
    +-- Archives previous runs when branch changes
    +-- Repeats until all stories complete
```

## Key Files

| File | Purpose |
|------|---------|
| `chief-wiggum.sh` | Main orchestrator script |
| `chief-wiggum.config.json` | Configuration (iterations, promises, quality checks) |
| `story-prompt.template.md` | Template for story execution prompts |
| `prd.json` | User stories with `passes` status |
| `progress.txt` | Append-only learnings log |
| `skills/` | Claude Code skills for PRD generation and conversion |

## Running Chief Wiggum

```bash
# Execute all stories (default)
./chief-wiggum.sh

# Limit to N stories
./chief-wiggum.sh 5
```

## Configuration

Edit `chief-wiggum.config.json`:

```json
{
  "maxIterationsPerStory": 25,
  "completionPromise": "STORY_COMPLETE",
  "blockedPromise": "BLOCKED",
  "qualityChecks": [
    {"name": "typecheck", "command": "npm run typecheck"},
    {"name": "lint", "command": "npm run lint"},
    {"name": "test", "command": "npm run test"}
  ]
}
```

## Story Lifecycle

1. Chief Wiggum reads `prd.json`
2. Picks highest priority story where `passes: false`
3. Renders `story-prompt.template.md` with story data
4. Executes Claude with `/ralph-loop:ralph-loop`
5. On `STORY_COMPLETE`: marks story as passed, continues
6. On `BLOCKED`: stops and logs blocker
7. On timeout: logs and continues to next story

## Promise System

- `<promise>STORY_COMPLETE</promise>`: Story implemented and verified
- `<promise>BLOCKED</promise>`: Cannot proceed, needs human intervention

## Quality Requirements

- All commits must pass configured quality checks
- Never commit broken code
- Keep changes focused and minimal
- Follow existing code patterns

## Memory and Context

Each Claude Code invocation is fresh. Memory persists via:
- Git history (commits from previous stories)
- `progress.txt` (learnings and patterns)
- `prd.json` (story completion status)
- `CLAUDE.md` files (codebase patterns)

## Skills

### PRD Skill (`/prd`)
Generates detailed Product Requirements Documents from feature descriptions.

### Ralph Skill (`/ralph`)
Converts PRD markdown files to `prd.json` format for Chief Wiggum execution.

## Best Practices

1. **Small Stories**: Each story should complete in one context window
2. **Clear Criteria**: Acceptance criteria must be verifiable
3. **Dependency Order**: Schema -> Backend -> UI
4. **Update CLAUDE.md**: Record reusable patterns
5. **Browser Testing**: UI stories must include browser verification
