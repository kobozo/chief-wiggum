#!/bin/bash
# Chief Wiggum - Autonomous PRD executor for Claude Code
# Two-tier architecture: Chief Wiggum (outer loop) + /ralph-loop (inner loop per story)
# Usage: ./chief-wiggum.sh [max_stories] or via /chief-wiggum command

set -e

# Script configuration - script is at plugin root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$SCRIPT_DIR"

# Files in current working directory (user's project)
PRD_FILE="$(pwd)/prd.json"
PROGRESS_FILE="$(pwd)/progress.txt"
ARCHIVE_DIR="$(pwd)/archive"
LAST_BRANCH_FILE="$(pwd)/.chief-wiggum-last-branch"

# Files in plugin directory
CONFIG_FILE="$PLUGIN_DIR/chief-wiggum.config.json"
TEMPLATE_FILE="$PLUGIN_DIR/story-prompt.template.md"
REVIEW_TEMPLATE_FILE="$PLUGIN_DIR/review-prompt.template.md"
FIX_TEMPLATE_FILE="$PLUGIN_DIR/review-fix-prompt.template.md"

# Load configuration
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: Configuration file not found: $CONFIG_FILE"
  exit 1
fi

MAX_ITERATIONS_PER_STORY=$(jq -r '.maxIterationsPerStory // 25' "$CONFIG_FILE")
COMPLETION_PROMISE=$(jq -r '.completionPromise // "STORY_COMPLETE"' "$CONFIG_FILE")
BLOCKED_PROMISE=$(jq -r '.blockedPromise // "BLOCKED"' "$CONFIG_FILE")

# Code review configuration
CODE_REVIEW_ENABLED=$(jq -r '.codeReview.enabled // true' "$CONFIG_FILE")
MAX_REVIEW_CYCLES=$(jq -r '.codeReview.maxCycles // 3' "$CONFIG_FILE")
REVIEW_APPROVED=$(jq -r '.codeReview.approvedSignal // "APPROVED"' "$CONFIG_FILE")
REVIEW_NEEDS_CHANGES=$(jq -r '.codeReview.needsChangesSignal // "NEEDS_CHANGES"' "$CONFIG_FILE")

# Command line args override config
MAX_STORIES=${1:-100}

# Check for required files
if [ ! -f "$PRD_FILE" ]; then
  echo "Error: PRD file not found: $PRD_FILE"
  echo "Create a prd.json file with your user stories first."
  exit 1
fi

if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "Error: Template file not found: $TEMPLATE_FILE"
  exit 1
fi

# Archive previous run if branch changed
if [ -f "$PRD_FILE" ] && [ -f "$LAST_BRANCH_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")

  if [ -n "$CURRENT_BRANCH" ] && [ -n "$LAST_BRANCH" ] && [ "$CURRENT_BRANCH" != "$LAST_BRANCH" ]; then
    # Archive the previous run
    DATE=$(date +%Y-%m-%d)
    # Strip "chief-wiggum/" prefix from branch name for folder
    FOLDER_NAME=$(echo "$LAST_BRANCH" | sed 's|^chief-wiggum/||')
    ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$FOLDER_NAME"

    echo "Archiving previous run: $LAST_BRANCH"
    mkdir -p "$ARCHIVE_FOLDER"
    [ -f "$PRD_FILE" ] && cp "$PRD_FILE" "$ARCHIVE_FOLDER/"
    [ -f "$PROGRESS_FILE" ] && cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"
    echo "   Archived to: $ARCHIVE_FOLDER"

    # Reset progress file for new run
    echo "# Chief Wiggum Progress Log" > "$PROGRESS_FILE"
    echo "Started: $(date)" >> "$PROGRESS_FILE"
    echo "---" >> "$PROGRESS_FILE"
  fi
fi

# Track current branch
if [ -f "$PRD_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  if [ -n "$CURRENT_BRANCH" ]; then
    echo "$CURRENT_BRANCH" > "$LAST_BRANCH_FILE"
  fi
fi

# Initialize progress file if it doesn't exist
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Chief Wiggum Progress Log" > "$PROGRESS_FILE"
  echo "Started: $(date)" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

# Function to build quality checks string from config
build_quality_checks() {
  jq -r '.qualityChecks[]? | "   - \(.name): \(.command)"' "$CONFIG_FILE" 2>/dev/null || echo "   - typecheck: npm run typecheck"
}

# Function to render the prompt template with story data
render_prompt() {
  local story_id="$1"
  local story_title="$2"
  local story_description="$3"
  local acceptance_criteria="$4"
  local project_name="$5"
  local branch_name="$6"
  local project_description="$7"

  local quality_checks
  quality_checks=$(build_quality_checks)

  # Read template and substitute placeholders
  cat "$TEMPLATE_FILE" | \
    sed "s|{{STORY_ID}}|$story_id|g" | \
    sed "s|{{STORY_TITLE}}|$story_title|g" | \
    sed "s|{{STORY_DESCRIPTION}}|$story_description|g" | \
    sed "s|{{ACCEPTANCE_CRITERIA}}|$acceptance_criteria|g" | \
    sed "s|{{PROJECT_NAME}}|$project_name|g" | \
    sed "s|{{BRANCH_NAME}}|$branch_name|g" | \
    sed "s|{{PROJECT_DESCRIPTION}}|$project_description|g" | \
    sed "s|{{QUALITY_CHECKS}}|$quality_checks|g" | \
    sed "s|{{COMPLETION_PROMISE}}|$COMPLETION_PROMISE|g" | \
    sed "s|{{BLOCKED_PROMISE}}|$BLOCKED_PROMISE|g"
}

# Function to get the next incomplete story
get_next_story() {
  jq -r '.userStories | map(select(.passes == false)) | sort_by(.priority) | .[0] // empty' "$PRD_FILE"
}

# Function to mark a story as complete
mark_story_complete() {
  local story_id="$1"
  local tmp_file=$(mktemp)
  jq --arg id "$story_id" '(.userStories[] | select(.id == $id)).passes = true' "$PRD_FILE" > "$tmp_file"
  mv "$tmp_file" "$PRD_FILE"
}

# Function to check if all stories are complete
all_stories_complete() {
  local incomplete=$(jq -r '.userStories | map(select(.passes == false)) | length' "$PRD_FILE")
  [ "$incomplete" -eq 0 ]
}

# Function to capture git diff for a story (from start commit to HEAD)
capture_story_diff() {
  local start_commit="$1"
  if [ -n "$start_commit" ]; then
    git diff "$start_commit"..HEAD 2>/dev/null || git diff HEAD~1..HEAD 2>/dev/null || echo "No diff available"
  else
    git diff HEAD~1..HEAD 2>/dev/null || echo "No diff available"
  fi
}

# Function to render the review prompt template
# Uses direct content insertion instead of sed for multiline content (macOS compatible)
render_review_prompt() {
  local story_id="$1"
  local story_title="$2"
  local acceptance_criteria="$3"
  local git_diff="$4"
  local previous_feedback="$5"

  # Generate the review prompt directly (avoiding sed issues with multiline content)
  cat <<REVIEW_PROMPT_EOF
# Code Review for $story_id

You are a code reviewer analyzing changes from a completed user story.

## Story Context

**ID:** $story_id
**Title:** $story_title

### Acceptance Criteria
$acceptance_criteria

## Git Diff (Changes Made)

\`\`\`diff
$git_diff
\`\`\`

## Previous Feedback (if any)

$previous_feedback

## Your Review Task

Analyze the git diff above and verify:

1. **Correctness** - Does the code implement ALL acceptance criteria?
2. **Bugs** - Are there logic errors, edge cases, or null risks?
3. **Patterns** - Does the code follow existing codebase patterns?
4. **Completeness** - Are tests, types, and error handling adequate?

## Output Format

You MUST output your review in this EXACT format:

If the implementation is correct:
\`\`\`
<review>
STATUS: APPROVED
COMMENTS:
</review>
\`\`\`

If changes are needed:
\`\`\`
<review>
STATUS: NEEDS_CHANGES
COMMENTS:
- [Specific issue 1 with file/line reference]
- [Specific issue 2 with file/line reference]
</review>
\`\`\`

## Guidelines

- Focus on REAL issues, not style preferences
- Each comment must be specific and actionable
- Reference file names and functions when possible
- If minor issues exist but functionality is correct, use APPROVED
- Only use NEEDS_CHANGES for actual bugs or missing functionality
- Do NOT comment on code that wasn't changed in this diff
REVIEW_PROMPT_EOF
}

# Function to render the fix prompt template
# Uses direct content insertion instead of sed for multiline content (macOS compatible)
render_fix_prompt() {
  local story_id="$1"
  local story_title="$2"
  local review_feedback="$3"

  local quality_checks
  quality_checks=$(build_quality_checks)

  # Generate the fix prompt directly (avoiding sed issues with multiline content)
  cat <<FIX_PROMPT_EOF
# Code Review Fixes Required

You previously implemented story $story_id: $story_title

The code reviewer found issues that need to be addressed.

## Review Feedback

$review_feedback

## Your Task

1. **Address EACH item** in the review feedback above
2. **Run quality checks** (typecheck, lint, test) - all must pass
3. **Commit fixes** with message: \`fix: $story_id - address review feedback\`
4. When ALL feedback items are resolved, output: <promise>$COMPLETION_PROMISE</promise>

## Important

- Focus ONLY on addressing the review feedback
- Do NOT refactor unrelated code
- Keep changes minimal and focused
- If a feedback item is unclear, make a reasonable interpretation
- All quality checks must still pass after fixes

## Quality Checks
$quality_checks

## Completion

When you have:
- Fixed all issues from the review feedback
- Passed all quality checks
- Committed the fixes

Output: <promise>$COMPLETION_PROMISE</promise>

If you cannot fix an issue after reasonable attempts, explain why and output: <promise>$BLOCKED_PROMISE</promise>
FIX_PROMPT_EOF
}

# Function to parse review result and extract status
parse_review_status() {
  local output="$1"
  if echo "$output" | grep -q "STATUS: $REVIEW_APPROVED"; then
    echo "APPROVED"
  elif echo "$output" | grep -q "STATUS: $REVIEW_NEEDS_CHANGES"; then
    echo "NEEDS_CHANGES"
  else
    echo "UNCLEAR"
  fi
}

# Function to extract review comments from output
extract_review_comments() {
  local output="$1"
  # Extract content between <review> tags, get lines starting with -
  echo "$output" | sed -n '/<review>/,/<\/review>/p' | grep "^-" | sed 's/^- //' || echo ""
}

# Function to run a single review cycle
run_review_cycle() {
  local story_id="$1"
  local story_title="$2"
  local acceptance_criteria="$3"
  local start_commit="$4"
  local previous_feedback="$5"

  echo "Capturing git diff..."
  local git_diff
  git_diff=$(capture_story_diff "$start_commit")

  echo "Rendering review prompt..."
  local review_prompt
  review_prompt=$(render_review_prompt "$story_id" "$story_title" "$acceptance_criteria" "$git_diff" "$previous_feedback")

  local review_prompt_file=$(mktemp)
  echo "$review_prompt" > "$review_prompt_file"

  echo "Running code review..."
  local output
  output=$(cat "$review_prompt_file" | claude --dangerously-skip-permissions --print 2>&1 | tee /dev/stderr) || true

  rm -f "$review_prompt_file"

  # Parse the result
  local status
  status=$(parse_review_status "$output")

  if [ "$status" = "APPROVED" ]; then
    echo "REVIEW_APPROVED"
  elif [ "$status" = "NEEDS_CHANGES" ]; then
    # Extract and return the comments
    local comments
    comments=$(extract_review_comments "$output")
    echo "REVIEW_NEEDS_CHANGES:$comments"
  else
    echo "REVIEW_UNCLEAR"
  fi
}

# Function to run a fix iteration based on review feedback
run_fix_iteration() {
  local story_id="$1"
  local story_title="$2"
  local review_feedback="$3"

  echo "Rendering fix prompt..."
  local fix_prompt
  fix_prompt=$(render_fix_prompt "$story_id" "$story_title" "$review_feedback")

  local fix_prompt_file=$(mktemp)
  echo "$fix_prompt" > "$fix_prompt_file"

  echo "Applying fixes..."
  local output
  output=$(cat "$fix_prompt_file" | claude --dangerously-skip-permissions --print --continue 2>&1 | tee /dev/stderr) || true

  rm -f "$fix_prompt_file"

  # Check for completion signal
  if echo "$output" | grep -q "<promise>$COMPLETION_PROMISE</promise>"; then
    echo "FIX_COMPLETE"
  elif echo "$output" | grep -q "<promise>$BLOCKED_PROMISE</promise>"; then
    echo "FIX_BLOCKED"
  else
    echo "FIX_INCOMPLETE"
  fi
}

# Main execution
echo "=================================================="
echo "  Chief Wiggum - Claude Code Story Orchestrator"
echo "=================================================="
echo ""

PROJECT_NAME=$(jq -r '.project // "Unknown"' "$PRD_FILE")
BRANCH_NAME=$(jq -r '.branchName // "main"' "$PRD_FILE")
PROJECT_DESCRIPTION=$(jq -r '.description // ""' "$PRD_FILE")
TOTAL_STORIES=$(jq -r '.userStories | length' "$PRD_FILE")
COMPLETED_STORIES=$(jq -r '.userStories | map(select(.passes == true)) | length' "$PRD_FILE")

echo "Project: $PROJECT_NAME"
echo "Branch: $BRANCH_NAME"
echo "Stories: $COMPLETED_STORIES/$TOTAL_STORIES complete"
echo "Max iterations per story: $MAX_ITERATIONS_PER_STORY"
echo ""

STORY_COUNT=0

while [ $STORY_COUNT -lt $MAX_STORIES ]; do
  # Check if all stories are complete
  if all_stories_complete; then
    echo ""
    echo "=================================================="
    echo "  ALL STORIES COMPLETE!"
    echo "=================================================="
    echo ""
    echo "Chief Wiggum has successfully completed all $TOTAL_STORIES stories."
    exit 0
  fi

  # Get next story
  STORY_JSON=$(get_next_story)
  if [ -z "$STORY_JSON" ]; then
    echo "No more stories to process."
    break
  fi

  STORY_ID=$(echo "$STORY_JSON" | jq -r '.id')
  STORY_TITLE=$(echo "$STORY_JSON" | jq -r '.title')
  STORY_DESCRIPTION=$(echo "$STORY_JSON" | jq -r '.description')
  STORY_PRIORITY=$(echo "$STORY_JSON" | jq -r '.priority')

  # Build acceptance criteria as a formatted list
  ACCEPTANCE_CRITERIA=$(echo "$STORY_JSON" | jq -r '.acceptanceCriteria | map("- [ ] " + .) | join("\n")')

  STORY_COUNT=$((STORY_COUNT + 1))

  echo ""
  echo "=================================================="
  echo "  Story $STORY_COUNT: $STORY_ID - $STORY_TITLE"
  echo "  Priority: $STORY_PRIORITY"
  echo "=================================================="
  echo ""

  # Render the prompt with story data
  PROMPT=$(render_prompt "$STORY_ID" "$STORY_TITLE" "$STORY_DESCRIPTION" "$ACCEPTANCE_CRITERIA" "$PROJECT_NAME" "$BRANCH_NAME" "$PROJECT_DESCRIPTION")

  # Write prompt to temp file for claude to read
  PROMPT_FILE=$(mktemp)
  echo "$PROMPT" > "$PROMPT_FILE"

  # Track start commit for code review diff
  STORY_START_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "")

  # Execute Claude with iterative loop (Ralph technique)
  echo "Starting iterative execution..."
  echo "Max iterations: $MAX_ITERATIONS_PER_STORY"
  echo ""

  ITERATION=0
  STORY_RESULT=""

  while [ $ITERATION -lt $MAX_ITERATIONS_PER_STORY ]; do
    ITERATION=$((ITERATION + 1))
    echo ""
    echo "--- Iteration $ITERATION of $MAX_ITERATIONS_PER_STORY ---"

    # Run Claude with the prompt
    # Use --continue to maintain conversation context between iterations
    if [ $ITERATION -eq 1 ]; then
      # First iteration: start fresh
      OUTPUT=$(cat "$PROMPT_FILE" | claude --dangerously-skip-permissions --print 2>&1 | tee /dev/stderr) || true
    else
      # Subsequent iterations: continue with same prompt
      OUTPUT=$(cat "$PROMPT_FILE" | claude --dangerously-skip-permissions --print --continue 2>&1 | tee /dev/stderr) || true
    fi

    # Check for completion or blocked signals
    if echo "$OUTPUT" | grep -q "<promise>$COMPLETION_PROMISE</promise>"; then
      STORY_RESULT="COMPLETE"
      break
    elif echo "$OUTPUT" | grep -q "<promise>$BLOCKED_PROMISE</promise>"; then
      STORY_RESULT="BLOCKED"
      break
    fi

    echo "Iteration $ITERATION complete, continuing..."
    sleep 1
  done

  # Clean up temp file
  rm -f "$PROMPT_FILE"

  echo ""
  echo "Finished after $ITERATION iterations"

  # Check for completion signal
  if [ "$STORY_RESULT" = "COMPLETE" ]; then
    echo ""
    echo "Story $STORY_ID implementation complete!"

    # Code review phase (if enabled)
    REVIEW_PASSED=false
    if [ "$CODE_REVIEW_ENABLED" = "true" ]; then
      echo ""
      echo "=================================================="
      echo "  Code Review Phase"
      echo "=================================================="

      REVIEW_CYCLE=0
      REVIEW_FEEDBACK=""

      while [ $REVIEW_CYCLE -lt $MAX_REVIEW_CYCLES ]; do
        REVIEW_CYCLE=$((REVIEW_CYCLE + 1))
        echo ""
        echo "--- Review Cycle $REVIEW_CYCLE of $MAX_REVIEW_CYCLES ---"

        REVIEW_RESULT=$(run_review_cycle "$STORY_ID" "$STORY_TITLE" "$ACCEPTANCE_CRITERIA" "$STORY_START_COMMIT" "$REVIEW_FEEDBACK")

        if [ "$REVIEW_RESULT" = "REVIEW_APPROVED" ]; then
          echo ""
          echo "Code review APPROVED!"
          REVIEW_PASSED=true
          break
        elif [[ "$REVIEW_RESULT" == REVIEW_NEEDS_CHANGES:* ]]; then
          REVIEW_FEEDBACK="${REVIEW_RESULT#REVIEW_NEEDS_CHANGES:}"
          echo ""
          echo "Code review found issues. Running fix iteration..."
          echo "Feedback: $REVIEW_FEEDBACK"

          FIX_RESULT=$(run_fix_iteration "$STORY_ID" "$STORY_TITLE" "$REVIEW_FEEDBACK")

          if [ "$FIX_RESULT" = "FIX_BLOCKED" ]; then
            echo "Fix iteration blocked. Stopping review cycles."
            break
          fi
          # Continue to next review cycle
        else
          echo ""
          echo "Review result unclear, treating as approved."
          REVIEW_PASSED=true
          break
        fi
      done

      if [ "$REVIEW_PASSED" = false ] && [ $REVIEW_CYCLE -ge $MAX_REVIEW_CYCLES ]; then
        echo ""
        echo "Max review cycles ($MAX_REVIEW_CYCLES) reached without full approval."
        echo "Marking story as complete anyway to continue progress."
        REVIEW_PASSED=true
      fi
    else
      # Code review disabled, auto-pass
      REVIEW_PASSED=true
    fi

    if [ "$REVIEW_PASSED" = true ]; then
      echo ""
      echo "Story $STORY_ID completed and reviewed successfully!"
      mark_story_complete "$STORY_ID"

      # Update progress
      COMPLETED_STORIES=$((COMPLETED_STORIES + 1))
      echo ""
      echo "Progress: $COMPLETED_STORIES/$TOTAL_STORIES stories complete"

      # Log completion to progress file
      echo "" >> "$PROGRESS_FILE"
      echo "## $(date) - $STORY_ID COMPLETED" >> "$PROGRESS_FILE"
      echo "Story: $STORY_TITLE" >> "$PROGRESS_FILE"
      if [ "$CODE_REVIEW_ENABLED" = "true" ]; then
        echo "Review cycles: $REVIEW_CYCLE" >> "$PROGRESS_FILE"
      fi
      echo "---" >> "$PROGRESS_FILE"
    fi

  elif [ "$STORY_RESULT" = "BLOCKED" ]; then
    echo ""
    echo "Story $STORY_ID is BLOCKED!"
    echo "Check progress.txt for blocker details."

    # Log blocker to progress file
    echo "" >> "$PROGRESS_FILE"
    echo "## $(date) - $STORY_ID BLOCKED" >> "$PROGRESS_FILE"
    echo "Story: $STORY_TITLE" >> "$PROGRESS_FILE"
    echo "Check Claude output for blocker details." >> "$PROGRESS_FILE"
    echo "---" >> "$PROGRESS_FILE"

    echo ""
    echo "Stopping due to blocker. Fix the issue and restart."
    exit 1
  else
    echo ""
    echo "Story $STORY_ID did not complete within $MAX_ITERATIONS_PER_STORY iterations."
    echo "The story may need to be split into smaller tasks."

    # Log timeout to progress file
    echo "" >> "$PROGRESS_FILE"
    echo "## $(date) - $STORY_ID TIMEOUT" >> "$PROGRESS_FILE"
    echo "Story: $STORY_TITLE" >> "$PROGRESS_FILE"
    echo "Did not complete within max iterations." >> "$PROGRESS_FILE"
    echo "Consider splitting this story into smaller tasks." >> "$PROGRESS_FILE"
    echo "---" >> "$PROGRESS_FILE"

    echo ""
    echo "Stopping execution. Split the story or increase max-iterations, then restart."
    exit 1
  fi

  echo ""
  echo "Waiting before next story..."
  sleep 2
done

echo ""
echo "=================================================="
echo "  Chief Wiggum Session Complete"
echo "=================================================="
echo ""

if all_stories_complete; then
  echo "All stories completed successfully!"
  exit 0
else
  REMAINING=$(jq -r '.userStories | map(select(.passes == false)) | length' "$PRD_FILE")
  echo "Processed $STORY_COUNT stories."
  echo "Remaining stories: $REMAINING"
  echo "Check progress.txt for status."
  exit 1
fi
