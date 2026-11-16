require "test_helper"
require_relative "../support/session_requests"

class SessionsTest < ActionDispatch::IntegrationTest
  include SessionRequests

  test "authenticates with normalized email and rotates the CSRF token" do
    get root_path
    assert_redirected_to new_session_path
    follow_redirect!
    before_login = csrf_token

    assert_difference "Session.count", 1 do
      post session_path, params: {
        email_address: " #{users(:owner).email_address.upcase} ", password: "test password", authenticity_token: before_login
      }
      assert_redirected_to root_path
    end
    follow_redirect!

    assert_select ".account-email", users(:owner).email_address
    post api_v1_contracts_path, params: {}, as: :json, headers: { "X-CSRF-Token" => before_login }
    assert_response :forbidden
  end

  test "unknown account and wrong password receive the same error" do
    get new_session_path
    token = csrf_token

    assert_no_difference "Session.count" do
      [ users(:owner).email_address, "unknown@example.test" ].each do |email|
        post session_path, params: { email_address: email, password: "wrong password", authenticity_token: token }
        assert_response :unprocessable_content
        assert_select '[role="alert"]', "Check your email address and password."
      end
    end
  end

  test "signing out revokes the stored session" do
    token = sign_in

    assert_difference "Session.count", -1 do
      delete session_path, params: { authenticity_token: token }
      assert_redirected_to new_session_path
    end

    get api_v1_contracts_path
    assert_response :unauthorized
    get root_path
    assert_redirected_to new_session_path
  end

  test "expired sessions require a new sign-in" do
    sign_in

    travel 25.hours do
      get api_v1_contracts_path
      assert_response :unauthorized
    end
  end
end
