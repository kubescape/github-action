FROM quay.io/armosec/kubescape

USER ks
ADD entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
