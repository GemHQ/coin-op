require_relative "setup"

Fee = CoinOp::Bit::Fee
Output = CoinOp::Bit::Output

describe "Bit::Fee" do

  specify "#priority" do

    # example from https://en.bitcoin.it/wiki/Transaction_fees
    priority = Fee.priority :size => 500, :unspents => [
      {:value => 500_000_000, :age => 10},
      {:value => 200_000_000, :age => 3},
    ]
    assert_equal 11_200_000, priority

    # Halve the value, double the age
    priority = Fee.priority :size => 500, :unspents => [
      {:value => 250000000, :age => 20},
      {:value => 100000000, :age => 6},
    ]
    assert_equal 11_200_000, priority

    # Double the size, double the age
    priority = Fee.priority :size => 1000, :unspents => [
      {:value => 500_000_000, :age => 20},
      {:value => 200_000_000, :age => 6},
    ]
    assert_equal 11_200_000, priority
  end

  specify "#estimate_tx_size" do
    size = Fee.estimate_tx_size(1, 1)
    assert_equal 192, size

    size = Fee.estimate_tx_size(2, 2)
    assert_equal 374, size

    size = Fee.estimate_tx_size(8, 2)
    assert_equal 1262, size
  end

  describe "#estimate" do

    specify "has fee when unknown priority" do
      unspents = [
        Output.new(:value => 100_000_000)
      ]
      payees = [
        Output.new(:value => 1_500_000)
      ]
      fee = Fee.estimate(unspents, payees)
      assert_equal 10_000, fee
    end

    specify "no fee when small tx size, large outputs, high priority" do
      unspents = [
        Output.new(:value => 100_000_000, :confirmations => 150)
      ]
      payees = [
        Output.new(:value => 1_500_000)
      ]
      fee = Fee.estimate(unspents, payees)
      assert_equal 0, fee
    end

    specify "has fee when small tx size, large outputs, low priority" do
      unspents = [
        Output.new(:value => 100_000_000, :confirmations => 2)
      ]
      payees = [
        Output.new(:value => 1_500_000)
      ]
      fee = Fee.estimate(unspents, payees)
      assert_equal 10_000, fee
    end

    specify "has fee when small tx size, small outputs, high priority" do
      unspents = [
        Output.new(:value => 100_000_000, :confirmations => 150)
      ]
      payees = [
        Output.new(:value => 900_000)
      ]
      fee = Fee.estimate(unspents, payees)
      assert_equal 10_000, fee
    end

    specify "has fee when large tx size, large outputs, high priority" do
      unspents = [
        Output.new(:value => 100_000_000, :confirmations => 150),
        Output.new(:value => 100_000_000, :confirmations => 150),
        Output.new(:value => 100_000_000, :confirmations => 150),
        Output.new(:value => 100_000_000, :confirmations => 150),
        Output.new(:value => 100_000_000, :confirmations => 150),
        Output.new(:value => 100_000_000, :confirmations => 150),
        Output.new(:value => 100_000_000, :confirmations => 150)
      ]
      payees = [
        Output.new(:value => 1_500_000)
      ]
      fee = Fee.estimate(unspents, payees)
      assert_equal 20_000, fee
    end
  end

end

