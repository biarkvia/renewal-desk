class Reminder < ApplicationRecord
  belongs_to :contract, class_name: "ContractRecord", inverse_of: :reminders
end
