require 'spec_helper'

describe CoinOp::Bit::Script do
  describe '#initialize' do
    context 'the literal options' do
      it 'should equal the same thing' do
        s = 'OP_DUP OP_HASH160 2N3DdaZ8K9PmxXYXmwj9QZcPbcgqqPcs8hM OP_EQUALVERIFY OP_CHECKSIG'
        b = Bitcoin::Script.binary_from_string(s)
        h = CoinOp::Encodings.hex(b)
        string = CoinOp::Bit::Script.new(s).to_blob
        string2 = CoinOp::Bit::Script.new(string: s).to_blob
        blob = CoinOp::Bit::Script.new(blob: b).to_blob
        hex = CoinOp::Bit::Script.new(hex: h).to_blob
        expect(string).to eq string2
        expect(string2).to eq blob
        expect(string).to eq hex
      end
    end
  end
end