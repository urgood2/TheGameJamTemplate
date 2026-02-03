#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
build_dir="${root_dir}/build"

cmake -B "${build_dir}" -DENABLE_UNIT_TESTS=ON
cmake --build "${build_dir}" --target test_mode_config_cli

bin_path="${build_dir}/tests/test_mode_config_cli"

work_dir="$(mktemp -d)"
cleanup() {
  rm -rf "${work_dir}"
}
trap cleanup EXIT

mkdir -p "${work_dir}/assets/scripts/tests/e2e"
echo "return true" > "${work_dir}/tests/sample.lua"

pushd "${work_dir}" >/dev/null

"${bin_path}" --test-mode --headless --seed 1 --test-script tests/sample.lua

out_dir="${work_dir}/tests/out"
run_id="$(ls -1 "${out_dir}")"
if [ -z "${run_id}" ]; then
  echo "missing run output"
  exit 1
fi

if [ ! -d "${out_dir}/${run_id}/artifacts" ]; then
  echo "missing artifacts dir"
  exit 1
fi

if [ ! -d "${out_dir}/${run_id}/forensics" ]; then
  echo "missing forensics dir"
  exit 1
fi

set +e
"${bin_path}" --test-mode --unknown-flag
status=$?
set -e

if [ "${status}" -ne 2 ]; then
  echo "expected exit code 2"
  exit 1
fi

popd >/dev/null
