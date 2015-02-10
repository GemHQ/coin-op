
module CoinOp::Bit

  class Input

    include CoinOp::Encodings

    attr_reader :native, :output, :binary_sig_hash,
      :signatures, :sig_hash, :script_sig, :index

    # Takes a Hash containing these fields:
    #
    # * :transaction - a Transaction instance
    # * :index - the index of the input within the transaction
    # * :output - a value representing this input's unspent output
    #
    # Optionally:
    #
    # * script_sig_asm - the string form of the scriptSig for this input
    #
    def initialize(transaction:, index:, output:, script_sig_asm: nil)
      @transaction, @index, @output = transaction, index, output

      unless @output.is_a? Output
        @output = Output.new(@output)
      end

      @native = Bitcoin::Protocol::TxIn.new

      # TODO: the reverse is cargo-culted from a function in bitcoin-ruby
      # that doesn't document the reason.  Find the explanation in the bitcoin
      # wiki or in the reference client source and document here.
      @native.prev_out = decode_hex(@output.transaction_hash).reverse
      @native.prev_out_index = @output.index

      if script_sig_asm
        self.script_sig = Bitcoin::Script.binary_from_string(script_sig_asm)
      end
      @signatures = []
    end

    # Set the sig_hash (the digest used in signing) for this input using a
    # string of bytes.
    def binary_sig_hash=(blob)
      # This is only a setter because of the initial choice to do things
      # eagerly.  Can become an attr_accessor when we move to lazy eval.
      @binary_sig_hash = blob
      @sig_hash = hex(blob)
    end

    # Set the scriptSig for this input using a string of bytes.
    def script_sig=(blob)
      # This is only a setter because of the initial choice to do things
      # eagerly.  Can become an attr_accessor when we move to lazy eval.
      script = Script.new(:blob => blob)
      @script_sig = script.to_s
      @native.script_sig = blob
    end


    def to_json(*a)
      {
        :output => self.output,
        :signatures => self.signatures.map {|b| hex(b) },
        :sig_hash => self.sig_hash || "",
        :script_sig => self.script_sig || ""
      }.to_json(*a)
    end

  end

  # Used in Transaction.from_native or other situations where we do
  # not have full information about the unspent output being used
  # for an input.
  class SparseInput
    include CoinOp::Encodings
    attr_reader :output

    def initialize(binary_hash, index)
      @output = {
        # the binary hash is the result of 
        # [tx.hash].pack("H*").reverse
        :transaction_hash => hex(binary_hash.reverse),
        :index => index,
      }
    end

    def to_json(*a)
      {
        :output => @output,
      }.to_json(*a)
    end

  end



end


