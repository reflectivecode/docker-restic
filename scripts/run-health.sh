#!/usr/bin/env sh
set -o errexit
set -o pipefail
set -o nounset

test `find "${HEALTH_FLAG}" -mmin -"$((INTERVAL / 60 + HEALTH_TIMEOUT))"`
mkdir -p ${HEALTH_ERRORS} || exit 1
find ${HEALTH_ERRORS} -type f -maxdepth 1 -print || exit 1
error_count=$(find ${HEALTH_ERRORS} -type f -maxdepth 1 -print | wc -l)

if [ "${error_count}" != "0" ]; then
    echo "errors backing up ${error_count} repos"
    exit 1
fi
