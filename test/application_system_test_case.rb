require "test_helper"
require "selenium-webdriver"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome,
    options: { service: Selenium::WebDriver::Service.chrome(path: "/usr/bin/chromedriver") } do |options|
    options.binary = "/usr/bin/chromium"
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--no-sandbox")
  end
end
