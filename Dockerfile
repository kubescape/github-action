FROM quay.io/kubescape/kubescape:dev-v2.0.371

USER root
COPY entrypoint.sh entrypoint.sh

ENV KS_SKIP_UPDATE_CHECK true
ENV KS_DOWNLOAD_ARTIFACTS false

ENTRYPOINT ["./entrypoint.sh"]
