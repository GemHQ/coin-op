require 'coin-op'
require 'pry-debugger'
require 'factory_girl'
require 'factories'

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  config.include FactoryGirl::Syntax::Methods

  config.order = 'random'
end
