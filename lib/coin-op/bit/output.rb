
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
    def initialize(options, network: nil)
      network_name = options[:network] || network
      raise(ArgumentError, 'Network cannot be nil!') unless network_name
      if options[:transaction]
        @transaction = options[:transaction]
      elsif options[:transaction_hash]
        @transaction_hash = options[:transaction_hash]
      end

      # FIXME: be aware of string bitcoin values versus
      # integer satoshi values
      @index, @value, @address, confirmations =
        options.values_at :index, :value, :address, :confirmations

      @metadata = options[:metadata] || {}
      @metadata[:confirmations] ||= confirmations

      if options[:script]
        @script = Script.new(options[:script], network: network_name)
      elsif @address
        @script = Script.new(address: @address, network: network_name)
      end


      @native = Bitcoin::Protocol::TxOut.from_hash(
        "value" => @value.to_s,
        "scriptPubKey" => @script.to_s
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
        :transaction_hash => self.transaction_hash,
        :index => self.index,
        :value => self.value,
        :script => self.script,
        :address => self.address,
        :metadata => self.metadata
      }
    end

    def to_json(*a)
      self.to_hash.to_json(*a)
    end

  end

end

