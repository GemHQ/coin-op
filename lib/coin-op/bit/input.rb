
module CoinOp::Bit

  class Input

    include CoinOp::Encodings

    attr_reader :output, :binary_sig_hash,
      :signatures, :sig_hash, :script_sig, :index

    attr_accessor :native

    def self.new_with_output(index:, transaction:, output:, script_sig_asm: nil)
      output = Output.new(output) unless output.is_a? Output
      native = Bitcoin::Protocol::TxIn.new

      # TODO: the reverse is cargo-culted from a function in bitcoin-ruby
      # that doesn't document the reason.  Find the explanation in the bitcoin
      # wiki or in the reference client source and document here.
      native.prev_out = CoinOp::Encodings.decode_hex(output.transaction_hash).reverse
      native.prev_out_index = output.index

      new(index: index, native: native, transaction: transaction,
          output: output, script_sig_asm: script_sig_asm)
    end

    def self.new_without_output(prev_transaction_hash:, prev_out_index:, index:)
      native = Bitcoin::Protocol::TxIn.new
      native.prev_out = CoinOp::Encodings.decode_hex(prev_transaction_hash).reverse
      native.prev_out_index = prev_out_index
      new(index: index, native: native)
    end

    def initialize(index:, native:, transaction: nil, output: nil, script_sig_asm: nil)
      @native, @index, @transaction, @output = native, index, transaction, output
      @signatures = []
      if script_sig_asm
        @script_sig = Bitcoin::Script.binary_from_string(script_sig_asm)
      end
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
end


