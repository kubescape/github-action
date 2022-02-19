#!/bin/sh

set -e

if [ ! -z "$INPUT_FRAMEWORK" ] && [ ! -z "$INPUT_CONTROL" ]; then
echo "Framework and Control is specified. Please specify either one of them or neither"
exit 1
fi

# Split the controls by comma and concatenate with quotes around each control
if [ ! -z "$INPUT_CONTROL" ]; then
    CONTROLS=""
    set -f; IFS=','
    set -- $INPUT_CONTROL
    set +f; unset IFS
    for control in "$@"
    do
        control=$(echo $control | xargs) # Remove leading/trailing whitespaces
        CONTROLS="$CONTROLS\"$control\","
    done
    CONTROLS=$(echo "${CONTROLS%?}")
    echo $CONTROLS
fi

FRAMEWORK_CMD=$([ ! -z "$INPUT_FRAMEWORK" ] && echo "framework $INPUT_FRAMEWORK" || echo "")
CONTROL_CMD=$([ ! -z "$INPUT_CONTROL" ] && echo control $CONTROLS || echo "")

COMMAND="kubescape scan $FRAMEWORK_CMD $CONTROL_CMD $INPUT_FILES $INPUT_ARGS"

eval $COMMAND

