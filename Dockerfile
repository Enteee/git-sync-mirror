FROM enteee/tls-tofu:alpine-latest

# Disable TLS-TOFU by default
ENV TLS_TOFU false

RUN set -exuo pipefail \
  && apk add \
    git \
    bash \
  && addgroup -g 1000 -S git \
  && adduser -u 1000 -S git -G git

USER git:git

COPY run.sh /run.sh
CMD ["/run.sh"]
