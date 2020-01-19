FROM enteee/tls-tofu:alpine-latest

# Disable TLS-TOFU by default
ENV TLS_TOFU=false

RUN set -exuo pipefail \
  && apk add \
    git \
    bash

ENV APP_ROOT=/opt/git-sync-mirror
ENV PATH=${APP_ROOT}/bin:${PATH}
ENV HOME=${APP_ROOT}

COPY bin/ ${APP_ROOT}/bin/

RUN set -exuo pipefail \
  && chmod -R u+x ${APP_ROOT}/bin \
  && chgrp -R 0 ${APP_ROOT} \
  && chmod -R g=u ${APP_ROOT} /etc/passwd

USER 1000080001:0

WORKDIR ${APP_ROOT}
CMD ["git-sync-mirror.sh"]
