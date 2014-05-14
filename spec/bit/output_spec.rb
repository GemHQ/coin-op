require 'spec_helper'

include CoinOp::Bit
include CoinOp::Encodings

describe Output do

  let(:output) { build(:output) }
  let(:transaction) { build(:transaction) }
  let(:transaction_hash) { '7KxGcWup3dvGbms5asKi3M6s2HL998oroR9qWq4BgFsY' }
  let(:output_with_transaction_hash) { build(:output, transaction_hash: transaction_hash) }
  let(:output_with_transaction) { build(:output, transaction: transaction) }

  describe '#initialize' do
    context 'with a value and script string' do
      it 'has the correct value' do
        output.value.should eql(21_000_000)
      end

      it 'has a script with the correct type' do
        output.script.should_not be_nil
        output.script.should be_kind_of(Script)
      end

      it 'has a native output' do
        output.native.should_not be_nil
      end
    end
  end

  describe '#set_transaction' do
    it 'sets the transaction and index' do
      output.set_transaction(transaction, 0)
      output.transaction.should eql(transaction)
      output.index.should eql(0)
    end
  end

  describe '#transaction_hash' do
    context 'with a transaction hash' do
      it 'returns the raw transaction hash' do
        output_with_transaction_hash.transaction_hash.should eql(decode_base58(transaction_hash))
      end
    end

    context 'with a transaction' do
      it 'returns the transaction hash of the transaction' do
        output_with_transaction.transaction_hash.should eql(transaction.binary_hash)
      end
    end
  end

  describe '#to_hash' do
    it 'returns a hash representation' do
      hash = output_with_transaction.to_hash
      hash.has_key?(:transaction_hash).should be_true
      hash.has_key?(:index).should be_true
      hash.has_key?(:value).should be_true
      hash.has_key?(:script).should be_true
      hash.has_key?(:address).should be_true
      hash.has_key?(:metadata).should be_true
    end
  end

end



