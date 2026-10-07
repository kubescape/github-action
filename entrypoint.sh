#!/bin/bash

# Checks if `string` contains `substring`.
contains() {
  case "$1" in
    *$2*) return 0 ;;
    *) return 1 ;;
  esac
}

set -e

# Expand filename patterns as data, with word splitting disabled. Bash does not
# execute shell syntax introduced by expanding a variable.
append_paths() {
  local IFS=
  # shellcheck disable=SC2206
  scan_command+=( $1 )
}

# Kubescape uses the client name to make a request for checking for updates
export KS_CLIENT="github_actions"

# Mark workspace as safe for git
if [ -d "/github/workspace" ]; then
  git config --global --add safe.directory /github/workspace || true
  cd /github/workspace
fi

if [ -n "${INPUT_FRAMEWORKS}" ] && [ -n "${INPUT_CONTROLS}" ]; then
  echo "Framework and Control are specified. Please specify either one of them"
  exit 1
fi

if [ -z "${INPUT_FRAMEWORKS}" ] && [ -z "${INPUT_CONTROLS}" ] && [ -z "${INPUT_IMAGE}" ]; then
  echo "Scanning scope is not specified. Scanning all frameworks"
  INPUT_FRAMEWORKS="all"
fi

# Split legacy whitespace-separated scopes without evaluating shell syntax.
scan_command=(kubescape scan)
if [ -n "${INPUT_IMAGE}" ]; then
  scan_command+=(image)
  if [ -n "${INPUT_REGISTRYUSERNAME}" ] && [ -n "${INPUT_REGISTRYPASSWORD}" ]; then
    scan_command+=("--username=${INPUT_REGISTRYUSERNAME}" "--password=${INPUT_REGISTRYPASSWORD}")
  fi
  scan_command+=("${INPUT_IMAGE}")
else
  scope=()
  if [ -n "${INPUT_FRAMEWORKS}" ]; then
    read -r -a scope <<< "${INPUT_FRAMEWORKS//$'\n'/ }"
    scan_command+=(framework "${scope[@]}")
  elif [ -n "${INPUT_CONTROLS}" ]; then
    scan_command+=(control "${INPUT_CONTROLS}")
  fi
  if [ -n "${INPUT_FILES}" ]; then
    if [ -e "${INPUT_FILES}" ]; then
      scan_command+=("${INPUT_FILES}")
    else
      read -r -a scope <<< "${INPUT_FILES//$'\n'/ }"
      for path in "${scope[@]}"; do
        append_paths "$path"
      done
    fi
  else
    scan_command+=(.)
  fi
fi
output_formats="${INPUT_FORMAT:-pretty-printer}"
output_file="${INPUT_OUTPUTFILE:-results}"

if [ -n "${INPUT_ARTIFACTS}" ]; then
  case "${INPUT_ARTIFACTS}" in
    /*)
      echo "Artifacts path must be relative to the GitHub workspace"
      exit 1
      ;;
  esac
  if [ -n "${INPUT_IMAGE}" ]; then
    echo "Artifacts cannot be used with image scans"
    exit 1
  fi
  if [ ! -d "${INPUT_ARTIFACTS}" ]; then
    echo "Artifacts directory '${INPUT_ARTIFACTS}' does not exist"
    exit 1
  fi

  workspace_path=$(pwd -P)
  resolved_artifacts_path=$(cd -- "${INPUT_ARTIFACTS}" && pwd -P)
  case "${resolved_artifacts_path}" in
    "${workspace_path}"|"${workspace_path}"/*) ;;
    *)
      echo "Artifacts directory must resolve inside the GitHub workspace"
      exit 1
      ;;
  esac
  scan_command+=(--use-artifacts-from "${resolved_artifacts_path}")
fi
should_fix_files="false"
if [ "${INPUT_FIXFILES}" = "true" ]; then
  should_fix_files="true"
  if ! contains "${output_formats}" "json"; then
    output_formats="${output_formats},json"
  fi
fi

if [ -n "${INPUT_SEVERITYTHRESHOLD}" ] && [ "${should_fix_files}" = "false" ]; then
  scan_command+=(--severity-threshold "${INPUT_SEVERITYTHRESHOLD}")
fi
for option in ACCOUNT ACCESSKEY SERVER FAILEDTHRESHOLD COMPLIANCETHRESHOLD EXCEPTIONS CONTROLSCONFIG; do
  input="INPUT_${option}"
  if [ -n "${!input}" ]; then
    case "$option" in
      ACCOUNT) flag=--account ;;
      ACCESSKEY) flag=--access-key ;;
      SERVER) flag=--server ;;
      FAILEDTHRESHOLD) flag=--fail-threshold ;;
      COMPLIANCETHRESHOLD) flag=--compliance-threshold ;;
      EXCEPTIONS) flag=--exceptions ;;
      CONTROLSCONFIG) flag=--controls-config ;;
    esac
    scan_command+=("$flag" "${!input}")
  fi
done
scan_command+=(--format "${output_formats}" --output "${output_file}")
if [ -n "${INPUT_VERBOSE}" ] && [ "${INPUT_VERBOSE}" != "false" ]; then
  scan_command+=(--verbose)
fi

# Do not log arguments containing account or registry credentials.
echo "Running Kubescape scan"
"${scan_command[@]}"

# Post-processing for SARIF to ensure relative paths and remove results with empty URIs
if contains "${output_formats}" "sarif"; then
  actual_sarif="${output_file}"
  if [ ! -f "${actual_sarif}" ] && [ -f "${output_file}.sarif" ]; then
    actual_sarif="${output_file}.sarif"
  fi
  
  if [ -f "${actual_sarif}" ]; then
    echo "Normalizing paths and filtering invalid results in ${actual_sarif}..."
    
    # 1. Clean up URIs
    # 2. Filter out results that have an empty URI (which GitHub rejects)
    jq '
      walk(if type == "object" and has("uri") and (.uri | type == "string") then 
        .uri |= sub("^file:///github/workspace/"; "") | 
        .uri |= sub("^/github/workspace/"; "") | 
        .uri |= sub("^file://"; "") |
        .uri |= sub("^/"; "") |
        .uri |= sub("^./"; "") 
      else . end) |
      .runs[].results |= map(select(
        .locations[0].physicalLocation.artifactLocation.uri != "" and 
        .locations[0].physicalLocation.artifactLocation.uri != null
      ))
    ' "${actual_sarif}" > "${actual_sarif}.tmp" && mv "${actual_sarif}.tmp" "${actual_sarif}"
    
    echo "Processing complete. Final URI list:"
    jq -r '.runs[].results[].locations[0].physicalLocation.artifactLocation.uri' "${actual_sarif}" | head -n 20
  else
    echo "Warning: SARIF file ${output_file} not found."
  fi
fi

if [ "$should_fix_files" = "true" ]; then
  json_file="${output_file}"
  if [ ! -f "${json_file}" ] && [ -f "${output_file}.json" ]; then
    json_file="${output_file}.json"
  fi
  if [ -f "${json_file}" ]; then
    kubescape fix --no-confirm "${json_file}"
  fi
fi
