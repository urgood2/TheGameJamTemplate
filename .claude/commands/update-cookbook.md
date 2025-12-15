# Update Cookbook

Synchronize the Lua API cookbook with the current codebase by auditing existing recipes and discovering new APIs to document.

## Instructions

### Phase 1: Audit Existing Recipes

1. **Read the cookbook** at `docs/lua-cookbook/cookbook.md`

2. **Extract all recipes** by parsing for this pattern:
   ```markdown
   ### Recipe Name
   \label{recipe:...}

   **When to use**: ...

   ```lua
   ...
   ```

   **Source**: `path/to/file.lua:123`
   ```

3. **For each recipe, verify**:
   - **File path exists**: Check that `Source:` reference points to a real file
   - **Function/API exists**: Grep for function names in code examples
   - **Pattern still valid**: Verify builder methods, module exports match codebase

4. **Categorize recipes**:
   - Valid (no changes needed)
   - Fixable (path moved, signature changed - can auto-repair)
   - Deprecated (API removed entirely - mark with `<!-- DEPRECATED: reason -->`)

### Phase 2: Discover New APIs

5. **Scan Lua core modules**:
   ```bash
   ls assets/scripts/core/*.lua
   ```
   For each file, extract:
   - Module exports (`return ModuleName`)
   - Public functions (`function M.name()` or `function ModuleName.name()`)
   - Global functions (`_G.name = ...`)

   Skip private functions (prefixed with `_`).

6. **Scan data definitions**:
   ```bash
   ls assets/scripts/data/*.lua
   ```
   Look for new data structure patterns not yet documented.

7. **Scan C++ bindings**:
   ```bash
   grep -n "lua.set_function\|lua.new_usertype" src/systems/scripting/scripting_functions.cpp
   ```
   Extract all bound function names and types.

8. **Check recent commits** for API changes:
   ```bash
   git log --since="2025-01-01" --oneline -- "assets/scripts/core/*.lua" "src/systems/scripting/*.cpp"
   ```

9. **Cross-reference** discovered APIs against documented recipes. The difference = undocumented APIs needing new recipes.

### Phase 3: Update Cookbook

10. **Fix outdated recipes** in-place:
    - Update code examples to match current API
    - Update `Source:` references with correct paths/line numbers
    - Preserve `\label{}` tags for cross-references

11. **Add new recipes** for undocumented APIs using this format:
    ```markdown
    ### <API Name>
    \label{recipe:<api-kebab-case>}

    **When to use**: <1-2 sentence description based on code/comments>

    ```lua
    -- Example from codebase or minimal working example
    ```

    **Source**: `path/to/file.lua:123`

    **Gotcha**: <Common mistake if identifiable>
    ```

12. **Place new recipes** in appropriate chapters:
    | File location | Target chapter |
    |---------------|----------------|
    | `core/entity_builder.lua` | Chapter 4: Entity Creation |
    | `core/physics_builder.lua` | Chapter 5: Physics |
    | `core/shader_builder.lua` | Chapter 6: Rendering & Shaders |
    | `core/draw.lua` | Chapter 6: Rendering & Shaders |
    | `core/timer.lua` | Chapter 3: Core Foundations |
    | `core/imports.lua` | Chapter 3: Core Foundations |
    | `combat/*.lua` | Chapter 8: Combat & Projectiles |
    | `wand/*.lua` | Chapter 9: Wand & Cards |
    | `data/*.lua` | Chapter 11: Data Definitions |
    | C++ bindings | Chapter 13: Appendix A |

13. **Update Task Index** (Chapter 2) with entries for each new recipe:
    ```markdown
    | I want to... | See |
    |--------------|-----|
    | <task description> | p.\pageref{recipe:<id>} |
    ```

### Phase 4: Finalize

14. **Build the PDF**:
    ```bash
    cd docs/lua-cookbook && ./build.sh
    ```
    If build fails, report the error and do NOT commit.

15. **Commit changes**:
    ```bash
    git add docs/lua-cookbook/cookbook.md docs/lua-cookbook/output/lua-cookbook.pdf
    git commit -m "docs(cookbook): sync with codebase - <N> updated, <M> added"
    ```

16. **Report results**:
    ```
    Cookbook sync complete

    Audit Results:
      - X recipes validated
      - Y recipes updated (path/signature fixes)
      - Z recipes deprecated

    Discovery Results:
      - N new APIs documented:
        - API name -> Chapter
        - ...

    PDF rebuilt: docs/lua-cookbook/output/lua-cookbook.pdf
    Committed: <hash>
    ```

## Edge Cases

- **No changes needed**: Report "Cookbook is up to date" and exit without committing
- **Build fails**: Report error with details, do not commit partial changes
- **API removed entirely**: Comment out recipe with `<!-- DEPRECATED: <reason> -->`, don't delete
- **Ambiguous chapter placement**: Default to Chapter 13: Appendix A (Function Index)
- **Large cookbook file**: Read in chunks if needed, process systematically

## Output

Report what was audited, updated, and added. Include the commit hash for easy review with `git show`.
