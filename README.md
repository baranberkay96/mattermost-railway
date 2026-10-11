# Deploy and Host Mattermost with Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/mattermost-v11-team-chat?referralCode=20H68q)

Mattermost is an open-source team messaging platform with channels, threads, direct messages, file sharing and integrations. This community template runs Mattermost Team Edition v11 on Railway with PostgreSQL, keeps its configuration in the database and stores every upload in a Railway Bucket, so nothing is lost on redeploy.

## About Hosting Mattermost

Mattermost is a single Go server that serves the web app, the REST API and real-time websockets, backed by PostgreSQL. Files (attachments, avatars, custom emoji, plugins) go to a file store. Railway Buckets only accept virtual-hosted S3 requests, while Mattermost's S3 client sends path-style requests, so this template adds a small S3 gateway (rclone) on the private network that writes into your Bucket. Mattermost itself runs from the official image with no volume: configuration lives in PostgreSQL, so System Console changes and installed plugins survive redeploys. The first person to sign up becomes System Admin.

## Common Use Cases

- Internal team chat for engineering, operations and support teams that want to own their data.
- Self-hosted Slack alternative for companies with data residency or compliance requirements.
- ChatOps hub with GitHub, GitLab, Jira and incoming/outgoing webhooks.
- Private community or project space for agencies, schools and clubs (up to 250 active users on Team Edition).

## Dependencies for Mattermost Hosting

- Mattermost Team Edition server (`mattermost/mattermost-team-edition`)
- PostgreSQL 18
- S3-compatible object storage (Railway Bucket, reached through an rclone S3 gateway)
- Optional: SMTP server for email notifications and invitations (Railway Pro plan)

### Deployment Dependencies

- Mattermost documentation: https://docs.mattermost.com
- Docker deployment guide and compose files: https://github.com/mattermost/docker
- Configuration settings and environment variables: https://docs.mattermost.com/configure/configuration-settings.html
- Mattermost releases: https://github.com/mattermost/mattermost/releases
- rclone serve s3: https://rclone.org/commands/rclone_serve_s3/
- Railway Buckets: https://docs.railway.com/storage-buckets

### Implementation Details

| Service | Image | Role | Public |
|---|---|---|---|
| `Mattermost` | `mattermost/mattermost-team-edition:11.11.1` | Web app, API, websockets; config stored in Postgres | HTTPS domain |
| `S3 Gateway` | `rclone/rclone:1.75.2` + start script | Private S3 endpoint that stores files in the Bucket | — |
| `Postgres` | `ghcr.io/railwayapp-templates/postgres-ssl:18` | Database and configuration | — |
| `Bucket` | Railway Bucket | Attachments, avatars, emoji, plugins | — |

**First login.** When `Mattermost` is healthy, open its domain and create an account; the first account becomes System Admin. Create a team and share its invite link. Open sign-up is off by default.

**Settings.** Most settings are changed in System Console and stored in Postgres. Settings defined as Railway variables (site URL, database, file storage, logging) are greyed out there; change them in Railway instead. When you add a custom domain, update `MM_SERVICESETTINGS_SITEURL`.

**Mobile push.** The mobile apps work with the Railway domain. Push notifications go through Mattermost's free test push service; the template sends only sender and channel name, not message text.

**Known platform limits.** Railway has no UDP, so the bundled Calls plugin (voice, video, screen share) cannot connect; disable it in System Console → Plugins or use the Zoom or Microsoft Teams Meetings plugins. Email needs SMTP, which Railway allows on the Pro plan; set it in System Console → Environment → SMTP. Mattermost Team Edition is limited by Mattermost to 250 active users per server, and Playbooks requires a paid Mattermost licence.

**Scaling.** Team Edition runs as a single server; give the `Mattermost` service more CPU and memory as your team grows. Files scale with the Bucket.

**Pinning and upgrades.** Change the `Mattermost` image tag (for example `11.11.1` to a newer `11.x`) after reading the release notes; Mattermost migrates the database on start. The gateway's rclone version is the `FROM` line in `services/s3-gateway/Dockerfile`.

### Why Deploy Mattermost on Railway?

Railway runs Mattermost, PostgreSQL, the S3 gateway and a Bucket together on a private network with automatic HTTPS, so you get a self-hosted team chat without managing servers, certificates or disks. Files are stored in a Bucket priced per gigabyte, and you pay for the compute your team actually uses.
