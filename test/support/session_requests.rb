module SessionRequests
  def sign_in(user = users(:owner))
    get new_session_path
    post session_path, params: { email_address: user.email_address, password: "test password", authenticity_token: csrf_token }
    assert_response :see_other
    assert_redirected_to root_path
    follow_redirect!
    assert_response :success
    csrf_token
  end

  def csrf_token
    css_select('meta[name="csrf-token"]').sole["content"]
  end

  def persist_contract(owner: users(:owner), **details)
    defaults = { title: "Office Internet", counterparty: "Example Telecom", ends_on: Date.new(2026, 12, 31), notice_days: 30 }
    Renewals::ContractWriter.create(owner: owner, **defaults.merge(details))
  end
end
