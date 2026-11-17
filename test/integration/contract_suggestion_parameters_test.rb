require "test_helper"
require_relative "../support/session_requests"

class ContractSuggestionParametersTest < ActionDispatch::IntegrationTest
  include SessionRequests

  test "an excerpt in the URL cannot supply the form body" do
    token = sign_in

    post contract_suggestion_path(contract_excerpt: "Text in the URL."), params: { authenticity_token: token }

    assert_response :unprocessable_content
    assert_select '[role="alert"]', text: /Enter an excerpt/
  end

  test "a valid proposal in the URL cannot fill the contract form" do
    token = sign_in
    proposal = Rails.application.message_verifier(:contract_suggestion).generate(
      { "ends_on" => "2026-12-31" }, purpose: "contract-suggestion:#{users(:owner).id}", expires_in: 15.minutes
    )

    post apply_contract_suggestion_path(proposal: proposal), params: { authenticity_token: token }

    assert_response :unprocessable_content
    assert_select 'input[name="contract[ends_on]"]', count: 0
  end
end
