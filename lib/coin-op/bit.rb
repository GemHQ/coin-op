require "bitcoin"
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

# Augmented functionality
require_relative "bit/multi_wallet"

