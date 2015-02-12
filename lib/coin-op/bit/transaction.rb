module CoinOp::Bit

  class Transaction
    include CoinOp::Encodings

    DeprecationError = Class.new(StandardError)
    def self.build
      raise DeprecationError
    end

    # Preparation for interface change, where the from_foo methods become
    # preferred, and the terser method names are deprecated.
    #
    # This nasty little construct allows us to work on the class's metaclass.

    # Construct a Transaction from a data structure of nested Hashes
    # and Arrays.
    def self.data(outputs:, confirmations: nil, fee: nil, inputs: [], version: nil, lock_time: nil)
      new(fee: fee, version: version, lock_time: lock_time, confirmations: confirmations ) do |t|
        t.inputs = inputs
        t.outputs = outputs
      end
    end

    # Construct a Transaction from raw bytes.
    def self.raw(raw_tx)
      self.native(::Bitcoin::Protocol::Tx.new(raw_tx))
    end

    # Construct a Transaction from a hex representation of the raw bytes.
    def self.hex(hex)
      self.from_bytes(CoinOp::Encodings.decode_hex(hex))
    end

    # Construct a transaction from an instance of ::Bitcoin::Protocol::Tx
    def self.native(tx)
      new do |updater, transaction|
        updater.native = tx
        updater.inputs = tx.inputs.each_with_index.collect do |input, i|
          Input.new_without_output(
            index: i,
            prev_transaction_hash: input.prev_out,
            prev_out_index: input.prev_out_index
          )
        end
        updater.outputs = tx.outputs.each_with_index.collect do |output, i|
          Output.new(
            transaction: transaction,
            index: i,
            value: output.value,
            script: { blob: output.pk_script }
          )
        end
      end
    end

    class << self
      alias_method :from_data, :data
      alias_method :from_hex, :hex
      alias_method :from_bytes, :raw
      alias_method :from_native, :native
    end

    TransactionUpdater = Struct.new(:native, :inputs, :outputs)
    def update(&block)
      t = TransactionUpdater.new
      block.call(t, self)
      @native = t.native if t.native
      t.inputs.each { |i| add_input(i) }
      t.outputs.each { |i| add_output(i) }
      validate_syntax
      self
    end

    attr_reader :inputs, :outputs, :confirmations, :fee_override, :version, :lock_time
    attr_accessor :native # Some may disagree with this. Let's talk about it.

    def initialize(fee: nil, confirmations: nil, version: nil, lock_time: nil, &block)
      @version, @lock_time, @fee_override, @confirmations = version, lock_time, fee, confirmations
      @inputs, @outputs = [], []
      @native = Bitcoin::Protocol::Tx.new
      update(&block) if block
    end
    # Monkeypatch to remove a test that fails because bitcoin-ruby thinks a
    # transaction doesn't have valid syntax when it contains a coinbase input.
    Bitcoin::Validation::Tx::RULES[:syntax].delete(:inputs)

    # Validate that the transaction is plausibly signable.
    InvalidNativeSyntaxError = Class.new(StandardError)
    def validate_syntax
      validator = Bitcoin::Validation::Tx.new(@native, nil)
      unless validator.validate(rules: [:syntax])
        raise InvalidNativeSyntaxError, validator.error.to_json
      end
    end

    # Verify that the script_sigs for all inputs are valid.
    def validate_script_sigs
      bad_inputs = inputs.each_with_index.map do |input, index|
        # TODO: confirm whether we need to mess with the block_timestamp arg
        index unless native.verify_input_signature(index, input.output.transaction.native)
      end.compact
      { valid: bad_inputs.empty?, inputs: bad_inputs }
    end

    # Takes one of
    #
    # * an instance of Input
    # * an instance of Output
    # * a Hash describing an Output
    #
    def add_input(input)
      unless input.is_a? Input
        input = Input.new_with_output(input.merge(transaction: self, index: @inputs.size))
      end

      @inputs << input
      @native.add_in(input.native)
      input
    end

    # Takes either an Output or a Hash describing an output.
    def add_output(output)
      unless output.is_a? Output
        output = Output.new(output.merge(transaction: self, index: @outputs.size))
      end
      @outputs << output
      @native.add_out(output.native)
      output
    end

    # Returns the transaction hash as a string of bytes.
    def binary_hash
      @native.binary_hash
    end

    # Returns the transaction hash encoded as hex
    def hex_hash
      @native.hash
    end

    def version
      @native.ver
    end

    def lock_time
      @native.lock_time
    end

    # Returns the transaction payload encoded as hex.  This value can
    # be used by other bitcoin tools for publishing to the network.
    def to_hex
      payload = self.native.to_payload
      CoinOp::Encodings.hex(payload)
    end

    # Returns a custom data structure representing the full transaction.
    # Typically used only by #to_json.
    def to_hash
      {
        :version => self.version,
        :lock_time => self.lock_time,
        :hash => self.hex_hash,
        :fee => self.fee,
        :inputs => self.inputs,
        :outputs => self.outputs,
      }
    end

    def to_json(*a)
      self.to_hash.to_json(*a)
    end

    # Compute the digest for a given input.  In most cases, you need to provide
    # the script.  Which script to supply can be confusing, especially in the
    # case of P2SH outputs.
    # TODO: explain the above more clearly.
    def sig_hash(input, script=nil)
      # We only allow SIGHASH_ALL at this time
      # https://en.bitcoin.it/wiki/OP_CHECKSIG#Hashtype_SIGHASH_ALL_.28default.29

      prev_out = input.output
      script ||= prev_out.script

      @native.signature_hash_for_input(input.index, nil, script.to_blob)
    end

    # A convenience method for authorizing inputs in a generic manner.
    # Rather than iterating over the inputs manually, the user can
    # provide this method with an array of values and a block that
    # knows what to do with the values.
    #
    # For example, if you happen to have the script sigs precomputed
    # for some strange reason, you could do this:
    #
    #   tx.set_script_sigs sig_array do |input, sig|
    #     sig
    #   end
    #
    # More realistically, if you have an array of the keypairs corresponding
    # to the inputs:
    #
    #   tx.set_script_sigs keys do |input, key|
    #     sig_hash = tx.sig_hash(input)
    #     key.sign(sig_hash)
    #   end
    #
    # Each element of the array may be an array, which allows for easy handling
    # of multisig situations.
    def set_script_sigs(*input_args, &block)
      # No sense trying to authorize when the transaction isn't usable.
      validate_syntax

      # Array#zip here allows us to iterate over the inputs in lockstep with any
      # number of sets of values.
      self.inputs.zip(*input_args) do |input, *input_arg|
        input.script_sig = yield input, *input_arg
      end
    end

    def fee_override
      @fee_override || self.estimate_fee
    end

    # Estimate the fee in satoshis for this transaction.  Takes an optional
    # tx_size argument because it is impossible to determine programmatically
    # the size of the scripts used to create P2SH outputs.
    # Rough testing of the size of a 2of3 multisig p2sh input: 297
    def estimate_fee(tx_size=nil)
      unspents = inputs.map(&:output)
      Fee.estimate(unspents, outputs, tx_size)
    end

    # Returns the transaction fee computed from the actual input and output
    # values, as opposed to the requested override fee or the estimated fee.
    def fee
      input_value - output_value rescue nil
    end

    # Total value of all outputs.
    def output_value
      total = 0
      @outputs.each do |output|
        total += output.value
      end

      total
    end

    # Are the currently selected inputs sufficient to cover the current
    # outputs and the desired fee?
    def funded?
      input_value >= (output_value + fee_override)
    end

    # Total value of all inputs.
    def input_value
      inputs.inject(0) { |sum, input| sum += input.output.value }
    end

    # Takes a set of Bitcoin addresses and returns the net change in value
    # expressed in this transaction.
    def value_for(addresses)
      output_value_for(addresses) - input_value_for(addresses)
    end

    # Takes a set of Bitcoin addresses and returns the value expressed in
    # the inputs for this transaction.
    def input_value_for(addresses)
      own = inputs.select { |input| addresses.include?(input.output.address) }
      own.inject(0) { |sum, input| input.output.value }
    end

    # Takes a set of Bitcoin addresses and returns the value expressed in
    # the outputs for this transaction.
    def output_value_for(addresses)
      own = outputs.select { |output| addresses.include?(output.address) }
      own.inject(0) { |sum, output| output.value }
    end

    # Returns the value that should be assigned to a change output.
    def change_value
      input_value - (output_value + fee_override)
    end

    # Add an output to receive change for this transaction.
    # Takes a bitcoin address and optional metadata Hash.
    def add_change(address, metadata={})
      add_output(
        :value => change_value,
        :address => address,
        :metadata => {:memo => "change"}.merge(metadata)
      )
    end

  end

end
