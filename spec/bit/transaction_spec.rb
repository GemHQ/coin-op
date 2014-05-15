require 'spec_helper'

include CoinOp::Bit
include CoinOp::Encodings

describe Transaction do

  let (:transaction_hash) {
    {
      version: 1,
      lock_time: 0,
      hash: "9fKuDQ57nnRSfu8m6ng2WDAjnS8LW3RdU2tZLUNzGBq9",
      inputs: [
        {
          output: {
            transaction_hash: "4ttdma4CEbDxgzGujsi74mJComa3gNtJaCZpERHL1GfV",
            index: 0,
            value: 2500000000,
            script: {
              type: "pubkey_hash",
              string: "OP_DUP OP_HASH160 5d4c7b8e70e32f6d21f17f8d3e7e88f8f545c8d6 OP_EQUALVERIFY OP_CHECKSIG"
            },
            address: nil,
            metadata: {
            },
            confirmations: nil
          },
          signatures: [

          ],
          sig_hash: "Ew4njZyXK5NnGysh1s1N1LpCi1SAc2cEdSPx8QxYZRTY",
          script_sig: ""
        },
        {
          output: {
            transaction_hash: "4ttdma4CEbDxgzGujsi74mJComa3gNtJaCZpERHL1GfV",
            index: 1,
            value: 1250000000,
            script: {
              type: "pubkey_hash",
              string: "OP_DUP OP_HASH160 01e1910b0bfb006a3370c6ff46fa5e40f944e994 OP_EQUALVERIFY OP_CHECKSIG"
            },
            address: nil,
            metadata: {
            },
            confirmations: nil
          },
          signatures: [

          ],
          sig_hash: "J1qWP65h512dzasEic432Sa2t8BSZ5izAVdCyB1isLbx",
          script_sig: ""
        }
      ],
      outputs: [
        {
          transaction_hash: "9fKuDQ57nnRSfu8m6ng2WDAjnS8LW3RdU2tZLUNzGBq9",
          index: 0,
          value: 3750000000,
          script: {
            type: "script_hash",
            string: "OP_HASH160 c3e63215662f1d5bf301da5384afc6d7c6a3bc73 OP_EQUAL"
          },
          address: nil,
          metadata: {
            wallet_path: "/m/1/0/1"
          },
          confirmations: nil
        }
      ]
    }
  }

  let(:transaction_from_hash) { Transaction.data(transaction_hash) }

  describe '.native' do
    context 'with a valid native transaction' do
      it 'populates the correct inputs' do

      end

      it 'populates the correct outputs' do

      end
    end
  end

  describe '.data' do
    context 'with a valid hash representation of a transaction' do
      it 'populates the correct inputs' do
        expect(transaction_from_hash.inputs.count).to eql(2)
      end

      it 'populates the correct outputs' do
        expect(transaction_from_hash.outputs.count).to eql(1)
      end

      it 'creates a native transaction with the correct inputs and outputs' do
        expect(transaction_from_hash.native.inputs.count).to eql(2)
        expect(transaction_from_hash.native.outputs.count).to eql(1)
      end
    end
  end

  describe '#add_input' do
    let(:hash_input) {
      {
        transaction_hash: "7KxGcWup3dvGbms5asKi3M6s2HL998oroR9qWq4BgFsY",
        index: 0,
        script: "OP_DUP OP_HASH160 9a80c2e7792a380423f2f5a918fd139b07556fea OP_EQUALVERIFY OP_CHECKSIG"
      }  
    }

    it 'adds a new input to an existing transaction' do
      expect {
        transaction_from_hash.add_input(hash_input)
      }.to change {transaction_from_hash.inputs.count}.by(1)
    end
  end

  describe '#add_output' do
    let(:address) {
      key = ::Bitcoin::Key.new
      key.generate
      key.addr
    }

    let(:hash_output) {
      {
        value: 5_000,
        script: {
          address: address
        }
      }
    }

    it 'addes a new output to an existing transaction' do
      expect {
        transaction_from_hash.add_output(hash_output)
      }.to change {transaction_from_hash.outputs.count}.by(1)
    end
  end

  describe '#update_native' do

  end

  describe '#validate_syntax' do

  end

end