FROM alpine:latest
ARG KUBESCAPE_VERSION=latest
RUN apk add --no-cache git bash curl jq
RUN curl -s https://raw.githubusercontent.com/kubescape/kubescape/master/install.sh | KUBESCAPE_VERSION=${KUBESCAPE_VERSION} /bin/bash
COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
