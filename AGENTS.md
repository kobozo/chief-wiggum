# Chief Wiggum Agent Instructions

## Overview

Chief Wiggum is an autonomous AI agent orchestrator that runs Claude Code with `/ralph-loop:ralph-loop` repeatedly until all PRD items are complete. Each story execution spawns a fresh Claude Code instance with clean context.

## Two-Tier Architecture

1. **Chief Wiggum (Outer Loop)**: `chief-wiggum.sh` - Orchestrates story execution
2. **Ralph Loop (Inner Loop)**: `/ralph-loop:ralph-loop` skill - Iterates on each story

## Commands

```bash
# Run Chief Wiggum (from project that has prd.json)
./chief-wiggum.sh [max_stories]

# Run the flowchart dev server
cd flowchart && npm run dev

# Build the flowchart
cd flowchart && npm run build
```

## Key Files

- `chief-wiggum.sh` - The bash orchestrator that spawns Claude Code instances
- `chief-wiggum.config.json` - Configuration for iterations, promises, quality checks
- `story-prompt.template.md` - Template for story execution prompts
- `prd.json` - User stories with completion status
- `prd.json.example` - Example PRD format
- `progress.txt` - Append-only learnings log
- `flowchart/` - Interactive React Flow diagram explaining how Chief Wiggum works

## Flowchart

The `flowchart/` directory contains an interactive visualization built with React Flow. It's designed for presentations - click through to reveal each step with animations.

```bash
cd flowchart
npm install
npm run dev
```

## Patterns

- Each story spawns a fresh Claude Code instance with clean context
- Memory persists via git history, `progress.txt`, and `prd.json`
- Stories should be small enough to complete in one context window
- Always update AGENTS.md with discovered patterns for future iterations
- Use `/ralph-loop:ralph-loop` with `--max-iterations` and `--completion-promise` flags

## Claude Code Integration

Chief Wiggum executes stories using:
```bash
claude --dangerously-skip-permissions --print "/ralph-loop:ralph-loop \"<prompt>\" --max-iterations 25 --completion-promise STORY_COMPLETE"
```

## Promise Detection

- `STORY_COMPLETE`: Story successfully implemented
- `BLOCKED`: Cannot proceed, needs intervention

## Configuration

See `chief-wiggum.config.json` for:
- `maxIterationsPerStory`: Max ralph-loop iterations per story
- `completionPromise`: Success promise string
- `blockedPromise`: Blocked promise string
- `qualityChecks`: Array of quality check commands
