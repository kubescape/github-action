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

new_case() {
  case_root="${test_root}/$1"
  workspace="${case_root}/workspace"
  bin_dir="${case_root}/bin"
  args_file="${case_root}/args"
  output_file="${case_root}/output"

  mkdir -p "${workspace}/manifests" "${bin_dir}"
  cat > "${bin_dir}/kubescape" <<'STUB'
#!/bin/bash
printf '%s\n' "$@" > "${KUBESCAPE_ARGS_FILE}"
STUB
  chmod +x "${bin_dir}/kubescape"

  unset INPUT_ACCESSKEY INPUT_ACCOUNT INPUT_ARTIFACTS INPUT_CONTROLSCONFIG
  unset INPUT_EXCEPTIONS INPUT_IMAGE INPUT_SERVER INPUT_FILES
  unset INPUT_FRAMEWORKS INPUT_CONTROLS INPUT_REGISTRYUSERNAME INPUT_REGISTRYPASSWORD
}

run_entrypoint() {
  (
    cd "${workspace}" || exit 1
    PATH="${bin_dir}:${PATH}" \
      KUBESCAPE_ARGS_FILE="${args_file}" \
      INPUT_ACCESSKEY="${INPUT_ACCESSKEY:-}" \
      INPUT_ACCOUNT="${INPUT_ACCOUNT:-}" \
      INPUT_ARTIFACTS="${INPUT_ARTIFACTS:-}" \
      INPUT_COMPLIANCETHRESHOLD="" \
      INPUT_CONTROLS="${INPUT_CONTROLS:-}" \
      INPUT_CONTROLSCONFIG="${INPUT_CONTROLSCONFIG:-}" \
      INPUT_EXCEPTIONS="${INPUT_EXCEPTIONS:-}" \
      INPUT_FAILEDTHRESHOLD="" \
      INPUT_FILES="${INPUT_FILES:-manifests}" \
      INPUT_FIXFILES="false" \
      INPUT_FORMAT="pretty-printer" \
      INPUT_FRAMEWORKS="${INPUT_FRAMEWORKS-nsa}" \
      INPUT_IMAGE="${INPUT_IMAGE:-}" \
      INPUT_OUTPUTFILE="results" \
      INPUT_REGISTRYPASSWORD="${INPUT_REGISTRYPASSWORD:-}" \
      INPUT_REGISTRYUSERNAME="${INPUT_REGISTRYUSERNAME:-}" \
      INPUT_SERVER="${INPUT_SERVER:-}" \
      INPUT_SEVERITYTHRESHOLD="" \
      INPUT_VERBOSE="false" \
      bash "${repo_root}/entrypoint.sh"
  ) > "${output_file}" 2>&1
}

test_default_command_is_unchanged() {
  new_case default

  if run_entrypoint && ! grep -Fq -- '--use-artifacts-from' "${args_file}"; then
    pass "default command does not use local artifacts"
  else
    fail "default command does not use local artifacts"
  fi
}

test_artifacts_are_forwarded_once() {
  new_case artifacts
  mkdir -p "${workspace}/kubescape-artifacts"
  INPUT_ARTIFACTS="kubescape-artifacts"

  if run_entrypoint &&
    [ "$(grep -Fxc -- '--use-artifacts-from' "${args_file}")" -eq 1 ] &&
    grep -Fxq -- "${workspace}/kubescape-artifacts" "${args_file}"; then
    pass "artifact directory is forwarded exactly once"
  else
    fail "artifact directory is forwarded exactly once"
  fi
}

test_artifact_path_with_spaces_is_one_argument() {
  new_case spaces
  mkdir -p "${workspace}/artifacts with spaces"
  INPUT_ARTIFACTS="artifacts with spaces"

  if run_entrypoint &&
    [ "$(grep -Fxc -- '--use-artifacts-from' "${args_file}")" -eq 1 ] &&
    [ "$(grep -Fxc -- "${workspace}/artifacts with spaces" "${args_file}")" -eq 1 ]; then
    pass "artifact path with spaces remains one argument"
  else
    fail "artifact path with spaces remains one argument"
  fi
}

test_missing_artifact_directory_fails() {
  new_case missing
  INPUT_ARTIFACTS="missing-artifacts"

  if ! run_entrypoint &&
    grep -Fq -- "Artifacts directory 'missing-artifacts' does not exist" "${output_file}" &&
    [ ! -e "${args_file}" ]; then
    pass "missing artifact directory fails before Kubescape"
  else
    fail "missing artifact directory fails before Kubescape"
  fi
}

test_absolute_artifact_path_fails() {
  new_case absolute
  mkdir -p "${workspace}/kubescape-artifacts"
  INPUT_ARTIFACTS="${workspace}/kubescape-artifacts"

  if ! run_entrypoint &&
    grep -Fq -- "Artifacts path must be relative to the GitHub workspace" "${output_file}" &&
    [ ! -e "${args_file}" ]; then
    pass "absolute artifact path is rejected"
  else
    fail "absolute artifact path is rejected"
  fi
}

test_artifact_symlink_escape_fails() {
  new_case symlink
  mkdir -p "${case_root}/outside"
  ln -s "${case_root}/outside" "${workspace}/escaped-artifacts"
  INPUT_ARTIFACTS="escaped-artifacts"

  if ! run_entrypoint &&
    grep -Fq -- "Artifacts directory must resolve inside the GitHub workspace" "${output_file}" &&
    [ ! -e "${args_file}" ]; then
    pass "artifact symlink outside the workspace is rejected"
  else
    fail "artifact symlink outside the workspace is rejected"
  fi
}

test_relative_artifact_escape_fails() {
  new_case relative_escape
  mkdir -p "${case_root}/outside"
  INPUT_ARTIFACTS="../outside"

  if ! run_entrypoint &&
    grep -Fq -- "Artifacts directory must resolve inside the GitHub workspace" "${output_file}" &&
    [ ! -e "${args_file}" ]; then
    pass "relative artifact path outside the workspace is rejected"
  else
    fail "relative artifact path outside the workspace is rejected"
  fi
}

test_artifacts_cannot_be_used_for_image_scans() {
  new_case image
  mkdir -p "${workspace}/kubescape-artifacts"
  INPUT_ARTIFACTS="kubescape-artifacts"
  INPUT_IMAGE="nginx:latest"

  if ! run_entrypoint &&
    grep -Fq -- "Artifacts cannot be used with image scans" "${output_file}" &&
    [ ! -e "${args_file}" ]; then
    pass "artifacts are rejected for image scans"
  else
    fail "artifacts are rejected for image scans"
  fi
}

test_exceptions_are_forwarded_with_artifacts() {
  new_case exceptions
  mkdir -p "${workspace}/kubescape-artifacts"
  INPUT_ARTIFACTS="kubescape-artifacts"
  INPUT_EXCEPTIONS="custom-exceptions.json"

  if run_entrypoint &&
    grep -Fxq -- '--exceptions' "${args_file}" &&
    grep -Fxq -- 'custom-exceptions.json' "${args_file}" &&
    grep -Fxq -- '--use-artifacts-from' "${args_file}"; then
    pass "explicit exceptions are forwarded with artifacts"
  else
    fail "explicit exceptions are forwarded with artifacts"
  fi
}

test_controls_config_is_forwarded_with_artifacts() {
  new_case controls_config
  mkdir -p "${workspace}/kubescape-artifacts"
  INPUT_ARTIFACTS="kubescape-artifacts"
  INPUT_CONTROLSCONFIG="custom-controls.json"

  if run_entrypoint &&
    grep -Fxq -- '--controls-config' "${args_file}" &&
    grep -Fxq -- 'custom-controls.json' "${args_file}" &&
    grep -Fxq -- '--use-artifacts-from' "${args_file}"; then
    pass "explicit controls config is forwarded with artifacts"
  else
    fail "explicit controls config is forwarded with artifacts"
  fi
}

test_account_credentials_are_forwarded_with_artifacts() {
  new_case account
  mkdir -p "${workspace}/kubescape-artifacts"
  INPUT_ARTIFACTS="kubescape-artifacts"
  INPUT_ACCOUNT="account-id"
  INPUT_ACCESSKEY="access-key"
  INPUT_SERVER="https://example.invalid"

  if run_entrypoint &&
    grep -Fxq -- '--account' "${args_file}" &&
    grep -Fxq -- 'account-id' "${args_file}" &&
    grep -Fxq -- '--access-key' "${args_file}" &&
    grep -Fxq -- 'access-key' "${args_file}" &&
    grep -Fxq -- '--server' "${args_file}" &&
    grep -Fxq -- 'https://example.invalid' "${args_file}" &&
    grep -Fxq -- '--use-artifacts-from' "${args_file}"; then
    pass "account credentials are forwarded with artifacts"
  else
    fail "account credentials are forwarded with artifacts"
  fi
}

test_artifact_path_cannot_inject_commands() {
  new_case injection
  mkdir -p "${workspace}/artifacts;touch PWNED"
  INPUT_ARTIFACTS="artifacts;touch PWNED"

  if run_entrypoint &&
    grep -Fxq -- "${workspace}/artifacts;touch PWNED" "${args_file}" &&
    [ ! -e "${workspace}/PWNED" ]; then
    pass "artifact path cannot inject a command"
  else
    fail "artifact path cannot inject a command"
  fi
}

# Shell punctuation and substitutions must remain literal arguments.
test_files_cannot_inject_commands() {
  new_case files_injection
  INPUT_FILES='evil\"; touch PWNED; #.yaml $(touch PWNED)'
  if run_entrypoint && [ ! -e "${workspace}/PWNED" ] &&
    grep -Fxq -- 'evil\";' "${args_file}" &&
    grep -Fxq -- '$(touch' "${args_file}"; then
    pass "file input cannot execute shell syntax"
  else
    fail "file input cannot execute shell syntax"
  fi
}

# Preserve ordinary multi-file scopes and comma-separated control names.
test_scan_scopes() {
  new_case scopes
  INPUT_FILES='manifests/one.yaml manifests/two.yaml'
  INPUT_FRAMEWORKS='nsa mitre'
  if run_entrypoint && grep -Fxq -- 'nsa' "${args_file}" &&
    grep -Fxq -- 'mitre' "${args_file}" &&
    grep -Fxq -- 'manifests/one.yaml' "${args_file}" &&
    grep -Fxq -- 'manifests/two.yaml' "${args_file}"; then
    pass "frameworks and file lists retain their arguments"
  else
    fail "frameworks and file lists retain their arguments"
  fi
  INPUT_FRAMEWORKS=''
  INPUT_CONTROLS='Control one,Control two'
  if run_entrypoint && grep -Fxq -- 'control' "${args_file}" &&
    grep -Fxq -- "$INPUT_CONTROLS" "${args_file}"; then
    pass "control names remain one comma-separated argument"
  else
    fail "control names remain one comma-separated argument"
  fi
}

# Credentials must stay literal and must not be printed in the scan log.
test_credentials_cannot_inject_commands() {
  new_case credential_injection
  INPUT_IMAGE='nginx:latest'
  INPUT_REGISTRYUSERNAME='user name'
  INPUT_REGISTRYPASSWORD='$(touch PWNED); secret'
  INPUT_ACCESSKEY='$(touch PWNED); key'
  if run_entrypoint && [ ! -e "${workspace}/PWNED" ] &&
    grep -Fxq -- "--password=$INPUT_REGISTRYPASSWORD" "${args_file}" &&
    grep -Fxq -- "$INPUT_ACCESSKEY" "${args_file}" &&
    ! grep -Fq -- "$INPUT_REGISTRYPASSWORD" "${output_file}" &&
    ! grep -Fq -- "$INPUT_ACCESSKEY" "${output_file}"; then
    pass "image credentials and access keys remain literal and private"
  else
    fail "image credentials and access keys remain literal and private"
  fi
}

# Patterns must match files while treating matched filenames as literal data.
test_globs_and_multiline_scopes() {
  new_case glob
  evil_name='evil"; touch PWNED; #.yaml'
  touch "${workspace}/manifests/${evil_name}" "${workspace}/manifests/normal.yaml"
  INPUT_FILES='manifests/*.yaml'
  INPUT_FRAMEWORKS=$'nsa\nmitre'
  if run_entrypoint && [ ! -e "${workspace}/PWNED" ] &&
    grep -Fxq -- "manifests/${evil_name}" "${args_file}" &&
    grep -Fxq -- 'manifests/normal.yaml' "${args_file}" &&
    grep -Fxq -- 'mitre' "${args_file}"; then
    pass "glob matches and multiline frameworks remain literal arguments"
  else
    fail "glob matches and multiline frameworks remain literal arguments"
  fi
  mkdir -p "${workspace}/manifests with spaces"
  INPUT_FILES='manifests with spaces'
  if run_entrypoint && grep -Fxq -- "$INPUT_FILES" "${args_file}"; then
    pass "a single existing file path can contain spaces"
  else
    fail "a single existing file path can contain spaces"
  fi
}

test_globs_and_multiline_scopes
test_scan_scopes
test_credentials_cannot_inject_commands
test_files_cannot_inject_commands
test_default_command_is_unchanged
test_artifacts_are_forwarded_once
test_artifact_path_with_spaces_is_one_argument
test_missing_artifact_directory_fails
test_absolute_artifact_path_fails
test_artifact_symlink_escape_fails
test_relative_artifact_escape_fails
test_artifacts_cannot_be_used_for_image_scans
test_exceptions_are_forwarded_with_artifacts
test_controls_config_is_forwarded_with_artifacts
test_account_credentials_are_forwarded_with_artifacts
test_artifact_path_cannot_inject_commands

printf '%s passed, %s failed\n' "${passed}" "${failed}"
[ "${failed}" -eq 0 ]
