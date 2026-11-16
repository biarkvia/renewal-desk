class ContractInput
  DETAILS = %w[title counterparty ends_on notice_days].freeze
  FORM_FIELDS = (DETAILS + %w[lock_version decision]).freeze

  class Error < StandardError
    attr_reader :status, :code, :field

    def initialize(message, status: 422, code: "invalid_input", field: nil)
      @status = status
      @code = code
      @field = field
      super(message)
    end
  end

  def initialize(attributes, form: false)
    @attributes = attributes
    @form = form
  end

  def create_attributes
    check_keys(DETAILS)
    DETAILS.to_h { |field| [ field.to_sym, parse_detail(field) ] }
  end

  def update_attributes
    check_keys(DETAILS + [ "lock_version" ])
    fields = DETAILS & @attributes.keys
    raise Error.new("Provide at least one contract field to update.") if fields.empty?

    fields.to_h { |field| [ field.to_sym, parse_detail(field) ] }.merge(lock_version: lock_version)
  end

  def decision_attributes
    check_keys(%w[decision lock_version])
    { lock_version: lock_version, decision: fetch("decision") }
  end

  private

  def check_keys(allowed)
    return if @attributes.is_a?(Hash) && (@attributes.keys - allowed).empty?

    raise Error.new("Send an object containing the supported fields.", status: 400, code: "invalid_request")
  end

  def fetch(field)
    @attributes.fetch(field) { raise Error.new("#{field.humanize} is required.", field: field) }
  end

  def parse_detail(field)
    value = fetch(field)

    case field
    when "ends_on"
      parse_date(value)
    when "notice_days"
      parse_integer(value) || raise(Error.new("Notice period must be a whole number of days.", code: "invalid_notice_period", field: field))
    else
      value
    end
  end

  def parse_date(value)
    if value.is_a?(String) && /\A[0-9]{4}-[0-9]{2}-[0-9]{2}\z/.match?(value)
      return Date.iso8601(value, Date::GREGORIAN)
    end

    raise Date::Error
  rescue Date::Error
    raise Error.new("Enter a valid end date in YYYY-MM-DD format.", code: "invalid_date", field: "ends_on")
  end

  def lock_version
    value = parse_integer(fetch("lock_version"))
    return value if value && value >= 0

    raise Error.new("Version must be a non-negative integer.", field: "lock_version")
  end

  def parse_integer(value)
    return value if value.is_a?(Integer)
    return unless @form && value.is_a?(String) && /\A-?[0-9]+\z/.match?(value)

    Integer(value, 10, exception: false)
  end
end
