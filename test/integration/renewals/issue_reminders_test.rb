require "test_helper"
require "fugit"

class IssueRemindersTest < ActiveSupport::TestCase
  test "creates a single reminder for each eligible open contract" do
    today = Date.new(2026, 12, 1)
    due = create_contract(today)
    last_day = create_contract(today + 7)
    overdue = create_contract(today - 5)
    outside_window = create_contract(today + 8)
    closed = create_contract(today)
    Renewals::ContractWriter.record_decision(owner: closed.owner, id: closed.id, lock_version: 0, decision: "renew")

    Renewals::IssueReminders.call(today: today)

    assert_equal [ due.id, last_day.id, overdue.id ].sort, Reminder.order(:contract_id).pluck(:contract_id)
    assert_nil outside_window.current_reminder
    assert_nil closed.reload.current_reminder
    reminder = last_day.current_reminder
    assert_equal 1, reminder.schedule_revision
    assert_predicate reminder.created_at, :present?

    next_contract = create_contract(today + 6)
    assert_difference "Reminder.count", 1 do
      Renewals::IssueReminders.call(today: today)
    end
    assert_equal reminder.id, last_day.current_reminder.id
    assert_equal next_contract.id, next_contract.current_reminder.contract_id
  end

  test "keeps prior revisions and hides reminders when a contract is decided" do
    today = Date.new(2026, 12, 1)
    record = create_contract(today)
    Renewals::IssueReminders.call(today: today)
    original = record.current_reminder

    record = Renewals::ContractWriter.update(owner: record.owner, id: record.id, lock_version: 0, title: "Updated title")
    assert_equal original.id, record.current_reminder.id

    record = Renewals::ContractWriter.update(owner: record.owner, id: record.id, lock_version: 1, notice_days: 28)
    assert_nil record.current_reminder
    Renewals::IssueReminders.call(today: today)
    assert_equal [ 1, 2 ], record.reminders.order(:schedule_revision).pluck(:schedule_revision)
    assert_equal 2, record.current_reminder.schedule_revision

    record = Renewals::ContractWriter.record_decision(owner: record.owner, id: record.id, lock_version: 2, decision: "do_not_renew")
    assert_nil record.current_reminder
    assert_no_difference "Reminder.count" do
      Renewals::IssueReminders.call(today: today)
    end
    assert_equal original, record.reminders.find(original.id)
  end

  test "uses the Prague calendar date even when UTC is still on the prior day" do
    record = create_contract(Date.new(2026, 12, 8))

    travel_to(Time.utc(2026, 11, 30, 22, 59)) do
      assert_no_difference "Reminder.count" do
        IssueRenewalRemindersJob.perform_now
      end
    end

    travel_to(Time.utc(2026, 11, 30, 23, 0)) do
      assert_difference "Reminder.count", 1 do
        IssueRenewalRemindersJob.perform_now
      end
    end

    assert_equal record.id, record.current_reminder.contract_id
  end

  test "the schedule stays at eight in Prague in winter and summer" do
    config = ActiveSupport::ConfigurationFile.parse(Rails.root.join("config/recurring.yml"))

    %w[development production].each do |environment|
      reminder_schedule = config.fetch(environment).fetch("issue_renewal_reminders")
      assert_equal "IssueRenewalRemindersJob", reminder_schedule.fetch("class")
      cron = Fugit.parse_cron(reminder_schedule.fetch("schedule"))
      assert_equal Time.utc(2026, 1, 15, 7), cron.next_time(Time.utc(2026, 1, 15)).to_t.utc
      assert_equal Time.utc(2026, 7, 15, 6), cron.next_time(Time.utc(2026, 7, 15)).to_t.utc
    end
  end

  private

  def create_contract(due_on)
    Renewals::ContractWriter.create(
      owner: users(:owner), title: "Office Internet", counterparty: "Example Telecom", ends_on: due_on + 30, notice_days: 30
    )
  end
end
