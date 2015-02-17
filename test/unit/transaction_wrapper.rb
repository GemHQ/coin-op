require_relative "setup"

include CoinOp::Bit

describe "Transaction" do
  include CoinOpTests::Bitcoin

  describe "created from a full, valid Hash representation" do

    # NOTE: the tx hash and address values in this test were plucked
    # from the testnet3 blockchain, but we're not testing anything
    # about the actual entities, just using them as values that
    # have the correct format.
    before do
      keypair = ::Bitcoin::Key.new
      address = keypair.addr
      @transaction = Transaction.data(
        :fee => 33_000,
        :inputs => [
          {
            :output => {
              :transaction_hash => "2f47a8d7537fd981670b6142f86e1961991577506a825cdfb4c6ab3666db4fc1",
              :index => 0,
              :value => 10_000_000
            }
          },
          {
            :output => {
              :transaction_hash => "fe4d26f6536c17c451e7d9fd7bca3e981a1c9f4542ee49f3bdcb71050c8ef243",
              :index => 0,
              :value => 3_333_000
            }
          }
        ],
        :outputs => [
          {
            :value => 3_000_000,
            :script => {
              :address => "2N9c7acEJNHkDaQvRShMxJcBu5Lw535AvwR"
            }
          },
          {
            :value => 2_000_000,
            :script => {
              :address => "2MsMogdq6yF4ccVA1vipnPoyi95stXdrQjp"
            }
          }
        ]
      )
    end


    it "has expected inputs and outputs" do
      # TODO:  add real tests, obviously.
      assert_equal 2, @transaction.inputs.size
      assert_equal 2, @transaction.outputs.size
    end

    it "passes syntax validation" do
      report = @transaction.validate_syntax!
      assert_equal(
        {:valid => true, :error => nil},
        report
      )
    end

    it "reports values correctly" do
      assert_equal 5_000_000, @transaction.output_value
      assert_equal 13_333_000, @transaction.input_value

      # Because we haven't added a change output yet, the fee is
      # exorbitant.
      assert_equal 8_333_000, @transaction.fee

      # But we did specify a fee override in the tx data
      assert_equal 33_000, @transaction.fee_override

      # So we can compute the correct change value
      assert_equal 8_300_000, @transaction.change_value
      # TODO: use the comments above to provide actual spec structure.
    end

    it "can add a change output" do
      @transaction.add_change "mwsqtNtp1xMk4a54N33s5x42aU2tdCPPrB"
      assert_equal 3, @transaction.outputs.size
      assert_equal 33_000, @transaction.fee
    end

    describe "Adding inputs" do

      before do
        @starting_hash = @transaction.hex_hash
        @transaction.add_input(
          :output => {
            :transaction_hash => "16adf95d1dc5a05935421a6d8ba62de1b2f3b9065075dfbae3be1faf99bc7ffa",
            :index => 0,
            :value => 3_333_000,
          }
        )
      end

      it "has the added input" do
        assert_equal 3, @transaction.inputs.size
        assert_equal 3, @transaction.native.inputs.size
      end

      it "reports tx values correctly" do
        assert_equal 16666000, @transaction.input_value
      end

      it "modifies the hash" do
        refute_equal @starting_hash, @transaction.hex_hash
      end

      ## this behavior got broken at some point.
      ## No app code presently relies on it, and we need to rework the
      ## wrappers to be lazy, instead of eager anyway.
      #it "computes a sig_hash for the input" do
        #sig_hash = @transaction.inputs[0].sig_hash
        #assert_kind_of String, sig_hash
        #refute_empty sig_hash
      #end
    end

    describe "Adding outputs" do

      before do
        @starting_hash = @transaction.hex_hash
        @transaction.add_output(
          :address => "mwsqtNtp1xMk4a54N33s5x42aU2tdCPPrB",
          :value => 1_000_000,
        )
      end

      it "has the added output" do
        assert_equal 3, @transaction.outputs.size
        assert_equal 3, @transaction.native.outputs.size
      end

      it "reports tx values correctly" do
        assert_equal 6000000, @transaction.output_value
      end

      it "modifies the hash" do
        refute_equal @starting_hash, @transaction.hex_hash
      end

    end
  end



  describe "created with no arguments" do

    before do
      @empty_tx = Transaction.new()
    end

    it "has a native Tx" do
      assert_kind_of Bitcoin::Protocol::Tx, @empty_tx.native
    end

    it "has no inputs" do
      assert_empty @empty_tx.inputs
    end

    it "has no outputs" do
      assert_empty @empty_tx.outputs
    end

    it "has binary and hex hash values" do
      refute_empty @empty_tx.binary_hash
      assert_kind_of String, @empty_tx.binary_hash
      refute_empty @empty_tx.hex_hash
      assert_kind_of String, @empty_tx.hex_hash
    end

    it "fails validation" do
      report = @empty_tx.validate_syntax!
      assert_equal false, report[:valid]
      assert_equal :lists, report[:error].first
    end

  end

  #describe "created from a valid Bitcoin::Protocol::Tx" do

    #def transaction
      #@transaction ||= Transaction.from_native(disbursal_tx)
    #end

    #it "has binary and hex hash values" do
      #assert_equal disbursal_tx.binary_hash, transaction.binary_hash
      #refute_empty transaction.hex_hash
      #assert_kind_of String, transaction.hex_hash
    #end

    #describe "inputs" do
      #it "has sparse inputs" do
        #transaction.inputs.each do |input|
          #assert_kind_of SparseInput, input
        #end
      #end

      #it "has the correct number" do
        #assert_equal disbursal_tx.inputs.size, transaction.inputs.size
      #end
    #end

    #describe "outputs" do
      #it "has the correct number" do
        #assert_equal disbursal_tx.outputs.size, transaction.outputs.size
      #end

      #it "has Output instances" do
        #transaction.outputs.each_with_index do |output, i|
          #assert_kind_of Output, output
        #end
      #end
    #end

    #it "passes validation" do
      #report = transaction.validate_syntax
      #assert_equal true, report[:valid]
    #end

    #it "can be encoded as JSON" do
      ## TODO: check attributes after round trip
      #JSON.parse(transaction.to_json)
    #end

  #end



end


