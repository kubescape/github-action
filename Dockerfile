FROM quay.io/armosec/kubescape

USER root

RUN addgroup -S non-root && adduser -S non-root -G non-root

RUN chown -R non-root:non-root /home/non-root

USER non-root

WORKDIR /home/non-root

ADD entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
