
module CoinOp::Bit

  class Output
    include CoinOp::Encodings

    attr_accessor :metadata
    attr_reader :native, :transaction, :index, :value, :script

    # Takes a Hash with required keys:
    #
    # * either :transaction (an instance of Transaction)
    #   or :transaction_hash (the hex-encoded hash of a Bitcoin transaction)
    # * :index
    # * :script
    #
    # optional keys:
    #
    # * :value
    # * :metadata
    # 
    def initialize(options)
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
        @script = Script.new(options[:script])
      elsif @address
        @script = Script.new(:address => @address)
      end


      @native = Bitcoin::Protocol::TxOut.from_hash(
        "value" => @value.to_s,
        "scriptPubKey" => @script.to_s
      )
    end

    def address
      if @script
        @script.address
      end
    end

    def confirmations
      @metadata[:confirmations]
    end

    def set_transaction(transaction, index)
      @transaction_hash = nil
      @transaction, @index = transaction, index
    end

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
