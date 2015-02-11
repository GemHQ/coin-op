require 'spec_helper'

describe CoinOp::Bit::Transaction do
  describe '.native' do
    let(:inputs) do
      [
        double('input', prev_out: '01', prev_out_index: '01'),
        double('input', prev_out: '02', prev_out_index: '02')
      ]
    end
    let(:outputs) do
      [
        double('output', value: '5', pk_script: '5'),
        double('output', value: '6', pk_script: '6')
      ]
    end
    it 'should set outputs' do
      expect_any_instance_of(CoinOp::Bit::Transaction).to receive(:validate_syntax).and_return({ valid: true })
      tx = double('tx', outputs: outputs, inputs: [])
      transaction = CoinOp::Bit::Transaction.native(tx)
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
      expect_any_instance_of(CoinOp::Bit::Transaction).to receive(:validate_syntax).and_return({ valid: true })
      tx = double('tx', outputs: [], inputs: inputs)
      transaction = CoinOp::Bit::Transaction.native(tx)
      expect(transaction.inputs[0].output[:transaction_hash]).to eq CoinOp::Encodings.hex('10')
      expect(transaction.inputs[0].output[:index]).to eq '01'
      expect(transaction.inputs[1].output[:transaction_hash]).to eq CoinOp::Encodings.hex('20')
      expect(transaction.inputs[1].output[:index]).to eq '02'
    end

    it 'should set native' do
      expect_any_instance_of(CoinOp::Bit::Transaction).to receive(:validate_syntax).and_return({ valid: true })
      tx = double('tx', outputs: outputs, inputs: inputs)
      transaction = CoinOp::Bit::Transaction.native(tx)
      expect(transaction.native).to eq tx
    end

    context 'invalid syntax' do
      it 'should raise error' do
        expect_any_instance_of(CoinOp::Bit::Transaction).to receive(:validate_syntax).and_return({ valid: false })
        tx = double('tx', outputs: outputs, inputs: inputs)
        expect { CoinOp::Bit::Transaction.native(tx) }.to raise_error
      end
    end
  end

  describe '.data' do
    it 'should set fee, confirmations' do
      tx = CoinOp::Bit::Transaction.data(fee: 2, confirmations: 1, outputs: [])
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
      tx = CoinOp::Bit::Transaction.data(inputs: inputs, outputs: [])
      expect(tx.inputs[0].output.index).to eq 42
      expect(tx.inputs[1].output.index).to eq 43
      expect(tx.inputs.size).to eq 2
    end

    it 'should set outputs' do
      outputs = [
          { index: 108, value: 5, transaction_hash: 'hash1', address: '37oUcVHj6yC1rk9YyQrJioW36U24UxP6YR' },
          { index: 109, value: 6, transaction_hash: 'hash2', address: '37oUcVHj6yC1rk9YyQrJioW36U24UxP6YR' }
      ]
      tx = CoinOp::Bit::Transaction.data(outputs: outputs)
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
         tx = CoinOp::Bit::Transaction.data(outputs: [])
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
        tx = CoinOp::Bit::Transaction.data(outputs: [])
        expect(native).to receive(:verify_input_signature).and_return(true, true, true)
        tx.instance_variable_set(:@native, native)
        expect(tx).to receive(:inputs).and_return inputs
        expect(tx.validate_script_sigs).to eq({ valid: true, inputs: [] })
      end
    end
  end
end