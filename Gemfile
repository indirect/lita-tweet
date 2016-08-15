source "https://rubygems.org"

gemspec

group :development do
  gem "coveralls", require: false
  gem "guard-rspec"
  gem "pry-byebug"
  gem "rack-test"
  gem "rake"
  gem "rspec", "~> 3.4"
  gem "simplecov"
  gem "webmock"
end

# This fixes `already initialized constant` warnings while running commands
begin; require "rb-readline"; rescue LoadError; end
