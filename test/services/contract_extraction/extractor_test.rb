require "test_helper"

module ContractExtraction
  class ExtractorTest < ActiveSupport::TestCase
    StubProvider = Struct.new(:response) do
      def suggest(_excerpt) = response
    end

    test "parses supported values and retains their exact source quotes" do
      result = extract(valid_response)

      assert_equal({ value: Date.new(2026, 12, 31), quote: DemoProvider::END_CLAUSE }, result.fetch("ends_on"))
      assert_equal({ value: 30, quote: DemoProvider::NOTICE_CLAUSE }, result.fetch("notice_days"))
    end

    test "a null term stays absent and two null terms produce no suggestions" do
      assert_equal [ "notice_days" ], extract(valid_response.merge("ends_on" => nil)).keys
      assert_empty extract("ends_on" => nil, "notice_days" => nil)
    end

    test "rejects unexpected keys and incorrectly typed terms" do
      invalid = [
        [],
        valid_response.except("ends_on"),
        valid_response.merge("decision" => nil),
        valid_response.merge("ends_on" => { "value" => "2026-12-31" }),
        valid_response.merge("notice_days" => valid_response.fetch("notice_days").merge("value" => "30")),
        valid_response.merge("notice_days" => valid_response.fetch("notice_days").merge("value" => 30.0))
      ]

      invalid.each { |response| assert_raises(InvalidResponse) { extract(response) } }
    end

    test "rejects invented quotes and invalid dates or periods" do
      %w[2026-2-20 2026-02-30 0000-12-31].each do |date|
        result = valid_response
        result.fetch("ends_on")["value"] = date
        assert_raises(InvalidResponse) { extract(result) }
      end
      [ -1, 366 ].each do |days|
        result = valid_response
        result.fetch("notice_days")["value"] = days
        assert_raises(InvalidResponse) { extract(result) }
      end

      result = valid_response
      result.fetch("notice_days")["quote"] = "Invented notice provision."
      assert_raises(InvalidResponse) { extract(result) }
    end

    test "rejects two terms that would calculate a deadline outside the domain range" do
      result = valid_response
      result.fetch("ends_on")["value"] = "0001-01-01"

      assert_raises(InvalidResponse) { extract(result) }
    end

    test "requires a nonempty bounded excerpt and a configured provider" do
      extractor = Extractor.new(provider: nil)
      [ nil, "   ", "a" * 4_001 ].each do |excerpt|
        assert_raises(InvalidExcerpt) { extractor.call(excerpt) }
      end
      assert_raises(Unavailable) { extractor.call(DemoProvider::SAMPLE) }
    end

    private

    def extract(response)
      Extractor.new(provider: StubProvider.new(response)).call(DemoProvider::SAMPLE)
    end

    def valid_response
      DemoProvider.new.suggest(DemoProvider::SAMPLE)
    end
  end
end
