require "bitcoin"

# bitcoin-ruby is not multi-network friendly.  It's also a hassle
# to tell what network you're using if you don't already know.
# This makes it a bit easier.
Bitcoin::NETWORKS.each do |name, definition|
  definition[:name] = name
end


# BIP 32 Hierarchical Deterministic Wallets
require "money-tree"

# establish the namespace
module CoinOp
  module Bit
  end
end

require_relative "encodings"

# Wrappers
require_relative "bit/script"
require_relative "bit/output"
require_relative "bit/input"
require_relative "bit/transaction"
require_relative "bit/spendable"
require_relative "bit/fee"

# Augmented functionality
require_relative "bit/multi_wallet"

