# Documentation Foundation for Future Prototypes

## TL;DR

> **Quick Summary**: Comprehensive audit, verification, and consolidation of all project documentation. Verify code examples against actual runtime, consolidate 290+ scattered pitfalls into searchable reference, create AGENTS.md knowledge base, and ensure all 100+ docs are indexed with timestamps.
> 
> **Deliverables**:
> - All 100+ docs verified with timestamps
> - `docs/guides/COMMON_PITFALLS.md` (full reference)
> - Enhanced `claude.md` with pitfall summary
> - `AGENTS.md` hierarchical knowledge base
> - Zero broken internal links
> - GitHub issues for all verification failures
> 
> **Estimated Effort**: Large (5-7 days equivalent)
> **Parallel Execution**: YES - 4 waves
> **Critical Path**: Static Analysis → Runtime Verification → Consolidation → Index Updates

---

## Context

### Original Request
Create a comprehensive documentation foundation for future game jam prototypes by verifying existing docs work, consolidating patterns from current project including UI practices, item interactibility, and all systems.

### Interview Summary
**Key Discussions**:
- Primary use case: Human developer onboarding
- Verification approach: Static analysis first, runtime verification for critical examples
- Pitfall consolidation: Full version in `docs/guides/COMMON_PITFALLS.md`, summary in `claude.md`
- Verification failures: Create GitHub issues for each problem found
- Scope: Gold standard - all 100+ docs verified, comprehensive pitfalls, perfect indexing
- Timestamps: Yes, with format `<!-- Verified: YYYY-MM-DD against commit HASH -->`

**Research Findings**:
- 100+ markdown files exist with varying quality
- 290+ pitfall/gotcha mentions scattered across 99 files
- `UI_PANEL_IMPLEMENTATION_GUIDE.md` is excellent (1088 lines, 11 documented pitfalls)
- `AGENTS.md` currently just redirects to `claude.md` - no knowledge base exists
- 9 markdown files in `src/systems/` not indexed anywhere
- `chugget_code_definitions.lua` is auto-generated API reference (source of truth for bindings)

### Metis Review
**Identified Gaps** (addressed):
- Verification criteria now defined (static + runtime)
- Pitfall consolidation location decided (both docs/ and claude.md)
- Failure handling decided (GitHub issues)
- Scope explicitly set to gold standard
- Timestamp format specified

---

## Work Objectives

### Core Objective
Create a bulletproof documentation foundation where every code example is verified working, all common pitfalls are consolidated and searchable, and navigation is comprehensive - enabling rapid prototype development with minimal errors.

### Concrete Deliverables
1. **Verification Infrastructure**: Scripts and tracking table for doc verification
2. **Verified Docs**: All 100+ docs verified with timestamps
3. **Pitfall Reference**: `docs/guides/COMMON_PITFALLS.md` with all pitfalls organized by category
4. **Claude.md Enhancement**: Updated common mistakes section with pitfall summary
5. **AGENTS.md Knowledge Base**: Hierarchical structure for `/init-deep` pattern
6. **Index Updates**: `docs/README.md` updated to include all docs
7. **GitHub Issues**: One issue per verification failure found

### Definition of Done
- [ ] `grep -r "<!-- Verified:" docs/ | wc -l` returns 100+ (all docs have timestamps)
- [ ] `test -f docs/guides/COMMON_PITFALLS.md && wc -l docs/guides/COMMON_PITFALLS.md | awk '{print $1}'` > 200
- [ ] `grep -c "Common Mistakes" claude.md` returns 1 (section exists and is enhanced)
- [ ] `test -f AGENTS.md && wc -l AGENTS.md | awk '{print $1}'` > 50 (knowledge base created)
- [ ] `gh issue list --label "doc-verification" --state open` returns issues (failures tracked)
- [ ] `(./build/raylib-cpp-cmake-template 2>&1 & sleep 8; kill $!) | grep -c "error\|Error"` = 0 for critical examples

### Must Have
- All priority system docs verified (UI, Physics, Combat/Wand)
- Consolidated pitfalls document
- Updated claude.md with pitfall summary
- AGENTS.md knowledge base
- Verification timestamps on all docs
- GitHub issues for failures

### Must NOT Have (Guardrails)
- No fixing code bugs found during verification (document only, create issues)
- No creating new tutorials or documentation beyond consolidation
- No moving or renaming existing doc files
- No deleting any documentation
- No code changes to fix doc examples
- No format standardization (different work)
- No deprecation of existing docs

---

## Verification Strategy

### Test Decision
- **Infrastructure exists**: YES (GoogleTest for C++, runtime for Lua)
- **User wants tests**: Manual verification with automated output capture
- **Framework**: Bash scripts + runtime verification

### Static Analysis Verification

For each doc, compare API signatures against `chugget_code_definitions.lua`:

```bash
# Extract function names from doc examples
grep -oP '(?<=\.)[\w]+\(' docs/api/physics_docs.md | sort -u > /tmp/doc_apis.txt

# Extract function names from bindings
grep -oP 'function [\w.]+\(' assets/scripts/chugget_code_definitions.lua | sort -u > /tmp/binding_apis.txt

# Find mismatches
comm -23 /tmp/doc_apis.txt /tmp/binding_apis.txt
```

### Runtime Verification

For critical code examples:

```bash
# Create test script from doc example
cat > /tmp/test_doc_example.lua << 'EOF'
-- Example code from doc
local dsl = require("ui.ui_syntax_sugar")
local myUI = dsl.vbox { config = { padding = 10 }, children = {} }
print("SUCCESS: UI DSL basic example")
EOF

# Run with timeout and capture errors
(./build/raylib-cpp-cmake-template --test-script /tmp/test_doc_example.lua 2>&1 & sleep 8; kill $!) | grep -E "(error|Error|SUCCESS)"
```

### Evidence Requirements
- Verification log file: `.sisyphus/evidence/doc-verification.log`
- Per-doc status in tracking table
- GitHub issue links for failures

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately - Infrastructure):
├── Task 1: Create verification tracking table
├── Task 2: Create static analysis script
└── Task 3: Extract all pitfalls inventory

Wave 2 (After Wave 1 - Priority System Verification):
├── Task 4: Verify UI/DSL docs (static + runtime)
├── Task 5: Verify Physics docs (static + runtime)
├── Task 6: Verify Combat/Wand docs (static)
└── Task 7: Verify remaining API docs (static)

Wave 3 (After Wave 2 - Consolidation):
├── Task 8: Create COMMON_PITFALLS.md
├── Task 9: Update claude.md pitfall summary
├── Task 10: Create AGENTS.md knowledge base
└── Task 11: Create GitHub issues for failures

Wave 4 (After Wave 3 - Index & Finalization):
├── Task 12: Update docs/README.md index
├── Task 13: Verify all internal links
├── Task 14: Add verification timestamps to all docs
└── Task 15: Final validation and summary

Critical Path: Task 1 → Task 4 → Task 8 → Task 12 → Task 15
Parallel Speedup: ~50% faster than sequential
```

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 1 | None | 4,5,6,7 | 2, 3 |
| 2 | None | 4,5,6,7 | 1, 3 |
| 3 | None | 8 | 1, 2 |
| 4 | 1,2 | 8,11 | 5, 6, 7 |
| 5 | 1,2 | 8,11 | 4, 6, 7 |
| 6 | 1,2 | 8,11 | 4, 5, 7 |
| 7 | 1,2 | 8,11 | 4, 5, 6 |
| 8 | 3,4,5,6,7 | 12 | 9, 10, 11 |
| 9 | 8 | 12 | 10, 11 |
| 10 | None | 12 | 8, 9, 11 |
| 11 | 4,5,6,7 | 15 | 8, 9, 10 |
| 12 | 8,9,10 | 15 | 13, 14 |
| 13 | 12 | 15 | 14 |
| 14 | 4,5,6,7 | 15 | 12, 13 |
| 15 | 12,13,14 | None | None (final) |

### Agent Dispatch Summary

| Wave | Tasks | Recommended Approach |
|------|-------|---------------------|
| 1 | 1, 2, 3 | Parallel - independent infrastructure setup |
| 2 | 4, 5, 6, 7 | Parallel - independent system verification |
| 3 | 8, 9, 10, 11 | Parallel after verification data available |
| 4 | 12, 13, 14, 15 | Sequential finalization |

---

## TODOs

### Wave 1: Infrastructure Setup

- [ ] 1. Create verification tracking table

  **What to do**:
  - Create `.sisyphus/evidence/doc-verification-tracking.md` with table structure
  - List all 100+ markdown files with columns: File, Status, Static Check, Runtime Check, Issues, Timestamp
  - Group by category (API, guides, systems, content-creation)

  **Must NOT do**:
  - Don't start verification yet
  - Don't modify any source docs

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: File listing and table creation is straightforward
  - **Skills**: [`git-master`]
    - `git-master`: For finding all markdown files accurately

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 2, 3)
  - **Blocks**: Tasks 4, 5, 6, 7
  - **Blocked By**: None

  **References**:
  - `docs/README.md` - Existing index structure to follow
  - `glob "**/*.md"` output - Complete file list

  **Acceptance Criteria**:
  ```bash
  # Tracking table created
  test -f .sisyphus/evidence/doc-verification-tracking.md
  # Assert: File exists
  
  # Contains all docs
  wc -l .sisyphus/evidence/doc-verification-tracking.md
  # Assert: > 100 lines (header + all docs)
  ```

  **Commit**: YES
  - Message: `docs: add verification tracking infrastructure`
  - Files: `.sisyphus/evidence/doc-verification-tracking.md`

---

- [ ] 2. Create static analysis verification script

  **What to do**:
  - Create `scripts/verify-doc-apis.sh` that:
    - Extracts API calls from markdown code blocks
    - Compares against `chugget_code_definitions.lua`
    - Reports mismatches
  - Make executable and document usage

  **Must NOT do**:
  - Don't run full verification yet
  - Don't modify docs based on findings

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Bash script creation is focused task
  - **Skills**: []
    - No special skills needed

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 3)
  - **Blocks**: Tasks 4, 5, 6, 7
  - **Blocked By**: None

  **References**:
  - `assets/scripts/chugget_code_definitions.lua` - Source of truth for Lua API bindings
  - `docs/api/lua_api_reference.md` - Example of documented APIs

  **Acceptance Criteria**:
  ```bash
  # Script exists and is executable
  test -x scripts/verify-doc-apis.sh
  # Assert: Executable exists
  
  # Script runs without error on sample doc
  ./scripts/verify-doc-apis.sh docs/api/entity-builder.md 2>&1 | head -5
  # Assert: Output contains analysis results (not bash errors)
  ```

  **Commit**: YES
  - Message: `docs: add static API verification script`
  - Files: `scripts/verify-doc-apis.sh`

---

- [ ] 3. Extract complete pitfalls inventory

  **What to do**:
  - Search all docs for pitfall patterns: "Don't", "WRONG", "pitfall", "gotcha", "caveat", "WARNING", "CRITICAL"
  - Create `.sisyphus/evidence/pitfalls-inventory.md` listing:
    - Source file
    - Pitfall text
    - Category (UI, Physics, Scripting, Combat, etc.)
    - Still relevant? (to be verified)
  - Target: Capture all 290+ pitfall mentions

  **Must NOT do**:
  - Don't consolidate yet (just inventory)
  - Don't remove from source docs
  - Don't judge relevance yet

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Grep and extraction task
  - **Skills**: []
    - No special skills needed

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2)
  - **Blocks**: Task 8
  - **Blocked By**: None

  **References**:
  - `claude.md:132-198` - Existing "Common Mistakes to Avoid" section
  - `docs/guides/UI_PANEL_IMPLEMENTATION_GUIDE.md:999-1013` - 11 documented pitfalls table
  - `docs/api/physics_docs.md` - "Gotchas & FAQs" section

  **Acceptance Criteria**:
  ```bash
  # Inventory created
  test -f .sisyphus/evidence/pitfalls-inventory.md
  # Assert: File exists
  
  # Contains substantial pitfalls
  grep -c "^\|" .sisyphus/evidence/pitfalls-inventory.md
  # Assert: > 100 table rows (pitfalls captured)
  ```

  **Commit**: YES
  - Message: `docs: extract pitfalls inventory from all docs`
  - Files: `.sisyphus/evidence/pitfalls-inventory.md`

---

### Wave 2: Priority System Verification

- [ ] 4. Verify UI/DSL documentation

  **What to do**:
  - Run static analysis on:
    - `docs/api/ui-dsl-reference.md`
    - `docs/guides/UI_PANEL_IMPLEMENTATION_GUIDE.md`
    - `docs/api/ui_helper_reference.md`
    - `docs/api/sprite-panels.md`
    - `docs/api/inventory-grid.md`
    - `docs/api/inventory-grid-quick-reference.md`
    - `docs/api/z-order-rendering.md`
  - Run runtime verification on 5 critical UI examples:
    - Basic DSL vbox/hbox creation
    - Sprite panel with nine-patch
    - Inventory grid basic usage
    - Button click handler
    - Z-order assignment
  - Update tracking table with results
  - Note any API mismatches or runtime errors

  **Must NOT do**:
  - Don't fix any issues found (document only)
  - Don't modify docs
  - Don't expand examples beyond what's documented

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: UI verification requires understanding visual/layout systems
  - **Skills**: [`codebase-teacher`]
    - `codebase-teacher`: For understanding UI patterns in actual codebase

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 5, 6, 7)
  - **Blocks**: Tasks 8, 11
  - **Blocked By**: Tasks 1, 2

  **References**:
  - `docs/api/ui-dsl-reference.md` - Primary UI DSL documentation (369 lines)
  - `docs/guides/UI_PANEL_IMPLEMENTATION_GUIDE.md` - Bulletproof patterns (1088 lines)
  - `assets/scripts/ui/ui_syntax_sugar.lua` - Actual DSL implementation
  - `assets/scripts/ui/player_inventory.lua` - Source of truth for UI patterns
  - `assets/scripts/chugget_code_definitions.lua` - API binding reference

  **Acceptance Criteria**:
  ```bash
  # Build exists for testing
  test -f ./build/raylib-cpp-cmake-template
  # Assert: Build exists
  
  # Static analysis completed
  ./scripts/verify-doc-apis.sh docs/api/ui-dsl-reference.md 2>&1 | grep -c "MISMATCH\|OK"
  # Assert: Output shows analysis ran (contains OK or MISMATCH)
  
  # Tracking table updated
  grep -c "ui-dsl-reference" .sisyphus/evidence/doc-verification-tracking.md
  # Assert: >= 1 (doc is in tracking table with status)
  ```

  **Commit**: NO (groups with Task 14 for timestamp commits)

---

- [ ] 5. Verify Physics documentation

  **What to do**:
  - Run static analysis on:
    - `docs/api/physics_docs.md`
    - `docs/api/lua_quadtree_api.md`
    - `src/systems/physics/steering_readme.md`
  - Run runtime verification on 3 critical physics examples:
    - PhysicsWorld creation
    - Collision tag setup
    - AddCollider basic usage
  - Update tracking table with results
  - Note any API mismatches or runtime errors

  **Must NOT do**:
  - Don't fix any issues found (document only)
  - Don't modify docs

  **Recommended Agent Profile**:
  - **Category**: `ultrabrain`
    - Reason: Physics verification requires understanding complex systems
  - **Skills**: [`codebase-teacher`]
    - `codebase-teacher`: For understanding physics patterns

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 4, 6, 7)
  - **Blocks**: Tasks 8, 11
  - **Blocked By**: Tasks 1, 2

  **References**:
  - `docs/api/physics_docs.md` - Primary physics documentation
  - `src/systems/physics/physics_manager.cpp` - C++ implementation
  - `assets/scripts/chugget_code_definitions.lua:physics.*` - Physics API bindings

  **Acceptance Criteria**:
  ```bash
  # Static analysis completed
  ./scripts/verify-doc-apis.sh docs/api/physics_docs.md 2>&1 | grep -c "MISMATCH\|OK"
  # Assert: Output shows analysis ran
  
  # Tracking table updated
  grep "physics_docs" .sisyphus/evidence/doc-verification-tracking.md | grep -c "Verified\|Failed"
  # Assert: >= 1 (status recorded)
  ```

  **Commit**: NO (groups with Task 14)

---

- [ ] 6. Verify Combat/Wand documentation

  **What to do**:
  - Run static analysis on all 11 combat docs:
    - `docs/systems/combat/ARCHITECTURE.md`
    - `docs/systems/combat/README.md`
    - `docs/systems/combat/QUICK_REFERENCE.md`
    - `docs/systems/combat/INTEGRATION_GUIDE.md`
    - `docs/systems/combat/PROJECTILE_SYSTEM_DOCUMENTATION.md`
    - `docs/systems/combat/PROJECTILE_ARCHITECTURE.md`
    - `docs/systems/combat/WAND_INTEGRATION_GUIDE.md`
    - `docs/systems/combat/WAND_EXECUTION_ARCHITECTURE.md`
    - `docs/systems/combat/wand_cast_feed_integration_steps.md`
    - `docs/systems/combat/wand_README.md`
    - `docs/systems/combat/integration_tutorial_WIP.md`
  - Skip runtime verification (combat system too complex for isolated tests)
  - Update tracking table with results
  - Note any API mismatches

  **Must NOT do**:
  - Don't attempt runtime verification of combat (too integrated)
  - Don't fix any issues found
  - Don't modify docs

  **Recommended Agent Profile**:
  - **Category**: `ultrabrain`
    - Reason: Combat system is complex, needs deep analysis
  - **Skills**: [`codebase-teacher`]
    - `codebase-teacher`: For understanding combat patterns

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 4, 5, 7)
  - **Blocks**: Tasks 8, 11
  - **Blocked By**: Tasks 1, 2

  **References**:
  - `docs/systems/combat/` - All 11 combat documentation files
  - `assets/scripts/combat/` - Combat Lua implementations
  - `assets/scripts/wand/` - Wand system implementations

  **Acceptance Criteria**:
  ```bash
  # All combat docs analyzed
  ls docs/systems/combat/*.md | wc -l
  # Assert: >= 11 docs exist
  
  # Tracking table has combat docs
  grep -c "combat/" .sisyphus/evidence/doc-verification-tracking.md
  # Assert: >= 11 (all combat docs tracked)
  ```

  **Commit**: NO (groups with Task 14)

---

- [ ] 7. Verify remaining API documentation

  **What to do**:
  - Run static analysis on remaining docs/api/ files:
    - `entity-builder.md`, `child-builder.md`
    - `signal_system.md`, `timer_docs.md`, `timer_chaining.md`
    - `text-builder.md`, `hitfx_doc.md`, `particles_doc.md`, `popup.md`
    - `shader-builder.md`, `shader_draw_commands_doc.md`
    - `lua_api_reference.md`, `lua_camera_docs.md`
    - `localization.md`, `save-system.md`, `Q_reference.md`
    - `behaviors.md`, `combat-systems.md`
    - `working_with_sol.md`, `render-groups.md`
  - Update tracking table with results
  - Categorize docs by verification status

  **Must NOT do**:
  - Don't attempt runtime verification on all (too time consuming)
  - Don't fix any issues found
  - Don't modify docs

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Bulk static analysis is straightforward
  - **Skills**: []
    - No special skills needed for grep-based analysis

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 4, 5, 6)
  - **Blocks**: Tasks 8, 11
  - **Blocked By**: Tasks 1, 2

  **References**:
  - `docs/api/` - All API documentation files
  - `assets/scripts/chugget_code_definitions.lua` - API binding reference

  **Acceptance Criteria**:
  ```bash
  # All API docs analyzed
  ls docs/api/*.md | wc -l
  # Assert: >= 30 docs
  
  # Tracking table comprehensive
  grep -c "docs/api/" .sisyphus/evidence/doc-verification-tracking.md
  # Assert: >= 30 (all API docs tracked)
  ```

  **Commit**: NO (groups with Task 14)

---

### Wave 3: Consolidation

- [ ] 8. Create COMMON_PITFALLS.md

  **What to do**:
  - Review pitfalls inventory from Task 3
  - Cross-reference with verification results (Tasks 4-7) to identify obsolete pitfalls
  - Create `docs/guides/COMMON_PITFALLS.md` with structure:
    ```markdown
    # Common Pitfalls Reference
    
    ## Quick Navigation
    - [UI/DSL Pitfalls](#uidsl-pitfalls)
    - [Physics Pitfalls](#physics-pitfalls)
    - [Scripting Pitfalls](#scripting-pitfalls)
    - [Combat Pitfalls](#combat-pitfalls)
    - [Performance Pitfalls](#performance-pitfalls)
    
    ## UI/DSL Pitfalls
    | # | Pitfall | Symptom | Fix | Source |
    |---|---------|---------|-----|--------|
    ...
    ```
  - Include all verified pitfalls organized by category
  - Add source doc cross-references

  **Must NOT do**:
  - Don't remove pitfalls from original source docs
  - Don't include unverified/obsolete pitfalls without marking them
  - Don't exceed 800 lines (if larger, split into sub-documents)

  **Recommended Agent Profile**:
  - **Category**: `writing`
    - Reason: Documentation consolidation is writing-focused
  - **Skills**: []
    - No special skills needed

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 9, 10, 11)
  - **Blocks**: Task 12
  - **Blocked By**: Tasks 3, 4, 5, 6, 7

  **References**:
  - `.sisyphus/evidence/pitfalls-inventory.md` - Complete pitfall inventory
  - `docs/guides/UI_PANEL_IMPLEMENTATION_GUIDE.md:999-1013` - Example pitfall table format
  - `claude.md:132-198` - Existing common mistakes section

  **Acceptance Criteria**:
  ```bash
  # File created
  test -f docs/guides/COMMON_PITFALLS.md
  # Assert: File exists
  
  # Substantial content
  wc -l docs/guides/COMMON_PITFALLS.md | awk '{print $1}'
  # Assert: > 200 lines
  
  # Has all categories
  grep -c "## " docs/guides/COMMON_PITFALLS.md
  # Assert: >= 5 (at least 5 category sections)
  ```

  **Commit**: YES
  - Message: `docs: add consolidated COMMON_PITFALLS.md reference`
  - Files: `docs/guides/COMMON_PITFALLS.md`

---

- [ ] 9. Update claude.md pitfall summary

  **What to do**:
  - Expand "Common Mistakes to Avoid" section in `claude.md`
  - Add top 10-15 most critical pitfalls (one-liners)
  - Add link to full `docs/guides/COMMON_PITFALLS.md`
  - Keep existing content, just enhance and reorganize
  - Add "See Also" section pointing to AGENTS.md

  **Must NOT do**:
  - Don't remove existing content
  - Don't add full pitfall explanations (keep summary)
  - Don't change other sections of claude.md

  **Recommended Agent Profile**:
  - **Category**: `writing`
    - Reason: Documentation editing
  - **Skills**: []
    - No special skills needed

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 8, 10, 11)
  - **Blocks**: Task 12
  - **Blocked By**: Task 8

  **References**:
  - `claude.md:132-198` - Existing common mistakes section
  - `docs/guides/COMMON_PITFALLS.md` - Full reference (from Task 8)

  **Acceptance Criteria**:
  ```bash
  # Common Mistakes section exists and is enhanced
  grep -A 30 "## Common Mistakes" claude.md | grep -c "COMMON_PITFALLS"
  # Assert: >= 1 (link to full reference added)
  
  # More pitfalls than before
  grep -c "^### Don't" claude.md
  # Assert: >= 10 (expanded pitfall count)
  ```

  **Commit**: YES
  - Message: `docs: enhance claude.md common mistakes section`
  - Files: `claude.md`

---

- [ ] 10. Create AGENTS.md knowledge base

  **What to do**:
  - Create hierarchical `AGENTS.md` for `/init-deep` pattern with structure:
    ```markdown
    # AGENTS.md - Knowledge Base
    
    ## Entry Point
    For AI agents: Start with `claude.md` for architecture overview.
    
    ## System Deep-Dives
    ### UI/DSL System
    - Primary: docs/guides/UI_PANEL_IMPLEMENTATION_GUIDE.md
    - Reference: docs/api/ui-dsl-reference.md
    - Pitfalls: docs/guides/COMMON_PITFALLS.md#uidsl-pitfalls
    
    ### Physics System
    - Primary: docs/api/physics_docs.md
    ...
    
    ## Quick References
    - API Cheatsheet: docs/api/lua_api_reference.md
    - Build Commands: README.md
    - Common Pitfalls: docs/guides/COMMON_PITFALLS.md
    
    ## Navigation Map
    [Comprehensive doc tree with descriptions]
    ```
  - Include all priority systems
  - Add navigation map for all docs

  **Must NOT do**:
  - Don't duplicate content from other docs (link instead)
  - Don't create overly complex structure
  - Don't exceed 300 lines

  **Recommended Agent Profile**:
  - **Category**: `writing`
    - Reason: Documentation architecture
  - **Skills**: []
    - No special skills needed

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 8, 9, 11)
  - **Blocks**: Task 12
  - **Blocked By**: None (can start with existing docs)

  **References**:
  - `claude.md` - Primary entry point to link from
  - `docs/README.md` - Existing index structure
  - `/init-deep` skill pattern - Structure to follow

  **Acceptance Criteria**:
  ```bash
  # File created with substantial content
  test -f AGENTS.md && wc -l AGENTS.md | awk '{print $1}'
  # Assert: > 50 lines
  
  # Has system sections
  grep -c "### " AGENTS.md
  # Assert: >= 4 (UI, Physics, Combat, Scripting sections minimum)
  
  # Links to claude.md
  grep -c "claude.md" AGENTS.md
  # Assert: >= 1
  ```

  **Commit**: YES
  - Message: `docs: create AGENTS.md hierarchical knowledge base`
  - Files: `AGENTS.md`

---

- [ ] 11. Create GitHub issues for verification failures

  **What to do**:
  - Review verification results from Tasks 4-7
  - For each failure (API mismatch or runtime error), create GitHub issue:
    - Title: `[Doc Verification] {doc name}: {brief issue}`
    - Label: `doc-verification`
    - Body: Include doc path, specific example that failed, expected vs actual behavior
  - Link issues in tracking table

  **Must NOT do**:
  - Don't fix the issues (just document)
  - Don't create issues for minor style problems (only functional failures)
  - Don't create duplicate issues

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: GitHub CLI operations are straightforward
  - **Skills**: [`git-master`]
    - `git-master`: For GitHub operations

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 8, 9, 10)
  - **Blocks**: Task 15
  - **Blocked By**: Tasks 4, 5, 6, 7

  **References**:
  - `.sisyphus/evidence/doc-verification-tracking.md` - Verification results
  - GitHub CLI documentation for issue creation

  **Acceptance Criteria**:
  ```bash
  # Issues created with correct label
  gh issue list --label "doc-verification" --json number --jq 'length'
  # Assert: >= 0 (may be 0 if all docs pass, but command works)
  
  # Tracking table updated with issue links
  grep -c "github.com/.*issues" .sisyphus/evidence/doc-verification-tracking.md
  # Assert: Matches number of failures found
  ```

  **Commit**: NO (issues are external)

---

### Wave 4: Index & Finalization

- [ ] 12. Update docs/README.md index

  **What to do**:
  - Add missing docs to index:
    - 9 docs in `src/systems/**/*.md` not currently indexed
    - Any new docs from this work (COMMON_PITFALLS.md, etc.)
  - Add "See Also" cross-references between related docs
  - Add link to AGENTS.md
  - Verify all links work

  **Must NOT do**:
  - Don't reorganize existing structure (just add missing items)
  - Don't move any docs
  - Don't remove existing links

  **Recommended Agent Profile**:
  - **Category**: `writing`
    - Reason: Index editing
  - **Skills**: []
    - No special skills needed

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 13, 14)
  - **Blocks**: Task 15
  - **Blocked By**: Tasks 8, 9, 10

  **References**:
  - `docs/README.md` - Current index (175 lines)
  - `.sisyphus/evidence/doc-verification-tracking.md` - Complete doc list
  - `AGENTS.md` - New knowledge base to link

  **Acceptance Criteria**:
  ```bash
  # Index includes src/systems docs
  grep -c "src/systems" docs/README.md
  # Assert: >= 5 (previously unindexed docs now included)
  
  # Index links to AGENTS.md
  grep -c "AGENTS.md" docs/README.md
  # Assert: >= 1
  
  # Index links to COMMON_PITFALLS
  grep -c "COMMON_PITFALLS" docs/README.md
  # Assert: >= 1
  ```

  **Commit**: YES
  - Message: `docs: update README.md index with complete doc list`
  - Files: `docs/README.md`

---

- [ ] 13. Verify all internal links

  **What to do**:
  - Extract all internal markdown links from all docs
  - Verify each link target exists
  - Create report of broken links
  - Fix any broken links found

  **Must NOT do**:
  - Don't change link targets (only fix if clearly broken)
  - Don't add new links

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Link checking is automated
  - **Skills**: []
    - No special skills needed

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 12, 14)
  - **Blocks**: Task 15
  - **Blocked By**: Task 12

  **References**:
  - All markdown files in project
  - Standard markdown link syntax: `[text](path)`

  **Acceptance Criteria**:
  ```bash
  # Link check script runs
  grep -roh "\[.*\](.*\.md)" docs/ | while read link; do
    path=$(echo "$link" | grep -oP '(?<=\().*(?=\))')
    test -f "docs/$path" || test -f "$path" || echo "BROKEN: $link"
  done | grep -c "BROKEN"
  # Assert: = 0 (no broken links)
  ```

  **Commit**: YES (if fixes needed)
  - Message: `docs: fix broken internal links`
  - Files: Any docs with fixed links

---

- [ ] 14. Add verification timestamps to all docs

  **What to do**:
  - For each doc in tracking table with status "Verified":
    - Add timestamp header: `<!-- Verified: 2026-01-30 against commit HASH -->`
    - Place at end of file (before any existing footer)
  - Get current commit hash for timestamp
  - Update tracking table to mark timestamp added

  **Must NOT do**:
  - Don't add timestamps to docs that failed verification
  - Don't change doc content (only add timestamp comment)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Bulk file editing with sed/awk
  - **Skills**: [`git-master`]
    - `git-master`: For getting commit hash

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 12, 13)
  - **Blocks**: Task 15
  - **Blocked By**: Tasks 4, 5, 6, 7

  **References**:
  - `.sisyphus/evidence/doc-verification-tracking.md` - List of verified docs
  - `git rev-parse HEAD` - Current commit hash

  **Acceptance Criteria**:
  ```bash
  # Timestamps added to verified docs
  grep -r "<!-- Verified:" docs/ | wc -l
  # Assert: >= 50 (substantial portion of docs have timestamps)
  
  # Timestamps have correct format
  grep -r "<!-- Verified: 2026-" docs/ | head -1
  # Assert: Output matches expected format
  ```

  **Commit**: YES
  - Message: `docs: add verification timestamps to all verified docs`
  - Files: All verified docs

---

- [ ] 15. Final validation and summary

  **What to do**:
  - Run all acceptance criteria checks from previous tasks
  - Create final summary report in `.sisyphus/evidence/documentation-foundation-summary.md`:
    - Total docs verified
    - Total pitfalls consolidated
    - GitHub issues created
    - Broken links fixed
    - Coverage statistics
  - Update tracking table with final status

  **Must NOT do**:
  - Don't make any new changes
  - This is validation only

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Reporting and validation
  - **Skills**: []
    - No special skills needed

  **Parallelization**:
  - **Can Run In Parallel**: NO (final task)
  - **Parallel Group**: Sequential (after Wave 4)
  - **Blocks**: None
  - **Blocked By**: Tasks 12, 13, 14

  **References**:
  - All acceptance criteria from Tasks 1-14
  - `.sisyphus/evidence/doc-verification-tracking.md` - Final tracking data

  **Acceptance Criteria**:
  ```bash
  # Summary report created
  test -f .sisyphus/evidence/documentation-foundation-summary.md
  # Assert: File exists
  
  # All verification timestamps present
  grep -r "<!-- Verified:" docs/ | wc -l
  # Assert: >= 80 (majority of docs verified)
  
  # COMMON_PITFALLS.md complete
  wc -l docs/guides/COMMON_PITFALLS.md | awk '{print $1}'
  # Assert: > 200
  
  # AGENTS.md complete
  wc -l AGENTS.md | awk '{print $1}'
  # Assert: > 50
  
  # Zero broken links
  grep -roh "\[.*\](.*\.md)" docs/ | while read link; do
    path=$(echo "$link" | grep -oP '(?<=\().*(?=\))')
    test -f "docs/$path" || test -f "$path" || echo "BROKEN"
  done | grep -c "BROKEN"
  # Assert: = 0
  ```

  **Commit**: YES
  - Message: `docs: complete documentation foundation - verification summary`
  - Files: `.sisyphus/evidence/documentation-foundation-summary.md`

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `docs: add verification tracking infrastructure` | `.sisyphus/evidence/doc-verification-tracking.md` | File exists |
| 2 | `docs: add static API verification script` | `scripts/verify-doc-apis.sh` | Script executable |
| 3 | `docs: extract pitfalls inventory from all docs` | `.sisyphus/evidence/pitfalls-inventory.md` | > 100 pitfalls |
| 8 | `docs: add consolidated COMMON_PITFALLS.md reference` | `docs/guides/COMMON_PITFALLS.md` | > 200 lines |
| 9 | `docs: enhance claude.md common mistakes section` | `claude.md` | Has PITFALLS link |
| 10 | `docs: create AGENTS.md hierarchical knowledge base` | `AGENTS.md` | > 50 lines |
| 12 | `docs: update README.md index with complete doc list` | `docs/README.md` | Has all docs |
| 13 | `docs: fix broken internal links` | Various | 0 broken links |
| 14 | `docs: add verification timestamps to all verified docs` | All docs | Timestamps present |
| 15 | `docs: complete documentation foundation - verification summary` | Summary file | All checks pass |

---

## Success Criteria

### Verification Commands
```bash
# All docs verified
grep -r "<!-- Verified:" docs/ | wc -l  # Expected: >= 80

# Pitfalls consolidated
wc -l docs/guides/COMMON_PITFALLS.md  # Expected: > 200

# AGENTS.md created
wc -l AGENTS.md  # Expected: > 50

# No broken links
grep -roh "\[.*\](.*\.md)" docs/ | while read link; do
  path=$(echo "$link" | grep -oP '(?<=\().*(?=\))')
  test -f "docs/$path" || test -f "$path" || echo "BROKEN"
done | grep -c "BROKEN"  # Expected: 0

# GitHub issues for failures
gh issue list --label "doc-verification" --json number --jq 'length'  # Expected: >= 0
```

### Final Checklist
- [ ] All "Must Have" present (verified docs, pitfalls, AGENTS.md, timestamps, issues)
- [ ] All "Must NOT Have" absent (no code changes, no doc deletions, no moved files)
- [ ] Build still works: `just build-debug` succeeds
- [ ] All acceptance criteria pass
