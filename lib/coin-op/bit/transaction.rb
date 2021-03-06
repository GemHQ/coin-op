module CoinOp::Bit

  class Transaction
    include CoinOp::Encodings

    # Deprecated.  Easier to use Transaction.from_data
    def self.build(&block)
      transaction = self.new
      yield transaction
      transaction
    end

    # Construct a Transaction from a data structure of nested Hashes and Arrays.
    def self.data(data, network:)
      version, lock_time, fee, inputs, outputs, confirmations =
        data.values_at :version, :lock_time, :fee, :inputs, :outputs, :confirmations

      transaction = self.new(
        fee: fee,
        version: version,
        lock_time: lock_time,
        confirmations: confirmations,
        network: network
      )

      outputs.each do |output_hash|
        transaction.add_output(output_hash, network: network)
      end

      #FIXME: we're not handling sig_scripts for already signed inputs.

      inputs.each do |input_hash|
        transaction.add_input(input_hash, network: network)

        ## FIXME: verify that the supplied and computed sig_hashes match
        #puts :sig_hashes_match => (data[:sig_hash] == input.sig_hash)
      end if inputs

      transaction
    end

    # Construct a Transaction from raw bytes.
    def self.raw(raw_tx)
      self.native ::Bitcoin::Protocol::Tx.new(raw_tx)
    end

    # Construct a Transaction from a hex representation of the raw bytes.
    def self.hex(hex)
      self.from_bytes CoinOp::Encodings.decode_hex(hex)
    end

    # Construct a transaction from an instance of ::Bitcoin::Protocol::Tx
    def self.native(tx)
      transaction = self.new()
      # TODO: reconsider use of instance_eval
      transaction.instance_eval do
        @native = tx
        tx.inputs.each_with_index do |input, i|
          # We use SparseInput because it does not require the retrieval
          # of the previous output.  Its functionality should probably be
          # folded into the Input class.
          @inputs << SparseInput.new(input.prev_out, input.prev_out_index)
        end
        tx.outputs.each_with_index do |output, i|
          @outputs << Output.new(
            :transaction => transaction,
            :index => i,
            :value => output.value,
            :script => {:blob => output.pk_script}
          )
        end
      end

      report = transaction.validate_syntax
      unless report[:valid] == true
        raise "Invalid syntax:  #{report[:error].to_json}"
      end
      transaction
    end

    # Preparation for interface change, where the from_foo methods become
    # preferred, and the terser method names are deprecated.
    #
    # This nasty little construct allows us to work on the class's metaclass.
    class << self
      alias_method :from_data, :data
      alias_method :from_hex, :hex
      alias_method :from_bytes, :raw
      alias_method :from_native, :native
    end


    attr_reader :native, :inputs, :outputs, :confirmations, :lock_time, :version

    # A new Transaction contains no inputs or outputs; these can be added with
    # #add_input and #add_output.
    def initialize(options={})
      @native = Bitcoin::Protocol::Tx.new
      @inputs = []
      @outputs = []
      @lock_time = @native.lock_time = (options[:lock_time] || 0)
      @version = @native.ver = (options[:version] || 1)
      @network = options[:network]
      @fee_override = options[:fee]
      @confirmations = options[:confirmations]
    end

    # Update the "native" bitcoin-ruby instances for the transaction and
    # all its inputs.  Will be removed when we rework the wrapper classes
    # to be lazy, rather than eager.
    def update_native
      yield @native if block_given?
      @native = Bitcoin::Protocol::Tx.new(@native.to_payload)
      @inputs.each_with_index do |input, i|
        native = @native.inputs[i]
        # Using instance_eval here because I really don't want to expose
        # Input#native=.  As we consume more and more of the native
        # functionality, we can dispense with such ugliness.
        input.instance_eval do
          @native = native
        end
        # TODO: is this re-nativization necessary for outputs, too?
      end
    end

    # Monkeypatch to remove a test that fails because bitcoin-ruby thinks a
    # transaction doesn't have valid syntax when it contains a coinbase input.
    Bitcoin::Validation::Tx::RULES[:syntax].delete(:inputs)

    # Validate that the transaction is plausibly signable.
    def validate_syntax
      update_native
      validator = Bitcoin::Validation::Tx.new(@native, nil)
      valid = validator.validate :rules => [:syntax]
      {:valid => valid, :error => validator.error}
    end

    # Verify that the script_sigs for all inputs are valid.
    def validate_script_sigs
      bad_inputs = []
      valid = true
      @inputs.each_with_index do |input, index|
        # TODO: confirm whether we need to mess with the block_timestamp arg
        unless self.native.verify_input_signature(index, input.output.transaction.native)
          valid = false
          bad_inputs << index
        end

      end
      {:valid => valid, :inputs => bad_inputs}
    end

    # Takes one of
    #
    # * an instance of Input
    # * an instance of Output
    # * a Hash describing an Output
    #
    def add_input(input, network: @network)
      # TODO: allow specifying prev_tx and index with a Hash.
      # Possibly stop using SparseInput.

      input = Input.new(input.merge(transaction: self,
                                    index: @inputs.size,
                                    network: network)
                       ) unless input.is_a?(Input)

      @inputs << input
      self.update_native do |native|
        native.add_in input.native
      end
      input
    end

    # Takes either an Output or a Hash describing an output.
    def add_output(output, network: @network)
      if output.is_a?(Output)
        output.set_transaction(self, @outputs.size)
      else
        output = Output.new(output.merge(transaction: self,
                                         index: @outputs.size),
                            network: network)
      end

      @outputs << output
      self.update_native do |native|
        native.add_out(output.native)
      end
    end

    # Returns the transaction hash as a string of bytes.
    def binary_hash
      update_native
      @native.binary_hash
    end

    # Returns the transaction hash encoded as hex
    def hex_hash
      update_native
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
        confirmations: self.confirmations.nil? ? 0 : self.confirmations,
        version: self.version,
        lock_time: self.lock_time,
        hash: self.hex_hash,
        fee: self.fee,
        inputs: self.inputs,
        outputs: self.outputs
      }
    end

    def to_json(*a)
      self.to_hash.to_json(*a)
    end

    # Compute the digest for a given input.  This is the value that is actually
    # signed in a transaction.
    # e.g. I want to spend UTXO0 - I provide the UTXO0 as an input.
    #      I provide as a script the script to which UTXO0 was paid.
    # If UTX0 was paid to a P2SH address, the script here needs to be the correct
    # m-of-n structure, which may well not be part of the input.output object
    # - This works here because we default to 2-of-3 and have consistent ordering
    # When we support multiple m-of-n's, this may become a prollem.
    def sig_hash(input, script=nil)
      # We only allow SIGHASH_ALL at this time
      # https://en.bitcoin.it/wiki/OP_CHECKSIG#Hashtype_SIGHASH_ALL_.28default.29

      prev_out = input.output
      script ||= prev_out.script

      @native.signature_hash_for_input(input.index, script.to_blob)
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
      report = validate_syntax
      unless report[:valid] == true
        raise "Invalid syntax:  #{report[:errors].to_json}"
      end

      # Array#zip here allows us to iterate over the inputs in lockstep with any
      # number of sets of values.
      self.inputs.zip(*input_args) do |input, *input_arg|
        input.script_sig = yield input, *input_arg
      end
    end

    def fee_override
      @fee_override || self.estimate_fee(network: @network)
    end

    # Estimate the fee in satoshis for this transaction.  Takes an optional
    # tx_size argument because it is impossible to determine programmatically
    # the size of the scripts used to create P2SH outputs.
    # Rough testing of the size of a 2of3 multisig p2sh input: 297 +/- 40 bytes
    def estimate_fee(tx_size: nil, network: @network, fee_per_kb: nil)
      unspents = inputs.map(&:output)
      Fee.estimate(unspents, outputs,
                   network: network, tx_size: tx_size, fee_per_kb: fee_per_kb)
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
        value: change_value,
        address: address,
        metadata: {memo: "change"}.merge(metadata)
      )
    end

  end

end
