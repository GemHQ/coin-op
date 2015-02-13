require 'spec_helper'

describe CoinOp::Bit::Transaction do
  before do
    allow_any_instance_of(CoinOp::Bit::Transaction).to receive(:validate_syntax)
  end
  describe '.from_native' do
    let(:inputs) do
      [
          Bitcoin::Protocol::TxIn.new('01', '01'),
          Bitcoin::Protocol::TxIn.new('02', '02')
      ]
    end
    let(:outputs) do
      [
          Bitcoin::Protocol::TxOut.new('5', nil, '5'),
          Bitcoin::Protocol::TxOut.new('6', nil, '6')
      ]
    end
    it 'should set outputs' do
      tx = instance_spy('Bitcoin::Protocol::Tx', outputs: outputs, inputs: [])
      transaction = CoinOp::Bit::Transaction.from_native(tx)
      expect(transaction.outputs[0].transaction).to eq transaction
      expect(transaction.outputs[0].index).to eq 0
      expect(transaction.outputs[0].value).to eq '5'
      expect(transaction.outputs[0].script.to_blob).to eq '5'
      expect(transaction.outputs[1].transaction).to eq transaction
      expect(transaction.outputs[1].index).to eq 1
      expect(transaction.outputs[1].value).to eq '6'
      expect(transaction.outputs[1].script.to_blob).to eq '6'
    end

    it 'should set inputs' do
      tx = spy('tx', outputs: [], inputs: inputs)
      transaction = CoinOp::Bit::Transaction.from_native(tx)
      expect(transaction.inputs[0].native.prev_out_index).to eq '01'
      expect(transaction.inputs[1].native.prev_out_index).to eq '02'
    end

    it 'should set native' do
      tx = spy('tx', outputs: outputs, inputs: inputs)
      transaction = CoinOp::Bit::Transaction.from_native(tx)
      expect(transaction.native).to eq tx
    end

    context 'invalid syntax' do
      it 'should raise error' do
        expect_any_instance_of(CoinOp::Bit::Transaction).to receive(:validate_syntax).and_raise(CoinOp::Bit::Transaction::InvalidNativeSyntaxError)
        tx = spy('tx', outputs: outputs, inputs: inputs)
        expect { CoinOp::Bit::Transaction.from_native(tx) }.to raise_error(CoinOp::Bit::Transaction::InvalidNativeSyntaxError)
      end
    end
  end

  describe '.from_data' do
    it 'should set fee, confirmations' do
      tx = CoinOp::Bit::Transaction.from_data(fee: 2, confirmations: 1, outputs: [])
      expect(tx.fee_override).to eq 2
      expect(tx.confirmations).to eq 1
    end

    it 'should set inputs' do
      output1 = double('output', transaction_hash: 'hash1', index: 42, is_a?: true)
      output2 = double('output', transaction_hash: 'hash2', index: 43, is_a?: true)
      inputs = [
          { output: output1 },
          { output: output2 }
      ]
      tx = CoinOp::Bit::Transaction.from_data(inputs: inputs, outputs: [])
      expect(tx.inputs[0].output.index).to eq 42
      expect(tx.inputs[1].output.index).to eq 43
      expect(tx.inputs.size).to eq 2
    end

    it 'should set outputs' do
      outputs = [
          { index: 108, value: 5, transaction_hash: 'hash1', address: '37oUcVHj6yC1rk9YyQrJioW36U24UxP6YR' },
          { index: 109, value: 6, transaction_hash: 'hash2', address: '37oUcVHj6yC1rk9YyQrJioW36U24UxP6YR' }
      ]
      tx = CoinOp::Bit::Transaction.from_data(outputs: outputs)
      expect(tx.outputs[0].script).to eq CoinOp::Bit::Script.new(address: '37oUcVHj6yC1rk9YyQrJioW36U24UxP6YR')
      expect(tx.outputs[1].script).to eq CoinOp::Bit::Script.new(address: '37oUcVHj6yC1rk9YyQrJioW36U24UxP6YR')
      expect(tx.outputs.size).to eq 2
    end
  end

  describe '#validate_script_sigs' do
     context 'when one is invalid' do
       it 'should return valid false and array of invalids' do
         native = double('native')
         inputs = [spy('input')] * 3
         tx = CoinOp::Bit::Transaction.from_data(outputs: [])
         expect(native).to receive(:verify_input_signature).and_return(false, true, false)
         tx.instance_variable_set(:@native, native)
         expect(tx).to receive(:inputs).and_return inputs
         expect(tx.validate_script_sigs).to eq({ valid: false, inputs: [0, 2] })
       end
     end

    context 'when none are invalid' do
      it 'should return valid true and empty array' do
        native = double('native')
        inputs = [spy('input')] * 3
        tx = CoinOp::Bit::Transaction.from_data(outputs: [])
        expect(native).to receive(:verify_input_signature).and_return(true, true, true)
        tx.instance_variable_set(:@native, native)
        expect(tx).to receive(:inputs).and_return inputs
        expect(tx.validate_script_sigs).to eq({ valid: true, inputs: [] })
      end
    end
  end
end