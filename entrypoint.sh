#!/bin/bash

set -e

echo "Number of args $#\n"
echo "args $2\n"
echo "INPUT_ARGS $INPUT_ARGS"
echo "INPUT_FILES $INPUT_FILES\n"
echo "INPUT_CONTROL $INPUT_CONTROL\n"

if [[ -nz "${INPUT_FRAMEWORK}" ]]; then
echo "Framework is set to $INPUT_FRAMEWORK"
fi
