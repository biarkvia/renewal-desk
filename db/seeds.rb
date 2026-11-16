if Rails.env.development? && ENV["SEED_DEMO"] == "1"
  %w[alex@example.test jamie@example.test].each do |email_address|
    User.find_or_create_by!(email_address: email_address) do |user|
      user.password = "renewal-demo"
    end
  end
end
