# Mattermost v11 Team Chat — composer spec

| Field | Value |
|---|---|
| Listing name | **Mattermost v11 Team Chat** (version label `v11` = Mattermost major, Mattermost's own "v" convention; image tag `11.11.1`) |
| Description | Secure team messaging with channels, threads and file storage on S3. (68 chars) |
| Category | Other |
| Tags | mattermost, team-chat, slack-alternative, messaging, collaboration, self-hosted |
| Base market template | `arWblT` "Mattermost" (329 projects, 92 active): `mattermost/mattermost-team-edition:latest` + Postgres, `/api/v4/system/ping` healthcheck, `SITEURL` from `RAILWAY_PUBLIC_DOMAIN`. Kept: official Team Edition image, ping healthcheck, site URL wiring, env-based configuration. Fixed: no persistent file storage, config lost on redeploy, database reached over the public TCP proxy, floating `latest` tag. Also reviewed `mattermost` (identical service layout, 96 projects) and `mattermost-team-edition` (26 projects, adds a volume for `/mattermost/data`). |
| Upstream checked | Mattermost `v11.11.1` (2026-09-24, current stable; `12.0.0` is still a release candidate): `mattermost/docker` `docker-compose.yml` + `env.example` (Apache-2.0), `server/public/model/config.go`, `server/config/environment.go`, `server/platform/shared/filestore/s3store.go`, `server/channels/app/limits.go`, `server/go.mod` (minio-go v7.3.0), image `mattermost/mattermost-team-edition:11.11.1` (distroless, amd64, defaults extracted from its `config.json`). Pinned 2026-10-11. |

## Architecture

```
 users (web, desktop, mobile) ──HTTPS/WSS──► Mattermost (:8065, official image, config stored in Postgres)
                                               │                         │
                                               ▼                         ▼  path-style S3, private network
                                           Postgres 18             S3 Gateway (rclone serve s3 :9000)
                                                                         │  virtual-hosted S3, HTTPS
                                                                         ▼
                                                                  Railway Bucket  (mattermost/… folder)
```

**Why a gateway.** Mattermost's S3 driver (minio-go) always sends path-style requests (`https://host/bucket/key`) to endpoints it does not recognise as AWS/GCS/Aliyun, and Mattermost has no setting to change that (`s3store.go` never sets `BucketLookup`). Railway Buckets (Tigris, `t3.storageapi.dev`) use virtual-hosted URLs; Tigris documents that path-style URLs are no longer supported for buckets created on or after 2025-02-19 and its client guides require virtual-hosted addressing. The `S3 Gateway` service runs `rclone serve s3` on the private network: Mattermost signs path-style requests with generated gateway keys, rclone stores each object in the Railway Bucket with virtual-hosted addressing. The Mattermost image itself is distroless (no shell), so the translation cannot live inside it.

**Stateless Mattermost.** `MM_CONFIG` points at Postgres, so the configuration (System Console changes, SAML certs, plugin settings) lives in the database; uploads, avatars, emoji and marketplace plugins live in the Bucket (Mattermost re-syncs plugins from the file store on every start). Mattermost therefore needs no volume and survives redeploys without losing anything.

## Services

| Service | Source | Start / pre-deploy | Public | Healthcheck | Volume | Restart | Replicas |
|---|---|---|---|---|---|---|---|
| `Mattermost` | image `mattermost/mattermost-team-edition:11.11.1` | image default (runs DB migrations on start) | domain → 8065 | `/api/v4/system/ping`, 600 s | — | ALWAYS | 1 (Team Edition has no clustering) |
| `S3 Gateway` | repo `/services/s3-gateway` (FROM `rclone/rclone:1.75.2`) | `s3-gateway.sh`: creates the `mattermost/` folder marker, then `rclone serve s3` | — (private :9000) | — (S3 API needs signed requests) | — | ALWAYS | 1 |
| `Postgres` | `ghcr.io/railwayapp-templates/postgres-ssl:18` (from `_railway-base/postgres.json`) | image | — | — | `/var/lib/postgresql/data` | ON_FAILURE ×10 | 1 |
| `Bucket` | Railway Bucket | — | — | — | — | — | — |

Migrations are not in a pre-deploy step on purpose: the image is distroless, Mattermost migrates on start in seconds, and a pre-deploy step would fail the whole deploy if Postgres were not reachable yet (Rule 8.5/8.6). Restart policy ALWAYS plus a 600 s healthcheck cover a slow Postgres start.

## Variables

**`Mattermost`** (settings set through variables are greyed out in System Console; change them in Railway)

| Variable | Default | Notes |
|---|---|---|
| `PORT` | `8065` | Railway healthcheck port. |
| `MM_SERVICESETTINGS_SITEURL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Update for a custom domain. |
| `MM_SERVICESETTINGS_LISTENADDRESS` | `:8065` | Go listener, dual-stack. |
| `MM_SERVICESETTINGS_TRUSTEDPROXYIPHEADER` | `X-Forwarded-For X-Real-IP` | Real client IPs behind Railway's proxy. |
| `MM_SQLSETTINGS_DRIVERNAME` / `MM_SQLSETTINGS_DATASOURCE` | `postgres` / `postgres://${{Postgres.PGUSER}}:${{Postgres.PGPASSWORD}}@${{Postgres.RAILWAY_PRIVATE_DOMAIN}}:5432/${{Postgres.PGDATABASE}}?sslmode=disable&connect_timeout=10` | Private network, upstream's DSN options. |
| `MM_CONFIG` | `${{MM_SQLSETTINGS_DATASOURCE}}` | Database-backed configuration. |
| `MM_SQLSETTINGS_MAXOPENCONNS` / `MAXIDLECONNS` | `50` / `20` | Upstream default 100 would exhaust Railway Postgres' 100 connections. |
| `MM_SQLSETTINGS_ATRESTENCRYPTKEY` | `${{secret(32)}}` | Never change. |
| `MM_FILESETTINGS_DRIVERNAME` | `amazons3` | |
| `MM_FILESETTINGS_AMAZONS3ENDPOINT` | `${{S3 Gateway.RAILWAY_PRIVATE_DOMAIN}}:${{S3 Gateway.PORT}}` | host:port without scheme. |
| `MM_FILESETTINGS_AMAZONS3BUCKET` | `mattermost` | Folder in the Railway Bucket; must be in the gateway's `GATEWAY_BUCKETS`. |
| `MM_FILESETTINGS_AMAZONS3ACCESSKEYID` / `SECRETACCESSKEY` | `${{S3 Gateway.GATEWAY_ACCESS_KEY}}` / `${{S3 Gateway.GATEWAY_SECRET_KEY}}` | |
| `MM_FILESETTINGS_AMAZONS3SSL` / `REGION` | `false` / `us-east-1` | Plain HTTP on the private network; explicit region avoids a `GetBucketLocation` call. |
| `MM_FILESETTINGS_PUBLICLINKSALT` | `${{secret(32)}}` | |
| `MM_FILESETTINGS_MAXFILESIZE` | `104857600` | 100 MB (upstream default). |
| `MM_TEAMSETTINGS_MAXUSERSPERTEAM` | `250` | Upstream default 50; Team Edition is capped at 250 active users per server anyway. |
| `MM_EMAILSETTINGS_PUSHNOTIFICATIONCONTENTS` | `generic` | Upstream default `full` sends message text through the external push proxy. |
| `MM_LOGSETTINGS_ENABLEFILE`, `MM_NOTIFICATIONLOGSETTINGS_ENABLEFILE`, `MM_LOGSETTINGS_CONSOLEJSON` | `false` | Logs go to Railway's log viewer, not the ephemeral disk. |
| `TZ`, `RAILWAY_DEPLOYMENT_DRAINING_SECONDS` | `UTC`, `30` | |

**`S3 Gateway`**: `PORT=9000`; `BUCKET_NAME/ENDPOINT/REGION/ACCESS_KEY_ID/SECRET_ACCESS_KEY` = `${{Bucket.*}}`; `BUCKET_FORCE_PATH_STYLE=false`; `BUCKET_PREFIX` (empty); `GATEWAY_ACCESS_KEY=${{secret(20, A-Z0-9)}}`; `GATEWAY_SECRET_KEY=${{secret(40, alnum)}}`; `GATEWAY_BUCKETS=mattermost`; `GATEWAY_LOG_LEVEL=NOTICE`. No variable starts with `RCLONE_` (Rule 8.10); the script maps them to rclone's own environment variables.

**`Postgres`**: Railway base variables unchanged (`postgres-ssl:18`; upstream `env.example` also uses PostgreSQL 18).

**Optional email (not set by default, because any variable set here locks the field in System Console):** `MM_EMAILSETTINGS_SENDEMAILNOTIFICATIONS=true`, `MM_EMAILSETTINGS_SMTPSERVER`, `MM_EMAILSETTINGS_SMTPPORT=587`, `MM_EMAILSETTINGS_ENABLESMTPAUTH=true`, `MM_EMAILSETTINGS_SMTPUSERNAME`, `MM_EMAILSETTINGS_SMTPPASSWORD`, `MM_EMAILSETTINGS_CONNECTIONSECURITY=STARTTLS`, `MM_EMAILSETTINGS_FEEDBACKEMAIL`. Alternatively configure SMTP in System Console → Environment → SMTP. Mattermost only supports SMTP and Railway allows outbound SMTP only on **Pro**.

## First start and accounts

1. Postgres starts, Mattermost connects, runs its migrations and creates the configuration table (first boot ≈ 1 min).
2. Open the public domain and create the first account: the **first user becomes System Admin**. Do this right after deploy. Then create a team.
3. Open sign-up is off (`TeamSettings.EnableOpenServer=false` upstream default): invite people with the team invite link or by email (email needs SMTP).
4. Mobile apps: enter the Railway domain as server URL. Push notifications go through Mattermost's free test push proxy (`push-test.mattermost.com`, no SLA, upstream default for Team Edition); message text is not included (`generic`).

## Platform limits (documented in README)

- **Calls**: the prepackaged Calls plugin needs UDP (default 8443); Railway has no UDP, so calls/screen share cannot connect. Disable it in System Console → Plugins → Calls, or use the Zoom / MS Teams Meetings plugins.
- **Team Edition limits (Mattermost policy, `server/channels/app/limits.go`)**: unlicensed servers warn at 200 and stop adding users at 250 active users; Playbooks requires a Professional licence (the prepackaged plugin refuses to start, visible as an error in the logs). The Enterprise image (`mattermost/mattermost-enterprise-edition:11.11.1`) can be swapped in by changing the image if you buy a licence.
- **Email**: SMTP only, Railway Pro plan.
- **Scaling**: Team Edition cannot cluster; scale vertically. Keep `Mattermost` at 1 replica.

## Composer steps (Railway dashboard)

1. Add `Postgres` from `_railway-base/postgres.json`; add a Bucket named `Bucket`.
2. `S3 Gateway`: GitHub repo `baranberkay96/mattermost-railway`, root `/services/s3-gateway`; no domain; restart ALWAYS; variables as above.
3. `Mattermost`: Docker image `mattermost/mattermost-team-edition:11.11.1`; domain → 8065; healthcheck `/api/v4/system/ping` (600 s); restart ALWAYS; variables as above.

## Improvements over market templates

| Area | Market templates | This template |
|---|---|---|
| Image | `mattermost-team-edition:latest` (all three) | Pinned `11.11.1` (current stable), upgrade by changing the tag |
| File storage | `arWblT`/`mattermost`: none → uploads lost on every redeploy; `mattermost-team-edition`: local volume | Railway Bucket through a private S3 gateway: unlimited, cheap ($0.015/GB), not tied to a volume |
| Configuration | `config.json` inside the container → System Console changes lost on redeploy (all three) | `MM_CONFIG` stores the config in Postgres; infrastructure settings pinned by variables |
| Database link | `arWblT`/`mattermost`: `${{Postgres.DATABASE_URL}}` = public TCP proxy (egress, public exposure) | Private network DSN, public TCP proxy removed, connection pool sized for Railway Postgres |
| Postgres | `postgres-ssl:latest` / `:16` / `:17` | Railway base `postgres-ssl:18` (matches upstream compose) |
| Proxy awareness | none | Trusted proxy headers for real client IPs |
| Healthcheck | `/` (`mattermost-team-edition`) | `/api/v4/system/ping`, 600 s, restart ALWAYS |
| Privacy | push contents `full` | `generic` push contents, file logging off |
| Docs | no mention of Calls/UDP, user cap, SMTP plan | Calls/UDP, 250-user cap, Playbooks licence, SMTP on Pro documented |

## Resource profile and cost (Railway: RAM $10/GB-mo, vCPU $20/mo, volume $0.15/GB-mo, bucket $0.015/GB-mo)

| Service | Idle RAM | Typical RAM | Idle CPU | Typical CPU |
|---|---|---|---|---|
| Mattermost (+ plugin processes: Boards, Calls, AI, integrations) | 0.45 GB | 0.7–1.2 GB | 0.02 | 0.1–0.4 |
| S3 Gateway (rclone) | 0.03 GB | 0.05–0.3 GB (upload buffers) | 0 | 0.01–0.1 |
| Postgres | 0.1 GB | 0.2–0.4 GB | 0.01 | 0.05–0.2 |
| **Total** | **~0.6 GB** | **~1–1.9 GB** | **~0.03 vCPU** | **~0.15–0.7 vCPU** |

Estimated monthly cost: **idle ≈ $7** (0.6 GB × $10 + 0.03 vCPU × $20 + ~1 GB Postgres volume); **typical team (20–150 users) ≈ $15–35**; files cost $0.015/GB in the Bucket. Minimum plan: **Hobby** (Trial's 1 GB per service is too tight once plugins load). Pro only if you need outbound SMTP.

## Pinning and upgrades

Pinned 2026-10-11: `mattermost/mattermost-team-edition:11.11.1` (service image), `rclone/rclone:1.75.2` (`services/s3-gateway/Dockerfile`), Postgres `postgres-ssl:18`. Upgrade Mattermost by changing the image tag after reading the release notes (`12.0` is in release candidates as of this date; the listing name's `v11` must change with a major upgrade). Mattermost migrates the schema on start; take a Postgres backup first.

## Verification checklist

- [ ] `S3 Gateway` logs: `logical bucket 'mattermost' ready`, then `Starting s3 server on [http://[::]:9000/]`. The Bucket's file browser shows a `mattermost/` folder.
- [ ] `Mattermost` becomes healthy; logs show `Loaded config ... source="postgres://****"` and `No plugins to sync from the file store` (no S3 error).
- [ ] Create the first user (System Admin) and a team; System Console → Environment → File Storage → **Test Connection** succeeds.
- [ ] Upload an image and a >10 MB file in a channel → thumbnails render, downloads match; objects appear under `mattermost/` in the Bucket.
- [ ] Change a System Console setting (e.g. site name), redeploy `Mattermost` → setting and files persist.
- [ ] Install a plugin from the Marketplace, redeploy → plugin is still installed (re-synced from the Bucket).
- [ ] Mobile app connects to the Railway domain and receives a push notification.

## Local test (2026-10-11)

Ran `mattermost-team-edition:11.11.1` (amd64) + Postgres 18 + this gateway (built from `services/s3-gateway`) against a local SeaweedFS S3 standing in for the Bucket: DB-backed config created, user/team created, 2 KB file, 12 MB file (multipart), PNG with thumbnail and preview all uploaded and downloaded byte-identical; Mattermost restart and gateway restart kept files available and uploads working.

## Open questions

- Not deployed on Railway. The gateway's Bucket side (virtual-hosted, region `auto`) uses the same rclone S3 settings as the round-1 Minecraft backup service; confirm a first upload lands in the Bucket.
- Empty (0-byte) attachments fail through the gateway (`MissingContentLength`: minio-go streams unknown-length uploads and `rclone serve s3` rejects an empty unsized part). Every non-empty file worked.
- `rclone serve s3` is labelled experimental by rclone; Mattermost's use (put/get/stat/copy/delete/list, multipart) was tested. Server-side multipart copy (`UploadPartCopy`) is not implemented, so copies of files larger than 5 GiB and upload-session appends (bulk import via `mmctl import upload`) are unsupported.
- If Railway later accepts path-style requests on Buckets, `S3 Gateway` can be removed by pointing `MM_FILESETTINGS_AMAZONS3ENDPOINT` at the Bucket host directly.
- Mattermost trademark guidelines ask for approval to use the mark; the listing is labelled a community template (not affiliated).
- `12.0.0` may be released soon; re-pin and rename to `v12` when it is stable.
