class ContractEvent < ApplicationRecord
  belongs_to :contract, class_name: "ContractRecord", inverse_of: :events
  belongs_to :actor, class_name: "User"
end
