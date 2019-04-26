FROM alpine:3.9.3

COPY run.sh /run.sh

RUN set -exuo pipefail \
  && apk add \
    git \
  && addgroup -g 1000 -S git \
  && adduser -u 1000 -S git -G git

USER git:git

ENTRYPOINT ["/run.sh"]
