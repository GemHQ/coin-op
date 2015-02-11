require 'spec_helper'

describe CoinOp::Bit::Output do
  describe '#initialize' do
    context 'neither transaction nor transaction hash are provided' do
      it 'should raise error' do
        expect { CoinOp::Bit::Output.new(index: 1, value: 2, script: '3') }.to raise_error ArgumentError
      end
    end

    context 'when address is provided' do
      it 'should set script with the address' do
        expect(CoinOp::Bit::Output.new(index: 1, value: 2, address: '37oUcVHj6yC1rk9YyQrJioW36U24UxP6YR', transaction_hash: 4).script).to eq CoinOp::Bit::Script.new(address: '37oUcVHj6yC1rk9YyQrJioW36U24UxP6YR')
      end
    end

    context 'when script is provided' do
      it 'should set script with script' do
        expect(CoinOp::Bit::Output.new(index: 1, value: 2, script: 'ah', transaction_hash: 4).script).to eq CoinOp::Bit::Script.new('ah')
      end
    end

    context 'when metadata is provided' do
      it 'should set metadata' do
        expect(CoinOp::Bit::Output.new(index: 1, value: 2, script: '3', metadata: { what: 'yeah' }, transaction_hash: 4).metadata).to eq({ what: 'yeah', confirmations: 0 })
      end
    end

    context 'when confirmations provided' do
      it 'should set confirmations on metadata' do
        expect(CoinOp::Bit::Output.new(index: 1, value: 2, confirmations: 3, script: '4', transaction_hash: 4).metadata).to eq({ confirmations: 3 })
      end
    end

    context 'if neither script nor address provided' do
      it 'should raise argument error' do
        expect { CoinOp::Bit::Output.new(index: 1, value: 2, transaction_hash: 3) }.to raise_error ArgumentError
      end
    end

    it 'should set native' do
      expect(CoinOp::Bit::Output.new(index: 1, value: 2, script: 'a', transaction_hash: 3).native)
          .to eq Bitcoin::Protocol::TxOut.from_hash('value' => '2', 'scriptPubKey' => CoinOp::Bit::Script.new('a').to_s)
    end
  end
end