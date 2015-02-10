require 'spec_helper'

describe CoinOp::Bit::Input do
  describe '#initialize' do
    it 'should set transaction, index, output, native, scriptsig' do
      output = double('output', transaction_hash: 'hash', index: 3, is_a?: CoinOp::Bit::Output)
      t = CoinOp::Bit::Input.new(transaction: 1, index: 2, output: output, script_sig_asm: 'blah')
      expect(t.instance_variable_get('@transaction')).to eq 1
      expect(t.index).to eq 2
      expect(t.output).to eq output
      expect(t.native.prev_out).to eq CoinOp::Encodings.decode_hex('hash').reverse
      expect(t.native.prev_out_index).to eq 3
      expect(t.script_sig).to_not be_nil
    end

  end
end