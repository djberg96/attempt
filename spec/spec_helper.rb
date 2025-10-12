# frozen_string_literal: true

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Filter out tests that require fork on platforms that don't support it
  config.filter_run_excluding :requires_fork if Gem.win_platform? || RUBY_ENGINE == 'java'

  # Filter out tests that require fiber features on older Ruby versions
  config.filter_run_excluding :requires_fiber_alive if RUBY_VERSION < '3.1.0'
end
