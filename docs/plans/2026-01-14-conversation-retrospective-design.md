# Conversation Retrospective Analysis - Design Document

**Date:** 2026-01-14
**Goal:** Analyze Claude Code and OpenCode conversation logs to identify recurring struggle patterns, then improve CLAUDE.md and create preventive skills.

---

## Overview

Scan 30 days of conversation transcripts using parallel LLM agents to identify:
- Bugs that took multiple iterations to fix
- Recurring confusion patterns (Lua-C++ bindings, UI rendering, ECS)
- Debugging approaches that eventually succeeded
- Anti-patterns that caused repeated issues

### Deliverables

1. **Analysis Report** - Comprehensive findings with evidence
2. **CLAUDE.md Patch** - Ready-to-apply additions documenting pitfalls
3. **Skill Templates** - Reusable workflows for top recurring patterns

---

## Data Sources

| Source | Volume | Location |
|--------|--------|----------|
| Claude transcripts | ~350 files (30 days) | `~/.claude/transcripts/` |
| OpenCode history | 3.7MB | `~/.local/state/opencode/prompt-history.jsonl` |
| Git worktrees | 24 branches | Various paths |

### Transcript Format (JSONL)

```json
{"type": "user", "timestamp": "2026-01-05T01:55:47.993Z", "content": "..."}
{"type": "assistant", "timestamp": "...", "content": "..."}
```

---

## Architecture

```
┌─────────────────┐
│  Coordinator    │ ← Manages batches, monitors progress
└────────┬────────┘
         │
    ┌────┴────┬────────┬────────┐
    ▼         ▼        ▼        ▼
┌───────┐ ┌───────┐ ┌───────┐ ┌───────┐
│Agent 1│ │Agent 2│ │Agent 3│ │Agent N│  ← Each analyzes ~20 transcripts
└───┬───┘ └───┬───┘ └───┬───┘ └───┬───┘
    │         │        │        │
    └─────────┴────────┴────────┘
                  ▼
         ┌──────────────┐
         │  Synthesizer │ ← Deduplicates, ranks, generates artifacts
         └──────────────┘
```

---

## Phase 1: Setup & Preprocessing

**Agent:** 1 (coordinator)
**Duration:** ~2 minutes

### Tasks

1. Query transcripts modified in last 30 days:
   ```bash
   find ~/.claude/transcripts -name "*.jsonl" -mtime -30
   ```

2. Parse each transcript to extract metadata:
   ```json
   {
     "session_id": "ses_xxx",
     "date": "2026-01-10",
     "working_dir": "/path/to/worktree",
     "turn_count": 45,
     "file_path": "~/.claude/transcripts/ses_xxx.jsonl"
   }
   ```

3. Create batch manifest at `/tmp/retrospective/manifest.json`

4. Create output directory structure:
   ```
   /tmp/retrospective/
   ├── manifest.json
   ├── agent_outputs/
   └── synthesis/
   ```

---

## Phase 2: Parallel Analysis

**Agents:** 15-20 parallel
**Duration:** ~15-20 minutes

### Batching Strategy

- ~20 transcripts per agent
- Transcripts assigned round-robin to balance load
- Each agent writes to `/tmp/retrospective/agent_outputs/agent_N.json`

### Struggle Detection Criteria

| Signal | Weight | Example |
|--------|--------|---------|
| Multiple edits to same file | High | 5+ edits to same file in one session |
| Error messages followed by retries | High | "sol: cannot set" → fix → same error |
| Explicit frustration phrases | Medium | "still not working", "let me try again" |
| Long debugging sequences | Medium | 10+ tool calls investigating same issue |
| Reverting changes | High | Undo/revert patterns |

### Categorization Taxonomy

- `lua_cpp_bindings` - Sol2, require vs globals, component access
- `ecs_components` - Entity creation, script tables, data ordering
- `ui_rendering` - Z-order, layers, DrawCommandSpace, collision
- `physics` - Chipmunk, collision masks, sync modes
- `shaders` - Pipeline, uniforms, multi-pass
- `debugging` - Diagnosis approaches, logging strategies
- `architecture` - Design patterns, module organization

### Output Schema (per struggle)

```json
{
  "id": "struggle_001",
  "category": "lua_cpp_bindings",
  "title": "Sol2 userdata arbitrary key assignment",
  "symptoms": ["sol: cannot set (new_index)", "attempted go.config.foo = bar"],
  "root_cause": "C++ userdata doesn't allow arbitrary keys",
  "solution": "Use Lua-side registry table instead",
  "iterations_to_fix": 4,
  "files_affected": ["gameplay.lua", "card_ui_policy.lua"],
  "evidence_transcript": "ses_xxx",
  "evidence_quotes": ["relevant quote from transcript"],
  "confidence": 0.9
}
```

---

## Phase 3: Synthesis

**Agent:** 1
**Duration:** ~5 minutes

### Deduplication Strategy

1. **Cluster by similarity** - Group struggles with matching `root_cause` or overlapping `symptoms`
2. **Merge evidence** - Combine transcript references into canonical entry
3. **Rank by frequency** - Struggles occurring 3+ times get priority
4. **Preserve unique insights** - Keep distinct solutions even for similar problems

### Output

Write merged findings to `/tmp/retrospective/synthesis/merged_findings.json`

---

## Phase 4: Artifact Generation

**Agent:** 1
**Duration:** ~5 minutes

### Artifact 1: Analysis Report

**Path:** `docs/analysis/conversation-retrospective-2026-01.md`

```markdown
# Conversation Retrospective - January 2026

## Executive Summary
- Analyzed N transcripts from last 30 days
- Identified N recurring struggle patterns
- Top categories: [ranked list]

## Detailed Findings

### Pattern #1: [Title] (N occurrences)
**Category:** [category]
**Symptoms:**
- [symptom 1]
- [symptom 2]

**Root Cause:** [explanation]

**Solution:** [how to fix]

**Evidence:** Sessions [ses_xxx, ses_yyy]

---
[repeat for each pattern]
```

### Artifact 2: CLAUDE.md Patch

**Path:** `docs/analysis/claude-md-additions.md`

Ready-to-copy content organized by section:
- New "Common Pitfalls" entries
- New code examples
- New anti-pattern warnings

### Artifact 3: Skill Templates

**Path:** `docs/analysis/proposed-skills/`

For top 5 recurring patterns, create skill templates:
```markdown
---
name: [skill-name]
description: [when to use]
---

# [Skill Title]

## When to Use
[triggers]

## Steps
1. [step 1]
2. [step 2]
...

## Common Mistakes
- [mistake 1]
- [mistake 2]
```

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Token limits exceeded | Truncate transcripts to last 50 turns |
| Agent failures | Retry failed batches up to 2 times |
| Duplicate detection misses | Manual review before applying patches |
| Low-quality findings | Confidence threshold (>0.7) for inclusion |

---

## Estimated Timeline

| Phase | Agents | Duration |
|-------|--------|----------|
| Setup & Preprocessing | 1 | ~2 min |
| Parallel Analysis | 18 | ~15-20 min |
| Synthesis | 1 | ~5 min |
| Artifact Generation | 1 | ~5 min |
| **Total** | | **~30 min** |

---

## Success Criteria

- [ ] Analyzed 300+ transcripts from last 30 days
- [ ] Identified 10+ distinct struggle patterns
- [ ] Generated CLAUDE.md patch with 5+ new entries
- [ ] Created 3+ skill templates for recurring issues
- [ ] All artifacts committed to `docs/analysis/`
