
module CoinOp::Bit

  module Fee

    module_function

    # Given an array of unspent Outputs and an array of Outputs for a
    # Transaction, estimate the fee required for the transaction to be
    # included in a block.  Optionally takes an Integer specifying the
    # transaction size in bytes, which is necessary when using unspents
    # that deviate from the customary single signature.
    #
    # Returns the estimated fee in satoshis.
    def estimate(unspents, payees, tx_size=nil, network:)
      # https://en.bitcoin.it/wiki/Transaction_fees

      # dupe because we'll need to add a change output
      payees = payees.dup

      unspent_total = unspents.inject(0) {|sum, output| sum += output.value}
      payee_total = payees.inject(0) {|sum, payee| sum += payee.value}
      nominal_change = unspent_total - payee_total
      payees << Output.new(value: nominal_change, network: network)

      tx_size ||= estimate_tx_size(unspents.size, payees.size)
      min = payees.min_by {|payee| payee.value }

      small = tx_size < 1000
      big_outputs = min.value > 1_000_000

      require 'pry';binding.pry
      p = priority :size => tx_size, :unspents => (unspents.map do |output|
        {:value => output.value, :age => output.confirmations}
      end)
      high_priority = p > PRIORITY_THRESHOLD

      if small && big_outputs && high_priority
        0
      else
        fee_for_bytes(tx_size, network: network)
      end

    end

    def fee_for_bytes(bytes, network:)
      # https://en.bitcoin.it/wiki/Transaction_fees
      # > the reference implementation will round up the transaction size to the
      # > next thousand bytes and add a fee of 0.1 mBTC (0.0001 BTC) per thousand bytes
      size = (bytes / 1000) + 1
      CoinOp.syncbit(network) { Bitcoin.network[:min_tx_fee] * size }
    end

    # From http://bitcoinfees.com.  This estimation is only valid for
    # transactions with all inputs using the common "public key hash" method
    # for authorization.
    def estimate_tx_size(num_inputs, num_outputs)
      # From http://bitcoinfees.com.
      (148 * num_inputs) + (34 * num_outputs) + 10
    end


    # https://en.bitcoin.it/wiki/Transaction_fees#Including_in_Blocks
    #
    # https://en.bitcoin.it/wiki/Transaction_fees#Technical_info
    # > Transactions need to have a priority above 57,600,000 to avoid the
    # > enforced limit.... This threshold is written in the code as
    # > COIN * 144 / 250, suggesting that the threshold represents a one day
    # > old, 1 btc coin (144 is the expected number of blocks per day) and a
    # > transaction size of 250 bytes.
    PRIORITY_THRESHOLD = 57_600_000

    def priority(params)
      tx_size, unspents = params.values_at :size, :unspents
      sum = unspents.inject(0) do |sum, output|
        age = output[:age] || 0
        sum += (output[:value] * age)
        sum
      end
      sum / tx_size
    end


  end
end
