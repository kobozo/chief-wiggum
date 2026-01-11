# Chief Wiggum - Claude Code Plugin

## Overview

Chief Wiggum is an autonomous PRD executor plugin for Claude Code. It uses the `/ralph-loop` skill to execute user stories from a PRD with iterative completion support. Two-tier architecture:

1. **Chief Wiggum (Outer Loop)**: Orchestrates story execution, tracks progress, manages state
2. **Inner Loop**: Each story executes via `/ralph-loop` with iteration support

## Installation

```bash
# First, install the required ralph-loop plugin (Claude Code default plugin)
claude plugins install ralph-loop

# Then install chief-wiggum
claude plugins install github:kobozo/chief-wiggum

# Or clone manually
git clone https://github.com/kobozo/chief-wiggum ~/.claude/plugins/chief-wiggum
```

## Architecture

```
/chief-wiggum (or chief-wiggum.sh)
    |
    +-- Reads prd.json from current directory
    +-- Picks highest priority story where passes: false
    +-- Generates prompt from story-prompt.template.md
    +-- Spawns: claude --dangerously-skip-permissions --print "/ralph-loop \"<prompt>\" --max-iterations 25 --completion-promise STORY_COMPLETE"
    |
    +-- Detects STORY_COMPLETE or BLOCKED promises
    +-- Updates prd.json (marks passes: true)
    +-- Archives previous runs when branch changes
    +-- Repeats until all stories complete
```

## Plugin Structure

| File | Purpose |
|------|---------|
| `plugin.json` | Plugin manifest |
| `chief-wiggum.sh` | Main orchestrator script |
| `chief-wiggum.config.json` | Configuration (iterations, promises, quality checks) |
| `story-prompt.template.md` | Template for story execution prompts |
| `skills/prd/` | Skill for generating PRDs |
| `skills/chief-wiggum/` | Skill for converting PRDs to prd.json |
| `hooks/stop-hook.sh` | Optional stop hook |

## User Project Files

These files live in your project directory (not the plugin):

| File | Purpose |
|------|---------|
| `prd.json` | User stories with `passes` status |
| `progress.txt` | Append-only learnings log |
| `archive/` | Previous run archives |

## Usage

```bash
# Via plugin command
/chief-wiggum

# Or directly
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
4. Executes Claude with `/ralph-loop`
5. On `STORY_COMPLETE`: marks story as passed, continues
6. On `BLOCKED`: stops and logs blocker
7. On timeout: logs and continues to next story

## Promise System

- `<promise>STORY_COMPLETE</promise>`: Story implemented and verified (stops loop immediately)
- `<promise>BLOCKED</promise>`: Cannot proceed, needs human intervention

**Note:** The `/ralph-loop` plugin only detects `STORY_COMPLETE` as the completion promise. If Claude outputs `BLOCKED`, the loop continues until `max-iterations`, then Chief Wiggum detects the blocked status.

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

### Chief Wiggum Skill (`/chief-wiggum`)
Converts PRD markdown files to `prd.json` format for Chief Wiggum execution.

## Best Practices

1. **Small Stories**: Each story should complete in one context window
2. **Clear Criteria**: Acceptance criteria must be verifiable
3. **Dependency Order**: Schema -> Backend -> UI
4. **Update CLAUDE.md**: Record reusable patterns
5. **Browser Testing**: UI stories must include browser verification
