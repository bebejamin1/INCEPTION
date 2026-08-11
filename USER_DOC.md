# User Documentation

This document explains, from an end-user/administrator point of view, how to
use the Inception stack: what it provides, how to start and stop it, how to
reach the site and its admin panel, where credentials live, and how to check
that everything is healthy.

## 1. What services are provided

The stack is a self-hosted WordPress site, split into three containers:

| Service    | Role                                                          |
|------------|----------------------------------------------------------------|
| `nginx`    | Public entry point. Serves the site over HTTPS on port 443.   |
| `wordpress`| Runs the WordPress application via PHP-FPM (not reachable directly from outside). |
| `mariadb`  | Stores the WordPress database (not reachable directly from outside). |

Only `nginx` is reachable from outside the virtual machine (port 443,
HTTPS/TLS only). WordPress and MariaDB are only reachable from other
containers on the internal `inception` Docker network.

## 2. Starting and stopping the project

All commands below are run from the root of the repository, on the virtual
machine hosting the project.

- **Start everything** (build images if needed, create data directories and
  secrets, start containers in the background):
  ```
  make
  ```
- **Stop the containers** (keeps them, data and images, just stops the
  processes):
  ```
  make stop
  ```
- **Start them again** after `make stop`:
  ```
  make start
  ```
- **Restart** all containers:
  ```
  make restart
  ```
- **Tear down** the containers (removes containers, keeps volumes/data and
  images):
  ```
  make down
  ```
- **Full reset**, including deleting all persisted website/database data on
  the host (`/home/bbeaurai/data`) and images — use with care:
  ```
  make fclean
  ```
- **Rebuild everything from a clean state**:
  ```
  make re
  ```

## 3. Accessing the website and the administration panel

1. Make sure `bbeaurai.42.fr` resolves to the virtual machine's IP address
   (add it to `/etc/hosts` on the machine you browse from if it's not
   handled by DNS).
2. Open `https://bbeaurai.42.fr` in a browser to view the WordPress site.
   The certificate is self-signed, so the browser will show a security
   warning the first time — this is expected for this project.
3. Open `https://bbeaurai.42.fr/wp-admin` to reach the WordPress
   administration panel, and log in with the administrator account (see
   below for where to find its credentials).

## 4. Locating and managing credentials

Nothing sensitive is stored in the Git repository or in the `.env` file.
Every password lives in a local, git-ignored file:

| File                             | Content                                          |
|-----------------------------------|---------------------------------------------------|
| `secrets/db_password.txt`         | Password of the MariaDB application user (`MYSQL_USER`, set in `srcs/.env`). |
| `secrets/db_root_password.txt`    | MariaDB root password.                            |
| `secrets/credentials.txt`         | `WP_ADMIN_PASSWORD` and `WP_USER_PASSWORD` for the two WordPress accounts. |

Non-sensitive settings (domain name, database name, usernames, WordPress
site title) are in `srcs/.env`.

The WordPress database has two users, configured from `srcs/.env` /
`secrets/credentials.txt`:

- **Administrator** — username `WP_ADMIN_USER` (see `srcs/.env`), password in
  `secrets/credentials.txt` under `WP_ADMIN_PASSWORD`. Note the username does
  **not** contain "admin" or "administrator", per project requirements.
- **Regular author** — username `WP_USER` (see `srcs/.env`), password in
  `secrets/credentials.txt` under `WP_USER_PASSWORD`.

These files are generated automatically by `make` the first time it runs (see
the `secrets` target in the `Makefile`) and are never committed to Git
(`secrets/*.txt` is listed in `.gitignore`).

## 5. Checking that the services are running correctly

- List the status of all containers:
  ```
  make ps
  ```
  All three services (`nginx`, `wordpress`, `mariadb`) should show as
  `running`/`healthy`. Every container is configured with
  `restart: unless-stopped`, so a crashed container should come back up on
  its own — if one stays down, check its logs.
- Follow the logs of all services live:
  ```
  make logs
  ```
- Confirm the site itself is reachable:
  ```
  curl -vk https://bbeaurai.42.fr
  ```
  A successful TLS handshake and an HTML response indicate NGINX, PHP-FPM,
  and the database are all working together correctly.
