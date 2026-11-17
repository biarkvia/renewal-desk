if Rails.env.development? && ENV["SEED_DEMO"] == "1"
  today = Date.current
  demo_contracts = {
    "alex@example.test" => [
      [ "Office internet", "Example Telecom", 0, nil ],
      [ "Building access", "Meridian Facilities", 7, nil ],
      [ "Cloud hosting", "Northstar Systems", 8, nil ],
      [ "Office cleaning", "Example Cleaning", -3, nil ],
      [ "Printer lease", "Example Office Supply", -7, "renew" ]
    ],
    "jamie@example.test" => [
      [ "Equipment maintenance", "Example Service Co.", 5, nil ]
    ]
  }

  demo_contracts.each do |email_address, contracts|
    owner = User.find_or_create_by!(email_address: email_address) { |user| user.password = "renewal-demo" }
    owner.with_lock do
      contracts.each do |title, counterparty, days_until_notice, decision|
        next if ContractRecord.exists?(owner: owner, title: title)

        record = Renewals::ContractWriter.create(
          owner: owner, title: title, counterparty: counterparty, ends_on: today + days_until_notice + 30, notice_days: 30
        )
        if decision
          Renewals::ContractWriter.record_decision(owner: owner, id: record.id, lock_version: record.lock_version, decision: decision)
        end
      end
    end
  end
end
