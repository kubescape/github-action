FROM quay.io/kubescape/kubescape:v2.0.171

# Kubescape uses root privileges for writing the results to a file
USER root

# KS_SKIP_UPDATE_CHECK - skip latest version check
ENV KS_SKIP_UPDATE_CHECK true

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
