# Local development

The initial development environment supports Rails API boot and MySQL smoke tests. Webhook ingestion, processing workers, business models, and the signed-event demo are later S1 work; starting this stack does not demonstrate the ledger's reliability guarantees.

The application uses Ruby 4.0.6, Rails 8.1.3.1, and MySQL 8.4.11 from the 8.4 LTS series. Ruby and Rails dependencies are resolved in the committed lockfile. The development image installs that locked resolution with Bundler frozen mode. The database image is pinned to `mysql:8.4.11`; record its actual digest when retaining experiment results.

## Docker-only setup

Install Docker with a running Linux-container engine and Docker Compose v2 supporting `up --wait`. Git and Docker are the only host prerequisites; no host Ruby, Bundler, MySQL, Node.js, or JavaScript package manager is needed.

From a clean repository checkout, run:

```sh
docker compose up --build --wait
```

This single command builds the Ruby image from the lockfile, initializes the dedicated local MySQL volume, waits for its test-database grant, runs `bin/setup` to prepare development and test databases, and starts Rails. The app is published only at `http://127.0.0.1:3000`; its `/up` endpoint supplies the container health check. The database has no published host port.

The first run downloads images and gems, so its duration depends on network and hardware. Subsequent setup runs preserve existing database contents; `bin/setup` never calls `db:reset` or `db:drop`. A ten-minute clone-to-demo target belongs to the later full fixture demo and has not been established by this scaffold alone.

Run the MySQL-backed tests in the app image:

```sh
docker compose run --rm app ruby bin/test
```

`bin/test` sets `RAILS_ENV=test`, checks locked dependencies, prepares the test database, and invokes Rails/Minitest. Normal test-file, `--name`, and `--seed` arguments can follow the command. Environment overrides are rejected before dependency checks or database preparation: this includes `-e`, attached short values, `--environment`, long abbreviations such as `--env`, and `=value` forms. The smoke suite uses a single process and the fixed test database. Later concurrency tests need an explicit connection strategy rather than implicit creation of databases outside the user's grants.

To rerun setup without rebuilding or starting another web server:

```sh
docker compose run --rm app ruby bin/setup
```

To inspect startup output or stop the stack while retaining local database contents:

```sh
docker compose logs app db
docker compose down
```

The repository is bind-mounted only into `/rails` for development edits. Installed gems live in the built image, so rebuild with the setup command after changing `Gemfile` or `Gemfile.lock`. Frozen mode intentionally rejects a mismatched manifest/lockfile. No unrelated host directory is mounted.

An optional untracked `.env` can set `APP_PORT` and `RAILS_MAX_THREADS`; `.env.example` documents these fields. Copying the example is unnecessary for the default setup. Container database settings are deliberately fixed to the disposable fixture user and do not inherit the host's `DB_*` values.

## Native Ruby setup

This alternative requires Ruby 4.0.6, Bundler matching the lockfile, MySQL client development headers, and a separately provisioned local MySQL 8.4.11 instance. The Compose database is isolated from host Ruby because its port is not published.

Provision two local databases, `commerce_event_ledger_development` and `commerce_event_ledger_test`, and a dedicated `commerce_event_ledger` user permitted to migrate and query only those databases. Use the synthetic password `ledger-local-only` if following the defaults. Do not use the database administrator account as the application user. The Compose image performs the equivalent grants automatically on its first initialization.

Export these settings in the native process environment:

| Variable | Native value | Container value |
| --- | --- | --- |
| `DB_HOST` | `127.0.0.1` | `db` |
| `DB_PORT` | `3306` | `3306` |
| `DB_USERNAME` | `commerce_event_ledger` | `commerce_event_ledger` |
| `DB_PASSWORD` | `ledger-local-only` | `ledger-local-only` |
| `RAILS_MAX_THREADS` | `5` | `5` by default |

`.env.example` is a reference file; Rails does not automatically load it in native mode. Once the local databases and shell variables are ready:

```sh
ruby bin/setup
ruby bin/test
ruby bin/rails server --binding 127.0.0.1
```

Setup checks or installs the locked bundle and uses Rails `db:prepare` for development and test. Both scripts refuse other Rails environments and reject an inherited `DATABASE_URL` or `PRIMARY_DATABASE_URL` before dependency checks or database commands: either URL can override the database name even under the test environment. Unset both keys and use the `DB_*` settings above for these fixed local databases. Guard diagnostics name the keys without printing their values. Tests then force the test environment. Neither command installs frontend tooling, starts a worker, clears project folders, or resets databases.

## Fixture database boundaries and troubleshooting

All passwords committed in the Compose configuration are public disposable fixture values. The MySQL root credential stays inside the database service; Rails uses the dedicated user. Underscores in database-specific grants are escaped so they cannot act as wildcards for unrelated database names. The development stack is for synthetic local data and does not configure production access.

The official MySQL image processes `docker/mysql/init.sql` only when its named data volume is initialized for the first time. Editing credentials or grants later does not rewrite an existing volume. Preserve useful fixture data and inspect the database logs/grants before making a deliberate local database change; restarting setup is not a reset mechanism.

If the app exits before becoming healthy, inspect `docker compose logs app db`. A failed locked bundle requires a consistent reviewed lockfile; a MySQL authentication failure requires checking the fixed fixture credentials and grants. An occupied app port can be changed with `APP_PORT` in `.env`. Containers call the database service `db`; native Ruby uses its separately provisioned `127.0.0.1` instance.

Runtime CI must validate image construction, healthy app/database startup, repeated setup, and the actual MySQL-backed test suite. A static configuration review alone is not evidence that these checks pass. See the [roadmap](roadmap.md) for the remaining signed-event vertical slice and [charter](project-charter.md) for the complete project gates.
