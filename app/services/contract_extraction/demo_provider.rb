module ContractExtraction
  class DemoProvider
    END_CLAUSE = "The agreement ends on 31 December 2026.".freeze
    NOTICE_CLAUSE = "Send written notice at least 30 calendar days before the agreement ends.".freeze
    SAMPLE = "#{END_CLAUSE}\n#{NOTICE_CLAUSE}".freeze

    def suggest(excerpt)
      raise InvalidExcerpt, "Use the sample excerpt in demo mode." unless excerpt.gsub("\r\n", "\n").strip == SAMPLE

      {
        "ends_on" => { "value" => "2026-12-31", "quote" => END_CLAUSE },
        "notice_days" => { "value" => 30, "quote" => NOTICE_CLAUSE }
      }
    end
  end
end
