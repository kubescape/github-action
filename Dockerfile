FROM quay.io/kubescape/kubescape:dev-v2.0.359

# USER root
COPY entrypoint.sh /usr/bin/entrypoint.sh

ENTRYPOINT ["entrypoint.sh"]
