#!/bin/sh

set -e

echo "INPUT_ARGS $INPUT_ARGS"
echo "INPUT_FILES $INPUT_FILES\n"
echo "INPUT_CONTROL $INPUT_CONTROL\n"

if [[ ! -z "$INPUT_FRAMEWORK" ]]; then
echo "Framework is set to $INPUT_FRAMEWORK"
fi
