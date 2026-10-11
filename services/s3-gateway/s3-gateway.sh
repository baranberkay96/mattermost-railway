#!/bin/sh
# Path-style S3 API on the private network, stored in a Railway Bucket.
#
# Inputs (all set by the template):
#   BUCKET_NAME, BUCKET_ENDPOINT, BUCKET_REGION,
#   BUCKET_ACCESS_KEY_ID, BUCKET_SECRET_ACCESS_KEY   Railway Bucket credentials
#   BUCKET_FORCE_PATH_STYLE  false for current Railway Buckets (virtual-hosted)
#   BUCKET_PREFIX            optional folder inside the Bucket for all data
#   GATEWAY_ACCESS_KEY, GATEWAY_SECRET_KEY            keys the apps sign with
#   GATEWAY_BUCKETS          space-separated logical bucket names to create
#   PORT                     listen port (default 9000)
set -eu

log() { printf '%s s3-gateway: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }
die() { log "ERROR: $*" >&2; exit 1; }

for name in BUCKET_NAME BUCKET_ENDPOINT BUCKET_ACCESS_KEY_ID BUCKET_SECRET_ACCESS_KEY \
            GATEWAY_ACCESS_KEY GATEWAY_SECRET_KEY; do
  eval "value=\${${name}:-}"
  [ -n "${value}" ] || die "${name} is not set"
done

# rclone remote "railway" = the Railway Bucket, configured through rclone's
# own environment variables (no config file on disk).
export RCLONE_CONFIG_RAILWAY_TYPE=s3
export RCLONE_CONFIG_RAILWAY_PROVIDER=Other
export RCLONE_CONFIG_RAILWAY_ENDPOINT="${BUCKET_ENDPOINT}"
export RCLONE_CONFIG_RAILWAY_REGION="${BUCKET_REGION:-auto}"
export RCLONE_CONFIG_RAILWAY_ACCESS_KEY_ID="${BUCKET_ACCESS_KEY_ID}"
export RCLONE_CONFIG_RAILWAY_SECRET_ACCESS_KEY="${BUCKET_SECRET_ACCESS_KEY}"
export RCLONE_CONFIG_RAILWAY_FORCE_PATH_STYLE="${BUCKET_FORCE_PATH_STYLE:-false}"
# The Bucket already exists and its keys may not be allowed to create buckets.
export RCLONE_CONFIG_RAILWAY_NO_CHECK_BUCKET=true
# Keep empty folders as marker objects so a logical bucket exists before its
# first file is written.
export RCLONE_CONFIG_RAILWAY_DIRECTORY_MARKERS=true

root="railway:${BUCKET_NAME}"
if [ -n "${BUCKET_PREFIX:-}" ]; then
  root="${root}/${BUCKET_PREFIX#/}"
fi

# Create each logical bucket as a folder. Retries cover the Bucket's
# credentials not being usable yet right after the project is created.
for bucket in ${GATEWAY_BUCKETS:-}; do
  attempt=1
  until rclone mkdir "${root}/${bucket}" --retries 1 --low-level-retries 3; do
    [ "${attempt}" -lt 30 ] || die "cannot reach the Railway Bucket (checked 30 times)"
    log "Bucket not reachable yet (attempt ${attempt}), retrying in 10 s"
    attempt=$((attempt + 1))
    sleep 10
  done
  log "logical bucket '${bucket}' ready"
done

log "serving ${root} as S3 on port ${PORT:-9000}"
# --no-cleanup keeps a logical bucket's folder when its last file is deleted.
exec rclone serve s3 "${root}" \
  --addr ":${PORT:-9000}" \
  --auth-key "${GATEWAY_ACCESS_KEY},${GATEWAY_SECRET_KEY}" \
  --no-cleanup \
  --max-header-bytes 65536 \
  --multipart-streaming-buffer-total "${GATEWAY_BUFFER_TOTAL:-512Mi}" \
  --log-level "${GATEWAY_LOG_LEVEL:-NOTICE}"
