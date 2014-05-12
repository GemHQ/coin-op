require "pp"

project_root = File.expand_path("#{File.dirname(__FILE__)}/../")
$:.unshift "#{project_root}/lib"

require "coin-op"
require_relative "helpers/mockchain"
require_relative "helpers/bitcoin"
require_relative "helpers/testnet_assets"

