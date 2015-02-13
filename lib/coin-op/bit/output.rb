
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
    def initialize(value:, index:, transaction: nil, transaction_hash: nil,
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
      @script.address if @script
    end

    def confirmations
      @metadata[:confirmations]
    end

    # Returns the transaction hash for this output.
    def transaction_hash
      @transaction ? @transaction.hex_hash : @transaction_hash
    end

    def with_transaction_and_index(transaction, index)
      @transaction = transaction
      @index = index
      self
    end

    def to_hash
      {
        transaction_hash: transaction_hash,
        index: index,
        value: value,
        script: script,
        address: address,
        metadata: metadata
      }
    end

    def to_json(*a)
      to_hash.to_json(*a)
    end

  end

end
