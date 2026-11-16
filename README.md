# Renewal Desk

Renewal Desk is a Rails project for tracking contract notice deadlines and recording renewal decisions. The first milestone provides a runnable Rails and PostgreSQL foundation.

## Quick start

Requires Docker with Compose v2.

```sh
docker compose up --build --wait
```

Open `http://127.0.0.1:3000/up` to check that Rails is running. Compose waits for PostgreSQL and prepares the development database before starting Puma.

Run the same application checks as GitHub Actions.

```sh
docker compose run --rm -T -e CI=true app bin/ci
```

The checks prepare a separate test database, verify Rails autoloading, run the Minitest suite, and run RuboCop. The smoke tests exercise the Rails health route and query PostgreSQL to verify the database name and server version.

```sh
docker compose down
```

The PostgreSQL volume persists when the stack is stopped. After changing application files, repeat the quick-start command to rebuild the image. Set `APP_PORT` before starting Compose to use a different host port.

## Platform

Ruby 3.4.12 · Rails 8.1.4.1 · PostgreSQL 17.12

The development web port binds to loopback. PostgreSQL is available inside the Compose network. The database credentials in `compose.yaml` are for this local stack.

See the [project specification and acceptance criteria](PROJECT_SPEC.md).
