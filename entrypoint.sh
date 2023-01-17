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

# Declare Kubescape client
export KS_CLIENT="github_actions"

if [ -n "${INPUT_FRAMEWORKS}" ] && [ -n "${INPUT_CONTROLS}" ]; then
    echo "Framework and Control is specified. Please specify either one of them or neither"
    exit 1
fi

# Fixing files requires a JSON output file to be present
have_json_format="false"
if [ -n "${INPUT_FORMAT}" ] && contains "${INPUT_FORMAT}" "json"; then
    have_json_format="true"
fi

should_fix_files="false"
if [ "${INPUT_FIXFILES}" = "true" ]; then
    should_fix_files="true"
fi

if [ "${should_fix_files}" = "true" ] && [ "${have_json_format}" != "true" ]; then
    echo 'No output in JSON format to fix files. Autofixing files requires a JSON output file to be present. Please use "format: "json[,OTHER_FORMATS]"'
    exit 1
fi

# Split the controls by comma and concatenate with quotes around each control
if [ -n "${INPUT_CONTROLS}" ]; then
    controls=""
    set -f; IFS=','
    set -- "${INPUT_CONTROLS}"
    set +f; unset IFS
    for control in "$@"
    do
        control=$(echo "${control}" | xargs) # Remove leading/trailing whitespaces
        controls="${controls}\"${control}\","
    done
    controls=$(echo "${controls%?}")
fi

# Subcommands
frameworks_cmd=$([ -n "${INPUT_FRAMEWORKS}" ] && echo "framework ${INPUT_FRAMEWORKS}" || echo "")
controls_cmd=$([ -n "${INPUT_CONTROLS}" ] && echo control "${controls}" || echo "")

# Files to scan
files=$([ -n "${INPUT_FILES}" ] && echo "${INPUT_FILES}" || echo .)

# Output file name
output_file=$([ -n "${INPUT_OUTPUTFILE}" ] && echo "${INPUT_OUTPUTFILE}" || echo "results")

# Command-line options
account_opt=$([ -n "${INPUT_ACCOUNT}" ] && echo --account "${INPUT_ACCOUNT}" || echo "")

# If account ID is empty, we load artifacts from the local path, otherwise we
# load from the cloud (this will enable custom framework support)
artifacts_path="/home/ks/.kubescape"
artifacts=$([ -n "${INPUT_ACCOUNT}" ] && echo "" || echo --use-artifacts-from "${artifacts_path}")

fail_threshold_opt=$([ -n "${INPUT_FAILEDTHRESHOLD}" ] && echo --fail-threshold "${INPUT_FAILEDTHRESHOLD}" || echo "")
severity_threshold_opt=$([ -n "${INPUT_SEVERITYTHRESHOLD}" ] && echo --severity-threshold "${INPUT_SEVERITYTHRESHOLD}" || echo "")

# `kubescape fix` requires the latest "json" format version. Other formats
# ignore this flag.
format_version_opt="--format-version v2"

scan_command="kubescape scan $frameworks_cmd $controls_cmd $files $account_opt $fail_threshold_opt $severity_threshold_opt --format $INPUT_FORMAT $format_version_opt --output $output_file"

eval "${scan_command}"

if [ "$should_fix_files" = "true" ]; then
    fix_command="kubescape fix --no-confirm ${output_file}.json"
    eval "${fix_command}"
fi
