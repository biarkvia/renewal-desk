require "application_system_test_case"

class RenewalWorkflowTest < ApplicationSystemTestCase
  test "an owner creates and edits a contract, receives a reminder, then records a decision" do
    travel_to(Time.zone.local(2026, 11, 24, 8)) do
      sign_in(users(:owner))
      click_link "New contract"
      fill_in "Contract name", with: "Office Internet"
      fill_in "Counterparty", with: "Example Telecom"
      fill_in "End date", with: Date.new(2026, 12, 31)
      fill_in "Notice period in days", with: "30"
      click_button "Add contract"

      assert_selector "h1", text: "Office Internet"
      assert_selector '.deadline time[datetime="2026-12-01"]'
      assert_no_selector ".renewal-reminder"
      contract_path = page.current_path

      click_link "Edit contract"
      fill_in "Notice period in days", with: "31"
      click_button "Save changes"
      assert_selector '.deadline time[datetime="2026-11-30"]'

      IssueRenewalRemindersJob.perform_now
      visit contract_path
      assert_selector ".renewal-reminder", text: "Review this contract by 30 Nov 2026."

      choose "Renew", exact: true
      click_button "Record decision"
      assert_selector ".decision-value", text: "Renew"
      assert_no_selector ".renewal-reminder"
      within ".history" do
        assert_selector "h3", text: "Contract added"
        assert_selector "h3", text: "Contract updated"
        assert_selector "h3", text: "Decision recorded"
      end

      click_button "Sign out"
      sign_in(users(:other))
      click_link "All", exact: true
      assert_no_text "Office Internet"
      visit contract_path
      assert_selector "h1", text: "Contract unavailable"
      assert_no_text "Office Internet"
    end
  end

  private

  def sign_in(user)
    visit root_path
    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "test password"
    click_button "Sign in"
    assert_selector "h1", text: "Contracts"
  end
end
