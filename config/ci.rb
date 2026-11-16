CI.run do
  step "Test the domain without Rails", "bin/test-domain"
  step "Prepare the test database", "bin/rails db:prepare"
  step "Check Rails autoloading", "bin/rails zeitwerk:check"
  step "Run tests", "bin/rails test"
  step "Check Ruby style", "bin/rubocop"
end
