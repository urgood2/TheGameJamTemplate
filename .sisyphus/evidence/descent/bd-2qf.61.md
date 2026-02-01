# bd-2qf.61 - H3 5-run soak + timing evidence

Date: 2026-02-01
Host: linux (container)

Goal: Run 5 complete playthroughs (seeds 101-105), record 3+ timed runs, compare to 15-20 min target.

## Attempts

### Build/run attempt 1
- Command: `./build-release/raylib-cpp-cmake-template`
- Result: `exec format error`
- Note: `file build-release/raylib-cpp-cmake-template` reports Mach-O 64-bit arm64 (macOS) binary, not runnable here.

### Build/run attempt 2 (native build)
- Command: `cmake -B build-native -DCMAKE_BUILD_TYPE=Release`
- Result: `cmake: command not found`

### Install cmake attempt (system)
- Command: `apt-get update`
- Result: permission denied (no root)

### Install cmake attempt (user)
- Command: `python3 -m pip install --user cmake`
- Result: PEP 668 externally-managed environment; venv creation fails due to missing `python3-venv`.

## Status
Unable to build or run native binary in this environment due to missing `cmake` (and inability to install it without root/venv). The only existing binary is macOS arm64 and not runnable on this host. Therefore, soak/timing runs could not be performed here.

## Next steps for completion
- Provide Linux build tooling (cmake + C++ toolchain) or a Linux binary.
- Then run 5 complete playthroughs with seeds 101-105 and record timings for at least 3 runs.

