class ContractRecord < ApplicationRecord
  self.table_name = "contracts"

  belongs_to :owner, class_name: "User"
  has_many :events, -> { order(:id) }, class_name: "ContractEvent", foreign_key: :contract_id, inverse_of: :contract
  has_many :reminders, foreign_key: :contract_id, inverse_of: :contract

  attribute :ends_on, Renewals::GregorianDate.new
  attribute :notice_due_on, Renewals::GregorianDate.new

  def current_reminder
    reminders.find_by(schedule_revision: schedule_revision) if decision.nil?
  end
end
