require_relative "setup"

include CoinOp::Bit

describe "Output" do
  include CoinOpTests::Bitcoin

  def empty_transaction
    @empty_transaction ||= Transaction.new
  end

  def script_string
    "OP_DUP OP_HASH160 7b936f13a9a2f0f2c30520c5cb24bc76a148d696 OP_EQUALVERIFY OP_CHECKSIG"
  end


  it "can be created as a standalone" do
    value = 21_000_000
    output = Output.new(:value => value, :script => script_string)
    assert_equal value, output.value
    assert_kind_of Script, output.script
  end

  it "can be created as a standalone, then associated" do
    value = 21_000_000
    output = Output.new(:value => value, :script => script_string)
    empty_transaction.add_output output
  end

  it "can be created with an address" do
    output = Output.new(:value => 22_000, :address => "2MuWs1hsyA1AkznLz1vFixEjbrZmetLrhF8")
    assert_equal(
      # The value in the middle is simply the hex version of the address
      "OP_HASH160 18e565c292cf09360d8fc0a1fb477ad4b262e65c OP_EQUAL",
      output.script.to_s
    )
  end

end



