# frozen_string_literal: true

require "test_helper"
require "open3"
require "rbconfig"

class EnvironmentGuardsTest < ActiveSupport::TestCase
  SENTINEL_URL = "mysql2://fixture:fixture@127.0.0.1:1/guard_must_not_connect"

  URL_GUARDS = {
    "bin/setup" => "Unset DATABASE_URL and PRIMARY_DATABASE_URL before setup;",
    "bin/test" => "Unset DATABASE_URL and PRIMARY_DATABASE_URL before tests;"
  }.freeze

  ARGUMENT_GUARD = "bin/test does not accept environment options; it always uses the test database."

  URL_GUARDS.each do |script, diagnostic|
    %w[DATABASE_URL PRIMARY_DATABASE_URL].each do |key|
      test "#{script} rejects #{key} before dependency or database commands" do
        output, status = run_script(script, key => SENTINEL_URL)

        refute status.success?, "#{script} unexpectedly accepted #{key}"
        assert_includes output, diagnostic
        refute_includes output, SENTINEL_URL
        refute_includes output, "== Checking locked Ruby dependencies =="
      end
    end
  end

  {
    "bin/setup" => "bin/setup only prepares development and test databases.",
    "bin/test" => "bin/test only runs from a development or test environment."
  }.each do |script, diagnostic|
    test "#{script} rejects the production environment" do
      output, status = run_script(script, "RAILS_ENV" => "production")

      refute status.success?, "#{script} unexpectedly accepted production"
      assert_includes output, diagnostic
      refute_includes output, "== Checking locked Ruby dependencies =="
    end
  end

  environment_arguments = [ [ "-e", "development" ], [ "-edevelopment" ] ]
  environment_option = "environment"
  (1..environment_option.length).each do |length|
    option = "--#{environment_option[0, length]}"
    environment_arguments << [ option, "development" ]
    environment_arguments << [ "#{option}=development" ]
  end

  environment_arguments.each do |arguments|
    test "bin/test rejects environment arguments #{arguments.join(" ")}" do
      output, status = run_script("bin/test", {}, arguments)

      refute status.success?, "bin/test unexpectedly accepted an environment override"
      assert_includes output, ARGUMENT_GUARD
      refute_includes output, "Locked dependencies are missing."
    end
  end

  [
    [ "test/models/example_test.rb" ],
    [ "--name", "/health/" ],
    [ "--seed", "1234" ],
    [ "--seed=1234" ]
  ].each do |arguments|
    test "bin/test accepts ordinary test arguments #{arguments.join(" ")}" do
      # A deliberately invalid URL stops the script at the next guard. Seeing
      # that diagnostic proves these arguments passed without touching a DB.
      output, status = run_script("bin/test", { "DATABASE_URL" => SENTINEL_URL }, arguments)

      refute status.success?
      assert_includes output, URL_GUARDS.fetch("bin/test")
      refute_includes output, ARGUMENT_GUARD
      refute_includes output, SENTINEL_URL
    end
  end

  private

  def run_script(script, overrides, arguments = [])
    # Explicitly clear both inherited URL sources for every subprocess so the
    # selected override, rather than the caller's environment, is under test.
    environment = {
      "DATABASE_URL" => nil,
      "PRIMARY_DATABASE_URL" => nil,
      "RAILS_ENV" => "development"
    }.merge(overrides)

    stdout, stderr, status = Open3.capture3(
      environment,
      RbConfig.ruby,
      Rails.root.join(script).to_s,
      *arguments,
      chdir: Rails.root.to_s
    )

    [ stdout + stderr, status ]
  end
end
