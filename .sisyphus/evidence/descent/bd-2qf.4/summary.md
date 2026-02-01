# bd-2qf.4: [Descent] A4 Just recipes for Descent tests

## Implementation Summary

Added three new recipes to `Justfile` for running Descent tests.

## Files Modified

1. **Justfile** - Added recipes after `test-ui-sizing`:

### New Recipes

1. **`just test-descent`**
   - Basic test execution
   - Exit 0 = pass, Exit 1 = fail/timeout/error

2. **`just test-descent-log`**
   - Same as above but captures output to `/tmp/descent_tests.log` via tee
   - Reports exit code

3. **`just test-descent-headless`**
   - Linux-only: uses xvfb-run for headless execution
   - Checks for xvfb-run availability with helpful error message
   - Captures output to `/tmp/descent_tests.log`

## Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| `just test-descent` runs §1.5 | ✅ Implemented |
| `just test-descent-headless` for Linux xvfb | ✅ Implemented |
| Helpful error if xvfb-run missing | ✅ Prints install instructions |

## Usage

```bash
# Build first
just build-debug

# Run tests
just test-descent

# Run with output capture
just test-descent-log

# Run headless on Linux
just test-descent-headless
```

## Agent

- Agent: RedEagle (claude-code/opus-4.5)
- Date: 2026-02-01
