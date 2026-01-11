---
name: chief-wiggum
description: "Execute all user stories from prd.json autonomously"
argument-hint: "[max_stories]"
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

Use the Bash tool to run whichever path exists. Pass any arguments (like max_stories) to the script.

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

1. Reads `prd.json` from current directory
2. Finds highest priority story where `passes: false`
3. Executes iterative loop (Ralph technique) for that story
4. On `STORY_COMPLETE`: marks story as passed, continues to next
5. On `BLOCKED` or timeout: stops and logs the issue
6. Repeats until all stories complete or stopped

## Prerequisites

- `prd.json` must exist in current directory
- `jq` must be installed
- Project should have quality checks configured

## Usage

```bash
/chief-wiggum           # Process all stories
/chief-wiggum 5         # Process max 5 stories
```
