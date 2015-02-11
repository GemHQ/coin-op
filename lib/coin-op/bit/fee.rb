module CoinOp::Bit

  module Fee
    # https://en.bitcoin.it/wiki/Transaction_fees#Including_in_Blocks
    #
    # https://en.bitcoin.it/wiki/Transaction_fees#Technical_info
    # > Transactions need to have a priority above 57,600,000 to avoid the
    # > enforced limit.... This threshold is written in the code as
    # > COIN * 144 / 250, suggesting that the threshold represents a one day
    # > old, 1 btc coin (144 is the expected number of blocks per day) and a
    # > transaction size of 250 bytes.
    PRIORITY_THRESHOLD = 57_600_000
    TX_SIZE_THRESHOLD = 1000
    PAYEE_VALUE_THRESHOLD = 1_000_000

    module_function

    # Given an array of unspent Outputs and an array of Outputs for a
    # Transaction, estimate the fee required for the transaction to be
    # included in a block.  Optionally takes an Integer specifying the
    # transaction size in bytes, which is necessary when using unspents
    # that deviate from the customary single signature.
    #
    # Returns the estimated fee in satoshis.
    def estimate(unspents, payees, tx_size=nil)
      tx_size ||= estimate_tx_size(unspents.size, payees.size)
      output_amounts = payees.map(&:value)
      output_amounts << nominal_change(unspents, output_amounts)

      return 0 if small?(tx_size) && big_outputs?(output_amounts) && high_priority?(tx_size, unspents)
      fee_for_bytes(tx_size)
    end

    def nominal_change(unspents, output_amounts)
      # SHOULD THERE BE AN ASSERTION THAT unspent - payee > 0 ??
      unspent = unspents.map(&:value).reduce(:+)
      output_amount = output_amounts.reduce(:+)
      unspent - output_amount
    end

    def high_priority?(tx_size, unspents)
      priority(tx_size, unspents) > PRIORITY_THRESHOLD
    end

    def priority(tx_size, unspents)
      sum = unspents.lazy.map do |output|
        output.value * (output.confirmations || 0)
      end.reduce(:+)
      sum / tx_size
    end

    def small?(tx_size)
      tx_size < TX_SIZE_THRESHOLD
    end

    def big_outputs?(output_amounts)
      output_amounts.min > PAYEE_VALUE_THRESHOLD
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
  end
end