FROM quay.io/kubescape/kubescape:dev-v2.0.359

# USER root
COPY entrypoint.sh entrypoint.sh

ENTRYPOINT ["entrypoint.sh"]
