FROM alpine:3.9.3

COPY run.sh /run.sh

RUN set -exuo pipefail \
  && apk add \
    git

USER 1000:1000

ENTRYPOINT ["/run.sh"]
