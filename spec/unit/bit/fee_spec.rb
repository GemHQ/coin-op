require 'spec_helper'

describe CoinOp::Bit::Fee do

  describe '.estimate' do
    let(:unspents) { [ double('unspent', value: 1, confirmations: 1) ] }
    let(:payees) { [ double('payee', value: 1) ] }

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
        expect(CoinOp::Bit::Fee).to receive(:small?).and_return true
        expect(CoinOp::Bit::Fee.estimate(unspents, payees)).to eq 42
      end
    end

    context 'small? is true' do
      it 'should return the fee' do
        expect(CoinOp::Bit::Fee).to receive(:fee_for_bytes).and_return 42
        expect(CoinOp::Bit::Fee).to receive(:big_outputs?).and_return false
        expect(CoinOp::Bit::Fee).to receive(:small?).and_return true
        expect(CoinOp::Bit::Fee.estimate(unspents, payees)).to eq 42
      end
    end
  end

  describe '.nominal_change' do
    let(:unspents) do
      [
        double('unspent', value: 100),
        double('unspent', value: 200),
        double('unspent', value: 200),
      ]
    end
    let(:payees) do
      [
        double('payee', value: 100),
        double('payee', value: 50),
        double('payee', value: 50)
      ]
    end

    it 'should return the difference in sums of values' do
      expect(CoinOp::Bit::Fee.nominal_change(unspents, payees).value).to eq 300
    end
  end

  describe '.priority' do
    context 'when confirmations is nil' do
      it 'should return 0' do
        unspents = [double('unspent', value: 1, confirmations: nil)]
        expect(CoinOp::Bit::Fee.priority(42, unspents)).to eq 0
      end
    end

    it 'should return sum of (value * confirmations) / tx_size' do
      unspents = [
          double('unspent', value: 1, confirmations: 4),
          double('unspent', value: 5, confirmations: 10),
          double('unspent', value: 10, confirmations: 3)
      ]
      expect(CoinOp::Bit::Fee.priority(21, unspents)).to eq 4
    end
  end

  describe ''
end