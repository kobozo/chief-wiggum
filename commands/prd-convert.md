---
name: prd-convert
description: "Convert a PRD markdown file to prd.json format for Chief Wiggum execution"
argument-hint: "<path/to/prd.md> [--file <output.json>]"
---

# PRD to JSON Converter

Converts existing PRDs to the prd.json format that Chief Wiggum uses for autonomous execution.

## The Job

Take a PRD (markdown file or text) and convert it to a JSON file (default: `.chief-wiggum/prd.json`).

## Options

| Option | Description |
|--------|-------------|
| `<path/to/prd.md>` | Input PRD markdown file (required) |
| `--file <output.json>` | Output file path (default: `.chief-wiggum/prd.json`) |

## Examples

```bash
/prd-convert docs/feature-prd.md                              # Output to .chief-wiggum/prd.json
/prd-convert docs/feature-prd.md --file .chief-wiggum/auth.json   # Output to custom file
```

## Output Format

```json
{
  "project": "[Project Name]",
  "branchName": "clancy/[feature-name-kebab-case]",
  "description": "[Feature description from PRD title/intro]",
  "userStories": [
    {
      "id": "US-001",
      "title": "[Story title]",
      "description": "As a [user], I want [feature] so that [benefit]",
      "acceptanceCriteria": [
        "Criterion 1",
        "Criterion 2",
        "Typecheck passes"
      ],
      "priority": 1,
      "passes": false,
      "notes": ""
    }
  ]
}
```

## Story Size: The Number One Rule

**Each story must be completable in ONE Claude Code context window via /ralph-loop.**

### Right-sized stories:
- Add a database column and migration
- Add a UI component to an existing page
- Update a server action with new logic
- Add a filter dropdown to a list

### Too big (split these):
- "Build the entire dashboard" → Split into: schema, queries, UI components, filters
- "Add authentication" → Split into: schema, middleware, login UI, session handling
- "Refactor the API" → Split into one story per endpoint or pattern

**Rule of thumb:** If you cannot describe the change in 2-3 sentences, it is too big.

## Story Ordering: Dependencies First

Stories execute in priority order. Earlier stories must not depend on later ones.

**Correct order:**
1. Schema/database changes (migrations)
2. Server actions / backend logic
3. UI components that use the backend
4. Dashboard/summary views that aggregate data

## Acceptance Criteria: Must Be Verifiable

### Good criteria (verifiable):
- "Add `status` column to tasks table with default 'pending'"
- "Filter dropdown has options: All, Active, Completed"
- "Clicking delete shows confirmation dialog"
- "Typecheck passes"

### Bad criteria (vague):
- "Works correctly"
- "User can do X easily"
- "Good UX"

### Always include:
- `"Typecheck passes"` for every story
- `"Verify in browser"` for UI stories

## Conversion Rules

1. **Each user story becomes one JSON entry**
2. **IDs**: Sequential (US-001, US-002, etc.)
3. **Priority**: Based on dependency order, then document order
4. **All stories**: `passes: false` and empty `notes`
5. **branchName**: Derive from feature name, kebab-case, prefixed with `clancy/`
6. **Always add**: "Typecheck passes" to every story's acceptance criteria

## Archiving Previous Runs

**Before writing a new prd.json, check if there is an existing one from a different feature:**

1. Read the current `.chief-wiggum/prd.json` if it exists
2. Check if `branchName` differs from the new feature's branch name
3. If different AND `.chief-wiggum/progress.txt` has content beyond the header:
   - Create archive folder: `.chief-wiggum/archive/YYYY-MM-DD-feature-name/`
   - Copy current `prd.json` and `progress.txt` to archive
   - Reset `progress.txt` with fresh header

## Checklist Before Saving

Before writing prd.json, verify:

- [ ] **Previous run archived** (if prd.json exists with different branchName)
- [ ] Each story is completable in one iteration
- [ ] Stories are ordered by dependency (schema → backend → UI)
- [ ] Every story has "Typecheck passes" as criterion
- [ ] UI stories have "Verify in browser" as criterion
- [ ] Acceptance criteria are verifiable (not vague)
- [ ] No story depends on a later story
