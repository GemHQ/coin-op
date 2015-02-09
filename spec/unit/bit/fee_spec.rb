require 'spec_helper'

describe CoinOp::Bit::Fee do

  describe '.estimate' do
    it 'should not modify payees' do
      unspents = [
          double('unspent', value: 1, confirmations: 1),
          double('unspent', value: 2, confirmations: 2),
          double('unspent', value: 3, confirmations: 3),
          double('unspent', value: 4, confirmations: 4)
      ]
      payees = [
          { value: 1 },
          { value: 2 },
          { value: 3 },
          { value: 4 },
      ]
      expect { CoinOp::Bit::Fee.estimate(unspents, payees) }.to change { payees.size }.by 0
    end

    context 'when tx is < size threshold, the minimum output is > output threshold,
        and the priority is > priority threshold' do
      it 'should return 0' do

      end
    end

    context 'when all three of the conditions are not met' do
      it 'should return the fee' do

      end
    end
  end
end