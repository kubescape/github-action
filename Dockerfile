FROM quay.io/armosec/kubescape

WORKDIR /home/armo
COPY --chown=armo:armo entrypoint.sh entrypoint.sh

ENTRYPOINT ["./entrypoint.sh"]
