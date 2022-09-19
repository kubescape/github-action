FROM quay.io/kubescape/kubescape:v2.0.171

# We will need root privileges, so that kubescape can write the results to a file
USER root
COPY entrypoint.sh /entrypoint.sh

# KS_SKIP_UPDATE_CHECK is used to skip checking whether the run is on the latest version of kubescape
ENV KS_SKIP_UPDATE_CHECK true
# KS_DOWNLOAD_ARTIFACTS X is used so that kubescape will not look for whether the artifact exists locally in cache
ENV KS_DOWNLOAD_ARTIFACTS false

ENTRYPOINT ["/entrypoint.sh"]
