require "test_helper"

class DatabaseSmokeTest < ActiveSupport::TestCase
  test "the application uses its isolated MySQL test database" do
    connection = ActiveRecord::Base.connection

    assert_equal "Mysql2", connection.adapter_name
    assert_equal "commerce_event_ledger_test", connection.select_value("SELECT DATABASE()")
    assert_equal 1, connection.select_value("SELECT 1")
    assert_match(/\A8\.4\./, connection.select_value("SELECT VERSION()"))
  end
end
