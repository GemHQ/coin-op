require 'spec_helper'

describe CoinOp::Bit::Input do
  describe '.new_with_output' do
    it 'should set transaction, index, output, native, scriptsig' do
      output = double('output', transaction_hash: 'hash', index: 3, is_a?: true)
      t = CoinOp::Bit::Input.new_with_output(transaction: 1, index: 2, output: output, script_sig_asm: 'blah')
      expect(t.instance_variable_get('@transaction')).to eq 1
      expect(t.index).to eq 2
      expect(t.output).to eq output
      expect(t.native.prev_out).to eq CoinOp::Encodings.decode_hex('hash').reverse
      expect(t.native.prev_out_index).to eq 3
      expect(t.script_sig).to_not be_nil
    end
  end

  describe '.new_without_output' do
    it 'should set native, index only' do
      t = CoinOp::Bit::Input.new_without_output(index: 0, prev_out_index: 42, prev_transaction_hash: 'aaa')
      expect(t.index).to eq 0
      expect(t.native.prev_out_index).to eq 42
      expect(t.native.prev_out).to eq CoinOp::Encodings.decode_hex('aaa').reverse
      expect(t.output).to be_nil
    end
  end
end