ENV["RAILS_ENV"] ||= "test"

require_relative "coverage_boot"

require_relative "../config/environment"
unless Rails.env.test? && ActiveRecord::Base.connection.select_value("SELECT DATABASE()") == "commerce_event_ledger_test"
  abort "Tests require the isolated commerce_event_ledger_test database"
end
require "rails/test_help"

module ActiveSupport
  class TestCase
    # A fixed test database keeps the disposable Docker account narrowly scoped.
    # Domain concurrency tests will use explicit independent connections.
    parallelize(workers: 1)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
