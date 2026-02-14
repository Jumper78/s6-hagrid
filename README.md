[![Docker Pulls](https://img.shields.io/docker/pulls/jumper78/hagrid-openpgp)](https://hub.docker.com/r/jumper78/hagrid-openpgp)

## About

[Hagrid](https://gitlab.com/hagrid-keyserver/hagrid) ("keeper of keys") is a verifying OpenPGP keyserver written in Rust. This image packages Hagrid with [s6-overlay](https://github.com/just-containers/s6-overlay) for process supervision and ships msmtp as a lightweight sendmail replacement.

Multi-arch image available for **amd64** and **arm64**.

## Quick start

```yaml
services:
  hagrid:
    image: jumper78/hagrid-openpgp
    environment:
      HOST: 'pgp.example.com'
      BASE_URI: 'https://pgp.example.com'
      TOKEN_SECRET: 'change-me'
      FROM_EMAIL: 'pgp@example.com'
      MAILHUB: 'mail.example.com'
      MAILDOMAIN: 'example.com'
      MAILUSER: 'pgp@example.com'
      MAILPASS: 'secret'
    volumes:
      - ./data:/data
    ports:
      - "8080:8080"
      - "11371:8080"
```

See the [docker-compose examples](./docker-compose-examples/) for more (including Traefik reverse proxy).

## Environment variables

### Required

| Variable | Description | Example |
|---|---|---|
| `HOST` | Public hostname, used for branding (replaces `keys.openpgp.org` in the UI) | `pgp.example.com` |
| `BASE_URI` | Full public URL of the service (used in confirmation emails) | `https://pgp.example.com` |
| `TOKEN_SECRET` | Secret for signing verification tokens | `some-random-string` |
| `FROM_EMAIL` | Sender address for verification emails | `pgp@example.com` |
| `MAILHUB` | SMTP server hostname | `mail.example.com` |
| `MAILDOMAIN` | Domain used in SMTP HELO/EHLO | `example.com` |
| `MAILUSER` | SMTP login username | `pgp@example.com` |
| `MAILPASS` | SMTP login password | `secret` |

### Optional

| Variable | Default | Description |
|---|---|---|
| `BIND` | `0.0.0.0` | Address the server listens on |
| `PORT` | `8080` | Port the server listens on |
| `MAILPORT` | `465` | SMTP port (`465` = implicit TLS, `587` = STARTTLS) |
| `MAIL_STARTTLS` | auto | Override TLS mode (`on` or `off`). Auto-detected from `MAILPORT` if not set: port 465 = `off` (implicit TLS), port 587 = `on` (STARTTLS). |

## Volumes

| Path | Description |
|---|---|
| `/data` | Persistent data: keys, tokens, and `Rocket.toml` config |

The configuration file `/data/Rocket.toml` is regenerated from the template on every container start, so changes to environment variables take effect immediately after a restart.

## Ports

| Port | Protocol | Description |
|---|---|---|
| `8080` | HTTP | Hagrid web interface and HKP API |

The standard HKP port is `11371`. Map it to the container port with `-p 11371:8080`.

## Building from source

```bash
docker build -t hagrid-openpgp .
```

For cross-compilation (e.g. arm64 on amd64):

```bash
docker buildx build --platform linux/arm64 -t hagrid-openpgp .
```
