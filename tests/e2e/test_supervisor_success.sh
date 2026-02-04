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
junit_xml="${work_dir}/reports/report.xml"

set +e
"${supervisor_bin}" run --timeout-seconds 5 --dump-grace-seconds 1 -- \
  "${stub_bin}" --exit-code 0 --write-report "${report_json}" --write-junit "${junit_xml}" \
  --report-json "${report_json}" --report-junit "${junit_xml}"
status=$?
set -e

if [ "${status}" -ne 0 ]; then
  echo "expected exit code 0"
  exit 1
fi

if [ ! -f "${report_json}" ]; then
  echo "missing report json"
  exit 1
fi

if [ ! -f "${junit_xml}" ]; then
  echo "missing report junit"
  exit 1
fi
