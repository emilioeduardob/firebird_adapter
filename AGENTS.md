# Firebird Adapter — Agent Guide

## Project Overview

This is `firebird_adapter`, a Ruby gem that provides an ActiveRecord connection adapter for Firebird databases. It targets **Rails 7.x** (version 7.0.0 of the gem) and is built on top of the low-level `fb` gem.

- **Repository**: https://github.com/FabioMR/firebird_adapter
- **License**: MIT
- **Author**: Fábio Rodrigues

The adapter allows Rails applications to use Firebird (2.5.x and compatible versions) as a backend database via standard ActiveRecord APIs, including migrations, schema statements, querying, and associations.

## Technology Stack

| Layer | Technology |
|-------|------------|
| Language | Ruby |
| Framework | Rails / ActiveRecord 7.x |
| Database | Firebird 2.5.x (tested with 2.5.8 SuperServer) |
| DB Driver | `fb` gem (Firebird Ruby bindings) |
| Testing | RSpec 6.x |
| Test DB cleanup | `database_cleaner` |
| Dependency mgmt | Bundler 2.4.x |
| Containerization | Docker Compose (optional, for local dev/test) |

## Build and Test Commands

### Setup

```bash
bin/setup        # Runs bundle install
bundle install   # Standard Bundler setup
```

### Running Tests

The test suite requires a running Firebird server. The project includes a `docker-compose.yml` that spins up Firebird alongside a Ruby container:

```bash
docker-compose up -d db   # Start Firebird container only
bundle exec rspec         # Run the full test suite
bundle exec rspec spec/queries_spec.rb   # Run a single spec file
```

### Gem Build / Release

```bash
bundle exec rake build    # Build the gem
bundle exec rake release  # Release (via bundler/gem_tasks)
```

## Code Organization

```
lib/
├── firebird_adapter.rb                           # Entry point; registers adapter for Rails >= 7.2
├── active_record/
│   ├── extensions.rb                             # Monkey patches: Calculations#count, bind param ordering
│   ├── internal_metadata_extensions.rb           # Workaround: uses "value_" instead of "value" (reserved word)
│   └── connection_adapters/
│       ├── firebird_adapter.rb                   # Main adapter class (inherits AbstractAdapter)
│       └── firebird/
│           ├── connection.rb                     # Connection factory (firebird_connection config handler)
│           ├── database_limits.rb                # Firebird-specific name/size limits
│           ├── database_statements.rb            # SQL execution, transactions, sequences, inserts
│           ├── schema_statements.rb              # Tables, columns, indexes, foreign keys
│           └── quoting.rb                        # Date and column name quoting rules
└── arel/
    └── visitors/
        └── firebird.rb                           # Arel visitor: FIRST/SKIP pagination, UNION syntax

spec/
├── spec_helper.rb                                # DB connection config and shared SisTest model
├── arel_spec.rb                                # Arel SQL generation tests
├── exception_spec.rb                           # Exception encoding round-trips
├── field_types_spec.rb                         # Data type persistence tests
├── hbtm_spec.rb                                # Has-and-belongs-to-many association tests
├── internal_metadata_spec.rb                   # ar_internal_metadata table creation
├── migration_spec.rb                           # Schema migration tests (all native types + indexes/FKs)
├── populate_spec.rb                            # CRUD tests
└── queries_spec.rb                             # ActiveRecord query interface tests
```

## Key Architecture Details

### Adapter Registration

For Rails >= 7.2, the adapter is registered explicitly via `ActiveRecord::ConnectionAdapters.register`. For earlier Rails 7.x versions it is loaded through the conventional require path.

### Connection Factory (`firebird_connection`)

Located in `lib/active_record/connection_adapters/firebird/connection.rb`, this method:
1. Merges defaults (`downcase_names: true`, `port: 3050`, `encoding: Windows-1252`).
2. Expands relative database paths against `Rails.root` when no host is given.
3. Constructs a host/port path (`host/port:database`) when connecting remotely.
4. Returns a new `FirebirdAdapter` wrapping an `Fb::Database` connection.

### Arel Visitor

Firebird uses `FIRST n SKIP m` instead of `LIMIT` / `OFFSET`. The custom `Arel::Visitors::Firebird` handles this translation. It also introduces `ignore_parentheses` on `SelectManager` to support `UNION` without wrapping the second query in parentheses (which Firebird rejects in some contexts).

### Sequences for Primary Keys

Firebird does not have auto-increment columns; it uses generators/sequences. The adapter:
- Creates a sequence named `{table}_g01` by default when creating a table with an ID.
- Fetches the next value via `SELECT NEXT VALUE FOR seq FROM RDB$DATABASE`.
- `prefetch_primary_key?` returns `true` so ActiveRecord knows to ask the adapter for the next ID before insert.

### Reserved Word Workaround

`VALUE` is a reserved word in Firebird. The adapter patches `ActiveRecord::InternalMetadata` to use a column named `value_` instead of `value` when the adapter is Firebird. This is critical for Rails migrations and the schema cache to function.

### Encoding Handling

- The adapter defaults to `Windows-1252` if no encoding is specified.
- SQL strings sent to Firebird are encoded from UTF-8 into the connection encoding.
- Result strings are transcoded back to UTF-8.
- Exception messages are also re-encoded to UTF-8 before being raised.

### Monkey Patches

The codebase uses direct monkey-patching on ActiveRecord classes (`module_eval`, `class << self`) rather than Rails hooks or concerns. Key patches:
- `ActiveRecord::Calculations#count` — forces `column_name` default to `1`.
- `ActiveRecord::ConnectionAdapters::AbstractAdapter#combine_bind_parameters` — changes bind order to put `limit` before `offset` (legacy Rails < 5.2 only).
- `ActiveRecord::InternalMetadata` — redefines column name and table creation logic.

## Development Conventions

- **Identifiers**: Firebird stores names uppercase by default; the adapter configures `downcase_names: true` so Ruby symbols/strings stay lowercase.
- **Name limits**: Table, column, index, and alias names are limited to **31 characters** (`database_limits.rb`).
- **Boolean storage**: Booleans are stored as `smallint` (`0` = false, `1` = true).
- **Date precision**: Firebird timestamps support up to 4 decimal digits (100 microseconds). The adapter truncates microsecond precision from 6 to 5 digits in `quoted_date`.
- **SQL query length limit**: 32,767 characters.
- **In-clause limit**: 1,499 elements.

## Testing Instructions

### Test Environment

The `spec/spec_helper.rb` establishes a connection to:

```ruby
adapter:  'firebird'
username: 'SYSDBA'
password: 'masterkey'
host:     'db'   # Docker Compose service name
database: '/firebird/data/example.fdb'
encoding: 'UTF-8'
```

The shared model `SisTest` maps to the pre-existing `sis_test` table in `db/example.fdb`.

### Test Isolation

- Specs that mutate data (`field_types_spec.rb`, `populate_spec.rb`, `queries_spec.rb`, `hbtm_spec.rb`) wrap execution in `DatabaseCleaner.cleaning` blocks.
- Migration specs create and drop temporary `records` tables inside `before(:each)` / `after(:each)` hooks with `Migration.verbose = false` to reduce noise.

### Running with Docker Compose

The provided `docker-compose.yml` defines two services:
- `app`: Ruby 2.7.7 development container (volume-mounted project + gem cache)
- `db`: Firebird 2.5.8 SuperServer with `ISC_PASSWORD=masterkey`

Example workflow:

```bash
docker-compose run --rm app bundle exec rspec
```

## Security Considerations

- **Hardcoded credentials**: Test configuration and Docker Compose use the default Firebird `SYSDBA` / `masterkey` credentials. These must never be used in production.
- **SQL injection in schema queries**: Some schema introspection methods (e.g., `primary_keys`, `indexes`, `foreign_keys`) interpolate table names directly into SQL strings using string concatenation. These are internal schema queries and operate on table names already validated by ActiveRecord, but contributors should avoid expanding untrusted input into these queries.
- **Exception messages**: Exception text from the Firebird driver is re-encoded to UTF-8. Be cautious that error messages may contain raw database values; do not expose them to end users without sanitization.

## Deployment / Distribution

This is a standard Ruby gem distributed via RubyGems (or a private gem server). Consumers add it to their `Gemfile`:

```ruby
gem 'firebird_adapter', '7.0'
```

And configure `database.yml`:

```yaml
development:
  adapter: firebird
  host: localhost
  database: db/development.fdb
  username: SYSDBA
  password: masterkey
  encoding: UTF-8
```
