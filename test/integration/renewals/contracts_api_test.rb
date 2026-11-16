require "test_helper"
require_relative "../../support/session_requests"

class ContractsApiTest < ActionDispatch::IntegrationTest
  include SessionRequests

  RESOURCE_KEYS = %w[id title counterparty ends_on notice_days notice_due_on decision decided_at lock_version].sort.freeze
  DETAILS = { title: "Office Internet", counterparty: "Example Telecom", ends_on: "2026-12-31", notice_days: 30 }.freeze

  test "requires a session for both reads and writes" do
    get api_v1_contracts_path
    assert_problem 401, "authentication_required"

    post api_v1_contracts_path, params: DETAILS, as: :json
    assert_problem 401, "authentication_required"
  end

  test "requires a token from the same session and rejects a foreign origin" do
    token = sign_in

    assert_no_difference "ContractRecord.count" do
      post api_v1_contracts_path, params: DETAILS, as: :json
      assert_problem 403, "csrf_invalid"

      post api_v1_contracts_path, params: DETAILS, as: :json, headers: { "X-CSRF-Token" => "bad-token" }
      assert_problem 403, "csrf_invalid"

      post api_v1_contracts_path(authenticity_token: token), params: DETAILS, as: :json
      assert_problem 403, "csrf_invalid"

      post api_v1_contracts_path, params: DETAILS, as: :json, headers: { "X-CSRF-Token" => token, "Origin" => "https://example.test" }
      assert_problem 403, "csrf_invalid"
    end
  end

  test "returns resources and Location for the contract lifecycle" do
    token = sign_in
    headers = { "X-CSRF-Token" => token }

    post api_v1_contracts_path, params: DETAILS, as: :json, headers: headers
    assert_response :created
    created = json
    assert_equal RESOURCE_KEYS, created.keys.sort
    id = created.fetch("id")
    assert_equal api_v1_contract_url(id), response.headers["Location"]
    assert_equal "2026-12-01", created.fetch("notice_due_on")
    assert_equal 0, created.fetch("lock_version")
    assert_nil created.fetch("decision")
    assert_nil created.fetch("decided_at")
    assert_equal users(:owner), ContractRecord.find(id).owner

    get api_v1_contract_path(id)
    assert_response :ok
    assert_equal created, json

    patch api_v1_contract_path(id), params: { notice_days: 31, lock_version: 0 }, as: :json, headers: headers
    assert_response :ok
    updated = json
    assert_equal RESOURCE_KEYS, updated.keys.sort
    assert_equal "2026-11-30", updated.fetch("notice_due_on")
    assert_equal 1, updated.fetch("lock_version")

    post decision_api_v1_contract_path(id), params: { decision: "renew", lock_version: 1 }, as: :json, headers: headers
    assert_response :ok
    assert_equal RESOURCE_KEYS, json.keys.sort
    assert_equal "renew", json.fetch("decision")
    assert_match(/Z\z/, json.fetch("decided_at"))
    assert_equal 2, json.fetch("lock_version")
  end

  test "filters the current owner's records in deadline and ID order" do
    sign_in
    late = persist_contract(title: "Later deadline")
    first = persist_contract(title: "First tied deadline", notice_days: 31)
    second = persist_contract(title: "Second tied deadline", notice_days: 31)
    closed = persist_contract(title: "Decided", notice_days: 32)
    Renewals::ContractWriter.record_decision(owner: users(:owner), id: closed.id, lock_version: 0, decision: "do_not_renew")
    persist_contract(owner: users(:other), title: "Other owner", notice_days: 31)

    get api_v1_contracts_path
    assert_response :ok
    assert_equal [ first.id, second.id, late.id ], json.pluck("id")

    get api_v1_contracts_path(view: "decided")
    assert_response :ok
    assert_equal [ closed.id ], json.pluck("id")

    get api_v1_contracts_path(view: "all")
    assert_response :ok
    assert_equal [ closed.id, first.id, second.id, late.id ], json.pluck("id")

    get api_v1_contracts_path(view: "today")
    assert_problem 400, "invalid_request"

    get "#{api_v1_contracts_path}?view=open&view%5B%5D=all"
    assert_problem 400, "invalid_request"
  end

  test "keeps lookup and mutations scoped to the session owner" do
    headers = { "X-CSRF-Token" => sign_in }
    other_record = persist_contract(owner: users(:other))

    get api_v1_contract_path(other_record)
    assert_problem 404, "contract_not_found"
    private_response = json

    get api_v1_contract_path(other_record.id + 1)
    assert_problem 404, "contract_not_found"
    assert_equal private_response, json

    assert_no_difference "ContractEvent.count" do
      patch api_v1_contract_path(other_record), params: { title: "Hijack", lock_version: 0 }, as: :json, headers: headers
      assert_problem 404, "contract_not_found"

      post decision_api_v1_contract_path(other_record), params: { decision: "renew", lock_version: 0 }, as: :json, headers: headers
      assert_problem 404, "contract_not_found"
    end
  end

  test "rejects malformed JSON bodies, non-object bodies and unsupported fields" do
    headers = { "X-CSRF-Token" => sign_in, "Content-Type" => "application/json" }
    assert_no_difference "ContractRecord.count" do
      [ "{", "[1]", "null", '"value"', "" ].each do |body|
        post api_v1_contracts_path, params: body.dup, headers: headers
        assert_problem 400, "invalid_request"
      end

      post api_v1_contracts_path, params: DETAILS.merge(owner_id: users(:other).id).to_json, headers: headers
      assert_problem 400, "invalid_request"
    end
  end

  test "rejects missing fields, invalid values and a patch without details" do
    headers = { "X-CSRF-Token" => sign_in }
    record = persist_contract

    post api_v1_contracts_path, params: DETAILS.except(:title), as: :json, headers: headers
    assert_problem 422, "invalid_input", field: "title"

    post api_v1_contracts_path, params: DETAILS.merge(ends_on: "2026-02-30"), as: :json, headers: headers
    assert_problem 422, "invalid_date", field: "ends_on"

    [ "30", 30.0, 366 ].each do |period|
      post api_v1_contracts_path, params: DETAILS.merge(notice_days: period), as: :json, headers: headers
      assert_problem 422, "invalid_notice_period", field: "notice_days"
    end

    patch api_v1_contract_path(record, title: "Injected"), params: { lock_version: 0 }, as: :json, headers: headers
    assert_problem 422, "invalid_input"

    patch api_v1_contract_path(record), params: { title: "New", lock_version: "0" }, as: :json, headers: headers
    assert_problem 422, "invalid_input", field: "lock_version"

    post decision_api_v1_contract_path(record), params: { decision: "cancel", lock_version: 0 }, as: :json, headers: headers
    assert_problem 422, "invalid_decision", field: "decision"
    assert_equal 0, record.reload.lock_version
  end

  test "reports the stale version before the decided contract error" do
    headers = { "X-CSRF-Token" => sign_in }
    record = persist_contract

    post decision_api_v1_contract_path(record), params: { decision: "renew", lock_version: 0 }, as: :json, headers: headers
    assert_response :ok

    assert_no_difference "ContractEvent.count" do
      post decision_api_v1_contract_path(record), params: { decision: "renew", lock_version: 0 }, as: :json, headers: headers
      assert_problem 409, "stale_version"

      post decision_api_v1_contract_path(record), params: { decision: "renew", lock_version: 1 }, as: :json, headers: headers
      assert_problem 409, "contract_already_decided"
    end
  end

  test "unexpected persistence errors return a public problem without leaking database details" do
    headers = { "X-CSRF-Token" => sign_in }
    ContractEvent.with_connection do |connection|
      connection.execute("ALTER TABLE contract_events ADD CONSTRAINT private_test_constraint CHECK (event_type <> 'contract_created') NOT VALID")
    end

    assert_no_difference "ContractRecord.count" do
      post api_v1_contracts_path, params: DETAILS, as: :json, headers: headers
      assert_problem 500, "internal_error"
      refute_includes response.body, "private_test_constraint"
      refute_includes response.body, "ActiveRecord"
    end
  end

  private

  def json = JSON.parse(response.body)

  def assert_problem(status, code, field: nil)
    assert_response status
    assert_equal "application/problem+json", response.media_type
    problem = json
    assert_equal "about:blank", problem.fetch("type")
    assert_equal Rack::Utils::HTTP_STATUS_CODES.fetch(status), problem.fetch("title")
    assert_equal status, problem.fetch("status")
    assert_equal code, problem.fetch("code")
    assert_predicate problem.fetch("detail"), :present?
    if field
      assert_equal field, problem.fetch("field")
    else
      refute problem.key?("field")
    end
  end
end
