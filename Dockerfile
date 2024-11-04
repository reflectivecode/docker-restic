FROM alpine:3.20

# required environment variables
#   AWS_ACCESS_KEY_ID
#   AWS_SECRET_ACCESS_KEY
#   RESTIC_REPOSITORY
#   RESTIC_PASSWORD

# optional environment variables
#   PUSH_URL
#   RESTIC_EXCLUDE

ENV HEALTH_TIMEOUT=5 \
    HEALTH_FLAG=.health \
    HEALTH_ERRORS=.health_errors \
    IDEMPOTENCE_FLAG=.restic_repo \
    INTERVAL=-1 \
    RESTIC_KEEP_WITHIN=1d \
    RESTIC_KEEP_WITHIN_HOURLY=7d \
    RESTIC_KEEP_WITHIN_DAILY=90d \
    RESTIC_COMPRESSION=max

RUN set -x \
 && apk add --no-cache \
    curl \
    jq \
    restic \
    tini

COPY scripts /usr/local/bin/

ENTRYPOINT ["/sbin/tini", "--"]

CMD ["run-root.sh"]

HEALTHCHECK --interval=30s --timeout=1s --retries=9 CMD run-health.sh || exit 1
