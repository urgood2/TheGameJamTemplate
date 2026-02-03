# Test Mode CLI Contract

All flags are optional unless noted. Defaults apply when flags are omitted.

**Core Flags**
- `--test-mode`: Enable all test systems.
- `--headless`: Offscreen or hidden rendering path for CI.
- `--test-script <path>`: Run one test file.
- `--test-suite <dir>`: Discover and run all tests under directory.
- `--list-tests`: Discover tests, print stable full names, exit 0.
- `--list-tests-json <path>`: Write test list JSON for orchestrator consumption.
- `--test-filter <glob_or_regex>`: Run matching tests only.
- `--run-test-id <id>`: Run exactly one test by stable id; error if not exactly one match.
- `--run-test-exact <full_name>`: Run exactly one test by full name; error if not exactly one match.
- `--exclude-tag <tag>`: Exclude tests tagged with `tag`.
- `--include-tag <tag>`: Include tests tagged with `tag`.
- `--seed <u32>`: Default `12345`.
- `--fixed-fps <int>`: Default `60`, forces fixed timestep.
- `--resolution <WxH>`: Default `1280x720`.
- `--allow-network <mode>`: Default `deny`, allowed values `deny|localhost|any`.

`--test-script` and `--test-suite` are mutually exclusive and must exit `2` when both are provided.
`--test-filter` must define deterministic matching. Accept glob by default and support a `regex:` prefix to force regex.
`--exclude-tag` and `--include-tag` may be provided multiple times.

**Output Paths**
- `--artifacts <dir>`: Default `tests/out/<run_id>/artifacts`.
- `--report-json <path>`: Default `tests/out/<run_id>/report.json`.
- `--report-junit <path>`: Default `tests/out/<run_id>/report.junit.xml`.

All paths must be validated via `path_sandbox` and written via `artifact_store` atomically.
Report fields must store relative paths under the run root.

**Baselines**
- `--update-baselines`: Accept missing or mismatched baselines by writing actual output to staging.
- `--fail-on-missing-baseline`: Default `true`, ignored when `--update-baselines` is set.
- `--baseline-key <key>`: Default auto-detected from renderer or colorspace.
- `--baseline-write-mode <mode>`: Default `deny`, allowed values `deny|stage|apply`.
- `--baseline-staging-dir <dir>`: Default `tests/baselines_staging`.
- `--baseline-approve-token <token>`: Default empty; if set, require env var `E2E_BASELINE_APPROVE=<token>`.

`baseline-write-mode` meanings:
`deny` never writes baselines, `stage` writes to `tests/baselines_staging`, `apply` writes to `tests/baselines`.
Baseline keys should follow `<backend>_<dynamic_range>_<colorspace>` and be recorded in `run_manifest.json` and `report.json.run.baseline_key`.

**Sharding and Timeouts**
- `--shard <n>`: Default `1`.
- `--total-shards <k>`: Default `1`.
- `--timeout-seconds <int>`: Default `600`, hard kill to avoid hung CI.
- `--default-test-timeout-frames <int>`: Default `1800`.
- `--failure-video <mode>`: Default `off`, allowed values `off|on`.
- `--failure-video-frames <n>`: Default `180`.

Sharding must be deterministic: order discovered tests stably after filters and tags, then include tests where `(index % total_shards) == (shard - 1)`.

**Retries and Flake Policy**
- `--retry-failures <n>`: Default `0`.
- `--allow-flaky`: Default `false`.
- `--auto-audit-on-flake`: Default `false`.
- `--flake-artifacts`: Default `true`.

**Suite Control and Hygiene**
- `--run-quarantined`: Default `false`.
- `--fail-fast`: Default `false`.
- `--max-failures <n>`: Default `0`, `0` means unlimited.
- `--shuffle-tests`: Default `false`.
- `--shuffle-seed <u32>`: Default derived from `--seed`.
- `--test-manifest <path>`: Default `tests/test_manifest.json`.

**RNG Scope**
- `--rng-scope <scope>`: Default `test`, allowed values `test|run`.

`test` reseeds deterministic RNG streams per test using `hash(seed, test_id)`.
`run` uses a single global RNG seed for the whole run.

**Renderer Control**
- `--renderer <mode>`: Default `offscreen`, allowed values `null|offscreen|windowed`.

`--headless` should imply `--renderer=offscreen` unless explicitly overridden.
If `--renderer=null`, screenshot APIs must report `capability_missing`.

**Determinism Audit**
- `--determinism-audit`: Default `false`.
- `--determinism-audit-runs <n>`: Default `2`.
- `--determinism-audit-scope <scope>`: Default `test_api`, allowed values `test_api|engine|render_hash`.
- `--determinism-violation <mode>`: Default `fatal`, allowed values `fatal|warn`.

Network violations when `--allow-network=deny|localhost` must surface as determinism violations.

**Log Gating**
- `--fail-on-log-level <level>`: Default empty, fail if logs at or above level occur during a test.
- `--fail-on-log-category <glob>`: Default empty, optional category filter.

Log level ordering should be explicit and normalized, for example `trace<debug<info<warn<error<fatal`.

**Input Record and Replay**
- `--record-input <path>`: Default empty, record input events to JSONL.
- `--replay-input <path>`: Default empty, replay a recorded input trace.

**Isolation**
- `--isolate-tests <mode>`: Default `none`, allowed values `none|process-per-file|process-per-test`.

In CI, `process-per-test` is recommended through the supervisor so a crash only kills one test.

**Lua Sandbox Control**
- `--lua-sandbox <mode>`: Default `on`, allowed values `on|off`.

**Performance**
- `--perf-mode <mode>`: Default `off`, allowed values `off|collect|enforce`.
- `--perf-budget <path>`: Default empty, JSON budget file.
- `--perf-trace <path>`: Default empty, write Chrome Trace JSON for the run.

**Exit Codes**
| Code | Meaning |
| --- | --- |
| `0` | All tests passed and no gating policy violations |
| `1` | One or more tests failed, including gating policy violations |
| `2` | Harness or configuration error, including invalid flags or schema violations |
| `3` | Timeout or watchdog abort |
| `4` | Crash or fatal error |

**Behavior Rules**
- `--test-mode` with neither `--test-script` nor `--test-suite` loads `assets/scripts/tests/framework/bootstrap.lua` and defaults to `--test-suite assets/scripts/tests/e2e`.
- Unknown or invalid flags print usage and exit `2`.
- All artifact and report paths must be created if missing, and path traversal outside approved roots is rejected.
- Approved write roots: `tests/out/**`, `tests/baselines_staging/**`, and `tests/baselines/**` only with explicit apply token.
- Approved read roots: `assets/**`, `tests/baselines/**`, `tests/baselines_staging/**`, `assets/scripts/tests/fixtures/**`.
