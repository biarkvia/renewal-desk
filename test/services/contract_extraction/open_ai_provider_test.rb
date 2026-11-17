require "test_helper"
require "net/http"

module ContractExtraction
  class OpenAiProviderTest < ActiveSupport::TestCase
    class Success < Net::HTTPSuccess
      def initialize(payload)
        super("1.1", "200", "OK")
        @payload = payload
      end

      def body = @payload
    end

    test "requests strict structured output and parses the assistant content" do
      result = { "ends_on" => nil, "notice_days" => nil }
      provider = OpenAiProvider.new(api_key: "test-key", transport: ->(request) do
        body = JSON.parse(request.body)
        assert_equal "/v1/responses", request.path
        assert_equal "Bearer test-key", request["Authorization"]
        assert_equal DemoProvider::SAMPLE, body.fetch("input")
        assert_equal "gpt-6-luna", body.fetch("model")
        assert_equal "none", body.dig("reasoning", "effort")
        assert_equal false, body.fetch("store")
        assert_equal "json_schema", body.dig("text", "format", "type")
        assert_equal true, body.dig("text", "format", "strict")
        assert_equal %w[ends_on notice_days], body.dig("text", "format", "schema", "required")
        Success.new(envelope({ type: "output_text", text: result.to_json }).to_json)
      end)

      assert_equal result, provider.suggest(DemoProvider::SAMPLE)
    end

    test "timeouts and HTTP errors become an unavailable provider" do
      timeout = OpenAiProvider.new(api_key: "test-key", transport: ->(_request) { raise Net::ReadTimeout })
      unavailable = OpenAiProvider.new(api_key: "test-key", transport: ->(_request) { Net::HTTPTooManyRequests.new("1.1", "429", "Too Many Requests") })

      assert_raises(Unavailable) { timeout.suggest(DemoProvider::SAMPLE) }
      assert_raises(Unavailable) { unavailable.suggest(DemoProvider::SAMPLE) }
    end

    test "refusals, incomplete responses and empty or invalid JSON are rejected" do
      payloads = [
        envelope({ type: "refusal", refusal: "Unavailable" }).to_json,
        envelope({ type: "output_text", text: "{" }).to_json,
        envelope({ type: "output_text", text: "{}" }).merge(status: "incomplete").to_json,
        "not JSON",
        nil
      ]

      payloads.each do |payload|
        provider = OpenAiProvider.new(api_key: "test-key", transport: ->(_request) { Success.new(payload) })
        assert_raises(InvalidResponse) { provider.suggest(DemoProvider::SAMPLE) }
      end
    end

    private

    def envelope(part)
      { status: "completed", output: [ { type: "message", role: "assistant", content: [ part ] } ] }
    end
  end
end
