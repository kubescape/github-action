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
        # # Optional: Specify the Kubescape cloud account ID
        # account: ${{secrets.KUBESCAPE_ACCOUNT}}
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

To make Kubescape automatically suggest fixes to your pull requests by code review, use the following workflow:

```yaml
name: Suggest autofixes with Kubescape for PR by reviews
on:
  pull_request_target:

jobs:
  kubescape-fix-pr-reviews:
    runs-on: ubuntu-latest
    permissions:
      pull-requests: write

    steps:
    - uses: actions/checkout@v3
      with:
        fetch-depth: 0
        ref: ${{github.event.pull_request.head.ref}}
        repository: ${{github.event.pull_request.head.repo.full_name}}
    - name: Get changed files
      id: changed-files
      uses: tj-actions/changed-files@v35
    - uses: kubescape/github-action@main
      with:
        account: ${{secrets.KUBESCAPE_ACCOUNT}}
        files: ${{ steps.changed-files.outputs.all_changed_files }}
        fixFiles: true
        format: "sarif"
    - name: PR Suggester according to SARIF file
      if: github.event_name == 'pull_request_target'
      uses: HollowMan6/sarif4reviewdog@v1.0.0
      with:
        file: 'results.sarif'
        level: warning
```

The above workflow works by collecting the [SARIF (Static Analysis Results Interchange Format)](https://www.oasis-open.org/committees/tc_home.php?wg_abbrev=sarif) file that kubescape generates. Then, with the help of [HollowMan6/sarif4reviewdog](https://github.com/marketplace/actions/sarif-support-for-reviewdog), convert the SARIF file into [RDFormat (Reviewdog Diagnostic Format)](https://github.com/reviewdog/reviewdog/tree/master/proto/rdf) and generate reviews using [Reviewdog](https://github.com/reviewdog/reviewdog).

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

## Inputs

| Name | Description | Required |
| --- | --- | ---|
| files | YAML files or Helm charts to scan for misconfigurations. The files need to be provided with the complete path from the root of the repository. | No (default is `.` which scans the whole repository) |
| outputFile | Name of the output file where the scan result will be stored without the extension. | No (default is `results`) |
| frameworks | Security framework(s) to scan the files against. Multiple frameworks can be specified separated by a comma with no spaces. Example - `nsa,devopsbest`. Run `kubescape list frameworks` in the [Kubescape CLI](https://hub.armo.cloud/docs/installing-kubescape) to get a list of all frameworks. Either frameworks have to be specified or controls. | No |
| controls | Security control(s) to scan the files against. Multiple controls can be specified separated by a comma with no spaces. Example - `Configured liveness probe,Pods in default namespace`. Run `kubescape list controls` in the [Kubescape CLI](https://hub.armo.cloud/docs/installing-kubescape) to get a list of all controls. You can use either the complete control name or the control ID such as `C-0001` to specify the control you want use. You must specify either the control(s) or the framework(s) you want used in the scan. | No |
| account | Account ID for [Kubescape cloud](https://cloud.armosec.io/). Used for custom configuration, such as frameworks, control configuration, etc. | No |
| failedThreshold | Failure threshold is the percent above which the command fails and returns exit code 1 (default 0 i.e, action fails if any control fails) | No (default 0) |
| severityThreshold | Severity threshold is the severity of a failed control at or above which the command terminates with an exit code 1 (default is `high`, i.e. the action fails if any High severity control fails) | No |
| verbose | Display all of the input resources and not only failed resources. Default is off | No |
| exceptions | The JSON file containing at least one resource and one policy. Refer [exceptions](https://hub.armo.cloud/docs/exceptions) docs for more info. Objects with exceptions will be presented as exclude and not fail. | No |
| controlsConfig | The file containing controls configuration. Use `kubescape download controls-inputs` to download the configured controls-inputs. | No |
## Examples


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

