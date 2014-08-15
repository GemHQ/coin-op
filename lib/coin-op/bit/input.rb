
module CoinOp::Bit

  class SparseInput
    include CoinOp::Encodings

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


  class Input
    include CoinOp::Encodings

    attr_reader :native, :output, :binary_sig_hash,
      :signatures, :sig_hash, :script_sig, :index

    def initialize(options={})
      @transaction, @index, @output =
        options.values_at :transaction, :index, :output

      script_sig_asm = options[:script_sig_asm]

      unless @output.is_a? Output
        @output = Output.new(@output)
      end

      @native = Bitcoin::Protocol::TxIn.new

      @native.prev_out = decode_hex(@output.transaction_hash).reverse
      @native.prev_out_index = @output.index

      if script_sig_asm
        self.script_sig = Bitcoin::Script.binary_from_string(script_sig_asm)
      end
      @signatures = []
    end

    def binary_sig_hash=(blob)
      @binary_sig_hash = blob
      @sig_hash = hex(blob)
    end

    def script_sig=(blob)
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


