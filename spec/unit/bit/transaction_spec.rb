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
       it 'should raise InvalidSignaturesError with bad ones' do
         native = double('native')
         inputs = [spy('input')] * 3
         tx = CoinOp::Bit::Transaction.from_data(outputs: [])
         expect(native).to receive(:verify_input_signature).and_return(false, true, false)
         tx.instance_variable_set(:@native, native)
         expect(tx).to receive(:inputs).and_return inputs
         expect { tx.validate_script_sigs }.to raise_error CoinOp::Bit::Transaction::InvalidSignaturesError, [0, 2].to_json
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
        expect(tx.validate_script_sigs).to eq true
      end
    end
  end

  describe '#Input' do
    let(:tx) { CoinOp::Bit::Transaction.from_data(outputs: []) }
    let(:address) { '1BYX25TtdZSwUCQqmwonLTEdj6ceamNg96' }
    before do
      allow_any_instance_of(CoinOp::Bit::Transaction).to receive(:validate_syntax)
    end

    context 'when input is hash' do
      it 'should produce correct input' do
        output = { index: 1, transaction_hash: 'aaa', address: address, value: 100 }
        expect(tx).to receive(:inputs).and_return double('inputs', size: 5)
        input = tx.Input({ output: output })
        expect(input.index).to eq 5
        expect(input.transaction).to eq tx
        expect(input.native.prev_out).to eq tx.decode_hex('aaa').reverse
        expect(input.native.prev_out_index).to eq 1
      end
    end

    context 'when input is Bitcoin::Protocol:TxIn' do
      it 'should produce correct input' do
        expect(tx).to receive(:inputs).and_return double('inputs', size: 7)
        initial = Bitcoin::Protocol::TxIn.new('aaa', 5)
        input = tx.Input(initial)
        expect(input.index).to eq 7
        expect(input.transaction).to eq tx
        expect(input.native.prev_out_index).to eq 5
        expect(input.native.prev_out).to eq tx.decode_hex('aaa').reverse
      end
    end

    context 'when input is Input' do
      it 'should update indices' do
        expect(tx).to receive(:inputs).and_return double('inputs', size: 11)
        initial = CoinOp::Bit::Input.new(
            index: 10,
            native: 'native',
            transaction: 'something'
        )
        input = tx.Input(initial)
        expect(input.index).to eq 11
        expect(input.transaction).to eq tx
      end
    end

    context 'when input is not recognized' do
      it 'should throw type error' do
        expect { tx.Input([]) }.to raise_error TypeError
      end
    end
  end

  describe '#Output' do
    let(:tx) { CoinOp::Bit::Transaction.from_data(outputs: []) }
    let(:address) { '1BYX25TtdZSwUCQqmwonLTEdj6ceamNg96' }
    before do
      allow_any_instance_of(CoinOp::Bit::Transaction).to receive(:validate_syntax)
    end
    context 'when output is a hash' do
      it 'should return correct output' do
        initial = { value: 10, index: 104, transaction: 'aha', address: address }
        expect(tx).to receive(:outputs).and_return double('outputs', size: 100)
        output = tx.Output(initial)
        expect(output.index).to eq 100
        expect(output.transaction).to eq tx
        expect(output.value).to eq 10
        expect(output.script).to eq CoinOp::Bit::Script.new(address: address)
      end
    end
    context 'when output is an Output' do
      it 'should return correct output' do
        initial = CoinOp::Bit::Output.new(value: 109, index: 110, transaction: 'wut', address: address)
        expect(tx).to receive(:outputs).and_return double('outputs', size: 56)
        output = tx.Output(initial)
        expect(output.index).to eq 56
        expect(output.transaction).to eq tx
        expect(output.value).to eq 109
      end
    end
    context 'when output is a Bitcoin::Protocol::TxOut' do
      it 'should return correct output' do
        initial = Bitcoin::Protocol::TxOut.new(100, nil, 'something')
        expect(tx).to receive(:outputs).and_return double('outputs', size: 89)
        output = tx.Output(initial)
        expect(output.index).to eq 89
        expect(output.transaction).to eq tx
        expect(output.value).to eq 100
      end
    end
    context 'when output is weird' do
      it 'should throw an error' do
        expect { tx.Output([]) }.to raise_error TypeError
      end
    end
  end

  describe '#process_unspents' do
    let!(:tx) { CoinOp::Bit::Transaction.from_data(outputs: []) }
    let!(:unspent100) { tx.Output(value: 100, address: '37oUcVHj6yC1rk9YyQrJioW36U24UxP6YR') }
    let!(:unspent200) { tx.Output(value: 200, address: '37oUcVHj6yC1rk9YyQrJioW36U24UxP6YR') }
    let!(:unspent300) { tx.Output(value: 300, address: '37oUcVHj6yC1rk9YyQrJioW36U24UxP6YR') }
    let!(:unspent400) { tx.Output(value: 400, address: '37oUcVHj6yC1rk9YyQrJioW36U24UxP6YR') }
    let!(:unspent500) { tx.Output(value: 500, address: '37oUcVHj6yC1rk9YyQrJioW36U24UxP6YR') }
    let!(:unspent601) { tx.Output(value: 601, address: '37oUcVHj6yC1rk9YyQrJioW36U24UxP6YR') }

    before do
      allow(tx).to receive(:output_value) { 700 }
    end

    context 'when unspents create dust' do
      it 'should skip the ones that create dust' do
        unspents = [ unspent300, unspent300, unspent200, unspent100 ]
        expect(tx.process_unspents(unspents).map(&:output).map(&:value)).to eq [300, 300, 100]
      end
    end

    context 'when unspents do not create dust' do
      it 'should fund' do
        unspents = [ unspent300, unspent100, unspent300, unspent200 ]
        expect(tx.process_unspents(unspents).map(&:output).map(&:value)).to eq [300, 100, 300]
      end
    end

    context 'when it never gets funded' do
      it 'should raise forbidden' do
        unspents = [ unspent300 ]
        expect { tx.process_unspents(unspents) }.to raise_error CoinOp::Bit::Transaction::Forbidden
      end
    end

    context 'when there is a weird case' do
      it 'should produce dust unnecessarily' do
        unspents = [ unspent601, unspent500, unspent500, unspent400 ]
        expect(tx.process_unspents(unspents).map(&:output).map(&:value)).to eq [601, 500]
      end
    end
  end
end