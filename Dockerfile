ARG KUBESCAPE_VERSION=v3.0.21
FROM quay.io/kubescape/kubescape-cli:${KUBESCAPE_VERSION}

# Kubescape uses root privileges for writing the results to a file
USER root

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
