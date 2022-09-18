FROM quay.io/armosec/kubescape

USER root
COPY entrypoint.sh entrypoint.sh

ENV KS_SKIP_UPDATE_CHECK true
ENV KS_DOWNLOAD_ARTIFACTS false

ENTRYPOINT ["./entrypoint.sh"]
