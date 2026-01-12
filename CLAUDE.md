# Chief Wiggum - Claude Code Plugin

## Overview

Chief Wiggum is an autonomous PRD executor plugin for Claude Code. It uses the `/ralph-loop` skill to execute user stories from a PRD with iterative completion support. Two-tier architecture:

1. **Chief Wiggum (Outer Loop)**: Orchestrates story execution, tracks progress, manages state
2. **Inner Loop (/ralph-loop)**: Each story executes via `/ralph-loop` with iteration support

## Installation

```bash
# First, install the required ralph-loop plugin
claude plugins install ralph-loop

# Then install chief-wiggum
claude plugins install github:kobozo/chief-wiggum

# Or clone manually
git clone https://github.com/kobozo/chief-wiggum ~/.claude/plugins/chief-wiggum
```

## Architecture

```
/chief-wiggum
    │
    ├── 1. BRANCH: Create/checkout feature branch
    │      └── chief-wiggum/<project-name> or --branch <custom>
    │
    ├── Executes chief-wiggum.sh
    │
    └── For each story in prd.json:
        ├── 1. TRACK: Save current git commit
        ├── 2. EXECUTE: Iterative Claude loop until STORY_COMPLETE
        │       └── Story commits: feat: <STORY_ID> - <STORY_TITLE>
        ├── 3. REVIEW: Code review phase (up to 3 cycles)
        │       ├── Capture git diff
        │       ├── Run code-reviewer agent
        │       ├── If APPROVED → mark complete
        │       └── If NEEDS_CHANGES → fix iteration (fix: <STORY_ID>), re-review
        ├── 4. UPDATE: prd.json (passes: true)
        ├── Archives previous runs when branch changes
        └── Continues to next story
```

## Plugin Structure

```
chief-wiggum/
├── .claude-plugin/
│   └── plugin.json              # Plugin manifest
├── commands/
│   └── chief-wiggum.md          # /chief-wiggum command → executes chief-wiggum.sh
├── agents/
│   ├── story-executor.md        # Optional agent for story execution
│   └── code-reviewer.md         # Code review agent for post-story review
├── skills/
│   ├── prd/
│   │   └── SKILL.md             # PRD generation skill
│   └── chief-wiggum/
│       └── SKILL.md             # PRD-to-JSON converter skill
├── hooks/
│   ├── hooks.json               # Hook configuration
│   └── stop-hook.sh             # Stop event handler
├── chief-wiggum.sh              # Main orchestrator script
├── chief-wiggum.config.json     # Configuration
├── story-prompt.template.md     # Prompt template for stories
├── review-prompt.template.md    # Prompt template for code reviews
└── review-fix-prompt.template.md # Prompt template for fix iterations
```

## User Project Files

These files live in your project's `.chief-wiggum/` directory (easy to .gitignore):

| File | Purpose |
|------|---------|
| `.chief-wiggum/prd.json` | User stories with `passes` status |
| `.chief-wiggum/progress.txt` | Append-only learnings log |
| `.chief-wiggum/archive/` | Previous run archives |
| `.chief-wiggum/last-branch` | Tracks last used branch |

Add to your `.gitignore`:
```
.chief-wiggum/
```

## Usage

```bash
# Execute all stories (creates branch from PRD project name)
/chief-wiggum

# Limit to N stories
/chief-wiggum 5

# Use a custom branch name
/chief-wiggum --branch feature/my-feature

# Create branch from a specific base branch (not the current one)
/chief-wiggum --start-branch main

# Use a custom PRD file instead of prd.json
/chief-wiggum --file my-feature.json

# Combine options
/chief-wiggum 5 --branch feature/my-feature --start-branch main --file stories.json
```

## Command Options

| Option | Description |
|--------|-------------|
| `[max_stories]` | Maximum number of stories to process (default: all) |
| `--branch <name>` | Use a custom branch name instead of auto-generated |
| `--start-branch <base>` | Create the feature branch from a specific base branch |
| `--file <path>` | Use a custom PRD file instead of `prd.json` |

## Branch Management

Chief Wiggum automatically creates a feature branch for PRD execution:

- **Default**: Creates `chief-wiggum/<project-name>` from current branch
- **Custom branch**: Use `--branch <name>` to specify your own branch name
- **Base branch**: Use `--start-branch <base>` to branch from a specific branch

If the target branch already exists, Chief Wiggum checks it out instead of creating a new one.

The branch name is sanitized (lowercase, spaces to dashes, special chars removed) and stored in the PRD file as `branchName`.

### Examples

```bash
# PRD with project "My Cool Feature" creates: chief-wiggum/my-cool-feature
/chief-wiggum

# Explicit branch name
/chief-wiggum --branch feature/add-user-auth

# Start from main branch instead of current branch
/chief-wiggum --start-branch main

# Custom branch from main
/chief-wiggum --branch feature/auth --start-branch main

# Use a different PRD file
/chief-wiggum --file auth-stories.json --start-branch main
```

## Commands & Skills

| Command/Skill | Description |
|---------------|-------------|
| `/chief-wiggum` | Execute stories from prd.json (auto-creates branch) |
| `/chief-wiggum 5` | Execute max 5 stories |
| `/chief-wiggum --branch <name>` | Execute with custom branch name |
| `/chief-wiggum --start-branch <base>` | Create feature branch from specified base |
| `/chief-wiggum --file <path>` | Use custom PRD file |
| `/prd` | Generate a PRD document |
| `/prd-convert <input> [--file <output>]` | Convert PRD markdown to `.chief-wiggum/prd.json` |

## Configuration

Edit `chief-wiggum.config.json`:

```json
{
  "maxIterationsPerStory": 25,
  "completionPromise": "STORY_COMPLETE",
  "blockedPromise": "BLOCKED",
  "codeReview": {
    "enabled": true,
    "maxCycles": 3,
    "approvedSignal": "APPROVED",
    "needsChangesSignal": "NEEDS_CHANGES"
  },
  "qualityChecks": [
    {"name": "typecheck", "command": "npm run typecheck"},
    {"name": "lint", "command": "npm run lint"},
    {"name": "test", "command": "npm run test"}
  ]
}
```

### Code Review Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `enabled` | `true` | Enable/disable code review after each story |
| `maxCycles` | `3` | Maximum review-fix cycles before auto-approving |
| `approvedSignal` | `APPROVED` | Signal from reviewer indicating approval |
| `needsChangesSignal` | `NEEDS_CHANGES` | Signal indicating fixes needed |

## Story Lifecycle

1. `/chief-wiggum` executes `chief-wiggum.sh`
2. **Creates/checks out feature branch** (from current branch)
3. Script reads `.chief-wiggum/prd.json` from current directory
4. Picks highest priority story where `passes: false`
5. **Tracks start commit** for code review diff
6. Renders `story-prompt.template.md` with story data
7. Executes iterative Claude loop (Ralph technique)
8. On `STORY_COMPLETE`:
   - Story code is committed: `feat: <STORY_ID> - <STORY_TITLE>`
   - **Enters code review phase**
9. **Code Review Phase** (up to 3 cycles):
   - Captures git diff from start commit
   - Runs code-reviewer agent
   - If `APPROVED`: marks story complete
   - If `NEEDS_CHANGES`: runs fix iteration, commits: `fix: <STORY_ID> - address review feedback`, re-reviews
10. On `BLOCKED`: stops and logs blocker
11. On timeout: logs and stops execution

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
- `.chief-wiggum/progress.txt` (learnings and patterns)
- `.chief-wiggum/prd.json` (story completion status)
- `CLAUDE.md` files (codebase patterns)

## Skills

### PRD Skill (`/prd`)
Generates detailed Product Requirements Documents from feature descriptions.

### PRD Convert Command (`/prd-convert`)
Converts PRD markdown files to `prd.json` format for Chief Wiggum execution.

## Code Review

After each story completes (`STORY_COMPLETE`), Chief Wiggum automatically runs a code review:

### How It Works

1. **Diff Capture**: Git diff from the commit before story started to HEAD
2. **Review**: Code reviewer agent analyzes the diff against acceptance criteria
3. **Fix Cycle**: If issues found, runs a fix iteration and re-reviews
4. **Max Cycles**: After 3 review cycles, auto-approves to continue progress

### Review Focus

The code-reviewer agent checks:
- **Correctness**: All acceptance criteria implemented
- **Bugs**: Logic errors, edge cases, null risks
- **Patterns**: Code follows existing codebase patterns
- **Completeness**: Tests, types, error handling present

### Review Output Format

```
<review>
STATUS: APPROVED | NEEDS_CHANGES
COMMENTS:
- [Specific, actionable items if NEEDS_CHANGES]
</review>
```

### Disabling Code Review

Set `codeReview.enabled` to `false` in config to skip the review phase.

## Best Practices

1. **Small Stories**: Each story should complete in one context window
2. **Clear Criteria**: Acceptance criteria must be verifiable
3. **Dependency Order**: Schema -> Backend -> UI
4. **Update CLAUDE.md**: Record reusable patterns
5. **Browser Testing**: UI stories must include browser verification

## Credits

Forked from [snarktank/ralph](https://github.com/snarktank/ralph) - the original autonomous PRD executor for Claude Code.
