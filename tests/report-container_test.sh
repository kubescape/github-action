#!/bin/bash

# Exercise the composite action's actual run script across a container/runner
# filesystem boundary. The scanner fixture models the CLI's 0600/0750 policy;
# tests/report_test.sh covers finalization failures separately.
set -euo pipefail
repo_root=${REPO_UNDER_TEST:-$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd -P)}
runtime=${CONTAINER_RUNTIME:-docker}
# Resolve before the scan subshell shadows docker on PATH with its test shim.
runtime_bin=$(command -v "$runtime")
test_root=$(mktemp -d)
image=
cleanup() {
  if [ -n "$image" ]; then
    "$runtime_bin" image rm "$image" > /dev/null 2>&1 || true
  fi
  if [ "$runtime" = podman ]; then
    "$runtime_bin" unshare rm -rf -- "$test_root"
  else
    rm -rf -- "$test_root"
  fi
}
trap cleanup EXIT
mkdir -p "${test_root}/context" "${test_root}/bin"
cp "${repo_root}/entrypoint.sh" "${test_root}/context/entrypoint.sh"
cat > "${test_root}/context/Dockerfile" <<'DOCKERFILE'
FROM alpine:latest
RUN apk add --no-cache bash git jq
COPY entrypoint.sh /entrypoint.sh
COPY kubescape /usr/local/bin/kubescape
ENTRYPOINT ["/entrypoint.sh"]
DOCKERFILE
cat > "${test_root}/context/kubescape" <<'SCANNER'
#!/bin/bash
set -e
umask "${TEST_UMASK:-0022}"
if [ "$1" = fix ]; then
  printf '%s\n' fixed >> manifests/pod.yaml
  exit 0
fi
output=results
threshold=
while [ "$#" -gt 0 ]; do
  case "$1" in
    --output) output=$2; shift ;;
    --severity-threshold) threshold=$2; shift ;;
  esac
  shift
done
mkdir -p "$HOME/.cache" "$(dirname -- "$output")"
if [ "${TEST_UMASK:-0022}" = 0077 ]; then
  chmod 700 "$(dirname -- "$output")"
else
  chmod 750 "$(dirname -- "$output")"
fi
printf '%s\n' cached > "$HOME/.cache/scanner"
printf '%s\n' '{"runs":[{"results":[{"locations":[{"physicalLocation":{"artifactLocation":{"uri":"/github/workspace/manifests/pod.yaml"}}}]}]}]}' > "${output}.sarif"
printf '%s\n' '{}' > "${output}.json"
chmod 600 "${output}.sarif" "${output}.json"
[ "$threshold" != high ]
SCANNER
chmod +x "${test_root}/context/kubescape"
image="kubescape-action:report-test-$$"
"$runtime_bin" build -q -t "$image" "${test_root}/context"

awk '
  /^    - name: Run Kubescape scan$/ { in_step=1; next }
  in_step && /^      run: \|$/ { in_run=1; next }
  in_run && /^        / { sub(/^        /, ""); print; next }
  in_run { exit }
' "${repo_root}/action.yml" > "${test_root}/run.sh"

# Podman keep-id models a rootful Docker bind mount: explicit --user wins;
# without it, force the image's root default rather than keep-id's user default.
cat > "${test_root}/bin/docker" <<'RUNTIME'
#!/bin/bash
command=$1
shift
if [ "$CONTAINER_RUNTIME" = podman ]; then
  exec "$CONTAINER_RUNTIME_BIN" "$command" --security-opt label=disable --userns=keep-id --user 0:0 \
    -e "TEST_UMASK=$TEST_UMASK" "$@"
fi
exec "$CONTAINER_RUNTIME_BIN" "$command" -e "TEST_UMASK=$TEST_UMASK" "$@"
RUNTIME
chmod +x "${test_root}/bin/docker"

for threshold in critical high autofix; do
  for mask in 0022 0077; do
    workspace="${test_root}/${threshold}-${mask}"
    mkdir -p "${workspace}/manifests"
    # Allow both baseline root and candidate runner to create outputs, so a
    # baseline failure is report access, not inability to start the scan.
    chmod 777 "$workspace"
    printf '%s\n' original > "${workspace}/manifests/pod.yaml"
    report='reports with spaces/nested/results'
    status=0
    (
      export CONTAINER_RUNTIME=$runtime PATH="${test_root}/bin:${PATH}"
      export CONTAINER_RUNTIME_BIN=$runtime_bin
      export TEST_UMASK=$mask
      export GITHUB_WORKSPACE=$workspace KUBESCAPE_VERSION="report-test-$$"
      export INPUT_ACCOUNT='' INPUT_ACCESSKEY='' INPUT_SERVER='' INPUT_FAILEDTHRESHOLD=''
      export INPUT_COMPLIANCETHRESHOLD='' INPUT_EXCEPTIONS='' INPUT_CONTROLSCONFIG=''
      export INPUT_ARTIFACTS='' INPUT_FRAMEWORKS=nsa INPUT_CONTROLS='' INPUT_FILES=manifests
      export INPUT_IMAGE='' INPUT_REGISTRYUSERNAME='' INPUT_REGISTRYPASSWORD=''
      export INPUT_VERBOSE=false INPUT_SEVERITYTHRESHOLD=$threshold
      export INPUT_FORMAT=sarif,json INPUT_OUTPUTFILE=$report INPUT_FIXFILES=false
      if [ "$threshold" = autofix ]; then
        export INPUT_FIXFILES=true
      fi
      umask "$mask"
      bash "${test_root}/run.sh"
    ) > "${workspace}/log" 2>&1 || status=$?
    expected_status=0
    [ "$threshold" != high ] || expected_status=1
    [ "$status" -eq "$expected_status" ] || { cat "${workspace}/log"; exit 1; }
    for extension in sarif json; do
      file="${workspace}/${report}.${extension}"
      [ "$(stat -c '%a:%u:%g' "$file")" = "600:$(id -u):$(id -g)" ]
      jq -e . "$file" > /dev/null
    done
    jq -e '.runs[0].results[0].locations[0].physicalLocation.artifactLocation.uri == "manifests/pod.yaml"' \
      "${workspace}/${report}.sarif" > /dev/null
    if [ "$threshold" = autofix ]; then
      grep -Fxq fixed "${workspace}/manifests/pod.yaml"
    else
      [ "$(cat "${workspace}/manifests/pod.yaml")" = original ]
    fi
    printf 'ok - runner reads private nested SARIF/JSON after %s scan (umask %s)\n' "$threshold" "$mask"
  done
done
