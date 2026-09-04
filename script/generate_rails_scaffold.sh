#!/usr/bin/env bash
set -euo pipefail

# Generate in a fresh runner directory, never over the project checkout.
scaffold_dir="${RUNNER_TEMP:?RUNNER_TEMP must be set}/commerce_event_ledger"
if [[ -e "$scaffold_dir" ]]; then
  echo "Scaffold destination already exists; refusing to overwrite it." >&2
  exit 1
fi

gem install rails --version 8.1.3.1 --no-document
rails _8.1.3.1_ new "$scaffold_dir" --api --database=mysql --skip-bundle \
  --skip-git --skip-docker --skip-kamal --skip-ci --skip-solid \
  --skip-active-storage --skip-action-text --skip-action-mailbox \
  --skip-action-mailer --skip-action-cable

cd "$scaffold_dir"
cat >> Gemfile <<'RUBY'

# Declared project dependencies; the lockfile is resolved by Bundler.
gem "solid_queue", "~> 1.7"
gem "graphql", "~> 2.6"
gem "packwerk", "~> 3.3", group: :development
gem "simplecov", "~> 0.22", group: :test, require: false
RUBY

bundle install
bundle lock --add-platform x86_64-linux aarch64-linux x64-mingw-ucrt
bundle exec rails solid_queue:install
bundle exec rails db:prepare
bundle exec rails runner '
  raise "Expected MySQL" unless ActiveRecord::Base.connection.adapter_name == "Mysql2"
  raise "Database unavailable" unless ActiveRecord::Base.connection.select_value("SELECT 1") == 1
  puts "MySQL boot verified: #{ActiveRecord::Base.connection.select_value("SELECT VERSION()") }"
'
bundle exec rails test

{
  ruby --version
  bundle --version
  bundle exec rails --version
  bundle exec rails runner 'puts "MySQL #{ActiveRecord::Base.connection.select_value("SELECT VERSION()")}"'
} > GENERATION_VERSIONS.txt

# Never export the generated encryption key, encrypted credentials or local state.
tar --exclude='./config/master.key' --exclude='./config/credentials.yml.enc' \
  --exclude='./log' --exclude='./tmp' --exclude='./storage' --exclude='./.bundle' \
  --exclude='./vendor' --exclude='./.git' \
  -czf "$RUNNER_TEMP/ledger-scaffold-source.tar.gz" .
