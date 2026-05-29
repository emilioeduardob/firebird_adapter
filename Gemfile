source 'https://rubygems.org'

gemspec

# The specs boot a minimal Rails stack (`require 'rails'`), so railties needs to
# be available alongside the activerecord runtime dependency from the gemspec.
#
# CI pins a specific Rails line through the RAILS_VERSION env var (e.g. "8.0" or
# "8.1") so the same suite can be exercised against every supported release.
rails_version = ENV['RAILS_VERSION']

if rails_version && !rails_version.empty?
  gem 'rails', "~> #{rails_version}.0"
else
  gem 'rails', '>= 8.0', '< 8.2'
end
