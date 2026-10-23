#!/bin/bash

set -uo pipefail

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd -P)
entrypoint=${ENTRYPOINT_UNDER_TEST:-${repo_root}/entrypoint.sh}
test_root=$(mktemp -d)
trap 'rm -rf "${test_root}"' EXIT
passed=0
failed=0

check() {
  local description=$1
  shift
  if "$@" > /dev/null; then
    printf 'ok - %s\n' "$description"
    passed=$((passed + 1))
  else
    printf 'not ok - %s\n' "$description"
    failed=$((failed + 1))
  fi
}

mkdir -p "${test_root}/bin"
# The CLI is an external boundary. Model its private report modes and status;
# all report processing below executes the real action entrypoint and jq.
cat > "${test_root}/bin/kubescape" <<'STUB'
#!/bin/bash
set -e
if [ "$1" = fix ]; then
  printf '%s\n' "$@" > fix-args
  exit "${FIX_EXIT:-0}"
fi
output=results
formats=sarif
while [ "$#" -gt 0 ]; do
  case "$1" in
    --output) output=$2; shift ;;
    --format) formats=$2; shift ;;
  esac
  shift
done
if [ "${REPORT_BEHAVIOR:-valid}" != missing ]; then
  mkdir -p -m 750 -- "$(dirname -- "$output")"
  if [[ "$formats" == *sarif* ]]; then
    printf '%s\n' '{"runs":[{"results":[{"locations":[{"physicalLocation":{"artifactLocation":{"uri":"/github/workspace/manifests/pod.yaml"}}}]}]}]}' > "${output}.sarif"
    chmod 600 -- "${output}.sarif"
    if [ "${REPORT_BEHAVIOR:-valid}" = invalid ]; then
      printf '%s\n' 'not JSON' > "${output}.sarif"
    elif [ "${REPORT_BEHAVIOR:-valid}" = empty ]; then
      : > "${output}.sarif"
    fi
  fi
  if [[ "$formats" == *json* ]]; then
    printf '%s\n' '{}' > "${output}.json"
    chmod 600 -- "${output}.json"
  fi
fi
exit "${SCANNER_EXIT:-0}"
STUB
chmod +x "${test_root}/bin/kubescape"

run_case() {
  local name=$1 scanner_exit=$2 behavior=${3:-valid} format=${4:-sarif}
  local output=${5:-results} mask=${6:-0022} fix=${7:-false} fix_exit=${8:-0}
  workspace="${test_root}/${name}"
  mkdir -p "$workspace"
  status=0
  (
    cd "$workspace" || exit 1
    umask "$mask"
    export PATH="${test_root}/bin:${PATH}" SCANNER_EXIT=$scanner_exit
    export REPORT_BEHAVIOR=$behavior FIX_EXIT=$fix_exit
    export INPUT_ACCOUNT='' INPUT_ACCESSKEY='' INPUT_SERVER='' INPUT_FAILEDTHRESHOLD=''
    export INPUT_COMPLIANCETHRESHOLD='' INPUT_EXCEPTIONS='' INPUT_CONTROLSCONFIG=''
    export INPUT_ARTIFACTS='' INPUT_FRAMEWORKS=nsa INPUT_CONTROLS='' INPUT_FILES=.
    export INPUT_IMAGE='' INPUT_REGISTRYUSERNAME='' INPUT_REGISTRYPASSWORD=''
    export INPUT_SEVERITYTHRESHOLD=high INPUT_VERBOSE=false
    export INPUT_FORMAT=$format INPUT_OUTPUTFILE=$output INPUT_FIXFILES=$fix
    bash "$entrypoint"
  ) > "${workspace}/log" 2>&1 || status=$?
}

run_case threshold 1
check "threshold failure keeps the scanner status" test "$status" -eq 1
check "threshold failure still normalizes the produced SARIF" jq -e \
  '.runs[0].results[0].locations[0].physicalLocation.artifactLocation.uri == "manifests/pod.yaml"' \
  "${workspace}/results.sarif"

run_case success 0
check "successful scan stays successful" test "$status" -eq 0
check "normalization preserves owner-only SARIF access" test \
  "$(stat -c %a "${workspace}/results.sarif")" = 600

run_case malformed 0 invalid
check "malformed SARIF fails an otherwise successful scan" test "$status" -ne 0
check "failed normalization leaves the original report intact" grep -Fxq 'not JSON' "${workspace}/results.sarif"
check "failed normalization cleans up temporary files" test \
  "$(find "$workspace" -name 'results.sarif.*' | wc -l)" -eq 0

run_case scanner_and_normalizer_fail 9 invalid
check "scanner status takes precedence over a normalization error" test "$status" -eq 9

run_case missing 0 missing
check "missing requested SARIF fails an otherwise successful scan" test "$status" -ne 0
run_case missing_scanner_failure 7 missing
check "failure without a report preserves the scanner status" test "$status" -eq 7

run_case json_only 0 valid json
check "JSON-only scan stays successful and private" test \
  "$status:$(stat -c %a "${workspace}/results.json")" = 0:600
run_case missing_json 0 missing json
check "missing requested JSON fails an otherwise successful scan" test "$status" -ne 0

for mask in 0022 0077; do
  run_case "nested_${mask}" 0 valid sarif,json 'reports with spaces/nested/results' "$mask"
  report="${workspace}/reports with spaces/nested/results"
  check "nested reports succeed under umask ${mask}" test "$status" -eq 0
  for extension in sarif json; do
    check "nested ${extension} stays private under umask ${mask}" test \
      "$(stat -c %a "${report}.${extension}")" = 600
    check "nested ${extension} is valid JSON under umask ${mask}" jq -e . "${report}.${extension}"
  done
done

run_case autofix 0 valid sarif results 0022 true
check "autofix still succeeds and requests JSON automatically" test "$status" -eq 0
check "autofix receives the generated report" grep -Fxq 'results.json' "${workspace}/fix-args"
check "autofix JSON stays private" test "$(stat -c %a "${workspace}/results.json")" = 600
run_case failed_autofix 0 valid sarif results 0022 true 6
check "autofix errors are not swallowed" test "$status" -eq 6
run_case failed_scan_with_autofix 3 valid sarif results 0022 true
check "failed scan with autofix preserves its status" test "$status" -eq 3
check "failed scan does not run autofix" test ! -e "${workspace}/fix-args"

run_case leading_dash 0 valid sarif -report
check "leading-dash report names normalize successfully" test "$status" -eq 0
check "leading-dash report paths are actually normalized" jq -e \
  '.runs[0].results[0].locations[0].physicalLocation.artifactLocation.uri == "manifests/pod.yaml"' \
  "${workspace}/-report.sarif"

run_case empty_report 0 empty
check "empty SARIF fails an otherwise successful scan" test "$status" -ne 0
run_case empty_report_failed_scan 7 empty
check "empty SARIF does not mask the scanner failure" test "$status" -eq 7
check "empty SARIF is reported as a normalization failure" grep -Fq \
  'Failed to normalize SARIF' "${workspace}/log"

printf '%s passed, %s failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
