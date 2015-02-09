require 'spec_helper'

describe CoinOp::Bit::Fee do

  describe '.estimate' do
      let(:unspents) do
        [
          double('unspent', value: 60_000_000, confirmations: 1),
          double('unspent', value: 50_000_000, confirmations: 2),
        ]
      end
      let(:payees) do
        [
          double('payee', value: 10_000_010)
        ]
      end
    it 'should not modify payees' do
      expect { CoinOp::Bit::Fee.estimate(unspents, payees) }.to change { payees.size }.by 0
    end

    context 'when tx is < size threshold, the minimum payee is > payee threshold,
        and the priority is > priority threshold' do
      before :each do
        expect(CoinOp::Bit::Fee).to receive(:high_priority?).and_return true
        expect(CoinOp::Bit::Fee).to receive(:big_outputs?).and_return true
      end
      context 'when tx_size is provided' do
        it 'should return 0' do
          expect(CoinOp::Bit::Fee).to receive(:small?).with(42).and_return true
          expect(CoinOp::Bit::Fee.estimate(unspents, payees, 42)).to eq 0
        end
      end

      context 'when tx_size is not provided' do
        it 'should return 0' do
          size = double('tx_size')
          expect(CoinOp::Bit::Fee).to receive(:estimate_tx_size).and_return size
          expect(CoinOp::Bit::Fee).to receive(:small?).with(size).and_return true
          expect(CoinOp::Bit::Fee.estimate(unspents, payees)).to eq 0
        end
      end
    end

    context 'big_outputs? is true' do
      it 'should return the fee' do
        expect(CoinOp::Bit::Fee).to receive(:fee_for_bytes).and_return 42
        expect(CoinOp::Bit::Fee).to receive(:big_outputs?).and_return true
        expect(CoinOp::Bit::Fee).to receive(:small?).and_return false
        expect(CoinOp::Bit::Fee).to receive(:high_priority?).and_return false
        expect(CoinOp::Bit::Fee.estimate(unspents, payees)).to eq 42
      end
    end

    context 'small? is true' do
      it 'should return the fee' do
        expect(CoinOp::Bit::Fee).to receive(:fee_for_bytes).and_return 42
        expect(CoinOp::Bit::Fee).to receive(:big_outputs?).and_return false
        expect(CoinOp::Bit::Fee).to receive(:small?).and_return true
        expect(CoinOp::Bit::Fee).to receive(:high_priority?).and_return false
        expect(CoinOp::Bit::Fee.estimate(unspents, payees)).to eq 42
      end
    end

    context 'high_priority? is true' do
      it 'should return the fee' do
        expect(CoinOp::Bit::Fee).to receive(:fee_for_bytes).and_return 42
        expect(CoinOp::Bit::Fee).to receive(:big_outputs?).and_return false
        expect(CoinOp::Bit::Fee).to receive(:small?).and_return false
        expect(CoinOp::Bit::Fee).to receive(:high_priority?).and_return true
        expect(CoinOp::Bit::Fee.estimate(unspents, payees)).to eq 42
      end
    end
  end
end