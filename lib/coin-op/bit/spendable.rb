module CoinOp::Bit

  # A mixin to provide simple transaction preparation. Not currently
  # used in any production code, so needs vetting.
  #
  # Requires the including class to define these methods:
  #
  # * network
  # * balance
  # * select_unspent
  # * authorize
  #
  module Spendable

    class InsufficientFunds < RuntimeError
    end

    # Return the network name (must be one of the keys from Bitcoin.network)
    def network
      raise "implement #network in your class"
    end

    def balance
      raise "implement #balance in your class"
    end

    # Takes a value in satoshis.
    # Returns an array of spendable Outputs
    def select_unspent(value)
      raise "implement #select_unspent in your class"
    end

    # Authorize the supplied transaction by setting its inputs' script_sigs
    # to whatever values are appropriate.
    def authorize(transaction)
      raise "implement #authorize in your class"
    end

    def create_transaction(outputs, change_address, fee_amount=nil)

      transaction = CoinOp::Bit::Transaction.from_data(
        :fee => fee_amount,
        :outputs => outputs
      )

      if self.balance < transaction.output_value
        raise InsufficientFunds
      end

      unspent = self.select_unspent(transaction.output_value)

      unspent.each do |output|
        transaction.add_input :output => output
      end

      input_amount = unspent.inject(0) {|sum, output| sum += output.value }

      # FIXME: there's likely another unspent output we can add, but the present
      # implementation of all this can't easily help us.  Possibly stop
      # using select_unspent(value) and start using a while loop that shifts
      # outputs off the array.  Then we can start the process over.
      unless transaction.funded?
        raise InsufficientFunds
      end

      transaction.add_change change_address

      self.authorize(transaction)
      transaction
    end

  end
end

