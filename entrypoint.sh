#!/bin/sh

set -e

if [ ! -z "$INPUT_FRAMEWORK" ] && [ ! -z "$INPUT_CONTROL" ]; then
echo "Framework and Control is specified. Please specify either one of them or neither"
exit 1
fi

FRAMEWORK_CMD=$([ ! -z "$INPUT_FRAMEWORK" ] && echo "framework $INPUT_FRAMEWORK" || echo "")
CONTROL_CMD=$([ ! -z "$INPUT_CONTROL" ] && echo "control $INPUT_CONTROL" || echo "")

kubescape scan $FRAMEWORK_CMD $CONTROL_CMD $INPUT_FILES $INPUT_ARGS

