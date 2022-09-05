FROM quay.io/armosec/kubescape

USER root
ADD entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
