# Kubescape action

Run security scans on your Kubernetes manifests and Helm charts as a part of your CI using the Kubescape action. Kubescape scans K8s clusters, YAML files, and HELM charts, detecting misconfigurations according to multiple frameworks (such as the [NSA-CISA](https://www.armosec.io/blog/kubernetes-hardening-guidance-summary-by-armo) , [MITRE ATT&CK®](https://www.microsoft.com/security/blog/2021/03/23/secure-containerized-environments-with-updated-threat-matrix-for-kubernetes/)), software vulnerabilities. 

## Prerequisites
You need to make sure that workflows have [Read and write permissions](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository#configuring-the-default-github_token-permissions).  

## Usage

Add the following step to your workflow configuration:

```yaml
name: Kubescape scanning for misconfigurations
on: [push, pull_request]
jobs:
  kubescape:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - uses: kubescape/github-action@main
      continue-on-error: true
      # with:
        # # Optional - Add Kubescape cloud account ID.
        # account: ${{secrets.KUBESCAPE_ACCOUNT}}
        # # Optional - Scan a specific path. Default will scan all
        # files: "examples/*.yaml"
    - name: Archive kubescape scan results
      uses: actions/upload-artifact@v2
      with:
        name: kubescape
        path: results.xml
    - name: Publish Unit Test Results
      uses: mikepenz/action-junit-report@v3
      if: always()
      with:
        report_paths: "*.xml" 
```

## Inputs

| Name | Description | Required |
| --- | --- | ---|
| files | The YAML files/Helm charts to scan for misconfigurations. The files need to be provided with the complete path from the root of the repository. | No (default all repository) |
| frameworks | The security framework(s) to scan the files against. Multiple frameworks can be specified separated by a comma with no spaces. Example - `nsa,devopsbest`. Run `kubescape list frameworks` with the [Kubescape CLI](https://hub.armo.cloud/docs/installing-kubescape) to get a list of all frameworks. Either frameworks have to be specified or controls. | No |
| controls | The security control(s) to scan the files against. Multiple controls can be specified separated by a comma with no spaces. Example - `Configured liveness probe,Pods in default namespace`. Run `kubescape list controls` with the [Kubescape CLI](https://hub.armo.cloud/docs/installing-kubescape) to get a list of all controls. The complete control name can be specified or the ID such as `C-0001` can be specified. Either controls have to be specified or frameworks. | No |
| account | Account-id for the [kubescape cloud](https://cloud.armosec.io/). Used for custom configuration, such as frameworks, control configuration, etc. | No |
| failedThreshold | Failure threshold is the percent above which the command fails and returns exit code 1 (default 0 i.e, action fails if any control fails) | No (default 0) |
| severityThreshold | Severity threshold is the severity of a failed control at or above which the command terminates with an exit code 1 (default is `high`, i.e. the action fails if any High severity control fails) | No |

## Examples


#### Scan and submit results to the [Kubescape cloud](https://cloud.armosec.io/)

```yaml
name: Kubescape scanning for misconfigurations
on: [push, pull_request]
jobs:
  kubescape:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: kubescape/github-action@main
        with:
          account: ${{secrets.ACCOUNT}}
      - name: Archive kubescape scan results
        uses: actions/upload-artifact@v2
        with:
          name: kubescape-scan-report
          path: results.xml
      - name: Publish Unit Test Results
        uses: mikepenz/action-junit-report@v3
        if: always()
        with:
          report_paths: "*.xml" 
```

#### Scan specific Kubernetes YAML paths

```yaml
name: Kubescape scanning for misconfigurations
on: [push, pull_request]
jobs:
  kubescape:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: kubescape/github-action@main
        continue-on-error: true
        with:
          files: "kubernetes-manifests/*.yaml"
      - name: Archive kubescape scan results
        uses: actions/upload-artifact@v2
        with:
          name: kubescape-scan-report
          path: results.xml
      - name: Publish Unit Test Results
        uses: mikepenz/action-junit-report@v3
        if: always()
        with:
          report_paths: "*.xml" 
```

#### Scan a list of specific frameworks

Scan repository using Kubescape against a list of specific frameworks

```yaml
name: Kubescape scanning for misconfigurations
on: [push, pull_request]
jobs:
  kubescape:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: kubescape/github-action@main
        continue-on-error: true
        with:
          framework: |
            nsa,mitre
      - name: Archive kubescape scan results
        uses: actions/upload-artifact@v2
        with:
          name: kubescape-scan-report
          path: results.xml
      - name: Publish Unit Test Results
        uses: mikepenz/action-junit-report@v3
        if: always()
        with:
          report_paths: "*.xml" 
```

#### Fail Kubescape scanning based on failed-threshold

Scan repository with Kubescape and failed action if the percent of failed controls is more than failedThreshold

```yaml
name: Kubescape scanning for misconfigurations
on: [push, pull_request]
jobs:
  kubescape:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: kubescape/github-action@main
        continue-on-error: true
        with:
          failedThreshold: 50
      - name: Archive kubescape scan results
        uses: actions/upload-artifact@v2
        with:
          name: kubescape
          path: results.xml
      - name: Publish Unit Test Results
        uses: mikepenz/action-junit-report@v3
        if: always()
        with:
          report_paths: "*.xml" 
```
#### Fail Kubescape scanning based on severity-threshold

Scan repository with Kubescape and fail the action if the scan found failed controls with severity of Medium and above.

```yaml
name: Kubescape scanning for misconfigurations
on: [push, pull_request]
jobs:
  kubescape:
    runs-on: ubuntu-latest
    steps:
      - uses: action/checkout@v3
      - uses: kubescape/github-action@main
        continue-on-error: true
        with:
          severityThreshold: medium
      - name: Archive kubescape scan results
        uses: actions/upload-artifact@v2
        with:
          name: kubescape
          path: results.xml
      - name: Publish Unit Test Results
        uses: mikepenz/action-junit-report@v3
        if: always()
        with:
          report_paths: "*.xml" 
```
 
