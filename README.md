# Renewal Desk

Renewal Desk tracks contract notice deadlines and records renewal decisions. It keeps a history of who changed a contract and when.

## Quick start

Requires Docker with Compose v2.

```sh
docker compose up --build --wait
docker compose exec -e SEED_DEMO=1 app bin/rails db:seed
```

Open [Renewal Desk](http://127.0.0.1:3000). Sign in as `alex@example.test` or `jamie@example.test` with the local demo password `renewal-demo`. Each account has its own contracts. Sessions last 24 hours, and signing out revokes the current session.

Add a contract ending on `2026-12-31` with a 30-day notice period. The contract page shows a notice deadline of `2026-12-01`. Edit the notice period and record a renewal decision to see both changes in History. The Decided filter shows contracts with a recorded decision.

## API

The API lives under `/api/v1`. It uses the same session as the web interface. Contract reads support `?view=open`, `?view=decided`, and `?view=all`. Mutations require a CSRF token from the signed-in page. Updates and decisions also require the current `lock_version` from the contract response.

For example, run this in the browser console on a signed-in page:

```javascript
const response = await fetch("/api/v1/contracts", {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
  },
  body: JSON.stringify({
    title: "Office Internet",
    counterparty: "Example Telecom",
    ends_on: "2026-12-31",
    notice_days: 30
  })
});
console.log(response.status, response.headers.get("Location"), await response.json());
```

A successful POST returns HTTP 201 with the contract resource and its `Location`. The full endpoint and error contracts are in the [project specification](PROJECT_SPEC.md#4-контракты-http).

## Checks

```sh
docker compose run --rm -T -e CI=true app bin/ci
docker compose run --build --rm --no-deps -T app bin/test-domain
```

The first command mirrors the application checks in GitHub Actions. It runs the domain suite, prepares a separate PostgreSQL test database, checks Rails autoloading, runs integration tests, and runs RuboCop. The second command runs only the domain suite with line and branch coverage.

`Renewals::Contract` owns the transition rules. `Renewals::NoticeSchedule` calculates dates in the Gregorian calendar. `Renewals::ContractWriter` locks the contract row before comparing the submitted version and saves the change and its history event in one transaction.

## Local environment

Ruby 3.4.12 · Rails 8.1.4.1 · PostgreSQL 17.12

The web port binds to loopback. PostgreSQL is available within the Compose network. Set `APP_PORT` to change the host port. Use `docker compose down` to stop the stack and keep the database volume.
