require 'spec_helper'

include CoinOp::Bit
include CoinOp::Encodings

describe Transaction do
  let(:native_transaction) { build(:native_transaction) }

  describe '.native' do
    context 'with a valid native transaction' do
      it 'populates the correct inputs' do

      end

      it 'populates the correct outputs' do

      end
    end
  end

  describe '.data' do
    context 'with a valid hash representation of a transaction' do
      it 'populates the correct inputs' do

      end

      it 'populates the correct outputs' do

      end
    end
  end

  describe '#initialize' do

  end

  describe '#add_input' do

  end

  describe '#add_output' do

  end

  describe '#update_native' do

  end

  describe '#validate_syntax' do

  end

end