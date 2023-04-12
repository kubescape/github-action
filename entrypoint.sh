#!/bin/sh

# Checks if `string` contains `substring`.
#
# Arguments:
#   String to check.
#
# Returns:
#   0 if `string` contains `substring`, otherwise 1.
contains() {
  case "$1" in
    *$2*) return 0 ;;
    *) return 1 ;;
  esac
}

set -e

# Kubescape uses the client name to make a request for checking for updates
export KS_CLIENT="github_actions"

if [ -n "${INPUT_FRAMEWORKS}" ] && [ -n "${INPUT_CONTROLS}" ]; then
  echo "Framework and Control is specified. Please specify either one of them or neither"
  exit 1
fi

# Split the controls by comma and concatenate with quotes around each control
if [ -n "${INPUT_CONTROLS}" ]; then
  controls=""
  set -f
  IFS=','
  set -- "${INPUT_CONTROLS}"
  set +f
  unset IFS
  for control in "$@"; do
    control=$(echo "${control}" | xargs) # Remove leading/trailing whitespaces
    controls="${controls}\"${control}\","
  done
  controls=$(echo "${controls%?}")
fi

frameworks_cmd=$([ -n "${INPUT_FRAMEWORKS}" ] && echo "framework ${INPUT_FRAMEWORKS}" || echo "")
controls_cmd=$([ -n "${INPUT_CONTROLS}" ] && echo control "${controls}" || echo "")

files=$([ -n "${INPUT_FILES}" ] && echo "${INPUT_FILES}" || echo .)

output_formats="${INPUT_FORMAT}"
have_json_format="false"
if [ -n "${output_formats}" ] && contains "${output_formats}" "json"; then
  have_json_format="true"
fi

verbose=""
if [ -n "${INPUT_VERBOSE}" ] && [ "${INPUT_VERBOSE}" != "false" ]; then
  verbose="--verbose"
fi

exceptions=""
if [ -n "$INPUT_EXCEPTIONS" ]; then
  exceptions="--exceptions ${INPUT_EXCEPTIONS}"
fi

controls_config=""
if [ -n "$INPUT_CONTROLSCONFIG" ]; then
  controls_config="--controls-config ${INPUT_CONTROLSCONFIG}"
fi

should_fix_files="false"
if [ "${INPUT_FIXFILES}" = "true" ]; then
  should_fix_files="true"
fi

# If a user requested Kubescape to fix their files, but forgot to ask for JSON
# output, do it for them
if [ "${should_fix_files}" = "true" ] && [ "${have_json_format}" != "true" ]; then
  output_formats="${output_formats},json"
fi

output_file=$([ -n "${INPUT_OUTPUTFILE}" ] && echo "${INPUT_OUTPUTFILE}" || echo "results")

account_opt=$([ -n "${INPUT_ACCOUNT}" ] && echo --account "${INPUT_ACCOUNT}" || echo "")

# If account ID is empty, we load artifacts from the local path, otherwise we
# load from the cloud (this will enable custom framework support)
artifacts_path="/home/ks/.kubescape"
artifacts_opt=$([ -n "${INPUT_ACCOUNT}" ] && echo "" || echo --use-artifacts-from "${artifacts_path}")

fail_threshold_opt=$([ -n "${INPUT_FAILEDTHRESHOLD}" ] && echo --fail-threshold "${INPUT_FAILEDTHRESHOLD}" || echo "")

# When a user requests to fix files, the action should not fail because the
# results exceed severity. This is subject to change in the future.
severity_threshold_opt=$(
  [ -n "${INPUT_SEVERITYTHRESHOLD}" ] &&
    [ "${should_fix_files}" = "false" ] &&
    echo --severity-threshold "${INPUT_SEVERITYTHRESHOLD}" ||
    echo ""
)

# The `kubescape fix` subcommand requires the latest "json" format version.
# Other formats ignore this flag.
format_version_opt="--format-version v2"

# TODO: include artifacts_opt once https://github.com/kubescape/kubescape/issues/1040 is resolved
scan_command="kubescape scan ${frameworks_cmd} ${controls_cmd} ${files} ${account_opt} ${fail_threshold_opt} ${severity_threshold_opt} --format ${output_formats} ${format_version_opt} --output ${output_file} ${verbose} ${exceptions} ${controls-config}"

echo "${scan_command}"
eval "${scan_command}"

if [ "$should_fix_files" = "true" ]; then
  fix_command="kubescape fix --no-confirm ${output_file}.json"
  eval "${fix_command}"
fi
