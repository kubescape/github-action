#!/bin/bash

set -u

# Verify the executed runner scripts contain no input expression interpolation.
if sed -n '/^runs:/,$p' "$(dirname "$0")/../action.yml" |
  sed '/^[[:space:]]*[A-Z_]*:.*\${{/d' | grep -q '\${{ inputs\.'; then
  echo "Action inputs must enter scripts through env" >&2
  exit 1
fi

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

# Exercise every action input with shell punctuation at the runner boundary.
input_value='"; touch PWNED; # $(touch PWNED)'
env_args=()
while read -r name expression; do
  name="${name%:}"
  if [[ "$name" == INPUT_* ]]; then
    if [[ "$expression" != '${{ inputs.'*' }}' ]]; then
      fail "$name is wired to an action input"
    fi
    env_args+=("$name=$input_value")
  fi
done < <(awk '
  /^    - name: Run Kubescape scan$/ { in_step=1; next }
  in_step && /^      env:$/ { in_env=1; next }
  in_env && /^        / { print; next }
  in_env { exit }
' "${repo_root}/action.yml")

if [ "${#env_args[@]}" -eq 0 ]; then
  fail "scan input environment was extracted"
  exit 1
fi

if (
  cd "${test_root}" &&
    env PATH="${bin_dir}:${PATH}" \
      DOCKER_ARGS_FILE="${args_file}" \
      "${env_args[@]}" bash "${run_script}"
) && [ ! -e "${test_root}/PWNED" ]; then
  for argument in "${env_args[@]}"; do
    if grep -Fxq -- "$argument" "${args_file}"; then
      pass "${argument%%=*} remains literal in the Docker command"
    else
      fail "${argument%%=*} remains literal in the Docker command"
    fi
  done
else
  fail "composite action keeps inputs data-only"
fi

if grep -Fxq -- '--user' "${args_file}" &&
  grep -Fxq -- "$(id -u):$(id -g)" "${args_file}" &&
  grep -Fxq -- 'HOME=/tmp' "${args_file}"; then
  pass "container uses the runner identity with a writable home"
else
  fail "container uses the runner identity with a writable home"
fi

# All report-producing CI examples must exercise the checkout under test rather
# than a separately downloaded upstream action that may not contain the fix.
for workflow in example-scan.yaml example-scan-image.yaml example-fix-pr-review.yaml; do
  workflow_file="${repo_root}/.github/workflows/${workflow}"
  if grep -Eq '^    - uses: \./$' "$workflow_file" &&
    ! grep -Eq '^    - uses: kubescape/github-action@' "$workflow_file"; then
    pass "${workflow} scans with the checked-out action"
  else
    fail "${workflow} scans with the checked-out action"
  fi
done

# Exercise the container test's default Docker route without a daemon. The fake
# runtime stops the first run deliberately; reaching it proves that the inner
# Docker shim delegates instead of resolving itself again through PATH.
probe_bin="${test_root}/runtime-probe/bin"
probe_args="${test_root}/runtime-probe/args"
mkdir -p "$probe_bin"
cat > "${probe_bin}/docker" <<'PROBE'
#!/bin/bash
if [ "$1" = run ]; then
  printf '%s\n' "$@" > "$PROBE_ARGS_FILE"
  exit 88
fi
exit 0
PROBE
chmod +x "${probe_bin}/docker"
probe_status=0
timeout 5s env -u CONTAINER_RUNTIME \
  PATH="${probe_bin}:${PATH}" PROBE_ARGS_FILE="$probe_args" \
  bash "${repo_root}/tests/report-container_test.sh" \
  > "${test_root}/runtime-probe/log" 2>&1 || probe_status=$?
if [ "$probe_status" -eq 1 ] && [ -f "$probe_args" ] &&
  [ "$(grep -Fxc -- run "$probe_args")" -eq 1 ] &&
  grep -Fxq -- 'TEST_UMASK=0022' "$probe_args" &&
  grep -Fxq -- 'INPUT_OUTPUTFILE=reports with spaces/nested/results' "$probe_args"; then
  pass "default Docker container test reaches the configured runtime once"
else
  fail "default Docker container test reaches the configured runtime once"
fi

# Version input must not introduce shell code or container tag syntax.
version_script="${test_root}/version.sh"
awk '
  /^    - id: resolve_version$/ { in_step=1; next }
  in_step && /^      run: \|$/ { in_run=1; next }
  in_run && /^        / { sub(/^        /, ""); print; next }
  in_run { exit }
' "${repo_root}/action.yml" > "${version_script}"
for version in v4.0.13 v4.0.13-rc.1; do
  if INPUT_VERSION="$version" GITHUB_OUTPUT="${test_root}/version-output" \
    bash -e "${version_script}" &&
    grep -Fxq -- "version=$version" "${test_root}/version-output"; then
    pass "version $version resolves successfully"
  else
    fail "version $version resolves successfully"
  fi
done
if (
  cd "${test_root}" &&
    INPUT_VERSION='"; touch PWNED; #' GITHUB_OUTPUT="${test_root}/version-output" \
      bash -e "${version_script}" >/dev/null 2>&1
); then
  fail "invalid version is rejected"
elif [ ! -e "${test_root}/PWNED" ]; then
  pass "invalid version is rejected without executing shell syntax"
else
  fail "invalid version executed shell syntax"
fi

printf '%s passed, %s failed\n' "${passed}" "${failed}"
[ "${failed}" -eq 0 ]
