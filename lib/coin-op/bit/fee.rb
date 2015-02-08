
module CoinOp::Bit

  module Fee

    # includes all methods as methods on Fee instance. ~ static methods
    module_function

    # Given an array of unspent Outputs and an array of Outputs for a
    # Transaction, estimate the fee required for the transaction to be
    # included in a block.  Optionally takes an Integer specifying the
    # transaction size in bytes, which is necessary when using unspents
    # that deviate from the customary single signature.
    #
    # Returns the estimated fee in satoshis.
    # unspents: an array of unspent outputs
    # must respond to value, confirmations.
    # payees: an array of hashes, who we expect to pay
    # I assume keys = [:value, :address]
    def estimate(unspents, payees)
      # https://en.bitcoin.it/wiki/Transaction_fees

      # so we don't modify original payees
      payees = payees.dup
      # sum the values of the unspent outputs
      unspent_total = unspents.inject(0) {|sum, output| sum += output.value}
      # sum the values going to each desired payee
      payee_total = payees.inject(0) {|sum, payee| sum += payee[:value]}
      # the change, i'm guessing a check for negatives was done elsewhere
      nominal_change = unspent_total - payee_total
      # add the change transaction, no address though?
      payees << {:value => nominal_change}

      # set in stone formula for tx size
      tx_size = estimate_tx_size(unspents.size, payees.size)
      # get the minumum desired payment
      min = payees.min_by {|payee| payee[:value] }

      # is tx size under 1000kb?
      small = tx_size < 1000
      # is the min desired payee "big"?
      big_outputs = min[:value] > 1_000_000

      p = priority :size => tx_size, :unspents => (unspents.map do |output|
        {:value => output.value, :age => output.confirmations}
      end)
      high_priority = p > PRIORITY_THRESHOLD

      # if the stars align, no fee
      if small && big_outputs && high_priority
        0
      else
        fee_for_bytes(tx_size)
      end

    end

    def fee_for_bytes(bytes)
      # https://en.bitcoin.it/wiki/Transaction_fees
      # > the reference implementation will round up the transaction size to the
      # > next thousand bytes and add a fee of 0.1 mBTC (0.0001 BTC) per thousand bytes
      size = (bytes / 1000) + 1
      Bitcoin.network[:min_tx_fee] * size
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

    # takes size in kb, num unspents
    # priority defined by sum of unspent's values * their num confirmations / size of tx in kb
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
