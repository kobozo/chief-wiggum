# Code Review Fixes Required

You previously implemented story {{STORY_ID}}: {{STORY_TITLE}}

The code reviewer found issues that need to be addressed.

## Review Feedback

{{REVIEW_FEEDBACK}}

## Your Task

1. **Address EACH item** in the review feedback above
2. **Run quality checks** (typecheck, lint, test) - all must pass
3. **Commit fixes** with message: `fix: {{STORY_ID}} - address review feedback`
4. When ALL feedback items are resolved, output: <promise>{{COMPLETION_PROMISE}}</promise>

## Important

- Focus ONLY on addressing the review feedback
- Do NOT refactor unrelated code
- Keep changes minimal and focused
- If a feedback item is unclear, make a reasonable interpretation
- All quality checks must still pass after fixes

## Quality Checks
{{QUALITY_CHECKS}}

## Completion

When you have:
- Fixed all issues from the review feedback
- Passed all quality checks
- Committed the fixes

Output: <promise>{{COMPLETION_PROMISE}}</promise>

If you cannot fix an issue after reasonable attempts, explain why and output: <promise>{{BLOCKED_PROMISE}}</promise>
