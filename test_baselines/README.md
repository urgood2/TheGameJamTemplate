# Test Baselines

## Visual Quarantine

Visual test quarantines live in `test_baselines/visual_quarantine.json`.
The file is read by `assets/scripts/tests/test_runner.lua` when visual tests run.

### Schema

Top-level fields:
- `schema_version`: string, current version `"1.0"`.
- `updated_at`: ISO timestamp for last update.
- `default_expiry_days`: number of days to apply when calculating expiries.
- `quarantined_tests`: array of quarantine entries.

Each quarantine entry must include:
- `test_id`: full test identifier.
- `reason`: why the test is flaky.
- `owner`: responsible person or team (use @mention).
- `issue_link`: tracking issue URL.
- `quarantined_at`: ISO timestamp when added.
- `expires_at`: ISO timestamp for expiry.
- `platforms`: array of affected platforms or `["*"]`.

Optional fields:
- `renewal_count`: integer count of renewals.
- `max_renewals`: integer cap for renewals.

### Renewal Policy

- Default expiry is 14 days.
- To renew, update `expires_at`, increment `renewal_count`, and add a comment to the linked issue explaining the delay.
- Max renewals is 2 (42 days total). After max renewals, remove the quarantine or fix the test.

### CI Modes

Set `TEST_QUARANTINE_MODE` to control behavior:
- `pr` (default in CI): quarantined visual failures are warnings.
- `nightly` or `verify`: quarantined visual failures are blocking errors.
- `local`: behaves like `pr` for warnings.

Expired quarantines are always blocking.

Override the quarantine file path with `TestRunner.set_quarantine_path(path)` when running tests programmatically.
