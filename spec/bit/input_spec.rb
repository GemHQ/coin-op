require 'spec_helper'

include CoinOp::Bit
include CoinOp::Encodings

describe Input do
  let(:output) { build(:output) }
  let(:input) { build(:input, output: output) }
  let(:blob) { '123456abcdef' }

  describe '#initialize' do
    context 'with an output object' do
      it 'sets the output' do
        input.output.should_not be_nil
        input.output.should eql(output)
      end

      it 'sets a native input' do
        input.native.should_not be_nil
      end
    end
  end

  describe '#binary_sig_hash=' do
    it 'sets the binary and base58 sig hash' do
      input.binary_sig_hash = blob
      input.binary_sig_hash.should_not be_nil
      input.sig_hash.should_not be_nil
      input.sig_hash.should eql(base58(blob))
    end
  end

  describe '#script_sig=' do
    it 'sets the script sig' do
      input.script_sig = blob
      input.script_sig.should eql(Script.new(blob: blob).to_s)
    end
  end

  describe '#to_hash' do
    let(:complete_input) {
      input = build(:input, output: output)
      input.binary_sig_hash = blob
      input.script_sig = blob
      input
    }

    it 'returns a hash representation' do
      hash = complete_input.to_hash
      hash.has_key?(:output).should be_true
      hash.has_key?(:signatures).should be_true
      hash.has_key?(:sig_hash).should be_true
      hash.has_key?(:script_sig).should be_true
    end
  end
end