*This project has been created as part of the 42 curriculum by bbeaurai.*

# Inception

## Description

Inception is a system administration project whose goal is to build a small,
production-style web infrastructure entirely with Docker, from scratch, using
hand-written Dockerfiles (no pre-built images from Docker Hub other than the
base OS image).

The stack is orchestrated with Docker Compose and is made up of three
services, each running in its own dedicated container:

- **NGINX** — the single entry point of the infrastructure. Terminates TLS
  (TLSv1.2/TLSv1.3 only) on port 443 and proxies PHP requests to WordPress.
- **WordPress + php-fpm** — the WordPress core and PHP-FPM process that
  renders the site (no web server bundled in this container).
- **MariaDB** — the database backing WordPress.

All three services run on a dedicated bridge network (`inception`) and never
expose ports directly to the host except NGINX on 443. WordPress data
(website files) and database data are stored in Docker named volumes bound to
`/home/bbeaurai/data` on the host. The site is served at `bbeaurai.42.fr`.

## Instructions

### Prerequisites

- A Linux virtual machine with Docker and Docker Compose (v2, `docker compose`) installed.
- `bbeaurai.42.fr` resolving to the VM's local IP address (see `/etc/hosts` on
  the host you're browsing from).

### Setup

1. Add the domain to your hosts file (on the machine you browse from):
   ```
   <VM_IP>  bbeaurai.42.fr
   ```
2. From the repository root, build and start everything:
   ```
   make
   ```
   This creates the host data directories under `/home/bbeaurai/data`,
   generates the secret files under `secrets/`, and builds/starts the stack
   with Docker Compose.
3. Visit `https://bbeaurai.42.fr` in your browser (accept the self-signed
   certificate warning).

See [DEV_DOC.md](DEV_DOC.md) for full developer setup details and
[USER_DOC.md](USER_DOC.md) for day-to-day usage (starting/stopping,
credentials, health checks).

## Project description

### Docker & sources overview

Each service is built from its own Dockerfile under
`srcs/requirements/<service>/`, based on `debian:bookworm-slim`. Nothing is
pulled ready-made from Docker Hub besides that base image:

- `srcs/requirements/nginx/` — installs `nginx` + `openssl`, generates a
  self-signed TLS certificate on first boot, renders the config from a
  template with the domain name, and runs NGINX in the foreground.
- `srcs/requirements/wordpress/` — installs `php-fpm` and required PHP
  extensions plus WP-CLI, downloads and configures WordPress (creating an
  admin user and a second, non-admin user) on first boot, then runs
  `php-fpm` in the foreground.
- `srcs/requirements/mariadb/` — installs `mariadb-server`, initializes the
  data directory and creates the WordPress database/user on first boot, then
  runs `mysqld` in the foreground.

Each container's entrypoint script performs idempotent first-run
initialization (only if the data directory is empty) and then `exec`s the
real service process as PID 1 — no `tail -f`, no `sleep infinity`, no
background daemonizing.

Docker Compose (`srcs/docker-compose.yml`) wires the three services together
on a custom bridge network, mounts the named volumes, injects configuration
via environment variables (`srcs/.env`) and passwords via Docker secrets
(`secrets/*.txt`), and sets `restart: unless-stopped` on every service.

### Virtual Machines vs Docker

A VM virtualizes an entire machine, including its own kernel, which makes it
heavier to boot, larger on disk, and slower to provision, but it gives full
isolation between guest and host. Docker containers instead share the host
kernel and only isolate the process/filesystem/network namespace, which makes
them start in milliseconds and much lighter, at the cost of weaker isolation
than a VM. In this project, Docker is used to isolate each *service*
(NGINX, WordPress, MariaDB) cheaply within a single VM, rather than giving
each service its own full VM.

### Secrets vs Environment Variables

Plain environment variables (as set in `srcs/.env` and passed through
`docker-compose.yml`) are convenient for non-sensitive configuration (domain
name, DB name, usernames) but they end up visible in `docker inspect`, in
the container's process environment, and potentially in logs. Docker
secrets, by contrast, are mounted as files under `/run/secrets/` inside the
container, are not persisted in the image or in `docker inspect` output, and
never need to be baked into a Dockerfile. This project therefore keeps
non-sensitive settings in `.env` and puts every password (`db_password`,
`db_root_password`, WordPress admin/user passwords) in files under
`secrets/`, referenced via `*_FILE` environment variables and Compose's
`secrets:` mechanism.

### Docker Network vs Host Network

With `network: host`, a container shares the host's network namespace
directly: no isolation, no per-container hostname resolution, and a risk of
port collisions. A user-defined Docker bridge network (used here as the
`inception` network) instead gives each container its own network namespace,
built-in DNS resolution by container/service name (e.g. WordPress reaches
the database simply as `mariadb`), and lets us expose only what's needed
(NGINX's port 443) to the host, while `mariadb` and `wordpress` stay
unreachable from outside the Docker network entirely. This is both more
secure and closer to how multi-service deployments are run in production.

### Docker Volumes vs Bind Mounts

A bind mount maps an arbitrary host path directly into the container and is
managed entirely by hand (permissions, path existence, etc. are the user's
responsibility). A named volume is created and managed by the Docker
daemon, has a stable identity independent of any specific host path, and is
the mechanism Docker itself recommends for persistent service data. This
project uses named volumes (`mariadb_data`, `wordpress_data`) for the two
persistent datasets, configured with the `local` driver and bind-mount
`driver_opts` so their actual data still physically lives at
`/home/bbeaurai/data/mariadb` and `/home/bbeaurai/data/wordpress` on the
host, satisfying both the "named volume" requirement and the fixed-location
requirement.

## Resources

- [Docker documentation](https://docs.docker.com/)
- [Docker Compose file reference](https://docs.docker.com/compose/compose-file/)
- [Docker secrets](https://docs.docker.com/engine/swarm/secrets/)
- [WordPress CLI (WP-CLI) handbook](https://developer.wordpress.org/cli/commands/)
- [WordPress + php-fpm manual configuration](https://www.php.net/manual/en/install.fpm.php)
- [MariaDB installation and configuration docs](https://mariadb.com/kb/en/documentation/)
- [NGINX documentation](https://nginx.org/en/docs/)
- [NGINX TLS/SSL configuration guide](https://nginx.org/en/docs/http/configuring_https_servers.html)
- [About PID 1 and container init processes](https://github.com/krallin/tini#why-tini)

### AI usage

An AI assistant (Claude) was used during this project as a support tool, not
as a code generator to copy-paste blindly:

- Drafting and reviewing the structure of the entrypoint shell scripts
  (`tools/setup.sh` in each service), which were then read line by line,
  tested, and adjusted manually.
- Explaining Docker/Compose concepts referenced in the subject (named
  volumes vs bind mounts, Docker secrets, PID 1 / daemon best practices) to
  make sure the implementation choices above could be justified during
  defense.
- Generating and reviewing the project documentation files
  (`README.md`, `USER_DOC.md`, `DEV_DOC.md`) based on the actual contents of
  `srcs/` and the `Makefile`, then checked against the subject's
  requirements.

Every generated snippet was read, tested against the running stack, and
discussed with peers before being kept.
