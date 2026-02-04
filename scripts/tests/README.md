# Scripts Unit Tests

Unit tests for Python automation scripts in TheGameJamTemplate.

## Running Tests

```bash
# Quick run
pytest -q scripts/tests

# With coverage
pytest scripts/tests --cov=scripts --cov-report=term-missing

# With verbose output
pytest scripts/tests -v

# Run specific test file
pytest scripts/tests/test_sample.py

# Run specific test
pytest scripts/tests/test_sample.py::TestFixtureExamples::test_tmp_path_fixture
```

## Test Conventions

- **Location**: All tests live in `scripts/tests/`
- **Naming**: Test files must be named `test_<module>.py`
- **Classes**: Test classes must be named `Test*`
- **Functions**: Test functions must be named `test_*`
- **Determinism**: Tests must be deterministic (no network, no engine)

## Available Fixtures

See `conftest.py` for all shared fixtures:

| Fixture | Description |
|---------|-------------|
| `tmp_path` | Built-in pytest fixture for temp directory |
| `project_root` | Path to repository root |
| `scripts_dir` | Path to `scripts/` directory |
| `assets_dir` | Path to `assets/` directory |
| `temp_script` | Temporary Lua script file |
| `mock_project_structure` | Mock project layout for testing |

## Writing New Tests

1. Create `test_<module>.py` in `scripts/tests/`
2. Import fixtures from conftest
3. Write deterministic tests

Example:
```python
def test_my_function(tmp_path):
    # Arrange
    input_file = tmp_path / "input.txt"
    input_file.write_text("test data")

    # Act
    result = my_function(input_file)

    # Assert
    assert result == expected
```

## CI Integration

When run via `check_all` or CI, output follows this format:
```
[PYTEST] Running scripts unit tests...
[PYTEST] PASS: 8 tests
```

Or on failure:
```
[PYTEST] Running scripts unit tests...
[PYTEST] FAIL: Tests failed
<test output>
```
