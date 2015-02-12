
module CoinOp::Bit

  class Output
    include CoinOp::Encodings

    attr_accessor :metadata
    attr_reader :native, :transaction, :index, :value, :script

    # Takes a Hash with required keys:
    #
    # * either  :transaction (instance of Transaction)
    #   or      :transaction_hash (hex-encoded hash of a Bitcoin transaction)
    # * :index
    # * :value
    #
    # optional keys:
    #
    # * either  :script (a value usable in Script.new)
    #   or      :address (a valid Bitcoin address)
    # * :metadata (a Hash with arbitrary contents)
    #
    def initialize(value:, index: nil, transaction: nil, transaction_hash: nil,
                    metadata: {}, script: nil, address: nil, confirmations: 0)
      unless transaction || transaction_hash
        raise ArgumentError, 'Must provide either transaction or transaction hash!'
      end
      unless script || address
        raise ArgumentError, 'Must provide either script or address!'
      end
      @transaction = transaction
      @transaction_hash = transaction_hash
      @index, @value, @address, @metadata = index, value, address, metadata
      @metadata[:confirmations] = confirmations

      @script = script ? Script.new(script) : Script.new(address: address)

      @native = Bitcoin::Protocol::TxOut.from_hash(
        'value' => @value.to_s,
        'scriptPubKey' => @script.to_s
      )
    end

    # The bitcoin address generated from the associated Script.
    def address
      if @script
        @script.address
      end
    end

    def confirmations
      @metadata[:confirmations]
    end

    # DEPRECATED
    def set_transaction(transaction, index)
      @transaction_hash = nil
      @transaction, @index = transaction, index
    end

    # Returns the transaction hash for this output.
    def transaction_hash
      if @transaction
        @transaction.hex_hash
      elsif @transaction_hash
        @transaction_hash
      else
        ""
      end
    end


    def to_hash
      {
        transaction_hash: self.transaction_hash,
        index: self.index,
        value: self.value,
        script: self.script,
        address: self.address,
        metadata: self.metadata
      }
    end

    def to_json(*a)
      self.to_hash.to_json(*a)
    end

  end

end
