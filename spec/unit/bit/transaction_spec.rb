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
end