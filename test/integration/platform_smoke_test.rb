require "test_helper"

class PlatformSmokeTest < ActionDispatch::IntegrationTest
  test "Rails health endpoint responds" do
    get rails_health_check_path

    assert_response :ok
  end

  test "the test suite connects to the PostgreSQL test database" do
    ActiveRecord::Base.with_connection do |connection|
      assert_equal "PostgreSQL", connection.adapter_name
      assert_match(/\Arenewal_desk_test(?:-\d+)?\z/, connection.select_value("SELECT current_database()"))
      assert_equal 17, connection.select_value("SHOW server_version_num").to_i / 10_000
    end
  end
end
