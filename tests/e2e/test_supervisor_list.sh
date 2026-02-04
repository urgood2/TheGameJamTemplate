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

output="$(${supervisor_bin} list --timeout-seconds 5 --dump-grace-seconds 1 -- "${stub_bin}")"
if ! echo "${output}" | grep -q "stub.test"; then
  echo "missing list output"
  exit 1
fi
