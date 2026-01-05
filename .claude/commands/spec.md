---
description: Thoroughly flesh out a feature spec through iterative questioning, then write to file
model: opus
---

# Spec Writer

$ARGUMENTS

Thoroughly flesh out every aspect of a feature specification through iterative questioning, then write it to a file.

**IMPORTANT**: Always use extended thinking (ultrathink) when running this command. Think deeply about each question, the user's answers, and what follow-up questions would uncover the most important details.

## Instructions

### Phase 1: Initial Understanding

1. **Ask for the feature overview** using AskUserQuestion:
   - "What is the core feature you want to specify?"
   - Options: Let user describe freely (use "Other" option)

2. **Clarify the scope** with targeted questions:
   - Feature type: New feature / Enhancement / Refactor / Bug fix / System design
   - Scope: Single file / Multiple files / Cross-system / Architecture change
   - Priority: Critical path / Nice to have / Exploratory

### Phase 2: Deep Dive Questions

For each category below, use AskUserQuestion to extract details. Ask 2-4 questions per category, adapting based on prior answers.

#### 2.1 Goals & Motivation
- What problem does this solve?
- Who benefits from this feature?
- What does success look like?
- What happens if we don't build this?

#### 2.2 User-Facing Behavior
- What does the user see/interact with?
- What triggers this feature?
- What feedback does the user receive?
- Walk through the happy path step by step

#### 2.3 Edge Cases & Error Handling
- What can go wrong?
- How should errors be communicated?
- What are the boundary conditions?
- What happens with invalid input?

#### 2.4 Technical Constraints
- What existing systems does this touch?
- Are there performance requirements?
- What dependencies does this have?
- Are there platform-specific considerations (web, native)?

#### 2.5 Data & State
- What data needs to be stored?
- How does state change over time?
- What needs to persist vs. be ephemeral?
- Are there sync/race condition concerns?

#### 2.6 Integration Points
- What events should be emitted?
- What existing APIs should be reused?
- What new APIs need to be exposed?
- How does this interact with existing features?

#### 2.7 Non-Goals & Scope Boundaries
- What is explicitly OUT of scope?
- What might seem related but should be separate work?
- What are we intentionally NOT solving?

#### 2.8 Acceptance Criteria
- How do we know when this is done?
- What tests would verify correctness?
- What would a reviewer check?

### Phase 3: Synthesis

3. **Review all answers** and identify:
   - Contradictions or ambiguities
   - Missing details that need follow-up
   - Implicit assumptions that should be explicit

4. **Ask follow-up questions** for any gaps discovered.

5. **Propose the spec structure** to the user:
   - "Based on our discussion, here's the outline I'll use..."
   - Let user approve or adjust

### Phase 4: Write the Spec

6. **Determine output location**:
   - Ask: "Where should I save this spec?"
   - Suggest: `docs/specs/<feature-name>-spec.md` or `docs/plans/<date>-<feature-name>.md`

7. **Write the spec file** using this template:

```markdown
# <Feature Name> Specification

**Status**: Draft | Ready for Review | Approved
**Created**: <date>
**Author**: Claude + <user>

## Overview

<2-3 sentence summary of the feature>

## Motivation

### Problem Statement
<What problem does this solve?>

### Goals
<Bulleted list of goals>

### Non-Goals
<What is explicitly out of scope>

## Detailed Design

### User-Facing Behavior
<Step-by-step description of how users interact with this>

### Technical Approach
<How will this be implemented at a high level>

### Data Model
<What data structures, state, or storage is needed>

### API / Events
<New or modified APIs, signals emitted>

## Edge Cases & Error Handling

| Scenario | Expected Behavior |
|----------|-------------------|
| <edge case 1> | <how to handle> |
| <edge case 2> | <how to handle> |

## Integration Points

- <System 1>: <how it integrates>
- <System 2>: <how it integrates>

## Acceptance Criteria

- [ ] <Criterion 1>
- [ ] <Criterion 2>
- [ ] <Criterion 3>

## Open Questions

<Any unresolved questions that emerged>

## Implementation Notes

<Any helpful hints for implementation, gotchas to watch for>
```

### Phase 5: Finalize

8. **Read back key sections** to the user for final confirmation

9. **Commit the spec** (if user approves):
   ```bash
   git add <spec-file>
   git commit -m "docs(spec): add <feature-name> specification"
   ```

10. **Report completion**:
    ```
    Spec created: <path>

    Summary:
    - <N> questions asked across <M> categories
    - Key decisions documented: <list>
    - Open questions remaining: <count>

    Next steps: Review spec, then use /superpowers:write-plan to create implementation tasks
    ```

## Questioning Strategies

### Ask Good Questions
- **Be specific**: "What happens when X?" not "Any edge cases?"
- **Offer examples**: "Like A, B, or C?" helps anchor thinking
- **Challenge assumptions**: "You mentioned X - does that mean Y?"
- **Explore alternatives**: "Have you considered Z approach?"

### Use Multi-Select for Lists
When gathering multiple items (features, constraints, criteria), use `multiSelect: true`.

### Batch Related Questions
Use the AskUserQuestion tool's ability to ask up to 4 questions at once for related topics.

### Know When to Stop
- User says "I don't know" → Document as open question
- User says "Doesn't matter" → Document the flexibility
- Answers become repetitive → Move to next category

## Edge Cases

- **User wants to skip categories**: Ask which are most important, focus there
- **Spec already exists**: Offer to update/extend existing spec
- **Feature is too vague**: Start with Phase 1 only, then pause for user to think
- **Feature is well-defined**: Quickly confirm details, spend time on edge cases
- **User changes mind mid-spec**: Update earlier sections, note the evolution

## Thinking Guidelines

This command requires deep thinking. For each phase:

1. **Before asking questions**: Think about what you DON'T know yet
2. **After each answer**: Consider implications and follow-up questions
3. **During synthesis**: Look for logical gaps and contradictions
4. **While writing**: Ensure every claim is backed by user input

Do NOT rush through questions. Quality specs prevent wasted implementation time.
