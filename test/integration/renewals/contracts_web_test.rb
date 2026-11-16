require "test_helper"
require_relative "../../support/session_requests"

class ContractsWebTest < ActionDispatch::IntegrationTest
  include SessionRequests

  test "creates and updates a contract before recording its decision" do
    sign_in
    get new_contract_path
    assert_select "h1", "New contract"

    post contracts_path, params: {
      authenticity_token: csrf_token,
      contract: { title: "Office Internet", counterparty: "Example Telecom", ends_on: "2026-12-31", notice_days: "30" }
    }
    assert_response :see_other
    follow_redirect!
    record = ContractRecord.find_by!(title: "Office Internet")
    assert_select 'time[datetime="2026-12-01"]', "1 Dec 2026"

    get edit_contract_path(record)
    assert_select 'input[name="contract[notice_days]"][value="30"]'
    patch contract_path(record), params: { authenticity_token: csrf_token, contract: { notice_days: "31", lock_version: "0" } }
    assert_response :see_other
    follow_redirect!
    assert_select 'time[datetime="2026-11-30"]', "30 Nov 2026"

    post decision_contract_path(record), params: { authenticity_token: csrf_token, contract: { decision: "renew", lock_version: "1" } }
    assert_response :see_other
    follow_redirect!
    assert_select "#decision-heading", "Renewal decision"
    assert_select ".decision-value", "Renew"
    assert_equal [ "Contract added", "Contract updated", "Decision recorded" ], css_select(".history h3").map(&:text)
    assert_select "a[href=?]", edit_contract_path(record), count: 0

    get contracts_path
    assert_select ".empty-state", "No open contracts."
    get contracts_path(view: "decided")
    assert_select '.tabs a[aria-current="page"]', "Decided"
    assert_select ".contract-link", "Office Internet"
  end

  test "renders the date relative to Prague, including today's deadline" do
    travel_to(Time.utc(2026, 11, 30, 23, 30)) do
      sign_in
      persist_contract(title: "Due on December 1")
      get contracts_path
      assert_select ".badge", "Due today"
    end
  end

  test "preserves submitted values and gives an explicit reload link on conflicts" do
    token = sign_in
    record = persist_contract

    patch contract_path(record), params: { authenticity_token: token, contract: { title: "Edited name", notice_days: "366", lock_version: "0" } }
    assert_response :unprocessable_content
    assert_select '[role="alert"]', "Notice period must be between 0 and 365 days"
    assert_select 'input[name="contract[title]"][value="Edited name"]'
    assert_equal "Office Internet", record.reload.title

    Renewals::ContractWriter.update(owner: users(:owner), id: record.id, lock_version: 0, title: "Saved elsewhere")
    patch contract_path(record), params: { authenticity_token: token, contract: { title: "Old form", lock_version: "0" } }
    assert_response :conflict
    assert_select "a[href=?]", contract_path(record), text: "Reload contract"
    assert_equal "Saved elsewhere", record.reload.title
  end

  test "a foreign contract is absent from the web list and cannot be opened" do
    sign_in
    record = persist_contract(owner: users(:other), title: "Private contract")
    get contracts_path(view: "all")
    assert_select ".empty-state", "No contracts yet."

    get contract_path(record)
    assert_response :not_found
    refute_includes response.body, "Private contract"

    get edit_contract_path(record)
    assert_response :not_found
  end
end
