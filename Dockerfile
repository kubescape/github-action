FROM quay.io/armosec/kubescape

COPY --chown=armo:armo entrypoint.sh entrypoint.sh

ENTRYPOINT ["./entrypoint.sh"]
