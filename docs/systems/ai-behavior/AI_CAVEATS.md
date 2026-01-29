Looks like when a status bit changes during an action, the action isn't continued the next tick - rather, the action is interrupted and the AI re-evaluates what to do next in update_goap.
<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
