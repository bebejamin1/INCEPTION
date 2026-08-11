# Developer Documentation

This document explains how to set up, build, and work on the Inception
project as a developer: environment setup, build/launch commands, container
and volume management, and where project data lives.

## 1. Setting up the environment from scratch

### Prerequisites

- A Linux virtual machine.
- Docker Engine and Docker Compose v2 (the `docker compose` subcommand).
- `openssl` available on the host (used by the `Makefile` to generate
  secrets).
- `make`.

### Repository layout

```
.
├── Makefile
├── README.md / USER_DOC.md / DEV_DOC.md
├── secrets/                     # generated locally, git-ignored
│   ├── credentials.txt
│   ├── db_password.txt
│   └── db_root_password.txt
└── srcs/
    ├── .env                     # non-sensitive configuration, git-ignored
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   ├── conf/50-server.cnf
        │   └── tools/setup.sh
        ├── nginx/
        │   ├── Dockerfile
        │   ├── conf/nginx.conf
        │   └── tools/setup.sh
        └── wordpress/
            ├── Dockerfile
            ├── conf/www.conf
            └── tools/setup.sh
```

### Configuration files

- `srcs/.env` — non-sensitive settings consumed by `docker-compose.yml`:
  `LOGIN`, `DOMAIN_NAME`, `MYSQL_DATABASE`, `MYSQL_USER`, `WP_TITLE`,
  `WP_ADMIN_USER`, `WP_ADMIN_EMAIL`, `WP_USER`, `WP_USER_EMAIL`. Not
  committed to Git; recreate it locally if missing (see the example values
  currently checked out on this machine).
- `secrets/db_password.txt`, `secrets/db_root_password.txt`,
  `secrets/credentials.txt` — generated automatically by `make` (target
  `secrets` in the `Makefile`) via `openssl rand -base64 …` if they don't
  already exist. Delete a file and re-run `make` to rotate that secret.

## 2. Building and launching with the Makefile / Docker Compose

The `Makefile` at the repository root wraps `docker compose -f
srcs/docker-compose.yml` and adds a couple of convenience targets:

| Target         | Effect |
|----------------|--------|
| `make` / `make all` | Alias for `make up`. |
| `make up`      | Creates host data directories, generates secrets if missing, then `docker compose up -d --build`. |
| `make build`   | Generates secrets if missing, then `docker compose build` (build only, no start). |
| `make down`    | `docker compose down` — stops and removes containers (volumes/data untouched). |
| `make stop` / `make start` | `docker compose stop` / `start` — stop/start existing containers without removing them. |
| `make restart` | `docker compose restart`. |
| `make logs`    | `docker compose logs -f`. |
| `make ps`      | `docker compose ps`. |
| `make clean`   | `make down` + `docker system prune -f`. |
| `make fclean`  | `down`, prunes all Docker resources including volumes, and removes `/home/<LOGIN>/data` on the host. |
| `make re`      | `fclean` then `all` — full rebuild from scratch. |

You normally only need:

```
make          # build + start
make logs     # watch it come up
make down     # stop and remove containers when done
```

Each Dockerfile is built from `debian:bookworm-slim` and only installs the
packages required for its role (no ready-made service images are pulled).
Each `tools/setup.sh` entrypoint script does idempotent first-run setup and
then execs the real service as PID 1 (`mysqld`, `nginx -g "daemon off;"`,
`php-fpm8.2 -F`) — no wrapper loops, no backgrounding.

## 3. Managing containers and volumes

Useful raw Docker Compose / Docker commands beyond the Makefile shortcuts
(run from the repo root, or add `-f srcs/docker-compose.yml`):

```
docker compose -f srcs/docker-compose.yml ps                 # container status
docker compose -f srcs/docker-compose.yml logs -f <service>  # logs for one service
docker compose -f srcs/docker-compose.yml exec wordpress bash
docker compose -f srcs/docker-compose.yml exec mariadb bash

docker volume ls                                              # list volumes
docker volume inspect mariadb_data wordpress_data             # inspect mount points
docker network inspect inception                              # inspect the shared network
```

To rebuild a single service after editing its Dockerfile or scripts:

```
docker compose -f srcs/docker-compose.yml up -d --build wordpress
```

## 4. Where data is stored and how it persists

Two Docker **named volumes** are declared in `srcs/docker-compose.yml`:

- `mariadb_data` → mounted at `/var/lib/mysql` inside the `mariadb`
  container.
- `wordpress_data` → mounted at `/var/www/html` inside both the
  `wordpress` and `nginx` containers (so NGINX can serve WordPress's static
  files directly while PHP execution is proxied to `wordpress:9000`).

Both volumes use the `local` driver with bind-mount `driver_opts`, so their
data is physically stored on the host at:

```
/home/bbeaurai/data/mariadb
/home/bbeaurai/data/wordpress
```

These host directories are created by `make` (target `data-dirs`) before the
stack starts. Because they're named volumes (not bind mounts declared
directly in the `volumes:` service section), data survives `docker compose
down` and container recreation; it is only deleted by `make fclean`, which
explicitly prunes volumes and removes `/home/bbeaurai/data`.

First-run initialization (creating the MariaDB database/users, downloading
and installing WordPress) is guarded in each `tools/setup.sh` by checking
whether the relevant data directory is already populated, so restarting the
containers does not repeat installation or wipe existing data.
