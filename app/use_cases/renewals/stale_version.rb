module Renewals
  class StaleVersion < StandardError
    attr_reader :contract_id, :expected_version, :current_version

    def initialize(contract_id:, expected_version:, current_version:)
      @contract_id = contract_id
      @expected_version = expected_version
      @current_version = current_version
      super("The contract has changed since it was opened")
    end
  end
end
