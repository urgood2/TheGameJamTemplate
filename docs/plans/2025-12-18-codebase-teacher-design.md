# Codebase Teacher Skill Design

**Date:** 2025-12-18
**Status:** Approved

## Overview

A Claude Code skill that transforms Claude into a teaching assistant for this game engine codebase. Instead of just answering questions, it shows actual code first, then explains, and surfaces related pitfalls.

**Core Principle:** *"Show the code, then teach the concept."*

## Use Cases

1. **Discovery** — "How does X work?", "Where do I add Y?"
2. **Debugging** — "Why isn't X working?", "What's wrong with my code?"

## Teaching Style

**Show-then-explain:**
- Find relevant actual code in the codebase first
- Show it with file:line references
- Explain what it does and why
- Surface related pitfalls from documented common mistakes

## Triggering

Always-on via skill description. Triggers on:
- "how does X work" / "where is X" (discovery)
- "why isn't X working" / "what's wrong with" (debugging)
- Questions mentioning core systems: EntityBuilder, physics, shaders, scripting, combat, timers, signals, etc.

## Verification Depth

**Adaptive:**
- Simple API question → check CLAUDE.md + one key file
- Complex system question → search for multiple usage examples
- Debugging → deep dive with actual file:line citations

## Teaching Workflow

### For Discovery Questions

```
1. SEARCH: Find actual code examples in the codebase
2. SHOW: Present 1-3 real examples with file:line references
3. EXPLAIN: Walk through what the code does and why
4. WARN: Surface contextually-relevant mistakes from CLAUDE.md
5. GUIDE: Point to related systems or next steps
```

### For Debugging Questions

```
1. LOCATE: Find the implementation of the problematic system
2. SHOW: Present the actual code path that's likely involved
3. DIAGNOSE: Explain what typically causes this symptom
4. VERIFY: Check against common mistakes list
5. FIX: Show the correct pattern with a concrete example
```

## Knowledge Sources

### Layer 1: CLAUDE.md (Quick Reference)
- API patterns (EntityBuilder, PhysicsBuilder, ShaderBuilder, Timer, Text, etc.)
- Common mistakes with explicit "Don't" patterns
- Event names and parameters

### Layer 2: Documentation (docs/)
- `docs/api/` — Timer docs, physics docs, camera docs
- `docs/systems/` — Combat architecture, AI behavior, shader pipeline
- `docs/guides/` — Implementation summaries, troubleshooting

### Layer 3: Actual Codebase (Verification)
- `assets/scripts/` — Lua gameplay, combat, UI, AI
- `src/systems/` — C++ implementations when needed

## Contextual Mistake Mapping

| Topic | Related Pitfalls |
|-------|------------------|
| EntityBuilder / script tables | attach_ecs order, getScriptTableFromEntityID nil |
| Physics | globals.physicsWorld vs PhysicsManager.get_world |
| Events | publishLuaEvent vs signal.emit |
| GameObject | Don't store data in GameObject component |
| Timers | tag parameter for cleanup, sequence API |

## File Structure

```
~/.claude/skills/codebase-teacher/
  SKILL.md              # Main skill
  mistake-catalog.md    # Expanded pitfall reference
```

## Example Interactions

**Discovery:**
> User: "How do I spawn an enemy with physics?"
>
> Claude shows actual code from enemy_spawner.lua, explains EntityBuilder + PhysicsBuilder pattern, warns about attach_ecs ordering.

**Debugging:**
> User: "Why is my script table nil?"
>
> Claude checks attach_ecs implementation, lists common causes, shows correct pattern from codebase.

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
