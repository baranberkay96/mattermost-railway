# NOTICE — Mattermost template

This is a community template. It is not affiliated with or endorsed by Mattermost, Inc. "Mattermost" is a trademark of Mattermost, Inc.

## Upstream sources checked (2026-10-11)

| Source | Version / path | License | Use |
|---|---|---|---|
| mattermost/mattermost | `v11.11.1`: `server/public/model/config.go`, `server/config/environment.go` | AGPL-3.0 source; compiled Team Edition under MIT (see `LICENSE.txt`) | Setting names, environment override rules (space-separated lists, JSON maps, env-set fields locked) |
| mattermost/mattermost | `v11.11.1`: `server/platform/shared/filestore/s3store.go`, `server/go.mod` | as above | S3 driver behaviour (minio-go v7.3.0, no bucket-lookup option → path-style for non-AWS hosts) |
| mattermost/mattermost | `v11.11.1`: `server/channels/app/limits.go` | as above | Team Edition user limits (200 warning / 250 hard) |
| mattermost/docker | `main` (2026-05): `docker-compose.yml`, `env.example` | Apache-2.0 | Topology, Postgres 18, DSN options, Bleve/site URL variables (nothing copied verbatim) |
| `mattermost/mattermost-team-edition:11.11.1` | image `config.json` defaults, entrypoint, user | MIT (compiled) | Defaults for file store, logging, push, SQL pool |
| minio/minio-go | `v7.3.0`: `pkg/s3utils/utils.go`, `api.go` | Apache-2.0 | Confirmed path-style addressing for non-AWS endpoints |
| rclone/rclone | `v1.75.2`, `rclone serve s3` docs | MIT | Gateway behaviour and flags |
| tigrisdata/tigris-os-docs | `docs/buckets/public-bucket.md`, `docs/guides/ragflow.md`, `docs/sdks/s3/aws-go-sdk.mdx` | — | Virtual-hosted addressing requirement for new buckets |
| Railway docs | Storage Buckets | — | Bucket variables, URL style, limitations |

## Market templates reviewed

| Code | License | Use |
|---|---|---|
| `arWblT` "Mattermost" (base) | n/a (image-based) | Service layout and ping healthcheck idea; no files copied |
| `mattermost` "Mattermost [Updated Oct '26]" | n/a (image-based) | Reviewed only |
| `mattermost-team-edition` | n/a (image-based) | Reviewed only |

## Railway base services

`Postgres` copied from `templates/_railway-base/postgres.json` (unchanged).

## Runtime images

- `mattermost/mattermost-team-edition:11.11.1` — compiled by Mattermost, Inc., MIT licence for compiled versions.
- `rclone/rclone:1.75.2` — MIT.
- `ghcr.io/railwayapp-templates/postgres-ssl:18` — PostgreSQL License.

All files in `template/` (gateway Dockerfile and script, documentation) were written for this template.
