# Renewal Desk

Renewal Desk tracks contract notice deadlines and renewal decisions. The domain rules and PostgreSQL write operations are available through the Rails console.

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

The checks run the domain suite with line and branch coverage, prepare a separate PostgreSQL test database, verify Rails autoloading, run the Rails suite, and run RuboCop.

```sh
docker compose down
```

The PostgreSQL volume persists when the stack is stopped. After changing application files, repeat the quick-start command to rebuild the image. Set `APP_PORT` before starting Compose to use a different host port.

## Try a contract in the console

Run `docker compose exec app bin/rails console` while the stack is running.

```ruby
owner = User.find_or_create_by!(email_address: "owner@example.test") do |user|
  user.password = SecureRandom.hex(16)
end
record = Renewals::ContractWriter.create(
  owner: owner, title: "Office Internet", counterparty: "Example Telecom",
  ends_on: Date.new(2026, 12, 31), notice_days: 30
)
record.notice_due_on.iso8601 # => "2026-12-01"

record = Renewals::ContractWriter.record_decision(
  owner: owner, id: record.id, lock_version: record.lock_version, decision: "renew"
)
record.events.pluck(:event_type) # => ["contract_created", "decision_recorded"]
```

`Renewals::Contract` owns the transition rules. `Renewals::NoticeSchedule` calculates dates in the Gregorian calendar. `Renewals::ContractWriter` locks the contract row before comparing the submitted version and writes each change and its history event in one transaction.

To run only the domain suite without Rails or PostgreSQL:

```sh
docker compose run --build --rm --no-deps -T app bin/test-domain
```

## Platform

Ruby 3.4.12 · Rails 8.1.4.1 · PostgreSQL 17.12

The development web port binds to loopback. PostgreSQL is available inside the Compose network. The database credentials in `compose.yaml` are for this local stack.

See the [project specification and acceptance criteria](PROJECT_SPEC.md).
