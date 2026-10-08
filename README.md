# Kubescape action

Run security scans on your Kubernetes manifests and Helm charts as a part of your CI using the Kubescape action. Kubescape scans Kubernetes clusters, YAML files, and HELM charts, detecting misconfigurations according to multiple frameworks (such as the [NSA-CISA](https://www.armosec.io/blog/kubernetes-hardening-guidance-summary-by-armo/?utm_source=github&utm_medium=repository) , [MITRE ATT&CK®](https://www.microsoft.com/security/blog/2021/03/23/secure-containerized-environments-with-updated-threat-matrix-for-kubernetes/) and [CIS Benchmark](https://www.armosec.io/blog/kubescape-adds-cis-benchmark/?utm_source=github&utm_medium=repository)), software vulnerabilities. 

## Usage

### Scanning with Kubescape

To scan your repository with [Kubescape in your Github workflow](https://www.armosec.io/blog/kubescape-now-integrates-with-github-actions/?utm_source=github&utm_medium=repository), add the following steps to your workflow configuration:

```yaml
name: Kubescape scanning for misconfigurations
on: [push, pull_request]
jobs:
  kubescape:
    runs-on: ubuntu-latest
    permissions:
      actions: read
      contents: read
      security-events: write
    steps:
    - uses: actions/checkout@v3
    - uses: kubescape/github-action@main
      continue-on-error: true
      with:
        format: sarif
        outputFile: results
        # # Optional: Specify the Kubescape Portal credentials 
        # account: ${{secrets.KUBESCAPE_ACCOUNT}}
        # accessKey: ${{secrets.KUBESCAPE_ACCESS_KEY}}
        # server: ${{ vars.KUBESCAPE_SERVER }}
        # # Optional: Scan a specific path. Default will scan the whole repository
        # files: "examples/*.yaml"
    - name: Upload Kubescape scan results to Github Code Scanning
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: results.sarif
```

This workflow definition scans your repository with Kubescape and publishes the results to Github.
You can then see the results in the Pull Request that triggered the scan and the _Security → Code scanning_ tab.

### Automatically Suggest Fixes

To scan pull requests and suggest fixes on branches in the same repository, use the following workflow:

```yaml
name: Suggest autofixes with Kubescape for PR by reviews
on:
  pull_request:

permissions:
  contents: read

jobs:
  kubescape-fix-pr-reviews:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v5
      with:
        fetch-depth: 0
        ref: ${{ github.event.pull_request.head.sha }}
        persist-credentials: false
    # Scan the workspace rather than interpolating changed filenames into inputs.
    # Fork contents are analyzed without repository secrets or write permissions.
    - uses: kubescape/github-action@main
      with:
        files: .
        fixFiles: true
        format: "sarif"
    - name: Save scan results
      if: always()
      uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02 # v4
      with:
        name: kubescape-pr-results
        path: |
          results.sarif
          results.json
        if-no-files-found: error

  publish-reviews:
    needs: kubescape-fix-pr-reviews
    if: github.event.pull_request.head.repo.full_name == github.repository
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
    steps:
    - uses: actions/checkout@v5
      with:
        ref: ${{ github.event.pull_request.head.sha }}
        persist-credentials: false
    - uses: actions/download-artifact@d3f86a106a0bac45b974a628896c90dbdf5c8093 # v4
      with:
        name: kubescape-pr-results
    - name: PR Suggester according to SARIF file
      uses: HollowMan6/sarif4reviewdog@v1.0.0
      with:
        file: 'results.sarif'
        level: warning
```

The scan job runs on `pull_request` with read-only permissions and no repository secrets. It scans the workspace and saves SARIF and JSON results as a downloadable artifact. A separate job uses Reviewdog to post reviews only for pull requests from branches in the same repository. Fork pull requests receive scan artifacts; they do not run the posting job. Do not enable unsafe fork checkout under `pull_request_target`.

You can also make Kubescape automatically suggest fixes for the pushes to your main branch by opening new PRs with the following workflow:

```yaml
name: Suggest autofixes with Kubescape for direct commits by PR
on: 
  push:
    branches: [ main ]

jobs:
  kubescape-fix-commit:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write

    steps:
    - uses: actions/checkout@v3
      with:
        fetch-depth: 0
    - name: Get changed files
      id: changed-files
      uses: tj-actions/changed-files@v35
    - uses: kubescape/github-action@main
      with:
        account: ${{secrets.KUBESCAPE_ACCOUNT}}
        accessKey: ${{secrets.KUBESCAPE_ACCESS_KEY}}
        server: ${{ vars.KUBESCAPE_SERVER }}
        files: ${{ steps.changed-files.outputs.all_changed_files }}
        fixFiles: true
        format: "sarif"
    - uses: peter-evans/create-pull-request@v4
      # Remember to allow GitHub Actions to create and approve pull requests
      # https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository#preventing-github-actions-from-creating-or-approving-pull-requests
      if: github.event_name != 'pull_request_target'
      with:
        add-paths: |
          *.yaml
        commit-message: "chore: fix K8s misconfigurations"
        title: "[Kubescape] chore: fix K8s misconfigurations"
        body: |
          # What this PR changes

          [Kubescape](https://github.com/kubescape/kubescape) has found misconfigurations in the targeted branch. This PR fixes the misconfigurations that have automatic fixes available.

          You may still need to fix misconfigurations that do not have automatic fixes.
        base: ${{ github.head_ref }}
        branch: kubescape-auto-fix-${{ github.head_ref || github.ref_name }}
        delete-branch: true
```

The above workflow works by collecting the changes made directly to the original files. In the example above, a separate step that runs a different action opens the appropriate pull request. Due to how Github works, there are [limitations](https://github.com/peter-evans/create-pull-request/blob/main/docs/concepts-guidelines.md#triggering-further-workflow-runs) on running and opening pull requests to forks. The action running in this step is maintained by its respective maintainers, and not the Kubescape team, so you should review its documentation when troubleshooting the process of triggering the workflow run and opening pull requests.

Please note that since Kubescape provides automatic fixes only to the rendered YAML manifests, the workflow above will not produce correct fixes for Helm charts.

The next important thing to note is that Kubescape only fixes the files. It does not open pull requests or generate code reviews on its own.

### Scanning images

The Kubescape Github Action is also able to scan images. But you should be aware that image scanning cannot run in parallel with configuration scanning and file fixing at the moment. If you would like to run both image and configuration scanning, you should define at least two separate steps with the same action but different arguments: one for image scanning and the other for configuration scanning.

To scan a container image with a Kubescape Github Action, use the following workflow definition, keeping in mind that you need to replace `image: "quay.io/kubescape/kubescape"` with the appropriate image name:

```yaml
name: Kubescape scanning for image vulnerabilities
on: [push, pull_request]
jobs:
  kubescape-scan-image:
    runs-on: ubuntu-latest
    permissions:
      actions: read
      contents: read
      security-events: write
    steps:
    - uses: actions/checkout@v3
    - uses: kubescape/github-action@main
      continue-on-error: true
      with:
        image: nginx
        format: sarif
        outputFile: results.sarif
        # severityThreshold: "critical"
        # # Username for a private registry with the image
        # registryUsername: ${{secrets.REGISTRY_USERNAME}}
        # # Password for a private registry with the image
        # registryPassword: ${{secrets.REGISTRY_PASSWORD}}
        # # Fail at or above the specified vulnerability severity threshold
        # Kubescape Portal credentials
        # account: ${{secrets.KUBESCAPE_ACCOUNT}}
        # accessKey: ${{secrets.KUBESCAPE_ACCESS_KEY}}
        # server: ${{ vars.KUBESCAPE_SERVER }}
    - name: Upload Kubescape scan results to Github Code Scanning
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: results.sarif
```

## Inputs

| Name | Description | Required |
| --- | --- | ---|
| files | YAML files or Helm charts to scan, using paths or glob patterns relative to the repository root, separated by whitespace. A single existing path may contain spaces. Shell expressions and quoted shell-style path lists are not supported. | No (default is `.` which scans the whole repository) |
| outputFile | Name of the output file where the scan result will be stored without the extension. | No (default is `results`) |
| format | Output format of the scan results. Can take one or more formats separated by a comma with no spaces. Example - `sarif,json`. When multiple formats are specified, Kubescape produces one file per format using the `outputFile` name, e.g. `results.sarif` and `results.json`. Run `kubescape scan -h` in the [Kubescape CLI](https://hub.armo.cloud/docs/installing-kubescape) to get a list of all supported formats. | No (default is `junit`) |
| frameworks | Security framework(s) to scan the files against. Multiple frameworks can be specified separated by a comma with no spaces. Example - `nsa,devopsbest`. Run `kubescape list frameworks` in the [Kubescape CLI](https://hub.armo.cloud/docs/installing-kubescape) to get a list of all frameworks. Either frameworks have to be specified or controls. | No |
| controls | Security control(s) to scan the files against. Multiple controls can be specified separated by a comma with no spaces. Example - `Configured liveness probe,Pods in default namespace`. Run `kubescape list controls` in the [Kubescape CLI](https://hub.armo.cloud/docs/installing-kubescape) to get a list of all controls. You can use either the complete control name or the control ID such as `C-0001` to specify the control you want use. You must specify either the control(s) or the framework(s) you want used in the scan. | No |
| account | account ID for integrating with a third-party server  | No |
| accessKey | access-key for integrating with a third-party server  | No |
| server | URL for integrating with a third-party server | No |
| failedThreshold | Failure threshold is the percent above which the command fails and returns exit code 1 (default 0 i.e, action fails if any control fails) | No (default 0) |
| severityThreshold | Severity threshold is the severity of a failed control at or above which the command terminates with an exit code 1 (default is `high`, i.e. the action fails if any High severity control fails) | No |
| verbose | Display all of the input resources and not only failed resources. Default is off | No |
| exceptions | The JSON file containing at least one resource and one policy. Refer [exceptions](https://hub.armo.cloud/docs/exceptions) docs for more info. Objects with exceptions will be presented as exclude and not fail. | No |
| controlsConfig | The file containing controls configuration. Use `kubescape download controls-inputs` to download the configured controls-inputs. | No |
| artifacts | Workspace-relative path to a vendored Kubescape artifacts directory. The directory must resolve inside the workspace and cannot be used with `image`. | No |
| image | The image you wish to scan. Launches an image scan, which cannot run together with configuration scans. | No |
| registryUsername | Username to a private registry that hosts the scanned image. | No |
| registryPassword | Password to a private registry that hosts the scanned image. | No |
| version | The version of Kubescape to use. Can be a specific version (e.g. "v3.0.21") or "latest". | No (default is `latest`) |

## Examples

> **Note:** The `version` input defaults to `latest`, but pinning a Kubescape version alone does not pin the policy library used by a scan. Use a reviewed artifact bundle as described below when policy stability is required.

### Reproducible policy evaluation

Create the artifacts outside the CI run, review them, and commit the directory alongside the manifests that will be scanned:

```bash
kubescape download artifacts --output kubescape-artifacts
```

Then pin the action commit and Kubescape version, and scan a path that does not contain the artifact JSON files:

```yaml
- uses: actions/checkout@v3
- uses: kubescape/github-action@<full-commit-sha>
  with:
    version: v4.0.13
    frameworks: nsa
    files: manifests/
    artifacts: kubescape-artifacts/
```

The `artifacts` path must be relative to the checked-out workspace and must resolve inside it. Downloading the bundle during every CI run would fetch the current policy library again and defeat policy reproducibility.

The bundle includes `exceptions.json` and `controls-inputs.json`. Kubescape v4.0.13 prefers explicit `exceptions` and `controlsConfig` inputs when they are supplied together with `artifacts`; older versions such as v3.0.21 prefer the files in the artifact bundle. When `account`, `accessKey`, or `server` are also supplied, they are still forwarded, but the vendored artifacts remain the policy source. Ensure that any required custom policies are present in the bundle.

Pinning the action commit, Kubescape version, scanned manifests, and reviewed artifact bundle makes policy and rule evaluation reproducible. It does not make the entire container build reproducible because the action currently retrieves Kubescape's installer separately.

#### Scan and submit results to the [Kubescape Cloud](https://cloud.armosec.io/)

```yaml
name: Kubescape scanning for misconfigurations
on: [push, pull_request]
jobs:
  kubescape:
    runs-on: ubuntu-latest
    permissions:
      actions: read
      contents: read
      security-events: write
    steps:
    - uses: actions/checkout@v3
    - uses: kubescape/github-action@main
      continue-on-error: true
      with:
        format: sarif
        outputFile: results
        # Specify the Kubescape cloud account ID
        account: ${{secrets.KUBESCAPE_ACCOUNT}}
        accessKey: ${{secrets.KUBESCAPE_ACCESS_KEY}}
        server: ${{ vars.KUBESCAPE_SERVER }}
    - name: Upload Kubescape scan results to Github Code Scanning
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: results.sarif
```

#### Scan specific file paths

Scan a spefic pathspec, for example `examples/kubernetes-manifests/*.yaml`:

```yaml
name: Kubescape scanning for misconfigurations
on: [push, pull_request]
jobs:
  kubescape:
    runs-on: ubuntu-latest
    permissions:
      actions: read
      contents: read
      security-events: write
    steps:
    - uses: actions/checkout@v3
    - uses: kubescape/github-action@main
      continue-on-error: true
      with:
        format: sarif
        outputFile: results
        # Scan a specific path. Default will scan the whole repository
        files: "examples/kubernetes-manifests/*.yaml"
    - name: Upload Kubescape scan results to Github Code Scanning
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: results.sarif
```

#### Scan against specific frameworks

Perform a Kubescape scan against a list of specific frameworks (NSA and MITRE in this example):

```yaml
name: Kubescape scanning for misconfigurations
on: [push, pull_request]
jobs:
  kubescape:
    runs-on: ubuntu-latest
    permissions:
      actions: read
      contents: read
      security-events: write
    steps:
      - uses: actions/checkout@v3
      - uses: kubescape/github-action@main
        continue-on-error: true
        with:
          format: sarif
          outputFile: results
          frameworks: |
            nsa,mitre
      - name: Upload Kubescape scan results to Github Code Scanning
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: results.sarif
```

#### Fail Kubescape scanning based on the percentage of failed controls

Scan a repository with Kubescape and fail the scanning step if the percent of failed controls is more than the specified `failedThreshold`:

```yaml
name: Kubescape scanning for misconfigurations
on: [push, pull_request]
jobs:
  kubescape:
    runs-on: ubuntu-latest
    permissions:
      actions: read
      contents: read
      security-events: write
    steps:
      - uses: actions/checkout@v3
      - uses: kubescape/github-action@main
        continue-on-error: false
        with:
          format: sarif
          outputFile: results
          failedThreshold: 50
      - name: Upload Kubescape scan results to Github Code Scanning
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: results.sarif
```
#### Fail Kubescape scanning based on maximum severity of a failed control

Scan a repository with Kubescape and fail the scanning step if the scan has found failed controls with severity of Medium and above:

```yaml
name: Kubescape scanning for misconfigurations
on: [push, pull_request]
jobs:
  kubescape:
    runs-on: ubuntu-latest
    permissions:
      actions: read
      contents: read
      security-events: write
    steps:
      - uses: action/checkout@v3
      - uses: kubescape/github-action@main
        continue-on-error: false
        with:
          format: sarif
          outputFile: results
          severityThreshold: medium
      - name: Upload Kubescape scan results to Github Code Scanning
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: results.sarif
```
