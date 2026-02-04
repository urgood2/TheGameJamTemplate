# Script Tests

## Tooling setup

Python script unit tests (deterministic, no engine required):

```sh
python3 -m pytest -q scripts/tests
```

Or via the helper (includes CI-friendly log prefixes):

```sh
scripts/run_pytests.sh
```
