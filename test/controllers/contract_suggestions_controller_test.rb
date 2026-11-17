require "test_helper"

class ContractSuggestionsControllerTest < ActionController::TestCase
  tests ContractSuggestionsController

  class ControllerWithProvider < ContractSuggestionsController
    self.allow_forgery_protection = false

    attr_accessor :test_provider

    def self.controller_path = "contract_suggestions"

    private

    def load_provider
      @provider = test_provider
    end
  end

  setup do
    @controller = ControllerWithProvider.new
    @controller.test_provider = ContractExtraction::DemoProvider.new
    @owner_session = Session.create!(user: users(:owner))
  end

  test "shows source quotes and applies the terms only after confirmation" do
    assert_no_difference "ContractRecord.count" do
      post :create, params: { contract_excerpt: ContractExtraction::DemoProvider::SAMPLE }, session: credentials(@owner_session)
      assert_response :success
      assert_select "blockquote", text: ContractExtraction::DemoProvider::END_CLAUSE
      assert_select "blockquote", text: ContractExtraction::DemoProvider::NOTICE_CLAUSE
      assert_select 'input[name="contract[ends_on]"]', count: 0

      token = css_select('input[name="proposal"]').sole["value"]
      post :apply, params: { proposal: token }, session: credentials(@owner_session)
      assert_response :success
      assert_select 'input[name="contract[ends_on]"][value="2026-12-31"]'
      assert_select 'input[name="contract[notice_days]"][value="30"]'
    end
  end

  test "a different user cannot apply the proposal" do
    post :create, params: { contract_excerpt: ContractExtraction::DemoProvider::SAMPLE }, session: credentials(@owner_session)
    token = css_select('input[name="proposal"]').sole["value"]
    other_session = Session.create!(user: users(:other))

    post :apply, params: { proposal: token }, session: credentials(other_session)
    assert_response :unprocessable_content
    assert_select "a[href=?]", new_contract_path, text: "Back to manual entry"
    assert_select 'input[name="contract[ends_on]"]', count: 0
  end

  test "manual entry remains accessible when the provider is unavailable" do
    @controller.test_provider = nil

    post :create, params: { contract_excerpt: ContractExtraction::DemoProvider::SAMPLE }, session: credentials(@owner_session)
    assert_response :service_unavailable
    assert_select '[role="alert"]', text: /temporarily unavailable/
    assert_select "a[href=?]", new_contract_path, text: "Back to manual entry"
  end

  private

  def credentials(session)
    { renewal_session_id: session.id }
  end
end
