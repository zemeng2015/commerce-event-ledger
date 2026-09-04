require "test_helper"

class HealthCheckTest < ActionDispatch::IntegrationTest
  test "the Rails health endpoint is reachable" do
    get "/up"

    assert_response :success
  end
end
