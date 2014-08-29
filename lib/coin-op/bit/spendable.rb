module CoinOp::Bit
  module Spendable

    class InsufficientFunds < RuntimeError
    end

    def network
      raise "implement #network in your class"
    end

    def balance
      raise "implement #balance in your class"
    end

    def unspent
      raise "implement #unspent in your class"
    end

    def select_unspent
      raise "implement #select_unspent in your class"
    end

    def authorize
      raise "implement #authorize in your class"
    end

    def blockchain
      # FIXME: use the return value of #network as the arg, once this ticket
      # is resolved: # https://github.com/BitVault/bitvault/issues/251
      @blockchain ||= BitVaultAPI::Blockchain::Blockr.new(:test)
    end

    def lock(outputs)
      # no op
      # Mixing classes may wish to lock down these selected outputs
      # so that concurrent payments or transfers cannot use them.
      #
      # When do we release unspents (if a user abandons a transaction)?
    end

    def unlock(outputs)
    end

    def create_transaction(outputs, change_address)

      transaction = CoinOp::Bit::Transaction.build do |t|
        outputs.each do |output|
          t.add_output(output)
        end
      end

      if self.balance < transaction.output_value
        raise InsufficientFunds
      end

      unspent = self.select_unspent(transaction.output_value)

      unspent.each do |output|
        transaction.add_input :output => output
      end

      input_amount = unspent.inject(0) {|sum, output| sum += output.value }
      fee = transaction.suggested_fee

      # FIXME: there's likely another unspent output we can add, but the present
      # implementation of all this can't easily help us.  Possibly stop
      # using select_unspent(value) and start using a while loop that shifts
      # outputs off the array.  Then we can start the process over.
      if input_amount < (transaction.output_value + transaction.suggested_fee)
        raise InsufficientFunds
      end

      change = input_amount - (transaction.output_value + fee)

      transaction.add_output(
        :value => change,
        :script => {
          :address => change_address
        },
        :address => change_address,
      )

      self.authorize(transaction)
      transaction
    end

  end
end
