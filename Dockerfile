FROM quay.io/kubescape/kubescape:dev-v2.0.359

USER root
ADD entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
