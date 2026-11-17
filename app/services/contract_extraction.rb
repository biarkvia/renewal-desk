module ContractExtraction
  class Error < StandardError; end
  class InvalidExcerpt < Error; end
  class InvalidResponse < Error; end
  class Unavailable < Error; end

  def self.provider
    if Rails.env.development? && ENV["CONTRACT_EXTRACTION_DEMO"] == "1"
      DemoProvider.new
    elsif ENV["OPENAI_API_KEY"].present?
      OpenAiProvider.new(api_key: ENV.fetch("OPENAI_API_KEY"))
    end
  end
end
