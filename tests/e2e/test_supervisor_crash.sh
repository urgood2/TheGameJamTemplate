#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
build_dir="${root_dir}/build-tests-local"

if [ ! -f "${build_dir}/CMakeCache.txt" ]; then
  cmake -B "${build_dir}" -DENABLE_UNIT_TESTS=ON
fi
cmake --build "${build_dir}" --target e2e_supervisor --target e2e_supervisor_stub -- -j4

supervisor_bin="${root_dir}/tools/e2e_supervisor"
stub_bin="${build_dir}/tests/e2e_supervisor_stub"
if [ ! -x "${stub_bin}" ]; then
  stub_bin="${build_dir}/e2e_supervisor_stub"
fi

if [ ! -x "${stub_bin}" ]; then
  echo "missing stub binary"
  exit 1
fi

if [ ! -x "${supervisor_bin}" ]; then
  echo "missing supervisor binary"
  exit 1
fi

work_dir="$(mktemp -d)"
cleanup() {
  rm -rf "${work_dir}"
}
trap cleanup EXIT

report_json="${work_dir}/reports/report.json"

set +e
"${supervisor_bin}" run --timeout-seconds 5 --dump-grace-seconds 1 -- \
  "${stub_bin}" --crash --stderr "crash" --write-report "${report_json}" \
  --report-json "${report_json}"
status=$?
set -e

if [ "${status}" -ne 4 ]; then
  echo "expected exit code 4"
  exit 1
fi

run_root="$(dirname "${report_json}")"
if [ ! -f "${run_root}/run_manifest.json" ]; then
  echo "missing run manifest"
  exit 1
fi

if [ ! -f "${run_root}/forensics/stderr.txt" ]; then
  echo "missing forensics stderr"
  exit 1
fi
