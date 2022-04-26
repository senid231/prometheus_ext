# frozen_string_literal: true

require 'prometheus_ext'
Dir[File.join(__dir__, 'support/**/*.rb')].sort.each { |path| require path }

RSpec.configure do |config|
  config.include CustomHelper

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.mock_with :rspec do |mocks|
    mocks.allow_message_expectations_on_nil = false
  end

  config.order = 'random'
end
