ENV["RAILS_ENV"] ||= "test"

require "simplecov"
SimpleCov.start "rails" do
  enable_coverage :branch
  track_files "{app,packages}/**/*.rb"
end

require_relative "../config/environment"
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
