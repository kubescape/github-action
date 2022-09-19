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
fi

FRAMEWORK_CMD=$([ ! -z "$INPUT_FRAMEWORK" ] && echo "framework $INPUT_FRAMEWORK" || echo "")
CONTROL_CMD=$([ ! -z "$INPUT_CONTROL" ] && echo "control $CONTROLS" || echo "")
EXCEPTIONS_CMD=$([ ! -z "$INPUT_EXCEPTIONS"] && echo "--exceptions $INPUT_EXCEPTIONS" || echo "")

if [ "$INPUT_SCANREPOSITORY"  = "no" ]; then
  if [ -z "$INPUT_FILES" ]; then
  echo "No files specified to scan. Please specify files to scan or scan the entire repository."
  exit 1
  fi
  COMMAND="kubescape scan $FRAMEWORK_CMD $CONTROL_CMD $INPUT_FILES --fail-threshold $INPUT_THRESHOLD $INPUT_ARGS $EXCEPTIONS_CMD"
else
  if [ -z "$INPUT_ACCOUNTGUID" ]; then
  echo "Account id is not specified. Please provide the account id"
  exit 1
  else
  COMMAND="kubescape scan https://github.com/$GITHUB_REPOSITORY $FRAMEWORK_CMD $CONTROL_CMD --fail-threshold $INPUT_THRESHOLD $INPUT_ARGS $EXCEPTIONS_CMD --submit --account=$INPUT_ACCOUNTGUID"
  fi
fi

eval $COMMAND

