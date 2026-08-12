FROM alpine:latest
ARG KUBESCAPE_VERSION=latest
RUN apk add --no-cache git bash curl jq
RUN if [ "${KUBESCAPE_VERSION}" = "latest" ]; then \
      curl -s https://raw.githubusercontent.com/kubescape/kubescape/master/install.sh | /bin/bash; \
    else \
      curl -s https://raw.githubusercontent.com/kubescape/kubescape/master/install.sh | /bin/bash -s -- -v "${KUBESCAPE_VERSION}"; \
    fi
COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
