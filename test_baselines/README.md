# Visual Baselines

Visual baselines are stored under:

```
test_baselines/screenshots/<platform>/<renderer>/<resolution>/
```

## Recording Baselines

Baselines are recorded only when explicitly requested:

```lua
local TestRunner = require("test.test_runner")
TestRunner.run({ record_baselines = true })
```

Baselines are never deleted automatically. Use the size checker before committing changes:

```bash
python scripts/check_baseline_size.py
```

## Tolerances

Per-test tolerances live in `test_baselines/visual_tolerances.json`.
Use `default` unless a test needs a tighter/looser threshold.

## Quarantine

If a visual test is flaky, add it to `test_baselines/visual_quarantine.json` with:
- reason
- owner
- issue/task link
- expiration date

Quarantined tests still run, but should not fail PR CI until resolved.
