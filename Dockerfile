# TODO(vladklokun): bump to a Kubescape version with image scanning support
FROM quay.io/kubescape/kubescape:v2.0.9-ghactions

# Kubescape uses root privileges for writing the results to a file
USER root

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
