#!/bin/bash

# Checks if `string` contains `substring`.
contains() {
  case "$1" in
    *$2*) return 0 ;;
    *) return 1 ;;
  esac
}

set -e

# Kubescape uses the client name to make a request for checking for updates
export KS_CLIENT="github_actions"

# Mark workspace as safe for git and try to initialize git info
if [ -d "/github/workspace" ]; then
  git config --global --add safe.directory /github/workspace || true
  cd /github/workspace
  echo "Git status in /github/workspace:"
  git status || echo "Git not available or not a repository."
fi

if [ -n "${INPUT_FRAMEWORKS}" ] && [ -n "${INPUT_CONTROLS}" ]; then
  echo "Framework and Control are specified. Please specify either one of them"
  exit 1
fi

if [ -z "${INPUT_FRAMEWORKS}" ] && [ -z "${INPUT_CONTROLS}" ] && [ -z "${INPUT_IMAGE}" ]; then
  echo "Scanning scope is not specified. Scanning all frameworks"
  INPUT_FRAMEWORKS="all"
fi

if [ -n "${INPUT_CONTROLS}" ]; then
  controls=""
  set -f
  IFS=','
  set -- "${INPUT_CONTROLS}"
  set +f
  unset IFS
  for control in "$@"; do
    control=$(echo "${control}" | xargs)
    controls="${controls}\"${control}\","
  done
  controls=$(echo "${controls%?}")
fi

frameworks_cmd=$([ -n "${INPUT_FRAMEWORKS}" ] && echo "framework ${INPUT_FRAMEWORKS}" || echo "")
controls_cmd=$([ -n "${INPUT_CONTROLS}" ] && echo control "${controls}" || echo "")
scan_input=$([ -n "${INPUT_FILES}" ] && echo "${INPUT_FILES}" || echo .)
output_formats="${INPUT_FORMAT:-pretty-printer}"
output_file=$([ -n "${INPUT_OUTPUTFILE}" ] && echo "${INPUT_OUTPUTFILE}" || echo "results")

verbose=""
if [ -n "${INPUT_VERBOSE}" ] && [ "${INPUT_VERBOSE}" != "false" ]; then
  verbose="--verbose"
fi

exceptions=$([ -n "$INPUT_EXCEPTIONS" ] && echo "--exceptions ${INPUT_EXCEPTIONS}" || echo "")
controls_config=$([ -n "$INPUT_CONTROLSCONFIG" ] && echo "--controls-config ${INPUT_CONTROLSCONFIG}" || echo "")
account_opt=$([ -n "${INPUT_ACCOUNT}" ] && echo --account "${INPUT_ACCOUNT}" || echo "")
access_key_opt=$([ -n "${INPUT_ACCESSKEY}" ] && echo --access-key "${INPUT_ACCESSKEY}" || echo "")
server_opt=$([ -n "${INPUT_SERVER}" ] && echo --server "${INPUT_SERVER}" || echo "")
fail_threshold_opt=$([ -n "${INPUT_FAILEDTHRESHOLD}" ] && echo --fail-threshold "${INPUT_FAILEDTHRESHOLD}" || echo "")
compliance_threshold_opt=$([ -n "${INPUT_COMPLIANCETHRESHOLD}" ] && echo --compliance-threshold "${INPUT_COMPLIANCETHRESHOLD}" || echo "")

should_fix_files="false"
if [ "${INPUT_FIXFILES}" = "true" ]; then
  should_fix_files="true"
  if ! contains "${output_formats}" "json"; then
    output_formats="${output_formats},json"
  fi
fi

severity_threshold_opt=""
if [ -n "${INPUT_SEVERITYTHRESHOLD}" ] && [ "${should_fix_files}" = "false" ]; then
  severity_threshold_opt="--severity-threshold ${INPUT_SEVERITYTHRESHOLD}"
fi

image_subcmd=""
if [ -n "${INPUT_IMAGE}" ]; then
  image_arg="${INPUT_IMAGE}"
  auth_opts=""
  if [ -n "${INPUT_REGISTRYUSERNAME}" ] && [ -n "${INPUT_REGISTRYPASSWORD}" ]; then
    auth_opts="--username=${INPUT_REGISTRYUSERNAME} --password=${INPUT_REGISTRYPASSWORD}"
  fi
  image_subcmd="image ${auth_opts}"
  scan_input="${image_arg}"
fi

scan_command="kubescape scan ${image_subcmd} ${frameworks_cmd} ${controls_cmd} ${scan_input} ${account_opt} ${access_key_opt} ${server_opt} ${fail_threshold_opt} ${compliance_threshold_opt} ${severity_threshold_opt} --format ${output_formats} --output ${output_file} ${verbose} ${exceptions} ${controls_config}"

echo "Running: ${scan_command}"
eval "${scan_command}"

# Post-processing for SARIF to ensure relative paths
if contains "${output_formats}" "sarif"; then
  actual_sarif="${output_file}"
  if [ ! -f "${actual_sarif}" ] && [ -f "${output_file}.sarif" ]; then
    actual_sarif="${output_file}.sarif"
  fi
  
  if [ -f "${actual_sarif}" ]; then
    echo "Normalizing paths in ${actual_sarif} using jq..."
    # 1. Use jq to walk through the object and fix any field named "uri"
    # It removes protocols and absolute workspace paths
    jq 'walk(if type == "object" and has("uri") and (.uri | type == "string") then 
          .uri |= sub("^file:///github/workspace/"; "") | 
          .uri |= sub("^/github/workspace/"; "") | 
          .uri |= sub("^file://"; "") |
          .uri |= sub("^/"; "") |
          .uri |= sub("^./"; "") 
        else . end)' "${actual_sarif}" > "${actual_sarif}.tmp" && mv "${actual_sarif}.tmp" "${actual_sarif}"
    
    echo "Path normalization complete. Snippet of results:"
    jq 'if .runs[].results then .runs[].results[].locations[].physicalLocation.artifactLocation.uri else "No results" end' "${actual_sarif}" | head -n 20
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
