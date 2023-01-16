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

if [ ! -z "$INPUT_FRAMEWORKS" ] && [ ! -z "$INPUT_CONTROLS" ]; then
    echo "Framework and Control is specified. Please specify either one of them or neither"
    exit 1
fi

# Fixing files requires a JSON output file to be present
have_json_format="false"
if [ ! -z "$INPUT_FORMAT" ] && contains $INPUT_FORMAT "json"; then
    have_json_format="true"
fi

should_fix_files="false"
if [ "$INPUT_FIXFILES" = "true" ]; then
    should_fix_files="true"
fi

if [ "$should_fix_files" = "true" ] && [ "$have_json_format" != "true" ]; then
    echo 'No output in JSON format to fix files. Autofixing files requires a JSON output file to be present. Please use `format: "json[,OTHER_FORMATS]`'
    exit 1
fi

# Split the controls by comma and concatenate with quotes around each control
if [ ! -z "$INPUT_CONTROLS" ]; then
    CONTROLS=""
    set -f; IFS=','
    set -- $INPUT_CONTROLS
    set +f; unset IFS
    for control in "$@"
    do
        control=$(echo $control | xargs) # Remove leading/trailing whitespaces
        CONTROLS="$CONTROLS\"$control\","
    done
    CONTROLS=$(echo "${CONTROLS%?}")
fi

# Subcommands
ARTIFACTS_PATH="/home/ks/.kubescape"
FRAMEWORKS_CMD=$([ ! -z "$INPUT_FRAMEWORKS" ] && echo "framework $INPUT_FRAMEWORKS" || echo "")
CONTROLS_CMD=$([ ! -z "$INPUT_CONTROLS" ] && echo control $CONTROLS || echo "")

# Files to scan
FILES=$([ ! -z "$INPUT_FILES" ] && echo "$INPUT_FILES" || echo .)

# Output file name
OUTPUT_FILE=$([ ! -z "$INPUT_OUTPUTFILE" ] && echo "$INPUT_OUTPUTFILE" || echo "results")

# Command-line options
ACCOUNT_OPT=$([ ! -z "$INPUT_ACCOUNT" ] && echo --account $INPUT_ACCOUNT || echo "")

# If account ID is empty, we load artifacts from the local path, otherwise we
# load from the cloud (this will enable custom framework support)
ARTIFACTS=$([ ! -z "$INPUT_ACCOUNT" ] && echo "" || echo --use-artifacts-from $ARTIFACTS_PATH)

FAIL_THRESHOLD_OPT=$([ ! -z "$INPUT_FAILEDTHRESHOLD" ] && echo --fail-threshold $INPUT_FAILEDTHRESHOLD || echo "")
SEVERITY_THRESHOLD_OPT=$([ ! -z "$INPUT_SEVERITYTHRESHOLD" ] && echo --severity-threshold $INPUT_SEVERITYTHRESHOLD || echo "")

# `kubescape fix` requires the latest "json" format version. Other formats
# ignore this flag.
format_version_opt="--format-version v2"

SCAN_COMMAND="kubescape scan $FRAMEWORKS_CMD $CONTROLS_CMD $FILES $ACCOUNT_OPT $FAIL_THRESHOLD_OPT $SEVERITY_THRESHOLD_OPT --format $INPUT_FORMAT $format_version_opt --output $OUTPUT_FILE $ARTIFACTS"

eval $SCAN_COMMAND

if [ "$should_fix_files" = "true" ]; then
    fix_command="yes | kubescape fix $OUTPUT_FILE"
    eval $fix_command
fi
