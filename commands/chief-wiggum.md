---
name: chief-wiggum
description: "Execute all user stories from prd.json autonomously"
argument-hint: "[max_stories] [--branch <name>] [--start-branch <base>] [--file <prd.json>]"
---

# Chief Wiggum - Autonomous PRD Executor

Execute the Chief Wiggum orchestrator to process user stories from `prd.json`.

## Execution

Find and run the `chief-wiggum.sh` script. Search in this order:

1. **If `$CLAUDE_PLUGIN_ROOT` is set:** `$CLAUDE_PLUGIN_ROOT/chief-wiggum.sh`

2. **Marketplace installation:** Find in cache directory:
   ```bash
   find ~/.claude/plugins/cache -name "chief-wiggum.sh" -type f 2>/dev/null | head -1
   ```

3. **Manual installation:** `~/.claude/plugins/chief-wiggum/chief-wiggum.sh`

Use the Bash tool to run whichever path exists. Pass any arguments to the script.

**Example command to find and run:**
```bash
SCRIPT=$(find ~/.claude/plugins/cache -name "chief-wiggum.sh" -type f 2>/dev/null | head -1)
if [ -n "$SCRIPT" ]; then
  bash "$SCRIPT" $ARGUMENTS
else
  echo "chief-wiggum.sh not found. Is the plugin installed?"
  exit 1
fi
```

## What happens:

1. Creates/checks out feature branch (auto-generated or custom)
2. Reads PRD file (default: `.chief-wiggum/prd.json`)
3. Finds highest priority story where `passes: false`
4. Executes iterative loop (Ralph technique) for that story
5. On `STORY_COMPLETE`: runs code review, marks story as passed, continues to next
6. On `BLOCKED` or timeout: stops and logs the issue
7. Repeats until all stories complete or stopped

## Prerequisites

- PRD file must exist (default: `.chief-wiggum/prd.json`)
- `jq` must be installed
- Project should have quality checks configured

## Options

| Option | Description |
|--------|-------------|
| `[max_stories]` | Maximum number of stories to process (default: all) |
| `--branch <name>` | Use custom branch name instead of auto-generated |
| `--start-branch <base>` | Create feature branch from specified base branch |
| `--file <path>` | Use custom PRD file instead of `prd.json` |

## Usage

```bash
/chief-wiggum                              # Process all stories from .chief-wiggum/prd.json
/chief-wiggum 5                            # Process max 5 stories
/chief-wiggum --branch feature/auth        # Use custom branch name
/chief-wiggum --start-branch main          # Create branch from main
/chief-wiggum --file custom.json           # Use custom PRD file
/chief-wiggum 5 --file stories.json --branch feat/x --start-branch main
```
