# FirebirdAdapter

ActiveRecord Firebird Adapter for Rails 8 and Rails 7.

## Version Compatibility

| Rails version | Adapter version | Branch      |
|---------------|-----------------|-------------|
| 8.x           | ~> 8.0          | `release80` |
| 7.x           | ~> 7.0          | `release70` |
| 6.x           | ~> 6.0          | —           |
| 5.x           | ~> 5.0          | —           |

We follow the same branching strategy as [oracle-enhanced](https://github.com/rsim/oracle-enhanced): each major/minor Rails version is supported on a dedicated release branch. Tags are cut from those branches for individual gem releases.

## Installation

Add to your Gemfile:

```ruby
gem 'firebird_adapter', '~> 8.1'
```

For Rails 7:

```ruby
gem 'firebird_adapter', '~> 7.0'
```

Then execute:

    $ bundle install

## Usage

Configure your `database.yml`:

```yaml
development:
  adapter: firebird
  host: localhost
  database: db/development.fdb
  username: SYSDBA
  password: masterkey
  encoding: UTF-8
```

## Development

The project includes a Docker Compose setup with Firebird 2.5.8 and Ruby 3.2:

```bash
docker-compose up -d db
bundle exec rspec
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
