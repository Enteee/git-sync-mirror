#!/usr/bin/env sh
set -euo pipefail

# Environment
SRC_REPO="${SRC_REPO?Missing source repository}"
DST_REPO="${DST_REPO?Missing destination repository}"

HTTP_TLS_VERIFY="${HTTP_TLS_VERIFY:-true}"
HTTP_SRC_PROXY="${HTTP_SRC_PROXY:-""}"
HTTP_DST_PROXY="${HTTP_DST_PROXY:-""}"

SLEEP_TIME="${SLEEP_TIME:-60s}"

git config --global "http.sslVerify" "${HTTP_TLS_VERIFY}"
git config --global "http.${SRC_REPO}.proxy" "${HTTP_SRC_PROXY}"
git config --global "http.${DST_REPO}.proxy" "${HTTP_DST_PROXY}"

LOCAL_REPO="$(mktemp -d)"
git clone --mirror "${SRC_REPO}" "${LOCAL_REPO}"

cd "${LOCAL_REPO}"
while true; do
  git remote update
  git push --mirror "${DST_REPO}"
  sleep "${SLEEP_TIME}"
done
