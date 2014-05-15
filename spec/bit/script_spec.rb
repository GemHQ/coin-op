require 'spec_helper'

include CoinOp::Bit
include CoinOp::Encodings

describe Script do
  let(:blob) { 'OP_DUP OP_HASH160 7b936f13a9a2f0f2c30520c5cb24bc76a148d696 OP_EQUALVERIFY OP_CHECKSIG' }
  let(:script) { build(:script) }

  describe '#initialize' do
    before(:each) do
      Bitcoin::Script.stub(:binary_from_string).with(anything()) { blob }
      Bitcoin::Script.stub(:to_address_script).with(anything()) { blob }
      Bitcoin::Script.stub(:to_pubkey_script).with(anything()) { blob }
      Bitcoin::Script.stub(:to_multisig_script).with(anything(), anything()) { blob }
      Bitcoin::Script.stub(:to_multisig_script_sig).with(anything()) { blob }
    end

    context 'with a string' do
      it 'calls binary_from_string' do
        expect(Bitcoin::Script).to receive(:binary_from_string).with(blob)
        Script.new(blob)
      end
    end

    context 'with string option' do
      it 'calls binary_from_string' do
        expect(Bitcoin::Script).to receive(:binary_from_string).with(blob)
        Script.new(string: blob)
      end
    end

    context 'with blob option' do
      it 'sets the blob attribute directly' do
        example = Script.new(blob: blob)
        example.to_blob.should eql(blob)
      end
    end

    context 'with hex option' do
      it 'decodes the blob from hex' do
        example = Script.new(hex: blob)
        example.to_blob.should eql(decode_hex(blob))
      end
    end

    context 'with address option' do
      it 'calls to_address_script' do
        expect(Bitcoin::Script).to receive(:to_address_script).with(blob)
        Script.new(address: blob)
      end
    end

    context 'with public key option' do
      it 'calls to_pubkey_script' do
        expect(Bitcoin::Script).to receive(:to_pubkey_script).with(blob)
        Script.new(public_key: blob)
      end
    end

    context 'with public keys option' do
      it 'calls to_multisig_script' do
        expect(Bitcoin::Script).to receive(:to_multisig_script).with(true, blob)
        Script.new(public_keys: blob, needed: true)
      end
    end

    context 'with signatures option' do
      it 'calls to_multisig_script_sig' do
        expect(Bitcoin::Script).to receive(:to_multisig_script_sig).with(blob)
        Script.new(signatures: blob)
      end
    end

    context 'with no options' do
      it 'raises ArgumentError' do
        expect {
          Script.new
        }.to raise_error(ArgumentError)
      end
    end

  end

  describe '#to_hash' do
    it 'should have the correct keys present' do
      hash = script.to_hash
      expect(hash.has_key?(:type)).to_not be_nil
      expect(hash.has_key?(:string)).to_not be_nil
    end
  end

end