---
name: cancel-chief-wiggum
description: "Cancel a running Chief Wiggum loop"
argument-hint: ""
---

# Cancel Chief Wiggum Loop

Cancel a running Chief Wiggum loop by removing the loop control file.

## Execution

Run this command in the Bash tool:

```bash
CONTROL_FILE=".chief-wiggum/wiggum-loop.local.md"
if [ -f "$CONTROL_FILE" ]; then
  rm -f "$CONTROL_FILE"
  echo "Chief Wiggum loop cancelled."
  echo "The loop will stop at the next iteration check."
else
  echo "No running Chief Wiggum loop found."
  echo "(Control file not present: $CONTROL_FILE)"
fi
```

## What happens:

1. Checks if the loop control file exists (`.chief-wiggum/wiggum-loop.local.md`)
2. If it exists, removes it
3. The running `/chief-wiggum` loop will detect the missing file at its next iteration and stop gracefully

## Notes

- The loop will stop at the next iteration check, not immediately
- Any in-progress Claude invocation will complete before the loop stops
- The current story may be partially complete when the loop stops
- Run `/chief-wiggum` again to resume from where it left off
