module ContractExtraction
  class Extractor
    MAX_EXCERPT_LENGTH = 4_000
    FIELDS = %w[ends_on notice_days].freeze
    SUGGESTION_KEYS = %w[value quote].freeze
    SCHEMA = {
      type: "object",
      properties: { ends_on: "string", notice_days: "integer" }.transform_values do |value_type|
        {
          anyOf: [
            { type: "null" },
            {
              type: "object",
              properties: { value: { type: value_type }, quote: { type: "string" } },
              required: SUGGESTION_KEYS,
              additionalProperties: false
            }
          ]
        }
      end,
      required: FIELDS,
      additionalProperties: false
    }.freeze

    def initialize(provider:)
      @provider = provider
    end

    def call(excerpt)
      unless excerpt.is_a?(String) && excerpt.valid_encoding? && excerpt.present? && excerpt.length <= MAX_EXCERPT_LENGTH
        raise InvalidExcerpt, "Enter an excerpt of 1 to #{MAX_EXCERPT_LENGTH} characters."
      end
      raise Unavailable unless @provider

      response = @provider.suggest(excerpt)
      expect_keys!(response, FIELDS)
      suggestions = response.compact.to_h do |field, suggestion|
        expect_keys!(suggestion, SUGGESTION_KEYS)
        quote = suggestion.fetch("quote")
        raise InvalidResponse unless quote.is_a?(String) && quote.present? && excerpt.include?(quote)

        [ field, { value: validated_value(field, suggestion.fetch("value")), quote: quote } ]
      end
      validate_schedule!(suggestions)
      suggestions
    rescue Date::Error, Renewals::Errors::InvalidDate, Renewals::Errors::InvalidNoticePeriod
      raise InvalidResponse
    end

    private

    def expect_keys!(value, keys)
      unless value.is_a?(Hash) && value.size == keys.size && keys.all? { |key| value.key?(key) }
        raise InvalidResponse
      end
    end

    def validated_value(field, value)
      if field == "ends_on"
        unless value.is_a?(String) && /\A[0-9]{4}-[0-9]{2}-[0-9]{2}\z/.match?(value)
          raise InvalidResponse
        end

        Date.iso8601(value, Date::GREGORIAN)
      else
        minimum = Renewals::NoticeSchedule::MINIMUM_NOTICE_DAYS
        maximum = Renewals::NoticeSchedule::MAXIMUM_NOTICE_DAYS
        raise InvalidResponse unless value.is_a?(Integer) && (minimum..maximum).cover?(value)

        value
      end
    end

    def validate_schedule!(suggestions)
      ends_on = suggestions.dig("ends_on", :value)
      return unless ends_on

      Renewals::NoticeSchedule.new(ends_on: ends_on, notice_days: suggestions.dig("notice_days", :value) || 0)
    end
  end
end
