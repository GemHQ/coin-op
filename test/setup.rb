require "pp"

project_root = File.expand_path("#{File.dirname(__FILE__)}/../")
$:.unshift "#{project_root}/lib"

require "coin-op"

Bitcoin.network = :testnet3
require_relative "helpers/bitcoin"
require_relative "helpers/testnet_assets"

