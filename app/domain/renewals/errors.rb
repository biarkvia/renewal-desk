# frozen_string_literal: true

module Renewals
  module Errors
    class DomainError < StandardError; end

    class InvalidNoticePeriod < DomainError
      attr_reader :value, :minimum, :maximum

      def initialize(value:, minimum:, maximum:)
        @value = value
        @minimum = minimum
        @maximum = maximum
        super("Notice period must be between #{minimum} and #{maximum} days")
      end
    end

    class InvalidDate < DomainError
      attr_reader :field, :value

      def initialize(field:, value:)
        @field = field
        @value = value
        super("#{field} must be a Gregorian date between 0001-01-01 and 9999-12-31")
      end
    end

    class InvalidDetails < DomainError
      attr_reader :field, :value, :maximum

      def initialize(field:, value:, maximum:)
        @field = field
        @value = value
        @maximum = maximum
        super("#{field} must be valid text between 1 and #{maximum} characters")
      end
    end

    class InvalidDecision < DomainError
      attr_reader :value

      def initialize(value:)
        @value = value
        super("Decision must be renew or do_not_renew")
      end
    end

    class InvalidState < DomainError
      attr_reader :field, :value

      def initialize(field:, value:, message:)
        @field = field
        @value = value
        super(message)
      end
    end

    class ContractAlreadyDecided < DomainError
      attr_reader :contract_id, :decision

      def initialize(contract_id:, decision:)
        @contract_id = contract_id
        @decision = decision
        super("A renewal decision has already been recorded")
      end
    end
  end
end
