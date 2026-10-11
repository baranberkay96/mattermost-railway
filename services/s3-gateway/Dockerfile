# S3 gateway for Railway Buckets.
#
# Mattermost's S3 client (minio-go) always sends path-style requests
# (https://host/bucket/key) to non-AWS endpoints, while Railway Buckets only
# accept virtual-hosted-style requests (https://bucket.host/key). This service
# runs `rclone serve s3`: Mattermost talks path-style S3 to it over Railway's
# private network, and rclone forwards every object to the Railway Bucket with
# virtual-hosted addressing. Files end up in the Bucket under one folder per
# logical bucket (default: mattermost/).
#
# The rclone version is pinned here; upgrade by changing this tag.
FROM rclone/rclone:1.75.2

COPY --chmod=755 s3-gateway.sh /usr/local/bin/s3-gateway

# All settings come from environment variables; an empty config file keeps
# rclone from logging a "config file not found" notice on every start.
RUN mkdir -p /config/rclone && touch /config/rclone/rclone.conf

ENV PORT=9000

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/s3-gateway"]
