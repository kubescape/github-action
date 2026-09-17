#!/bin/bash

set -u

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
test_root=$(mktemp -d)
trap 'rm -rf "${test_root}"' EXIT

passed=0
failed=0

pass() {
  passed=$((passed + 1))
  printf 'ok - %s\n' "$1"
}

fail() {
  failed=$((failed + 1))
  printf 'not ok - %s\n' "$1"
}

run_script="${test_root}/run.sh"
bin_dir="${test_root}/bin"
args_file="${test_root}/docker-args"
mkdir -p "${bin_dir}"

# Extract the composite step that constructs the docker command. Replacing
# GitHub expressions with inert values lets this test execute that boundary
# without needing a GitHub runner or Docker daemon.
awk '
  /^    - name: Run Kubescape scan$/ { in_step=1; next }
  in_step && /^      run: \|$/ { in_run=1; next }
  in_run && /^        / { sub(/^        /, ""); print; next }
  in_run { exit }
' "${repo_root}/action.yml" |
  sed -E 's/\$\{\{[^}]+\}\}/test/g' > "${run_script}"

cat > "${bin_dir}/docker" <<'STUB'
#!/bin/bash
printf '%s\n' "$@" > "${DOCKER_ARGS_FILE}"
STUB
chmod +x "${bin_dir}/docker"

artifact_input='artifacts;touch PWNED'
if PATH="${bin_dir}:${PATH}" \
  DOCKER_ARGS_FILE="${args_file}" \
  INPUT_ARTIFACTS="${artifact_input}" \
  bash "${run_script}" &&
  grep -Fxq -- "INPUT_ARTIFACTS=${artifact_input}" "${args_file}" &&
  [ ! -e "${test_root}/PWNED" ]; then
  pass "composite action keeps artifact input data-only"
else
  fail "composite action keeps artifact input data-only"
fi

printf '%s passed, %s failed\n' "${passed}" "${failed}"
[ "${failed}" -eq 0 ]
