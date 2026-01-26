# Decisions - UI Shader Pipeline Isolation Refactor

## [2026-01-26T10:07:04.095Z] Session started
Session ID: ses_4063a9284ffeikZaHRtkL0Qv63

## [2026-01-26] Task 4 - ObjectAttachedToUITag Investigation

### Root Cause Analysis
`ObjectAttachedToUITag` is a marker that **excludes entities from normal rendering passes**.

**Code Evidence:**
- `game.cpp:2063`: Text rendering excludes `ObjectAttachedToUITag`
- `game.cpp:2090`: Sprite rendering excludes `ObjectAttachedToUITag`
- `game.cpp:2135`: RenderLocalCallback rendering excludes `ObjectAttachedToUITag`

**Purpose:**
- Prevents "double rendering" of entities attached to UI elements
- Objects with this tag are rendered ONLY when their parent UI element renders them
- Used for text, sprites, and animations that are children of UI boxes

### Why It Conflicts with ShaderPipelineComponent
When a draggable card (or any UI element) has:
- `ShaderPipelineComponent` - expects to be rendered via shader pipeline
- `ObjectAttachedToUITag` - explicitly excluded from all rendering passes

Result: Entity is never rendered at all (excluded from both normal and shader rendering)

### Decision: Working As Designed
This is **NOT a bug** - it's correct behavior:
1. `ObjectAttachedToUITag` means "I am a child object, render me through my parent"
2. `ShaderPipelineComponent` means "I am a standalone entity with shaders"
3. These concepts are mutually exclusive by design

### Correct Usage
- **Draggable cards with shaders**: Do NOT add `ObjectAttachedToUITag`
- **Text/sprites inside UI boxes**: DO add `ObjectAttachedToUITag` (rendered by parent)
- **Standalone UI elements**: Never need `ObjectAttachedToUITag`

### Documentation Update Required
Update UI_PANEL_IMPLEMENTATION_GUIDE.md to clarify this is by design, not a bug.
