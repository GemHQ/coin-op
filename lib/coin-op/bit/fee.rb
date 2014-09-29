
module CoinOp::Bit
  module Fee

    module_function

    def estimate(unspents, payees)
      # https://en.bitcoin.it/wiki/Transaction_fees

      # dupe because we'll need to add a change output
      payees = payees.dup

      unspent_total = unspents.inject(0) {|sum, output| sum += output.value}
      payee_total = payees.inject(0) {|sum, payee| sum += payee[:value]}
      nominal_change = unspent_total - payee_total
      payees << {:value => nominal_change}

      tx_size = estimate_tx_size(unspents.size, payees.size)
      min = payees.min_by {|payee| payee[:value] }

      under_1k = tx_size < 1000
      big_outputs = min[:value] > 1_000_000

      p = priority :size => tx_size, :unspents => (unspents.map do |output|
        {:value => output.value, :age => output.confirmations}
      end)
      high_priority = p > PRIORITY_THRESHOLD

      if under_1k && big_outputs && high_priority
        0
      else
        fee_for_bytes(tx_size)
      end

    end

    def fee_for_bytes(bytes)
      # round up
      size = (bytes / 1000) + 1
      Bitcoin.network[:min_tx_fee] * size
    end

    # From http://bitcoinfees.com.  May not be applicable for
    # multisig inputs, as the redemption script is larger.
    # Thus TODO: determine sizes of the various script forms.
    def estimate_tx_size(num_inputs, num_outputs)
      (148 * num_inputs) + (34 * num_outputs) + 10
    end


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
