module Renewals
  class GregorianDate < ActiveRecord::Type::Date
    private

    # PostgreSQL uses the Gregorian calendar for dates before October 1582 too.
    def new_date(year, month, day)
      return unless year && month && day

      Date.new(year, month, day, Date::GREGORIAN)
    rescue Date::Error
      nil
    end
  end
end
