# Crash reporting & player debugging

This project now ships a lightweight crash reporter that works in both desktop and web builds.

- What gets captured: stack trace (native or Emscripten callstack), recent log ring buffer (default 200 entries), build type/platform/thread id, and a reason string.
- Where reports go:
  - Desktop: `crash_reports/crash_report_<timestamp>.json` beside the executable/CWD.
  - Web: a JSON download is triggered automatically (and for manual captures) with the same filename pattern.
- Manual capture: press `F10` in-game to save/download a report without crashing. The console log will print the saved path on desktop.
- Fatal capture: unhandled exceptions and common fatal signals are intercepted; a report is written before exit.
- Tweaks: see `src/main.cpp` for the `crash_reporter::Config` setup (log buffer size, output dir, build id, file vs. browser download).
