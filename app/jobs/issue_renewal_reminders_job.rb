class IssueRenewalRemindersJob < ApplicationJob
  queue_as :default

  def perform
    Renewals::IssueReminders.call(today: Date.current)
  end
end
