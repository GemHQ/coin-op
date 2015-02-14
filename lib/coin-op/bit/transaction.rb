module CoinOp::Bit

  class Transaction
    include CoinOp::Encodings
    CURRENT_VERSION = 1
    DUST_BAR = 546

    DeprecationError = Class.new(StandardError)
    def self.build
      raise DeprecationError
    end

    # Construct a Transaction from a data structure of nested Hashes
    # and Arrays.
    def self.from_data(outputs:, confirmations: 0, fee: 0, inputs: [],
                      version: CURRENT_VERSION, lock_time: 0)
      new(
        fee: fee,
        version: version,
        lock_time: lock_time,
        confirmations: confirmations,
        inputs: inputs,
        outputs: outputs
      )
    end

    # Construct a Transaction from raw bytes.
    def self.from_raw(raw_tx)
      self.from_native(::Bitcoin::Protocol::Tx.new(raw_tx))
    end

    # Construct a Transaction from a hex representation of the raw bytes.
    def self.from_hex(hex)
      self.from_bytes(CoinOp::Encodings.decode_hex(hex))
    end

    # Construct a transaction from an instance of ::Bitcoin::Protocol::Tx
    def self.from_native(tx)
      new(native: tx, inputs: tx.inputs, outputs: tx.outputs)
    end

    attr_reader :native, :inputs, :outputs, :confirmations, :fee_override,
                :version, :lock_time, :tx_hash

    def initialize(native: Bitcoin::Protocol::Tx.new, inputs:, outputs:,
                   fee: 0, confirmations: 0, version: CURRENT_VERSION,
                   lock_time: 0, tx_hash: nil)
      @inputs, @outputs = [], []
      @version, @lock_time, @tx_hash = version, lock_time, tx_hash
      @fee_override, @confirmations = fee, confirmations
      @native = native
      inputs.each { |i| add_input(i) }
      outputs.each { |i| add_output(i) }
      validate_syntax
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
    InvalidSignaturesError = Class.new(StandardError)
    def validate_script_sigs
      bad_inputs = inputs.each_with_index.map do |input, index|
        # TODO: confirm whether we need to mess with the block_timestamp arg
        index unless native.verify_input_signature(index, input.output.transaction.native)
      end.compact
      raise InvalidSignaturesError, bad_inputs.to_json unless bad_inputs.empty?
      true
    end

    def add_input(input)
      input = Input(input)
      @inputs << input
      @native.add_in(input.native)
      input
    end

    def add_output(output)
      output = Output(output)
      @outputs << output
      @native.add_out(output.native)
      output
    end

    Forbidden = Class.new(StandardError)
    def process_unspents(unspents)
      # TODO: We should discuss whether we want to use the largest outputs or
      # first do a lookahead and see if we can find the smallest output that
      # covers the remaining amount of the transaction.
      #
      # TODO: This has another problem, e.g.
      # tx.output_value = 1000
      # unspent_values = [601, 500, 500, 400, 101]
      # We could fund with 500 and 500, but since 400 gets added initially,
      # there's no combination of the other outputs that won't generate dust.
      # The transaction will still get funded due to the dusty_unspents loop,
      # But it's inefficient/wasteful.

      dusty_unspents = []
      valid_combs = unspents.combination.to_a.select { |comb| comb.reduce(:+) >= output_value }
      fee_sorted = valid_combs.min_by { |comb| Fee.estimate(comb, outputs) }
      no_dusts = fee_sorted.select do |comb|
        comb.reduce(:+) == 0 || comb.reduce(:+) > DUST_BAR
      end

      unspents.each do |unspent|
        # 546 satoshis is the dust bar, only use that output if it's the only
        # output that can fund the transaction.
        # the change IF you were to add the unspent
        change = (input_value + unspent.value) - output_value
        # change is <= 0 when we have more left over
        if change > DUST_BAR || change <= 0
          add_input(output: unspent)
        else
          # Add the output back to a dust array in case it ends up being
          # the only output we can use.
          dusty_unspents << unspent
        end

        return inputs if funded?
      end

      # Didn't get funded.
      dusty_unspents.each do |unspent|
        add_input(output: unspent)
        return inputs if funded?
      end

      if input_value > output_value
        raise Forbidden, "Balance cannot cover transaction fee of #{fee_override} satoshis"
      else
        raise Forbidden,'Balance cannot cover outputs'
      end
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


    def Output(initial)
      index = outputs.size
      case initial
        when Output then initial.with_transaction_and_index(self, index)
        when Bitcoin::Protocol::TxOut
          Output.new(
              transaction: self,
              index: index,
              value: initial.value,
              script: { blob: initial.pk_script }
          )
        when Hash
          Output.new(
              initial.merge(
                  transaction: self,
                  index: index
              )
          )
        else
          raise TypeError, "Can't convert #{initial.inspect} to Output."
      end
    end

    def Input(initial)
      index = inputs.size
      case initial
        when Input then initial.with_transaction_and_index(self, index)
        when Bitcoin::Protocol::TxIn
          Input.new_without_output(
              index: index,
              prev_transaction_hash: initial.prev_out,
              prev_out_index: initial.prev_out_index,
              transaction: self
          )
        when Hash
          Input.new_with_output(
              initial.merge(
                  transaction: self,
                  index: index
              )
          )
        else
          raise TypeError, "Can't convert #{initial.inspect} to Input"
      end
    end
  end

end
