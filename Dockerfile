FROM quay.io/armosec/kubescape

WORKDIR /kubescape

COPY entrypoint.sh /kubescape/entrypoint.sh

ENTRYPOINT ["/kubescape/entrypoint.sh"]
