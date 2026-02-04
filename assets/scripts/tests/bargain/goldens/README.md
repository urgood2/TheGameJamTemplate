# Bargain Golden Policy

This directory stores golden digests for deterministic script runs.

Policy
- A golden update must include a one-line rationale file next to the digest.
- A golden update must be validated by two consecutive runs that match.
- Update both the digest file and its rationale in version control.

Workflow
1) Run the script runner twice with the same seed and confirm matching digests.
2) Write the digest to the golden file under `goldens/scripts/`.
3) Update the adjacent `*.reason.txt` with a single-line explanation.
4) Re-run `lua assets/scripts/tests/run_bargain_tests.lua` to verify.
5) Commit both the digest and rationale updates.
