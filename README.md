# Coin-Op

Install:

    gem install coin-op


Basic usage:

```ruby
require "coin-op"

include CoinOp::Bit

transaction = Transaction.from_data(
  # Override the minimum suggested fee
  :fee => 20_000,
  :inputs => [
    {
      :output => {
        :transaction_hash => "2f47a8d7537fd981670b6142f86e1961991577506a825cdfb4c6ab3666db4fc1",
        :index => 0,
        :value => 2_000_000
      }
    },
    {
      :output => {
        :transaction_hash => "fe4d26f6536c17c451e7d9fd7bca3e981a1c9f4542ee49f3bdcb71050c8ef243",
        :index => 0,
        :value => 2_600_000
      }
    }
  ],
  :outputs => [
    {
      :value => 3_000_000,
      :address => "2N9c7acEJNHkDaQvRShMxJcBu5Lw535AvwR"
    }
  ]
)

transaction.add_change(change_address)

# Set the script_sigs manually
transaction.inputs[0].script_sig = "foo"
transaction.inputs[1].script_sig = "bar"

# Or use an iterating helper method. First argument is an array of
# items corresponding to the inputs.  The block yields to you each
# input, along with the corresponding element from your array.
transaction.set_script_sigs *keypairs do |input, keypair|
  sig_for(keypair, input)
end

```

# Developers

Installing dependencies:

    gem install starter
    rake gem:deps

Running the tests:

    rake test


