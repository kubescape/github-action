# Kubescape action

Run security scans on your Kubernetes manifests and Helm charts as a part of your CI using the Kubescape action. Kubescape scans K8s clusters, YAML files, and HELM charts, detecting misconfigurations according to multiple frameworks (such as the [NSA-CISA](https://www.armosec.io/blog/kubernetes-hardening-guidance-summary-by-armo) , [MITRE ATT&CK®](https://www.microsoft.com/security/blog/2021/03/23/secure-containerized-environments-with-updated-threat-matrix-for-kubernetes/)), software vulnerabilities. 

## Usage

Add the following step to your workflow configuration:

```yaml
steps:
  - uses: actions/checkout@master
  - uses: kubescape/github-action@main
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

## Inputs

| Name | Description | Required |
| --- | --- | ---|
| files | The YAML files/Helm charts to scan for misconfigurations. The files need to be provided with the complete path from the root of the repository. | No (default all repository) |
| framework | The security framework(s) to scan the files against. Multiple frameworks can be specified separated by a comma with no spaces. Example - `nsa,devopsbest`. Run `kubescape list frameworks` with the [Kubescape CLI](https://hub.armo.cloud/docs/installing-kubescape) to get a list of all frameworks. Either frameworks have to be specified or controls. | No |
| control | The security control(s) to scan the files against. Multiple controls can be specified separated by a comma with no spaces. Example - `Configured liveness probe,Pods in default namespace`. Run `kubescape list controls` with the [Kubescape CLI](https://hub.armo.cloud/docs/installing-kubescape) to get a list of all controls. The complete control name can be specified or the ID such as `C-0001` can be specified. Either controls have to be specified or frameworks. | No |
| account | Account-id for the [SAS](https://cloud.armosec.io/). Used for custom configuration, such as frameworks, control configuration, etc. | No |
| failedThreshold | Failure threshold is the percent above which the command fails and returns exit code 1 (default 0 i.e, action fails if any control fails) | No (default 0) |
| thresholdCritical |Threshold Critical is the number or more of critical controls that failed  and returns exit code 1 | No |
| thresholdHigh |Threshold High is the number or more of high controls that failed and returns exit code 1 | No |
| thresholdMedium |Threshold Medium is the number or more of medium controls that failed and returns exit code 1 | No |
| thresholdLow |Threshold Low is the number or more of low controls that failed and returns exit code 1 | No |

## Examples

- Standard

```yaml
name: Scan YAML files with Kubescape
on: push

jobs:
  kubescape:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@master
      - uses: kubescape/github-action@main
        with:
          files: "kubernetes-prod/*.yaml"
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

- Specifying frameworks

```yaml
name: Scan YAML files using Kubescape and against specific frameworks
on: push

jobs:
  kubescape:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@master
      - uses: kubescape/github-action@main
        with:
          files: "kubernetes-prod/*.yaml"
          framework: |
            nsa,devopsbest
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

- Specific controls

```yaml
name: Scan YAML files using Kubescape and for specific controls
on: push

jobs:
  kubescape:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@master
      - uses: kubescape/github-action@main
        with:
          files: "kubernetes-prod/*.yaml"
          control: |
            Configured liveness probe,Pods in default namespace,Bash/cmd inside container
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

- With Account-id

```yaml
name: Scan YAML files using Kubescape with account, To use custom configuration from the SAS system
on: push

jobs:
  kubescape:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@master
      - uses: kubescape/github-action@main
        with:
          account: "*****-*****-*****-*****"
          files: "kubernetes-prod/*.yaml"
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

- Using failed-threshold

```yaml
name: Scan YAML files with Kubescape and failed action If the percent of failed controls is more than failedThreshold
on: push

jobs:
  kubescape:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@master
      - uses: kubescape/github-action@main
        with:
          args: "--format junit --output results.xml"
          files: "kubernetes-prod/*.yaml"
          failedThreshold: 50
      - name: Archive kubescape scan results
        uses: actions/upload-artifact@v2
        with:
          name: kubescape-scan-report
          path: results.xml
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
- Using severity-threshold

```yaml
name: Scan YAML files with Kubescape and failed action If the number of failed controls with severity {X} is more than Threshold{X}
on: push

jobs:
  kubescape:
    runs-on: ubuntu-latest
    steps:
      - uses: action/checkout@master
      - uses: kubescape/github-action@main
        with:
          files: "kubernetes-prod/*.yaml"
          thresholdCritical: 1
          thresholdHigh: 5
          thresholdMedium: 10
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

## License

[//]: TODO
