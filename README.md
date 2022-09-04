# Kubescape action

Run security scans on your Kubernetes manifests and Helm charts as a part of your CI using the Kubescape action. Kubescape scans K8s clusters, YAML files, and HELM charts, detecting misconfigurations according to multiple frameworks (such as the [NSA-CISA](https://www.armosec.io/blog/kubernetes-hardening-guidance-summary-by-armo) , [MITRE ATT&CK®](https://www.microsoft.com/security/blog/2021/03/23/secure-containerized-environments-with-updated-threat-matrix-for-kubernetes/)), software vulnerabilities. 

## Usage

Add the following step to your workflow configuration:

```yaml
steps:
  - uses: actions/checkout@v2 
  - uses: avinashupadhya99/kubescape-action@main
    with:
      files: kubernetes/*.yaml
```

## Inputs

| Name | Description | Required |
| --- | --- | ---|
| files | The YAML files/Helm charts to scan for misconfigurations. The files need to be provided with the complete path from the root of the repository. | Yes |
| threshold | Failure threshold is the percent above which the command fails and returns exit code 1 (default 0 i.e, action fails if any control fails) | No (default 0) |
| framework | The security framework(s) to scan the files against. Multiple frameworks can be specified separated by a comma with no spaces. Example - `nsa,devopsbest`. Run `kubescape list frameworks` with the [Kubescape CLI](https://hub.armo.cloud/docs/installing-kubescape) to get a list of all frameworks. Either frameworks have to be specified or controls. | No |
| control | The security control(s) to scan the files against. Multiple controls can be specified separated by a comma with no spaces. Example - `Configured liveness probe,Pods in default namespace`. Run `kubescape list controls` with the [Kubescape CLI](https://hub.armo.cloud/docs/installing-kubescape) to get a list of all controls. The complete control name can be specified or the ID such as `C-0001` can be specified. Either controls have to be specified or frameworks. | No |
| args | Additional arguments to the Kubescape CLI. The following arguments are supported - <ul><li>` -f, --format` - Output format. Supported formats: "pretty-printer"/"json"/"junit"/"prometheus" (default "pretty-printer")</li><li>`-o, --output` - Output file. Print output to file and not stdout</li><li>` -s, --silent` - Silent progress messages</li><li>`--verbose` - Display all of the input resources and not only failed resources</li><li>`--logger` - Logger level. Supported: debug/info/success/warning/error/fatal (default "info")</li></ul> | No |
| exceptions | The JSON file containing at least one resource and one policy.Refer [exceptions](https://hub.armo.cloud/docs/exceptions) docs for more info. Objects with exceptions will be presented as exclude and not fail. | No |
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
      - uses: avinashupadhya99/kubescape-action@main
        with:
          files: "kubernetes-prod/*.yaml"
```

- With arguments

```yaml
name: Scan YAML files using Kubescape with additional arguments
on: push

jobs:
  kubescape:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@master
      - uses: avinashupadhya99/kubescape-action@main
        with:
          args: "--fail-threshold 90"
          files: "kubernetes-prod/*.yaml"
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
      - uses: avinashupadhya99/kubescape-action@main
        with:
          files: "kubernetes-prod/*.yaml"
          framework: |
            nsa,devopsbest
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
      - uses: avinashupadhya99/kubescape-action@main
        with:
          files: "kubernetes-prod/*.yaml"
          control: |
            Configured liveness probe,Pods in default namespace,Bash/cmd inside container
```

- Store the results in a file as an artifacts

```yaml
name: Scan YAML files with Kubescape and store results as an artifact
on: push

jobs:
  kubescape:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@master
      - uses: avinashupadhya99/kubescape-action@main
        with:
          args: "--format junit --output results.xml"
          files: "kubernetes-prod/*.yaml"
          framework: nsa
      - name: Archive kubescape scan results
        uses: actions/upload-artifact@v2
        with:
          name: kubescape-scan-report
          path: results.xml
```

## License

[//]: TODO
