#!/bin/sh

set -e

if [ ! -z "$INPUT_FRAMEWORKS" ] && [ ! -z "$INPUT_CONTROLS" ]; then
echo "Framework and Control is specified. Please specify either one of them or neither"
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

ARTIFACTS_PATH="/home/armo/.kubescape"
FRAMEWORKS_CMD=$([ ! -z "$INPUT_FRAMEWORKS" ] && echo "framework $INPUT_FRAMEWORKS" || echo "")
CONTROLS_CMD=$([ ! -z "$INPUT_CONTROLS" ] && echo control $CONTROLS || echo "")
FILES=$([ ! -z "$INPUT_FILES" ] && echo "$INPUT_FILES" || echo .)
ACCOUNT_CMD=$([ ! -z "$INPUT_ACCOUNT" ] && echo --account $INPUT_ACCOUNT --submit || echo "")
INPUT_FAILEDTHRESHOLD=$([ ! -z "$INPUT_FAILEDTHRESHOLD" ] && echo --fail-threshold $INPUT_FAILEDTHRESHOLD || echo "")
THRESHOLD_CRITICAL_CMD=$([ ! -z "$INPUT_THRESHOLDCRITICAL" ] && echo --threshold-critical $INPUT_THRESHOLDCRITICAL || echo "")
THRESHOLD_HIGH_CMD=$([ ! -z "$INPUT_THRESHOLDHIGH" ] && echo --threshold-high $INPUT_THRESHOLDHIGH || echo "")
THRESHOLD_MEDIUM_CMD=$([ ! -z "$INPUT_THRESHOLDMEDIUM" ] && echo --threshold-medium $INPUT_THRESHOLDMEDIUM || echo "")
THRESHOLD_LOW_CMD=$([ ! -z "$INPUT_THRESHOLDLOW" ] && echo --threshold-low $INPUT_THRESHOLDLOW || echo "")

COMMAND="kubescape scan $FRAMEWORKS_CMD $CONTROLS_CMD $FILES $ACCOUNT_CMD $INPUT_FAILEDTHRESHOLD $THRESHOLD_CRITICAL_CMD $THRESHOLD_HIGH_CMD $THRESHOLD_MEDIUM_CMD $THRESHOLD_LOW_CMD --format $INPUT_FORMAT --output results --use-artifacts-from $ARTIFACTS_PATH"

eval $COMMAND
