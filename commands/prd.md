---
name: prd
description: "Generate a Product Requirements Document (PRD) for a new feature"
argument-hint: "<feature description>"
---

# PRD Generator

Create detailed Product Requirements Documents that are clear, actionable, and suitable for implementation with Chief Wiggum and Claude Code.

## The Job

1. Receive a feature description from the user
2. Ask 3-5 essential clarifying questions (with lettered options)
3. Generate a structured PRD based on answers
4. Save to `tasks/prd-[feature-name].md`

**Important:** Do NOT start implementing. Just create the PRD.

## Step 1: Clarifying Questions

Ask only critical questions where the initial prompt is ambiguous. Focus on:

- **Problem/Goal:** What problem does this solve?
- **Core Functionality:** What are the key actions?
- **Scope/Boundaries:** What should it NOT do?
- **Success Criteria:** How do we know it's done?

### Format Questions Like This:

```
1. What is the primary goal of this feature?
   A. Improve user onboarding experience
   B. Increase user retention
   C. Reduce support burden
   D. Other: [please specify]

2. Who is the target user?
   A. New users only
   B. Existing users only
   C. All users
   D. Admin users only
```

This lets users respond with "1A, 2C, 3B" for quick iteration.

## Step 2: PRD Structure

Generate the PRD with these sections:

### 1. Introduction/Overview
Brief description of the feature and the problem it solves.

### 2. Goals
Specific, measurable objectives (bullet list).

### 3. User Stories
Each story needs:
- **Title:** Short descriptive name
- **Description:** "As a [user], I want [feature] so that [benefit]"
- **Acceptance Criteria:** Verifiable checklist of what "done" means

Each story should be small enough to implement in one focused session with Claude Code.

**Format:**
```markdown
### US-001: [Title]
**Description:** As a [user], I want [feature] so that [benefit].

**Acceptance Criteria:**
- [ ] Specific verifiable criterion
- [ ] Another criterion
- [ ] Typecheck/lint passes
- [ ] **[UI stories only]** Verify in browser
```

**Important:**
- Acceptance criteria must be verifiable, not vague. "Works correctly" is bad. "Button shows confirmation dialog before deleting" is good.
- **For any story with UI changes:** Always include "Verify in browser" as acceptance criteria.

### 4. Functional Requirements
Numbered list: "FR-1: The system must allow users to..."

### 5. Non-Goals (Out of Scope)
What this feature will NOT include.

### 6. Design Considerations (Optional)
UI/UX requirements, mockups, existing components to reuse.

### 7. Technical Considerations (Optional)
Constraints, dependencies, integration points.

### 8. Success Metrics
How will success be measured?

### 9. Open Questions
Remaining questions needing clarification.

## Output

- **Format:** Markdown (`.md`)
- **Location:** `tasks/`
- **Filename:** `prd-[feature-name].md` (kebab-case)

## Checklist

Before saving the PRD:

- [ ] Asked clarifying questions with lettered options
- [ ] Incorporated user's answers
- [ ] User stories are small and specific (completable in one Claude Code session)
- [ ] Functional requirements are numbered and unambiguous
- [ ] Non-goals section defines clear boundaries
- [ ] Saved to `tasks/prd-[feature-name].md`

## Final Step: Integration Prompt

After saving the PRD, ask the user:

> "PRD saved to `tasks/prd-[feature-name].md`. Would you like to integrate this feature now? I can convert it to `prd.json` and prepare it for execution with `/chief-wiggum`."

**If user agrees:**
1. Run `/prd-convert tasks/prd-[feature-name].md`
2. After conversion completes, inform the user:
   > "Done! Your feature is ready for autonomous execution. Run `/chief-wiggum` to start implementing all user stories."

**If user declines:**
Simply acknowledge and let them know they can run `/prd-convert` later when ready.
