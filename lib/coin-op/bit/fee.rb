
module CoinOp::Bit

  module Fee

    # From http://bitcoinfees.com
    AVG_P2PKH_BYTES = 148
    AVG_OUTPUT_SIZE = 34

    # From rough tests of Gem p2sh txs on 2015-09-08
    AVG_P2SH_BYTES = 300

    module_function

    # Given an array of unspent Outputs and an array of Outputs for a
    # Transaction, estimate the fee required for the transaction to be
    # included in a block.
    #
    # Optionally takes an Integer tx_size specifying the transaction size in bytes
    #   This is useful if you have the scriptSigs for the unspents, because
    #   you can get a more accurate size than the estimate which is generated
    #   here by default
    #
    # Optionally takes an Integer fee_per_kb specifying the chosen cost per 1000
    #   bytes to use
    #
    # Returns the estimated fee in satoshis.
    def estimate(unspents, payees, network:, tx_size: nil, fee_per_kb: nil)
      # https://en.bitcoin.it/wiki/Transaction_fees

      # dupe because we'll need to add a change output
      payees = payees.dup

      unspent_total = unspents.inject(0) { |sum, output| sum += output.value }
      payee_total = payees.inject(0) { |sum, payee| sum += payee.value }

      nominal_change = unspent_total - payee_total
      payees << Output.new(value: nominal_change, network: network) if nominal_change > 0

      tx_size ||= estimate_tx_size(unspents, payees)

      # conditions for 0-fee transactions
      small = tx_size < 1000

      min_payee = payees.min_by { |payee| payee.value }
      big_outputs = min_payee.value > 1_000_000
      high_priority = priority(
        size: tx_size,
        unspents: unspents.map { |output| { value: output.value, age: output.confirmations } }
      ) > PRIORITY_THRESHOLD

      # 0-fee requirements met
      return 0 if small && big_outputs && high_priority

      # Otherwise, calculate the fee by size
      fee_for_bytes(tx_size, network: network, fee_per_kb: fee_per_kb)
    end

    def fee_for_bytes(bytes, network:, fee_per_kb: nil)
      # https://en.bitcoin.it/wiki/Transaction_fees
      # > the reference implementation will round up the transaction size to the
      # > next thousand bytes and add a fee of 0.1 mBTC (0.0001 BTC) per thousand bytes
      size = (bytes / 1000) + 1
      return size * fee_per_kb if fee_per_kb
      CoinOp.syncbit(network) { Bitcoin.network[:min_tx_fee] * size }
    end

    def estimate_tx_size(inputs, outputs)
      # tx overhead
      10 +
        # outputs don't vary much in size
        (AVG_OUTPUT_SIZE * outputs.size) +
        # p2sh outputs are usually larger than p2pkh outputs, which don't vary much
        inputs.inject(0) { |sum, input|
          sum += input.script.type == :script_hash ? AVG_P2SH_BYTES : AVG_P2PKH_BYTES }
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
